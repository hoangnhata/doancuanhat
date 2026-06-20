"""
Pipeline OCR bill chuyển khoản (transfer-only).

    ảnh full → detect dòng → CRNN recognize → TextBox list
    (không parse merchant / món / VAT / POS).
"""

from __future__ import annotations

import re
from io import BytesIO

from PIL import Image, ImageEnhance, ImageOps

from .ocr_detect import LineBox, detect_lines
from .ocr_postprocess import correct_line, correct_transfer_note
from .ocr_real import (
    TextBox,
    _extract_date_from_lines,
    _extract_transfer_amount,
    _score_date_candidate,
    _TRANSFER_SUCCESS_LINE,
    boxes_to_lines,
)
from .ocr_recognizer import RecognizerBundle, recognize_batch

_AMOUNT_LINE = re.compile(r"\bvnd\b|vnđ|đ\b", re.IGNORECASE)
_VIETIN_HINT = re.compile(
    r"vetin|vietin|vetn\s*benk|vetn\s*bonk|vetn|ipay|44\d{3,}|"
    r"chuyen\s*tien|chuyển\s*tiền|ngan\s*hang\s*cong",
    re.IGNORECASE,
)

# Vùng crop cố định VietinBank iPay (portrait) — layout ổn định khi detect_lines fail
_VIETIN_AMOUNT_REGIONS = (
    (0.55, 0.505, 0.95, 0.575),
    (0.35, 0.508, 0.95, 0.572),
    (0.35, 0.568, 0.95, 0.628),
    (0.30, 0.48, 0.95, 0.60),
)
_VIETIN_DATETIME_REGIONS = (
    (0.50, 0.155, 0.98, 0.205),
    (0.52, 0.155, 0.92, 0.205),
    (0.48, 0.152, 0.98, 0.208),
    (0.55, 0.158, 0.98, 0.200),
    (0.52, 0.158, 0.96, 0.205),
    (0.45, 0.14, 0.98, 0.22),
)


def _prep_line_crop(im: Image.Image) -> Image.Image:
    """Tiền xử lý crop — ghi chú app ngân hàng thường rất nhỏ."""
    im = im.convert("L")
    target_h = 52
    if im.height < target_h:
        scale = target_h / max(im.height, 1)
        im = im.resize(
            (max(1, int(im.width * scale)), max(32, int(im.height * scale))),
            Image.LANCZOS,
        )
    im = ImageOps.autocontrast(im, cutoff=2)
    im = ImageOps.expand(im, border=(10, 6, 10, 6), fill=255)
    if im.height < 60:
        scale = 60 / im.height
        im = im.resize(
            (max(1, int(im.width * scale)), 60),
            Image.LANCZOS,
        )
    return im


def _looks_like_short_note(text: str) -> bool:
    if not text or len(text) > 50 or re.search(r"\d{9,}", text):
        return False
    if re.search(r"vnd|vietin|mbbank|chuyen\s*tien", text, re.I):
        return False
    return any(w.islower() for w in text.split()) and not text.isupper()


