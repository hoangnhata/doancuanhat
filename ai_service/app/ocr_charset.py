"""Bảng ký tự CTC cho từng loại field trên hóa đơn."""

from __future__ import annotations


def _uniq(s: str) -> str:
    seen: set[str] = set()
    out: list[str] = []
    for ch in s:
        if ch not in seen:
            seen.add(ch)
            out.append(ch)
    return "".join(out)


VIET_LOWER = "aàáảãạăằắẳẵặâầấẩẫậeèéẻẽẹêềếểễệiìíỉĩịoòóỏõọôồốổỗộơờớởỡợuùúủũụưừứửữựyỳýỷỹỵđ"
VIET_UPPER = VIET_LOWER.upper()
LATIN = "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ"
PUNCT = " .,-/&():'"

AMOUNT_CHARSET = list("0123456789.,")
DATE_CHARSET = list("0123456789/-.: ")
TEXT_CHARSET = list(_uniq(LATIN + VIET_LOWER + VIET_UPPER + PUNCT + "0123456789"))


def charset_maps(charset: list[str]) -> tuple[dict[str, int], dict[int, str], int]:
    char2idx = {c: i + 1 for i, c in enumerate(charset)}
    idx2char = {i + 1: c for i, c in enumerate(charset)}
    num_classes = 1 + len(charset)
    return char2idx, idx2char, num_classes


AMOUNT_CHAR2IDX, AMOUNT_IDX2CHAR, AMOUNT_NUM_CLASSES = charset_maps(AMOUNT_CHARSET)
DATE_CHAR2IDX, DATE_IDX2CHAR, DATE_NUM_CLASSES = charset_maps(DATE_CHARSET)
TEXT_CHAR2IDX, TEXT_IDX2CHAR, TEXT_NUM_CLASSES = charset_maps(TEXT_CHARSET)

# Giữ tương thích import cũ
CHAR2IDX = AMOUNT_CHAR2IDX
IDX2CHAR = AMOUNT_IDX2CHAR
NUM_CTC_CLASSES = AMOUNT_NUM_CLASSES
CTC_CHARSET = AMOUNT_CHARSET
