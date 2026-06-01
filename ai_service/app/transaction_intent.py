from __future__ import annotations

import re

from .category_hints import infer_income_subcategory

# Danh mục chỉ dùng cho chi tiêu — nếu phát hiện thu nhập mà model gán nhầm thì chuyển sang Thu nhập khác
_EXPENSE_ONLY_CATEGORIES = {
    "Ăn uống",
    "Di chuyển",
    "Mua sắm",
    "Nhà ở",
    "Hóa đơn",
    "Giải trí",
    "Du lịch",
    "Giáo dục",
    "Sức khỏe",
    "Gia đình",
    "Thú cưng",
    "Quà tặng",
    "Từ thiện",
    "Khác",
}

_INCOME_LABELS = {"Lương", "Thưởng", "Freelance", "Đầu tư", "Bán hàng", "Thu nhập khác"}

_INCOME_PATTERN = re.compile(
    r"\b("
    r"lương|luong|thưởng|thuong|thu nhập|thu nhap|bán|ban|doanh thu"
    r"|freelance|lãi|lai|cổ tức|co tuc|đầu tư|dau tu|hoàn tiền|hoan tien"
    r"|refund|cashback"
    r"|nhận|nhan|được nhận|duoc nhan|được tặng|duoc tang|thu về|thu ve|thu nhập|tiền mừng nhận"
    r")\b",
    re.IGNORECASE,
)

# Chi cho người khác / tặng đi (không có "nhận" cùng câu)
_EXPENSE_GIVE_PATTERN = re.compile(
    r"\b("
    r"cho\b|tặng|tang|biếu|bieu|mừng|mung|gửi quà|gui qua|trả tiền cho|tra tien cho"
    r")\b",
    re.IGNORECASE,
)


def infer_transaction_type(text: str, category: str) -> str:
    t = (text or "").lower()
    if category in _INCOME_LABELS:
        return "INCOME"
    if _INCOME_PATTERN.search(t):
        # "cho" trong "nhận tiền cho mượn" / "nhận lại" vẫn là thu
        if _EXPENSE_GIVE_PATTERN.search(t) and not re.search(
            r"\b(nhận|nhan|được|duoc|thu về|thu ve|hoàn|hoan|refund|cashback)\b",
            t,
        ):
            return "EXPENSE"
        return "INCOME"
    if _EXPENSE_GIVE_PATTERN.search(t):
        return "EXPENSE"
    return "EXPENSE"


def adjust_category_for_type(text: str, category: str, tx_type: str) -> str:
    """Thu nhập từ quà/mừng/sinh nhật không nên gán danh mục chi Quà tặng."""
    if tx_type != "INCOME":
        return category
    if category in _INCOME_LABELS:
        return category
    sub = infer_income_subcategory(text)
    if sub:
        return sub
    t = (text or "").lower()
    if category in _EXPENSE_ONLY_CATEGORIES or re.search(
        r"\b(sinh nhật|sinh nhat|tiền mừng|tien mung|quà|qua|mừng|mung|nhận|nhan)\b",
        t,
    ):
        return "Thu nhập khác"
    return category