def _prep_date_gap_crop(im: Image.Image) -> Image.Image:
    """Tiền xử lý vùng ngày nhỏ/mờ dưới số tiền (MB, VietinBank app)."""
    im = im.convert("L")
    im = ImageOps.autocontrast(im, cutoff=1)
    im = ImageEnhance.Contrast(im).enhance(2.0)
    scale = max(3, 120 // max(im.height, 1))
    if scale > 1:
        im = im.resize((im.width * scale, im.height * scale), Image.LANCZOS)
    return _prep_line_crop(im)


def _prep_amount_gap_crop(im: Image.Image) -> Image.Image:
    """Tiền xử lý vùng số tiền lớn/màu sáng trên bill app (MB xanh, vàng…)."""
    im = im.convert("L")
    im = ImageOps.autocontrast(im, cutoff=1)
    im = ImageEnhance.Contrast(im).enhance(2.5)
    scale = max(3, 120 // max(im.height, 1))
    if scale > 1:
        im = im.resize((im.width * scale, im.height * scale), Image.LANCZOS)
    return _prep_line_crop(im)


def _find_amount_box(boxes: list[TextBox]) -> TextBox | None:
    for box in boxes:
        if _AMOUNT_LINE.search(box.text) and _extract_transfer_amount([box.text])[0]:
            return box
    return None


def _find_success_idx(line_texts: list[str]) -> int | None:
    for i, text in enumerate(line_texts):
        if _TRANSFER_SUCCESS_LINE.search(text):
            return i
        if re.search(
            r"(?:chuyển|chuyen|giao\s*d[ií]ch).*thành\s*công|"
            r"(?:chuyển|chuyen|giao\s*dich).*thanh\s*cong",
            text,
            re.I,
        ):
            return i
    return None


def _ocr_amount_strip(
    img: Image.Image,
    line_boxes: list[LineBox],
    line_texts: list[str],
    recognizer: RecognizerBundle,
) -> TextBox | None:
    """OCR lại vùng số tiền — detect thường đọc sai/thiếu trên bill MB nền màu."""
    ow, oh = img.size
    success_idx = _find_success_idx(line_texts)
    if success_idx is not None:
        lb = line_boxes[success_idx]
        gap_top = lb.y1 + max(2, int(oh * 0.006))
        gap_bot = min(oh, lb.y1 + max(90, int(oh * 0.09)))
    else:
        gap_top, gap_bot = int(oh * 0.37), int(oh * 0.44)
    cx0, cx1 = int(ow * 0.12), int(ow * 0.88)
    crop = img.crop((cx0, gap_top, cx1, gap_bot))
    if crop.size[0] < 20 or crop.size[1] < 6:
        return None
    prep = _prep_amount_gap_crop(crop)
    preds = recognize_batch(recognizer, [crop, prep])
    best_text, best_conf = "", 0.0
    for text, conf in preds:
        text = correct_line((text or "").strip())
        if not text:
            continue
        if _extract_transfer_amount([text])[0] and conf > best_conf:
            best_text, best_conf = text, float(conf)
    if not best_text:
        return None
    return TextBox(
        text=best_text,
        conf=best_conf,
        y_top=gap_top / oh,
        y_bot=gap_bot / oh,
        x_left=cx0 / ow,
        x_right=cx1 / ow,
    )


def _ocr_date_bottom_card(
    img: Image.Image,
    recognizer: RecognizerBundle,
) -> TextBox | None:
    """Techcombank/VietinBank — ngày ở cuối thẻ bill (vd: 21 thg 9,2024)."""
    ow, oh = img.size
    cx0, cx1 = int(ow * 0.08), int(ow * 0.92)
    gap_top, gap_bot = int(oh * 0.52), int(oh * 0.72)
    crop = img.crop((cx0, gap_top, cx1, gap_bot))
    if crop.size[0] < 20 or crop.size[1] < 8:
        return None
    prep = _prep_date_gap_crop(crop)
    preds = recognize_batch(recognizer, [crop, prep])
    best_text, best_conf = "", 0.0
    for text, conf in preds:
        text = correct_line((text or "").strip())
        if not text:
            continue
        iso, _, _ = _extract_date_from_lines([text])
        if iso and conf > best_conf:
            best_text, best_conf = text, float(conf)
    if not best_text:
        return None
    return TextBox(
        text=best_text,
        conf=best_conf,
        y_top=gap_top / oh,
        y_bot=gap_bot / oh,
        x_left=cx0 / ow,
        x_right=cx1 / ow,
    )


def _ocr_vietin_fixed_regions(
    img: Image.Image,
    recognizer: RecognizerBundle,
    regions: tuple[tuple[float, float, float, float], ...],
    prep_fn,
    *,
    kind: str,
) -> TextBox | None:
    """OCR crop theo tỷ lệ ảnh — fallback khi detect_lines đọc sai bill VietinBank iPay."""
    ow, oh = img.size
    best_text, best_conf = "", 0.0
    best_box: tuple[int, int, int, int] | None = None
    best_date_score = -999.0
    for x0, y0, x1, y1 in regions:
        cx0, cx1 = int(ow * x0), int(ow * x1)
        gap_top, gap_bot = int(oh * y0), int(oh * y1)
        crop = img.crop((cx0, gap_top, cx1, gap_bot))
        if crop.size[0] < 20 or crop.size[1] < 6:
            continue
        prep = prep_fn(crop)
        preds = recognize_batch(recognizer, [crop, prep])
        for text, conf in preds:
            text = correct_line((text or "").strip())
            if not text:
                continue
            if kind == "amount":
                ok = _extract_transfer_amount([text])[0] is not None
                if ok and conf > best_conf:
                    best_text, best_conf = text, float(conf)
                    best_box = (cx0, gap_top, cx1, gap_bot)
            else:
                iso, raw, dconf = _extract_date_from_lines([text])
                if iso is None:
                    continue
                pick_score = _score_date_candidate(iso, raw or text, dconf, text)
                if pick_score > best_date_score:
                    best_text, best_conf = text, float(conf)
                    best_box = (cx0, gap_top, cx1, gap_bot)
                    best_date_score = pick_score
    if not best_text or best_box is None:
        return None
    cx0, gap_top, cx1, gap_bot = best_box
    return TextBox(
        text=best_text,
        conf=best_conf,
        y_top=gap_top / oh,
        y_bot=gap_bot / oh,
        x_left=cx0 / ow,
        x_right=cx1 / ow,
    )


def _ocr_vietin_amount_fixed(
    img: Image.Image,
    recognizer: RecognizerBundle,
) -> TextBox | None:
    return _ocr_vietin_fixed_regions(
        img, recognizer, _VIETIN_AMOUNT_REGIONS, _prep_amount_gap_crop, kind="amount",
    )


def _ocr_vietin_datetime_fixed(
    img: Image.Image,
    recognizer: RecognizerBundle,
) -> TextBox | None:
    return _ocr_vietin_fixed_regions(
        img, recognizer, _VIETIN_DATETIME_REGIONS, _prep_date_gap_crop, kind="date",
    )


def _date_gap_regions(
    img: Image.Image,
    amt: TextBox,
    boxes: list[TextBox],
) -> list[tuple[int, int, int, int]]:
    """Hai vùng quét ngày: ngay dưới số tiền (MoMo/MB thường) và chồng đáy strip amount (MB xanh)."""
    ow, oh = img.size
    amount_y0 = int(amt.y_top * oh)
    amount_y1 = int(amt.y_bot * oh)
    amount_h = max(8, amount_y1 - amount_y0)
    next_y0 = oh
    for box in sorted(boxes, key=lambda b: b.y_top):
        y0 = int(box.y_top * oh)
        if y0 > amount_y1 + 2:
            next_y0 = min(next_y0, y0)
            break
    cx0, cx1 = max(0, int(ow * 0.18)), min(ow, int(ow * 0.82))
    pad = max(3, int(oh * 0.004))
    below_top = amount_y1 + pad
    below_bot = min(
        next_y0 - pad,
        amount_y1 + max(55, int(oh * 0.035)),
        int(oh * 0.48),
    )
    overlap_top = max(0, amount_y1 - int(amount_h * 0.18))
    overlap_bot = min(
        next_y0 - pad,
        amount_y1 + int(amount_h * 0.12),
    )
    regions: list[tuple[int, int, int, int]] = []
    if below_bot - below_top >= 8:
        regions.append((cx0, below_top, cx1, below_bot))
    if overlap_bot - overlap_top >= 8 and (
        overlap_top != below_top or overlap_bot != below_bot
    ):
        regions.append((cx0, overlap_top, cx1, overlap_bot))
    return regions


def _ocr_date_below_amount(
    img: Image.Image,
    boxes: list[TextBox],
    recognizer: RecognizerBundle,
) -> TextBox | None:
    """OCR lại vùng giữa số tiền và khối chi tiết — detect thường bỏ sót dòng ngày MB."""
    amt = _find_amount_box(boxes)
    if amt is None:
        return None
    ow, oh = img.size
    best_text, best_conf = "", 0.0
    best_region: tuple[int, int, int, int] | None = None
    for cx0, gap_top, cx1, gap_bot in _date_gap_regions(img, amt, boxes):
        crop = img.crop((cx0, gap_top, cx1, gap_bot))
        if crop.size[0] < 20 or crop.size[1] < 6:
            continue
        prep = _prep_date_gap_crop(crop)
        preds = recognize_batch(recognizer, [crop, prep])
        for text, conf in preds:
            text = correct_line((text or "").strip())
            if not text:
                continue
            iso, _, _ = _extract_date_from_lines([text])
            if iso and conf > best_conf:
                best_text, best_conf = text, float(conf)
                best_region = (cx0, gap_top, cx1, gap_bot)
    if not best_text or best_region is None:
        return None
    cx0, gap_top, cx1, gap_bot = best_region
    return TextBox(
        text=best_text,
        conf=best_conf,
        y_top=gap_top / oh,
        y_bot=gap_bot / oh,
        x_left=cx0 / ow,
        x_right=cx1 / ow,
    )


def recognize_transfer_lines(
    img: Image.Image,
    recognizer: RecognizerBundle,
    *,
    min_conf: float = 0.0,
) -> list[TextBox]:
    """Detect + recognize → TextBox (chỉ hậu xử lý liên quan bill chuyển khoản)."""
    line_boxes = detect_lines(img)
    if not line_boxes:
        return []
    crops: list[Image.Image] = []
    for lb in line_boxes:
        crops.append(lb.image)
        crops.append(_prep_line_crop(lb.image))
    preds = recognize_batch(recognizer, crops)
    boxes: list[TextBox] = []
    line_texts: list[str] = []
    for i, lb in enumerate(line_boxes):
        best_text, best_conf = "", 0.0
        for text, conf in preds[i * 2:(i + 1) * 2]:
            text = (text or "").strip()
            if not text or conf < min_conf:
                continue
            text = correct_line(text)
            if _looks_like_short_note(text):
                text = correct_transfer_note(text)
            if not text:
                continue
            if re.match(r"^mung me \d{1,2}/\d{1,2}$", text, re.I):
                best_text, best_conf = text, float(conf)
                break
            if conf > best_conf:
                best_text, best_conf = text, float(conf)
        line_texts.append(best_text)
        if not best_text:
            continue
        boxes.append(TextBox(
            text=best_text,
            conf=best_conf,
            y_top=lb.ny0,
            y_bot=lb.ny1,
            x_left=lb.nx0,
            x_right=lb.nx1,
        ))
    if _extract_transfer_amount(boxes_to_lines(boxes))[0] is None:
        amt_box = _ocr_amount_strip(img, line_boxes, line_texts, recognizer)
        if amt_box is not None:
            boxes.append(amt_box)
        elif _extract_transfer_amount(boxes_to_lines(boxes))[0] is None:
            amt_box = _ocr_vietin_amount_fixed(img, recognizer)
            if amt_box is not None:
                boxes.append(amt_box)
    if _extract_date_from_lines(boxes_to_lines(boxes))[0] is None:
        date_box = _ocr_date_below_amount(img, boxes, recognizer)
        if date_box is not None:
            boxes.append(date_box)
        else:
            full = " ".join(b.text for b in boxes).lower()
            if "thg" in full or "techcombank" in full or "ngày chuyển" in full:
                date_box = _ocr_date_bottom_card(img, recognizer)
                if date_box is not None:
                    boxes.append(date_box)
            if _extract_date_from_lines(boxes_to_lines(boxes))[0] is None:
                date_box = _ocr_vietin_datetime_fixed(img, recognizer)
                if date_box is not None:
                    boxes.append(date_box)
    boxes.sort(key=lambda b: b.y_top)
    return boxes


def recognize_transfer_bytes(
    data: bytes,
    recognizer: RecognizerBundle,
    *,
    min_conf: float = 0.0,
) -> list[TextBox]:
    img = Image.open(BytesIO(data))
    if img.mode not in ("RGB", "L"):
        img = img.convert("RGB")
    return recognize_transfer_lines(img, recognizer, min_conf=min_conf)
