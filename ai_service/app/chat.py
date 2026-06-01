"""Chatbot Q&A về chi tiêu cá nhân.

Backend Spring gửi sang đây kèm context (giao dịch 30-60 ngày, danh mục, ngân sách).
- Nếu có GEMINI_API_KEY: gọi Google Gemini 1.5 Flash (free tier ~ 15 RPM, 1500 RPD).
- Nếu không: trả về phân tích rule-based gọn dựa trên context.

Endpoint: POST /api/chat
Body:
{
  "message": "Tháng này tôi tiêu nhiều nhất vào đâu?",
  "personality": "HAPPY" | "SAD" | "ANGRY",
  "context": {
    "currency": "VND",
    "month_total_expense": 5400000,
    "month_total_income": 12000000,
    "by_category": [{"name":"Ăn uống","amount":2000000}, ...],
    "recent_transactions": [
      {"date":"2026-05-20","amount":50000,"description":"ăn trưa","category":"Ăn uống","type":"EXPENSE"},
      ...
    ],
    "budgets": [{"category":"Ăn uống","limit":3000000,"used":2000000}, ...]
  }
}
"""

from __future__ import annotations

import os
from typing import Any, Optional

import httpx
from pydantic import BaseModel, Field


GEMINI_MODEL = os.environ.get("GEMINI_MODEL", "gemini-1.5-flash")
GEMINI_API_URL = "https://generativelanguage.googleapis.com/v1beta/models/{model}:generateContent?key={key}"
GEMINI_TIMEOUT_S = float(os.environ.get("GEMINI_TIMEOUT_S", "20"))


class ChatContextBudget(BaseModel):
    category: str
    limit: float = 0
    used: float = 0


class ChatContextTransaction(BaseModel):
    date: str
    amount: float
    description: Optional[str] = None
    category: Optional[str] = None
    type: str = "EXPENSE"


class ChatContextCategory(BaseModel):
    name: str
    amount: float


class ChatContext(BaseModel):
    currency: str = "VND"
    month_total_expense: float = 0
    month_total_income: float = 0
    by_category: list[ChatContextCategory] = Field(default_factory=list)
    recent_transactions: list[ChatContextTransaction] = Field(default_factory=list)
    budgets: list[ChatContextBudget] = Field(default_factory=list)


class ChatRequest(BaseModel):
    message: str = Field(min_length=1, max_length=2000)
    personality: Optional[str] = Field(default="HAPPY", description="HAPPY | SAD | ANGRY")
    context: Optional[ChatContext] = None


class ChatResponse(BaseModel):
    reply: str
    engine: str  # "gemini" | "rule"


def _persona_directive(personality: Optional[str]) -> str:
    p = (personality or "HAPPY").upper()
    if p == "SAD":
        return (
            "Bạn là Natta — trợ lý buồn rầu, nhẹ nhàng, phân tích sâu sắc. "
            "Hay dùng cảm xúc thông cảm, lo lắng cho người dùng. Vẫn đưa lời khuyên thực tế."
        )
    if p == "ANGRY":
        return (
            "Bạn là Natta — trợ lý nghiêm khắc, hơi gắt gỏng, mạnh mẽ. "
            "Hãy nhắc nhở thẳng thắn về chi tiêu lãng phí, nhưng không xúc phạm. Ngắn gọn."
        )
    return (
        "Bạn là Natta — trợ lý tài chính cá nhân vui vẻ, năng động, tích cực. "
        "Trả lời ngắn gọn, dùng emoji vừa phải, có hành động cụ thể."
    )


def _format_context(ctx: Optional[ChatContext]) -> str:
    if ctx is None:
        return "Không có dữ liệu chi tiêu."
    lines: list[str] = []
    lines.append(f"Đơn vị tiền: {ctx.currency}")
    lines.append(f"Tổng chi tháng này: {int(ctx.month_total_expense):,}")
    lines.append(f"Tổng thu tháng này: {int(ctx.month_total_income):,}")
    if ctx.by_category:
        top = sorted(ctx.by_category, key=lambda c: c.amount, reverse=True)[:8]
        lines.append("Top danh mục chi:")
        for c in top:
            lines.append(f"  - {c.name}: {int(c.amount):,}")
    if ctx.budgets:
        lines.append("Ngân sách:")
        for b in ctx.budgets[:8]:
            pct = (b.used / b.limit * 100) if b.limit > 0 else 0
            lines.append(f"  - {b.category}: dùng {int(b.used):,}/{int(b.limit):,} ({pct:.0f}%)")
    if ctx.recent_transactions:
        recent = ctx.recent_transactions[:12]
        lines.append("Giao dịch gần đây:")
        for t in recent:
            sign = "-" if t.type.upper() == "EXPENSE" else "+"
            desc = (t.description or "").strip()
            cat = t.category or "?"
            lines.append(f"  - {t.date}: {sign}{int(t.amount):,} • {cat} • {desc}")
    return "\n".join(lines)


def gemini_available() -> bool:
    return bool(os.environ.get("GEMINI_API_KEY", "").strip())


