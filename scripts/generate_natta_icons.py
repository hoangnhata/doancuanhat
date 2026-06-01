"""Generate PNG icons — Natta robot head (khớp favicon SVG)."""
from __future__ import annotations

from pathlib import Path

from PIL import Image, ImageDraw

C_BG = (2, 136, 209, 255)
C_SCREEN = (13, 27, 42, 255)
C_CYAN = (79, 195, 247, 255)
C_EAR = (227, 242, 253, 235)


def draw_logo(size: int) -> Image.Image:
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)
    s = size / 64.0
    r_bg = int(14 * s)

    draw.rounded_rectangle([0, 0, size - 1, size - 1], radius=r_bg, fill=C_BG)

    sx, sy, sw, sh = 14 * s, 16 * s, 36 * s, 28 * s
    rr = int(6 * s)
    draw.rounded_rectangle(
        [sx, sy, sx + sw, sy + sh],
        radius=rr,
        fill=C_SCREEN,
        outline=C_CYAN,
        width=max(1, int(1.5 * s)),
    )

    ew, eh = 4 * s, 5 * s
    for cx in (26 * s, 38 * s):
        draw.ellipse(
            [cx - ew / 2, 28 * s - eh / 2, cx + ew / 2, 28 * s + eh / 2],
            fill=C_CYAN,
        )

    draw.arc(
        [26 * s - 6 * s, 33 * s, 38 * s + 6 * s, 44 * s],
        start=200,
        end=340,
        fill=C_CYAN,
        width=max(1, int(2 * s)),
    )

    draw.polygon(
        [(20 * s, 12 * s), (22 * s, 8 * s), (28 * s, 14 * s)],
        fill=C_EAR,
    )
    draw.polygon(
        [(44 * s, 12 * s), (42 * s, 8 * s), (36 * s, 14 * s)],
        fill=C_EAR,
    )
    return img


def main() -> None:
    root = Path(__file__).resolve().parent.parent
    web_public = root / "web" / "public"
    flutter_assets = root / "frontend" / "assets" / "images"
    flutter_assets.mkdir(parents=True, exist_ok=True)

    draw_logo(180).save(web_public / "apple-touch-icon.png", "PNG")
    draw_logo(1024).save(flutter_assets / "app_icon.png", "PNG")

    print("Wrote apple-touch-icon.png and frontend/assets/images/app_icon.png")


if __name__ == "__main__":
    main()
