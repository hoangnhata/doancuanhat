from __future__ import annotations

from pathlib import Path

from dotenv import load_dotenv

load_dotenv(Path(__file__).resolve().parents[1] / ".env")

import re
from typing import Any, Optional

from fastapi import FastAPI, File, HTTPException, UploadFile
from pydantic import BaseModel, Field

from .chat import ChatRequest, ChatResponse, chat_answer, gemini_available
from .category_hints import hint_category
from .classify_ood import is_amount_only_text
from .classify_infer import (
    ClassifyBundle,
    load_classify_bundle,
    predict_top_label,
)
from .forecast_infer import ForecastBundle, load_forecast_bundle, predict_horizon_vnd
from .ocr_recognizer import load_recognizer_bundle
from .parsers import extract_date_from_note, normalize_note
from .rules import rule_based_category
from .transaction_intent import adjust_category_for_type, infer_transaction_type
from .transfer_parse import (
    TransferNotDetectedError,
    TransferParseResult,
    TransferRecognizerMissingError,
    parse_transfer_minimal_bytes,
)


MODELS_DIR = Path(__file__).resolve().parents[1] / "models"

app = FastAPI(title="Expense AI Service", version="0.3.0")

_forecast: Optional[ForecastBundle] = None
_classify: Optional[ClassifyBundle] = None
_recognizer = None


class CategorizeRequest(BaseModel):
    text: str = Field(min_length=1)


class BatchCategorizeRequest(BaseModel):
    text: str = Field(
        min_length=1,
        description="Raw input containing 1+ items separated by comma/semicolon/newlines/+/&/và",
    )


class CategorizeResponse(BaseModel):
    type: str = Field(default="EXPENSE", description="EXPENSE | INCOME")
    category: str
    amount: Optional[int] = None
    description: str
    transaction_date: Optional[str] = Field(
        default=None,
        description="Ngày giao dịch YYYY-MM-DD (từ câu nhập hoặc hôm nay)",
    )
    confidence: Optional[float] = Field(default=None, description="AI confidence (0-1), None nếu dùng rule-based")


@app.on_event("startup")
def _startup() -> None:
    global _forecast, _classify, _recognizer
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    print("Loading forecast model...", flush=True)
    _forecast = load_forecast_bundle(MODELS_DIR)
    print(f"Forecast loaded: {_forecast is not None}", flush=True)
    print("Loading classify model...", flush=True)
    _classify = load_classify_bundle(MODELS_DIR)
    print(f"Classify loaded: {_classify is not None}", flush=True)
    print("Loading OCR recognizer...", flush=True)
    _recognizer = load_recognizer_bundle(MODELS_DIR)
    print(f"OCR loaded: {_recognizer is not None}", flush=True)
    print("AI service ready.", flush=True)


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "ok": True,
        "gemini_available": gemini_available(),
        "forecast_loaded": _forecast is not None,
        "classify_loaded": _classify is not None,
        "ocr_transfer_loaded": _recognizer is not None,
    }


@app.post("/api/chat", response_model=ChatResponse)
def chat(req: ChatRequest) -> ChatResponse:
    return chat_answer(req)


class ForecastRequest(BaseModel):
    daily_expenses_vnd: list[float] = Field(min_length=1)
    last_observation_date: Optional[str] = None


class ForecastResponse(BaseModel):
    predicted_next_days_vnd: list[int]
    horizon: int
    window: int


@app.post("/api/forecast", response_model=ForecastResponse)
def forecast_next_days(req: ForecastRequest) -> ForecastResponse:
    if _forecast is None:
        raise HTTPException(
            status_code=503,
            detail="Chưa có forecast_model.pt — chạy train_forecast.ipynb và lưu vào models/",
        )
    w = _forecast.window
    if len(req.daily_expenses_vnd) < w:
        raise HTTPException(
            status_code=400,
            detail=f"Cần ít nhất {w} ngày dữ liệu, hiện có {len(req.daily_expenses_vnd)}",
        )
    preds = predict_horizon_vnd(
        _forecast,
        req.daily_expenses_vnd,
        last_date=req.last_observation_date,
    )
    return ForecastResponse(
        predicted_next_days_vnd=preds,
        horizon=len(preds),
        window=w,
    )