def _call_gemini(prompt: str, system: str) -> Optional[str]:
    api_key = os.environ.get("GEMINI_API_KEY", "").strip()
    if not api_key:
        return None
    url = GEMINI_API_URL.format(model=GEMINI_MODEL, key=api_key)
    payload: dict[str, Any] = {
        "systemInstruction": {"parts": [{"text": system}]},
        "contents": [{"role": "user", "parts": [{"text": prompt}]}],
        "generationConfig": {
            "temperature": 0.7,
            "topP": 0.9,
            "maxOutputTokens": 700,
        },
    }
    try:
        with httpx.Client(timeout=GEMINI_TIMEOUT_S) as client:
            r = client.post(url, json=payload)
            r.raise_for_status()
            data = r.json()
            candidates = data.get("candidates") or []
            if not candidates:
                return None
            parts = candidates[0].get("content", {}).get("parts") or []
            text = "".join(p.get("text", "") for p in parts).strip()
            return text or None
    except Exception:
        return None


def _rule_reply(message: str, ctx: Optional[ChatContext], personality: Optional[str]) -> str:
    """Trả lời cơ bản dựa trên context khi chưa có Gemini API key."""
    msg = (message or "").lower()
    if ctx is None or (ctx.month_total_expense == 0 and not ctx.by_category):
        return (
            "Tôi chưa có đủ dữ liệu để phân tích. Hãy thêm vài giao dịch trong tháng "
            "rồi quay lại hỏi Natta nhé! ✨"
        )

    # Câu hỏi điển hình: "tháng này tôi chi nhiều nhất vào đâu?"
    if any(k in msg for k in ["nhiều nhất", "lớn nhất", "top", "cao nhất"]):
        if ctx.by_category:
            top = max(ctx.by_category, key=lambda c: c.amount)
            return (
                f"Danh mục bạn chi nhiều nhất tháng này là **{top.name}** với "
                f"{int(top.amount):,} {ctx.currency}. Tổng chi cả tháng: "
                f"{int(ctx.month_total_expense):,} {ctx.currency}."
            )

    if any(k in msg for k in ["tổng", "tháng này", "đã chi", "tiêu"]):
        balance = ctx.month_total_income - ctx.month_total_expense
        sign = "dư" if balance >= 0 else "âm"
        return (
            f"Tháng này: thu {int(ctx.month_total_income):,}, chi "
            f"{int(ctx.month_total_expense):,}, {sign} {int(abs(balance)):,} "
            f"{ctx.currency}."
        )

    if "ngân sách" in msg or "budget" in msg:
        over = [b for b in ctx.budgets if b.limit > 0 and b.used >= b.limit * 0.8]
        if over:
            top = sorted(over, key=lambda b: b.used / max(b.limit, 1), reverse=True)[:3]
            lines = [
                f"- {b.category}: {int(b.used):,}/{int(b.limit):,}"
                for b in top
            ]
            return "Cẩn thận! Bạn đang gần/vượt ngân sách ở:\n" + "\n".join(lines)
        return "Ngân sách của bạn vẫn ổn. Cứ giữ phong độ này nhé! 💪"

    if any(k in msg for k in ["lời khuyên", "cắt giảm", "tiết kiệm", "giảm chi"]):
        if ctx.by_category:
            top3 = sorted(ctx.by_category, key=lambda c: c.amount, reverse=True)[:3]
            tips = "; ".join(f"{c.name} ({int(c.amount):,})" for c in top3)
            return (
                f"Top 3 danh mục chi nhiều: {tips}. "
                "Hãy thử đặt ngân sách cho từng cái + theo dõi hằng tuần để cắt giảm 10-15%."
            )

    persona = (personality or "HAPPY").upper()
    if persona == "ANGRY":
        return "Câu hỏi của bạn cần Gemini AI. Hãy cấu hình GEMINI_API_KEY rồi hỏi lại!"
    if persona == "SAD":
        return "Tôi chưa đủ thông minh để trả lời câu này. Vui lòng cấu hình GEMINI_API_KEY... 🥺"
    return "Câu này hay đấy! Hãy bật Gemini AI (set GEMINI_API_KEY) để Natta trả lời sâu hơn nhé. 😊"


def chat_answer(req: ChatRequest) -> ChatResponse:
    system = _persona_directive(req.personality)
    ctx_str = _format_context(req.context)

    prompt = (
        "Dưới đây là dữ liệu chi tiêu của người dùng:\n"
        f"```\n{ctx_str}\n```\n\n"
        f"Câu hỏi của người dùng: {req.message}\n\n"
        "Yêu cầu: Trả lời bằng tiếng Việt, súc tích (3-6 câu), dựa SÁT vào dữ liệu trên. "
        "Nếu thiếu dữ liệu, nói thẳng. Không bịa số. "
        "Nếu phù hợp, đề xuất 1-2 hành động cụ thể (đặt ngân sách, cắt giảm, ...)."
    )

    text = _call_gemini(prompt, system)
    if text:
        return ChatResponse(reply=text, engine="gemini")
    return ChatResponse(reply=_rule_reply(req.message, req.context, req.personality), engine="rule")
