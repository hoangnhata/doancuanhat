"""Cắt vùng header / body / footer trên ảnh hóa đơn full."""

from __future__ import annotations

from dataclasses import dataclass

from PIL import Image


@dataclass(frozen=True)
class ReceiptRegions:
    full: Image.Image
    header: Image.Image
    body: Image.Image
    footer: Image.Image


def split_receipt_regions(
    img: Image.Image,
    *,
    header_ratio: float = 0.18,
    footer_ratio: float = 0.28,
) -> ReceiptRegions:
    """Heuristic layout bill VN: tên cửa hàng trên, món giữa, tổng tiền dưới."""
    w, h = img.size
    y_header = int(h * header_ratio)
    y_footer = int(h * (1.0 - footer_ratio))
    y_footer = max(y_header + 8, min(y_footer, h - 8))

    header = img.crop((0, 0, w, y_header))
    body = img.crop((0, y_header, w, y_footer))
    footer = img.crop((0, y_footer, w, h))
    return ReceiptRegions(full=img, header=header, body=body, footer=footer)


def body_line_strips(
    body: Image.Image,
    *,
    max_lines: int = 3,
    strip_h: int = 36,
    gap: int = 4,
) -> list[Image.Image]:
    """Lấy N dải ngang đầu body làm ứng viên dòng món hàng."""
    w, h = body.size
    if h < strip_h:
        return [body]
    strips: list[Image.Image] = []
    y = 0
    while y + strip_h <= h and len(strips) < max_lines:
        strips.append(body.crop((0, y, w, y + strip_h)))
        y += strip_h + gap
    return strips or [body]
