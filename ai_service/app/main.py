from __future__ import annotations

import re
from pathlib import Path
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
from .ocr_infer import load_receipt_ocr_bundles
from .ocr_real import easyocr_available, parse_receipt_bytes_easyocr
from .parsers import extract_date_from_note, normalize_note
from .receipt_parse import ReceiptParseResult, parse_receipt_bytes
from .rules import rule_based_category
from .transaction_intent import adjust_category_for_type, infer_transaction_type


MODELS_DIR = Path(__file__).resolve().parents[1] / "models"

app = FastAPI(title="Expense AI Service", version="0.2.0")

_forecast: Optional[ForecastBundle] = None
_classify: Optional[ClassifyBundle] = None
_ocr = None


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
    global _forecast, _classify, _ocr
    MODELS_DIR.mkdir(parents=True, exist_ok=True)
    _forecast = load_forecast_bundle(MODELS_DIR)
    _classify = load_classify_bundle(MODELS_DIR)
    _ocr = load_receipt_ocr_bundles(MODELS_DIR)


@app.get("/health")
def health() -> dict[str, Any]:
    return {
        "ok": True,
        "easyocr_available": easyocr_available(),
        "gemini_available": gemini_available(),
        "forecast_loaded": _forecast is not None,
        "classify_loaded": _classify is not None,
        "ocr_amount_loaded": _ocr is not None and _ocr.amount is not None,
        "ocr_merchant_loaded": _ocr is not None and _ocr.merchant is not None,
        "ocr_date_loaded": _ocr is not None and _ocr.date is not None,
        "ocr_line_loaded": _ocr is not None and _ocr.line is not None,
    }


@app.post("/api/chat", response_model=ChatResponse)
def chat(req: ChatRequest) -> ChatResponse:
    """Hỏi đáp về chi tiêu cá nhân. Có Gemini key dùng Gemini, không thì rule-based."""
    return chat_answer(req)


class ForecastRequest(BaseModel):
    daily_expenses_vnd: list[float] = Field(
        min_length=1,
        description="Chuỗi tổng chi tiêu mỗi ngày (VND), thứ tự thời gian; cần đủ dài cho cửa sổ.",
    )
    last_observation_date: Optional[str] = Field(
        default=None,
        description="Ngày của quan sát cuối (YYYY-MM-DD). Cần cho mô hình có đặc trưng lịch; nếu bỏ qua dùng ngày hiện tại.",
    )


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

    # ── Phân loại: keyword ngắn → model argmax → rule-based ─────────────────
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
    if explicit_date is not None:
        tx_date_str = explicit_date.isoformat()
    else:
        tx_date_str = parsed.assumed_date.isoformat()

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


class ReceiptParseResponse(BaseModel):
    amount_vnd: Optional[int] = None
    transaction_date: Optional[str] = None
    merchant: Optional[str] = None
    description: Optional[str] = None
    category: Optional[str] = None
    type: str = "EXPENSE"
    category_confidence: Optional[float] = None
    field_confidence: dict[str, Optional[float]] = Field(default_factory=dict)
    raw: dict[str, Any] = Field(default_factory=dict)
    needs_review: bool = False
    ocr_engine: str = "crnn"


@app.post("/api/ocr/receipt/parse", response_model=ReceiptParseResponse)
async def ocr_receipt_parse(file: UploadFile = File(...)) -> ReceiptParseResponse:
    """
    Phân tích hóa đơn từ ảnh → số tiền, ngày, cửa hàng, mô tả, danh mục.

    Engine ưu tiên: EasyOCR (nếu đã pip install easyocr) — hoạt động với ảnh thật.
    Fallback: CRNN models (cần ocr_amount_model.pt).
    """
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="File rong")
    try:
        result: ReceiptParseResult = parse_receipt_bytes(
            data, _ocr, _classify, prefer_easyocr=True
        )
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Khong doc duoc anh: {exc}") from exc
    return ReceiptParseResponse(**result.to_dict())


@app.post("/api/ocr/receipt/parse-easyocr")
async def ocr_receipt_easyocr(file: UploadFile = File(...)) -> dict[str, Any]:
    """
    EasyOCR-only endpoint — hoạt động ngay cả khi chưa train CRNN models.
    Hỗ trợ bill POS, bill chụp, biên lai chuyển khoản ngân hàng / ví điện tử.
    """
    if not easyocr_available():
        raise HTTPException(
            status_code=503,
            detail="EasyOCR chua duoc cai. Chay: pip install easyocr",
        )
    data = await file.read()
    if not data:
        raise HTTPException(status_code=400, detail="File rong")
    try:
        from PIL import Image
        from io import BytesIO
        img = Image.open(BytesIO(data))
        ocr_res = parse_receipt_bytes_easyocr(data)
        # Classify
        from .receipt_parse import _classify_from_text
        cat, cat_conf, tx_type = _classify_from_text(
            _classify,
            ocr_res.merchant or "",
            ocr_res.description or "",
        )
        return {
            "amount_vnd": ocr_res.amount_vnd,
            "transaction_date": ocr_res.transaction_date,
            "merchant": ocr_res.merchant,
            "description": ocr_res.description,
            "category": cat,
            "type": tx_type,
            "category_confidence": round(cat_conf, 4) if cat_conf else None,
            "is_bank_transfer": ocr_res.is_bank_transfer,
            "ocr_engine": "easyocr",
            "raw": {
                "amount": ocr_res.raw_amount,
                "date": ocr_res.raw_date,
                "all_lines": ocr_res.all_lines[:15],
            },
            "field_confidence": {
                "amount": round(ocr_res.conf_amount, 4),
                "date": round(ocr_res.conf_date, 4),
                "merchant": round(ocr_res.conf_merchant, 4),
            },
        }
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Loi OCR: {exc}") from exc


@app.post("/api/ocr/receipt/amount")
async def ocr_receipt_amount_only(file: UploadFile = File(...)) -> dict[str, Any]:
    """Chi doc so tien — tu dong chon EasyOCR hoac CRNN."""
    data = await file.read()
    try:
        result = parse_receipt_bytes(data, _ocr, _classify, prefer_easyocr=True)
    except Exception as exc:
        raise HTTPException(status_code=400, detail=f"Loi: {exc}") from exc
    return {
        "amount_vnd": result.amount_vnd,
        "raw_text": result.raw.get("amount", ""),
        "confidence": result.field_confidence.amount,
        "ocr_engine": result.ocr_engine,
    }
