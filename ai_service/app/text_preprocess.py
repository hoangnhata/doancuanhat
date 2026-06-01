"""
Tiền xử lý văn bản thống nhất cho train / inference (from-scratch, không pretrained).
"""
from __future__ import annotations

import json
import re
import unicodedata
from dataclasses import asdict, dataclass
from pathlib import Path
from typing import Any, Optional

# Viết tắt → chuẩn (word-boundary aware qua padding space)
ABBREVIATIONS: dict[str, str] = {
    "zalo pay": "zalopay",
    "chuyen khoan": "chuyen khoan",
    "so tai khoan": "so tai khoan",
    "bach hoa xanh": "bach hoa xanh",
    "tien tro": "tien tro",
    "tien phong": "tien phong",
    "tien nha": "tien nha",
    "dien thoai": "dien thoai",
    "giao hang": "giao hang",
    "vietcombank": "vietcombank",
    "techcombank": "techcombank",
    "zalopay": "zalopay",
    "winmart": "winmart",
    "mbbank": "mbbank",
    "shopee": "shopee",
    "lazada": "lazada",
    "bidv": "bidv",
    "momo": "momo",
    "grab": "grab",
    "gs25": "gs25",
    "bhx": "bach hoa xanh",
    "stk": "so tai khoan",
    "ck": "chuyen khoan",
    "vcb": "vietcombank",
    "mb": "mbbank",
    "tcb": "techcombank",
    "cfe": "cafe",
    "cf": "cafe",
    "dt": "dien thoai",
    "đt": "dien thoai",
    "tx": "taxi",
    "ship": "giao hang",
    "tro": "tien tro",
    "trọ": "tien tro",
    "phong": "tien phong",
    "phòng": "tien phong",
    "nha": "tien nha",
    "be": "be",
}

# Thứ tự: cụm dài trước (zalo pay, …) đã xử lý qua sort key length
_ABBR_SORTED = sorted(ABBREVIATIONS.items(), key=lambda x: -len(x[0]))

_REPEAT_CHAR = re.compile(r"(.)\1{3,}", re.UNICODE)
_REPEAT_PUNCT = re.compile(r"([!?.…,;:]){2,}")
_SPACES = re.compile(r"\s+")

# 2tr5 / 2.5tr / 2,5tr
_RE_TR_FRAC = re.compile(
    r"\b(\d{1,3})[\s]*(?:[.,]\s*)?(\d)\s*(tr|triệu|trieu)\b",
    re.IGNORECASE,
)
# 300 nghìn / 300 ngàn
_RE_NGHIN = re.compile(
    r"\b(\d{1,4})\s*(nghìn|nghin|ngàn|ngan)\b",
    re.IGNORECASE,
)
# 1 triệu / 2 trieu
_RE_TRIEU_WORD = re.compile(
    r"\b(\d{1,3})\s*(triệu|trieu)\b",
    re.IGNORECASE,
)
# 50k / 50K / 50kđ / 50k vnd
_RE_K_SUFFIX = re.compile(
    r"\b(\d{1,4})\s*k(?:\s*(?:đ|vnđ|vnd))?\b",
    re.IGNORECASE,
)
# 100.000đ / 100,000 vnd
_RE_VND_SUFFIX = re.compile(
    r"\b(\d{1,3}(?:[.,]\d{3})+)\s*(?:đ|vnđ|vnd)?\b",
    re.IGNORECASE,
)
# 1tr / 2TR
_RE_TR_SUFFIX = re.compile(
    r"\b(\d{1,3})\s*tr\b",
    re.IGNORECASE,
)
# bare 50000 / 500000 (sau các pattern trên)
_RE_BARE_AMOUNT = re.compile(
    r"\b(\d{4,9})\b",
)


@dataclass
class PreprocessConfig:
    unicode_form: str = "NFC"
    lowercase: bool = True
    strip_accents: bool = False
    normalize_money: bool = True
    expand_abbreviations: bool = True
    max_repeat_char: int = 3

    def to_dict(self) -> dict[str, Any]:
        return asdict(self)

    @classmethod
    def from_dict(cls, d: dict[str, Any]) -> PreprocessConfig:
        fields = cls.__dataclass_fields__
        return cls(**{k: d[k] for k in fields if k in d})


DEFAULT_PREPROCESS = PreprocessConfig()


def strip_vietnamese_accents(text: str) -> str:
    nfd = unicodedata.normalize("NFD", text)
    return "".join(c for c in nfd if unicodedata.category(c) != "Mn")


def _digits_only(s: str) -> str:
    return re.sub(r"[^\d]", "", s)


def _money_token_k(val: int) -> str:
    return f"<money_{val}k>"


def _money_token_tr(val: int, frac: Optional[int] = None) -> str:
    if frac is not None and frac > 0:
        return f"<money_{val}tr{frac}>"
    return f"<money_{val}tr>"


