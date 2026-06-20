"""
Phát hiện DÒNG CHỮ trên ảnh hóa đơn / bill chuyển khoản — bằng xử lý ảnh cổ điển.

KHÔNG dùng model học sâu, KHÔNG pretrain. Mục tiêu: cắt ảnh full thành các dòng
chữ đơn lẻ để đưa vào model nhận dạng CRNN+CTC (train from scratch).

Pipeline (ưu tiên OpenCV nếu có, fallback NumPy thuần):
  1. Chuẩn hoá grayscale + scale chiều rộng hợp lý
  2. Tự nhận cực tính (chữ tối / nền sáng hay ngược lại) → đưa về chữ tối nền sáng
  3. Nhị phân hoá thích nghi (adaptive threshold)
  4. Khử nghiêng nhẹ (deskew)
  5. Dilate ngang gộp ký tự thành cụm dòng
  6. Tách dòng:
       - OpenCV: connected components → box, gộp box cùng hàng
       - NumPy: chiếu ngang (horizontal projection) tìm dải có chữ
  7. Cắt dòng từ ảnh grayscale gốc (có padding) → trả PIL.Image + box (toạ độ gốc)
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Optional

import numpy as np
from PIL import Image, ImageEnhance, ImageOps

try:
    import cv2  # type: ignore
    _HAS_CV2 = True
except Exception:  # pragma: no cover
    cv2 = None  # type: ignore
    _HAS_CV2 = False


@dataclass
class LineBox:
    image: Image.Image          # crop grayscale của dòng
    x0: int
    y0: int
    x1: int
    y1: int
    # toạ độ chuẩn hoá (0..1) theo ảnh gốc — phục vụ parse field
    nx0: float = 0.0
    ny0: float = 0.0
    nx1: float = 1.0
    ny1: float = 1.0


def cv2_available() -> bool:
    return _HAS_CV2


# ─────────────────────────── Chuẩn hoá ──────────────────────────────────────

def _to_gray_array(img: Image.Image, max_w: int = 1600) -> tuple[np.ndarray, float]:
    g = img.convert("L")
    w, h = g.size
    scale = 1.0
    if w > max_w:
        scale = max_w / float(w)
        g = g.resize((max_w, max(1, int(h * scale))), Image.BILINEAR)
    return np.asarray(g, dtype=np.uint8), scale


def _normalize_polarity(gray: np.ndarray) -> np.ndarray:
    """Đưa về chữ TỐI trên nền SÁNG (nền chiếm đa số & sáng)."""
    if float(gray.mean()) < 110:  # nền tối → đảo màu
        return 255 - gray
    return gray


# ─────────────────────────── Deskew ─────────────────────────────────────────

def _deskew(gray: np.ndarray) -> np.ndarray:
    if not _HAS_CV2:
        return gray
    try:
        thr = cv2.threshold(gray, 0, 255, cv2.THRESH_BINARY_INV + cv2.THRESH_OTSU)[1]
        coords = np.column_stack(np.where(thr > 0))
        if coords.shape[0] < 50:
            return gray
        angle = cv2.minAreaRect(coords)[-1]
        if angle < -45:
            angle = 90 + angle
        if abs(angle) < 0.5 or abs(angle) > 15:
            return gray
        h, w = gray.shape
        m = cv2.getRotationMatrix2D((w / 2, h / 2), angle, 1.0)
        return cv2.warpAffine(gray, m, (w, h), flags=cv2.INTER_CUBIC,
                              borderMode=cv2.BORDER_REPLICATE)
    except Exception:
        return gray


# ─────────────────────────── OpenCV path ────────────────────────────────────

def _detect_cv2(gray: np.ndarray) -> list[tuple[int, int, int, int]]:
    h, w = gray.shape
    binary = cv2.adaptiveThreshold(
        gray, 255, cv2.ADAPTIVE_THRESH_GAUSSIAN_C, cv2.THRESH_BINARY_INV,
        blockSize=35, C=15,
    )
    # Gộp ký tự thành dòng: dilate ngang mạnh, dọc nhẹ
    kx = max(8, w // 45)
    kernel = cv2.getStructuringElement(cv2.MORPH_RECT, (kx, 3))
    dil = cv2.dilate(binary, kernel, iterations=2)

    n, _, stats, _ = cv2.connectedComponentsWithStats(dil, connectivity=8)
    boxes: list[tuple[int, int, int, int]] = []
    for i in range(1, n):
        x, y, bw, bh, area = stats[i]
        if bh < 7 or bw < 12:
            continue
        if bh > h * 0.4:           # quá cao → không phải 1 dòng
            continue
        if bw / max(bh, 1) < 1.1 and bw < w * 0.05:
            continue
        if area < bw * bh * 0.04:  # quá rỗng
            continue
        boxes.append((x, y, x + bw, y + bh))
    return boxes


# ─────────────────────────── NumPy fallback ─────────────────────────────────

def _otsu(gray: np.ndarray) -> int:
    hist = np.bincount(gray.ravel(), minlength=256).astype(np.float64)
    total = gray.size
    sum_all = np.dot(np.arange(256), hist)
    w_b = 0.0
    sum_b = 0.0
    max_var = -1.0
    thr = 127
    for t in range(256):
        w_b += hist[t]
        if w_b == 0:
            continue
        w_f = total - w_b
        if w_f == 0:
            break
        sum_b += t * hist[t]
        m_b = sum_b / w_b
        m_f = (sum_all - sum_b) / w_f
        var = w_b * w_f * (m_b - m_f) ** 2
        if var > max_var:
            max_var = var
            thr = t
    return thr


def _detect_numpy(gray: np.ndarray) -> list[tuple[int, int, int, int]]:
    h, w = gray.shape
    thr = _otsu(gray)
    ink = (gray < thr).astype(np.float32)        # 1 = pixel chữ
    row_density = ink.sum(axis=1) / float(w)
    active = row_density > max(0.012, row_density.mean() * 0.5)

    boxes: list[tuple[int, int, int, int]] = []
    y = 0
    while y < h:
        if not active[y]:
            y += 1
            continue
        y0 = y
        while y < h and active[y]:
            y += 1
        y1 = y
        if y1 - y0 < 7:
            continue
        band = ink[y0:y1]
        col = band.sum(axis=0)
        nz = np.where(col > 0)[0]
        if nz.size == 0:
            continue
        x0, x1 = int(nz[0]), int(nz[-1]) + 1
        if x1 - x0 < 12:
            continue
        boxes.append((x0, y0, x1, y1))
    return boxes


# ─────────────────────────── Merge & post ───────────────────────────────────

def _collect_row_strips(active: np.ndarray, *, min_h: int = 6) -> list[tuple[int, int]]:
    strips: list[tuple[int, int]] = []
    y = 0
    n = len(active)
    while y < n:
        if not active[y]:
            y += 1
            continue
        y0 = y
        while y < n and active[y]:
            y += 1
        if y - y0 >= min_h:
            strips.append((y0, y))
    return strips


def _row_strips_from_gray(gray: np.ndarray) -> list[tuple[int, int]]:
    """Tách dòng trong crop cao — thử nhiều ngưỡng (bill app nền màu)."""
    h, w = gray.shape
    thr = _otsu(gray)
    ink = (gray < thr).astype(np.float32)
    row_density = ink.sum(axis=1) / float(max(w, 1))
    if row_density.max() <= 0:
        return []
    for pct in (58, 55, 50, 45, 65):
        cutoff = max(0.12, float(np.percentile(row_density, pct)), row_density.mean() * 0.55)
        strips = _collect_row_strips(row_density > cutoff)
        if len(strips) >= 2:
            return strips
    return _collect_row_strips(row_density > max(0.18, row_density.mean() * 0.45))


def _split_tall_crop_into_rows(
    crop: Image.Image,
    gx0: int,
    gy0: int,
    ow: int,
    oh: int,
    *,
    min_rel_h: float = 0.045,
) -> list[LineBox]:
    """Tách crop quá cao (khối chi tiết app ngân hàng) thành nhiều dòng."""
    h = crop.size[1]
    if h < max(12, int(oh * min_rel_h)):
        return []

    gray = np.asarray(
        ImageEnhance.Contrast(
            ImageOps.autocontrast(crop.convert("L"), cutoff=2)
        ).enhance(1.8),
        dtype=np.uint8,
    )
    strips = _row_strips_from_gray(gray)
    if len(strips) <= 1:
        return []

    # Pad dọc mỗi strip để không clip chân/đỉnh chữ (ghi chú nhạt, mảnh)
    vpad = max(3, int(oh * 0.005))
    thr = _otsu(gray)
    ink = (gray < thr).astype(np.float32)
    out: list[LineBox] = []
    for y0, y1 in strips:
        band = ink[y0:y1]
        col = band.sum(axis=0)
        nz = np.where(col > 0)[0]
        if nz.size == 0:
            continue
        lx0, lx1 = int(nz[0]), int(nz[-1]) + 1
        if lx1 - lx0 < 8:
            continue
        cy0 = max(0, y0 - vpad)
        cy1 = min(h, y1 + vpad)
        sub = crop.crop((lx0, cy0, lx1, cy1))
        if sub.size[0] < 6 or sub.size[1] < 6:
            continue
        gy0_sub = gy0 + cy0
        gy1 = gy0 + cy1
        out.append(LineBox(
            image=sub,
            x0=gx0 + lx0,
            y0=gy0_sub,
            x1=gx0 + lx1,
            y1=gy1,
            nx0=(gx0 + lx0) / ow,
            ny0=gy0_sub / oh,
            nx1=(gx0 + lx1) / ow,
            ny1=gy1 / oh,
        ))
    return out


def _expand_tall_line_boxes(out: list[LineBox], ow: int, oh: int) -> list[LineBox]:
    """Nếu một dòng detect quá cao → tách thành nhiều dòng nhỏ hơn."""
    expanded: list[LineBox] = []
    for lb in out:
        rel_h = (lb.y1 - lb.y0) / max(oh, 1)
        if rel_h > 0.10:
            subs = _split_tall_crop_into_rows(
                lb.image, lb.x0, lb.y0, ow, oh,
            )
            expanded.extend(subs if subs else [lb])
        else:
            expanded.append(lb)
    expanded.sort(key=lambda b: b.y0)
    return expanded


def _merge_same_row(boxes: list[tuple[int, int, int, int]]) -> list[tuple[int, int, int, int]]:
    if not boxes:
        return []
    boxes = sorted(boxes, key=lambda b: (b[1], b[0]))
    merged: list[list[int]] = []
    for x0, y0, x1, y1 in boxes:
        placed = False
        cy = (y0 + y1) / 2
        for m in merged:
            mcy = (m[1] + m[3]) / 2
            mh = m[3] - m[1]
            if abs(cy - mcy) < mh * 0.6:
                m[0] = min(m[0], x0)
                m[1] = min(m[1], y0)
                m[2] = max(m[2], x1)
                m[3] = max(m[3], y1)
                placed = True
                break
        if not placed:
            merged.append([x0, y0, x1, y1])
    merged.sort(key=lambda b: (b[1], b[0]))
    return [tuple(m) for m in merged]


def _needs_card_zone_fallback(boxes: list[LineBox], oh: int) -> bool:
    """Detect full ảnh thất bại (box quá cao / quá ít dòng) — cần crop vùng thẻ giữa."""
    if not boxes:
        return True
    if len(boxes) < 4:
        return True
    max_rel_h = max((lb.y1 - lb.y0) / max(oh, 1) for lb in boxes)
    return max_rel_h > 0.32


def _boxes_from_gray_region(
    orig: Image.Image,
    crop_rgb: Image.Image,
    *,
    ox: int,
    oy: int,
    pad_ratio: float = 0.18,
) -> list[LineBox]:
    """Detect dòng trong crop con, map toạ độ về ảnh gốc."""
    ow, oh = orig.size
    gray, _ = _to_gray_array(crop_rgb)
    gray = _normalize_polarity(gray)
    gray = np.asarray(
        ImageEnhance.Contrast(
            ImageOps.autocontrast(Image.fromarray(gray), cutoff=2)
        ).enhance(1.6),
        dtype=np.uint8,
    )
    raw = _detect_cv2(gray) if _HAS_CV2 else _detect_numpy(gray)
    if not raw and _HAS_CV2:
        raw = _detect_numpy(gray)
    raw = _merge_same_row(raw)
    out: list[LineBox] = []
    for x0, y0, x1, y1 in raw:
        bh = y1 - y0
        py = int(bh * pad_ratio)
        px = int(bh * pad_ratio * 0.6)
        gx0 = max(0, ox + x0 - px)
        gy0 = max(0, oy + y0 - py)
        gx1 = min(ow, ox + x1 + px)
        gy1 = min(oh, oy + y1 + py)
        if gx1 - gx0 < 6 or gy1 - gy0 < 6:
            continue
        crop = orig.crop((gx0, gy0, gx1, gy1))
        out.append(LineBox(
            image=crop, x0=gx0, y0=gy0, x1=gx1, y1=gy1,
            nx0=gx0 / ow, ny0=gy0 / oh, nx1=gx1 / ow, ny1=gy1 / oh,
        ))
    return out


def detect_lines_card_zone(img: Image.Image) -> list[LineBox]:
    """Fallback detect — vùng thẻ bill giữa màn hình app (MB xanh, MoMo…)."""
    orig = img.convert("L")
    ow, oh = orig.size
    x0, y0 = int(ow * 0.06), int(oh * 0.18)
    x1, y1 = int(ow * 0.94), int(oh * 0.62)
    crop_rgb = img.convert("RGB").crop((x0, y0, x1, y1))
    out = _boxes_from_gray_region(orig, crop_rgb, ox=x0, oy=y0)
    if not out:
        return []
    return _expand_tall_line_boxes(out, ow, oh)


def detect_lines(
    img: Image.Image,
    *,
    pad_ratio: float = 0.18,
    min_lines_fallback: bool = True,
) -> list[LineBox]:
    """Phát hiện các dòng chữ → list LineBox (crop grayscale + toạ độ gốc)."""
    orig = img.convert("L")
    ow, oh = orig.size
    gray, scale = _to_gray_array(img)
    gray = _normalize_polarity(gray)
    gray = _deskew(gray)
    h, w = gray.shape

    boxes = _detect_cv2(gray) if _HAS_CV2 else _detect_numpy(gray)
    if not boxes and _HAS_CV2:
        boxes = _detect_numpy(gray)
    boxes = _merge_same_row(boxes)

    # Fallback: không tách được dòng nào → trả nguyên ảnh
    if not boxes and min_lines_fallback:
        return [LineBox(image=orig, x0=0, y0=0, x1=ow, y1=oh,
                        nx0=0.0, ny0=0.0, nx1=1.0, ny1=1.0)]

    inv = 1.0 / scale if scale > 0 else 1.0
    out: list[LineBox] = []
    for (x0, y0, x1, y1) in boxes:
        bh = y1 - y0
        py = int(bh * pad_ratio)
        px = int(bh * pad_ratio * 0.6)
        gx0 = max(0, int((x0 - px) * inv))
        gy0 = max(0, int((y0 - py) * inv))
        gx1 = min(ow, int((x1 + px) * inv))
        gy1 = min(oh, int((y1 + py) * inv))
        if gx1 - gx0 < 6 or gy1 - gy0 < 6:
            continue
        crop = orig.crop((gx0, gy0, gx1, gy1))
        out.append(LineBox(
            image=crop, x0=gx0, y0=gy0, x1=gx1, y1=gy1,
            nx0=gx0 / ow, ny0=gy0 / oh, nx1=gx1 / ow, ny1=gy1 / oh,
        ))
    if not out and min_lines_fallback:
        return [LineBox(image=orig, x0=0, y0=0, x1=ow, y1=oh)]
    out = _expand_tall_line_boxes(out, ow, oh)
    if _needs_card_zone_fallback(out, oh):
        zone = detect_lines_card_zone(img)
        if zone:
            return zone
    return out