@app.post("/api/categorize", response_model=CategorizeResponse)
def categorize(req: CategorizeRequest) -> CategorizeResponse:
    parsed = normalize_note(req.text)
    conf: Optional[float] = None
    text_for_cls = parsed.cleaned_text
    if is_amount_only_text(text_for_cls):
        explicit = extract_date_from_note(req.text)
        return CategorizeResponse(
            type="EXPENSE",
            category="Khác",
            amount=parsed.amount,
            description=parsed.description,
            transaction_date=(
                explicit.isoformat() if explicit else parsed.assumed_date.isoformat()
            ),
            confidence=None,
        )

    hint = hint_category(text_for_cls)
    min_conf = 0.45
    if _classify is not None:
        min_conf = float(
            _classify.meta.get("confidence_threshold", _classify.meta.get("min_conf", 0.45))
        )

    if hint:
        cat = hint
    elif _classify is not None:
        top_cat, conf = predict_top_label(_classify, text_for_cls)
        if conf >= min_conf:
            cat = top_cat
        else:
            rb = rule_based_category(text_for_cls)
            cat = rb if rb != "Khác" else top_cat
            conf = None
    else:
        cat = rule_based_category(text_for_cls) or hint or "Khác"

    tx_type = infer_transaction_type(parsed.cleaned_text, cat)
    cat = adjust_category_for_type(parsed.cleaned_text, cat, tx_type)

    explicit_date = extract_date_from_note(req.text)
    tx_date_str = (
        explicit_date.isoformat() if explicit_date is not None
        else parsed.assumed_date.isoformat()
    )

    return CategorizeResponse(
        type=tx_type,
        category=cat,
        amount=parsed.amount,
        description=parsed.description,
        transaction_date=tx_date_str,
        confidence=round(conf, 4) if conf is not None else None,
    )


@app.post("/api/categorize/batch")
def categorize_batch(req: BatchCategorizeRequest) -> list[CategorizeResponse]:
    raw = (req.text or "").strip()
    if not raw:
        return []
    parts = [
        p.strip()
        for p in re.split(
            r"(?<!\d)\s*,\s*(?!\d)|[;\n+&]|\s+và\s+",
            raw,
            flags=re.IGNORECASE,
        )
        if p.strip()
    ]
    return [categorize(CategorizeRequest(text=p)) for p in parts]


class TransferParseResponse(BaseModel):
    """OCR bill chuyển khoản — chỉ số tiền + ngày; phân loại qua /api/categorize."""
    amount_vnd: Optional[int] = None
    transaction_date: Optional[str] = None
    confidence: Optional[float] = None
    needs_review: bool = False
    ocr_engine: str = "crnn_scratch"
    bank_transfer: bool = True
    raw_lines: list[str] = Field(default_factory=list)


@app.post("/api/ocr/transfer/parse", response_model=TransferParseResponse)
async def ocr_transfer_parse(
    file: UploadFile = File(...),
) -> TransferParseResponse:
    """OCR bill chuyển khoản — chỉ đọc số tiền và ngày giao dịch."""
    if _recognizer is None:
        raise HTTPException(
            status_code=503,
            detail="Chua co model OCR (ocr_reco_*). Hay train: python data/train_ocr_recognizer.py --bank-only",
        )
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="File rong")
    try:
        result: TransferParseResult = parse_transfer_minimal_bytes(data, _recognizer)
    except TransferNotDetectedError as exc:
        raise HTTPException(status_code=400, detail=str(exc)) from exc
    except TransferRecognizerMissingError as exc:
        raise HTTPException(status_code=503, detail=str(exc)) from exc
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Khong doc duoc anh: {exc}") from exc
    d = result.to_dict()
    return TransferParseResponse(
        amount_vnd=d.get("amount_vnd"),
        transaction_date=d.get("transaction_date"),
        confidence=d.get("confidence"),
        needs_review=bool(d.get("needs_review", False)),
        ocr_engine=d.get("ocr_engine", "crnn_scratch"),
        bank_transfer=True,
        raw_lines=d.get("raw_lines") or [],
    )