def normalize_money(text: str) -> str:
    """Chuẩn hóa mọi biến thể tiền tệ → token <money_*>."""
    if not text:
        return text

    def sub_tr_frac(m: re.Match) -> str:
        return _money_token_tr(int(m.group(1)), int(m.group(2)))

    def sub_nghin(m: re.Match) -> str:
        return _money_token_k(int(m.group(1)))

    def sub_trieu(m: re.Match) -> str:
        return _money_token_tr(int(m.group(1)))

    def sub_k(m: re.Match) -> str:
        return _money_token_k(int(m.group(1)))

    def sub_vnd(m: re.Match) -> str:
        raw = _digits_only(m.group(1))
        val = int(raw) if raw else 0
        if val >= 1_000_000:
            return _money_token_tr(val // 1_000_000)
        if val >= 1000:
            return _money_token_k(val // 1000)
        return f"<money_{val}>"

    def sub_tr(m: re.Match) -> str:
        return _money_token_tr(int(m.group(1)))

    def sub_bare(m: re.Match) -> str:
        val = int(m.group(1))
        if val >= 1_000_000:
            return _money_token_tr(val // 1_000_000)
        if val >= 1000:
            return _money_token_k(val // 1000)
        return f"<money_{val}>"

    t = text
    t = _RE_TR_FRAC.sub(sub_tr_frac, t)
    t = _RE_NGHIN.sub(sub_nghin, t)
    t = _RE_TRIEU_WORD.sub(sub_trieu, t)
    t = _RE_K_SUFFIX.sub(sub_k, t)
    t = _RE_VND_SUFFIX.sub(sub_vnd, t)
    t = _RE_TR_SUFFIX.sub(sub_tr, t)
    t = _RE_BARE_AMOUNT.sub(sub_bare, t)
    return t


def expand_abbreviations(text: str) -> str:
    t = f" {text.lower()} "
    for abbr, full in _ABBR_SORTED:
        t = t.replace(f" {abbr} ", f" {full} ")
    return _SPACES.sub(" ", t).strip()


def preprocess_text(text: str, cfg: Optional[PreprocessConfig] = None) -> str:
    """Pipeline đầy đủ — gọi đúng một lần trên raw input."""
    cfg = cfg or DEFAULT_PREPROCESS
    if not text:
        return ""

    t = unicodedata.normalize(cfg.unicode_form, text.strip())
    if cfg.lowercase:
        t = t.lower()
    t = _SPACES.sub(" ", t)
    t = _REPEAT_PUNCT.sub(r"\1", t)
    if cfg.max_repeat_char > 0:
        t = _REPEAT_CHAR.sub(
            lambda m: m.group(1) * min(cfg.max_repeat_char, len(m.group(0))),
            t,
        )

    if cfg.normalize_money:
        t = normalize_money(t)
    if cfg.expand_abbreviations:
        t = expand_abbreviations(t)
    if cfg.strip_accents:
        t = strip_vietnamese_accents(t)

    return _SPACES.sub(" ", t).strip()


def build_vocab(
    texts: list[str],
    min_freq: int = 1,
    cfg: Optional[PreprocessConfig] = None,
) -> dict[str, int]:
    cfg = cfg or DEFAULT_PREPROCESS
    counter: dict[str, int] = {}
    for t in texts:
        for ch in preprocess_text(t, cfg):
            counter[ch] = counter.get(ch, 0) + 1
    vocab = {"<PAD>": 0, "<UNK>": 1}
    for ch, freq in sorted(counter.items(), key=lambda x: (-x[1], x[0])):
        if freq >= min_freq and ch not in vocab:
            vocab[ch] = len(vocab)
    return vocab


def encode_preprocessed(
    preprocessed: str,
    vocab: dict[str, int],
    max_len: int,
    pad_idx: int = 0,
    unk_idx: int = 1,
) -> list[int]:
    """Encode chuỗi đã preprocess — không gọi preprocess lại."""
    ids = [vocab.get(ch, unk_idx) for ch in preprocessed[:max_len]]
    ids += [pad_idx] * (max_len - len(ids))
    return ids


def encode_text(
    text: str,
    vocab: dict[str, int],
    max_len: int,
    cfg: Optional[PreprocessConfig] = None,
    pad_idx: int = 0,
    unk_idx: int = 1,
    *,
    already_preprocessed: bool = False,
) -> list[int]:
    clean = text if already_preprocessed else preprocess_text(text, cfg)
    return encode_preprocessed(clean, vocab, max_len, pad_idx, unk_idx)


def save_preprocess_config(path: Path, cfg: PreprocessConfig) -> None:
    path.write_text(json.dumps(cfg.to_dict(), ensure_ascii=False, indent=2), encoding="utf-8")


def load_preprocess_config(path: Path) -> PreprocessConfig:
    if not path.is_file():
        return DEFAULT_PREPROCESS
    return PreprocessConfig.from_dict(json.loads(path.read_text(encoding="utf-8")))
