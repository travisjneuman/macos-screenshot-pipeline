#!/usr/bin/env python3
"""Generate README hero PNG + stylized 10s 720p demo animation (not a live screen recording)."""
from __future__ import annotations

import math
from pathlib import Path

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[1]
ASSETS = ROOT / "docs" / "assets"
W, H = 1280, 720
FPS = 15
DURATION = 10.0
NFRAMES = int(FPS * DURATION)

BG = (13, 17, 23)
PANEL = (22, 27, 34)
PANEL2 = (30, 36, 46)
BORDER = (48, 54, 61)
TEXT = (230, 237, 243)
MUTED = (139, 148, 158)
ACCENT = (63, 185, 80)  # green
ACCENT2 = (88, 166, 255)  # blue
ACCENT3 = (163, 113, 247)  # purple
WARN = (210, 153, 34)
WHITE = (255, 255, 255)


def font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont:
    candidates = [
        "/System/Library/Fonts/Supplemental/Arial Bold.ttf" if bold else "/System/Library/Fonts/Supplemental/Arial.ttf",
        "/Library/Fonts/Arial Unicode.ttf",
        "/System/Library/Fonts/Helvetica.ttc",
    ]
    for path in candidates:
        try:
            return ImageFont.truetype(path, size=size)
        except OSError:
            continue
    return ImageFont.load_default()


F_TITLE = font(42, bold=True)
F_H1 = font(32, bold=True)
F_H2 = font(22, bold=True)
F_BODY = font(20)
F_SMALL = font(16)
F_KEY = font(18, bold=True)
F_TINY = font(14)


def lerp(a: float, b: float, t: float) -> float:
    return a + (b - a) * t


def clamp01(t: float) -> float:
    return max(0.0, min(1.0, t))


def ease(t: float) -> float:
    t = clamp01(t)
    return t * t * (3 - 2 * t)


def scene_t(frame: int, start: float, end: float) -> float:
    """0..1 within [start,end) seconds."""
    t = frame / FPS
    if t < start:
        return 0.0
    if t >= end:
        return 1.0
    return (t - start) / (end - start)


def rounded_rect(draw: ImageDraw.ImageDraw, xy, r: int, fill, outline=None, width: int = 2):
    draw.rounded_rectangle(xy, radius=r, fill=fill, outline=outline, width=width)


def draw_keycap(draw: ImageDraw.ImageDraw, x: int, y: int, label: str, on: bool = False):
    w, h = 54, 36
    fill = (40, 80, 50) if on else PANEL2
    outline = ACCENT if on else BORDER
    rounded_rect(draw, (x, y, x + w, y + h), 8, fill, outline, 2)
    bbox = draw.textbbox((0, 0), label, font=F_KEY)
    tw, th = bbox[2] - bbox[0], bbox[3] - bbox[1]
    draw.text((x + (w - tw) / 2, y + (h - th) / 2 - 1), label, font=F_KEY, fill=WHITE if on else TEXT)


def draw_keys_row(draw: ImageDraw.ImageDraw, x: int, y: int, labels: list[str], active_idx: int | None = None):
    gap = 8
    for i, lab in enumerate(labels):
        draw_keycap(draw, x + i * (54 + gap), y, lab, on=(active_idx == i))
        if i < len(labels) - 1:
            # plus between
            px = x + (i + 1) * (54 + gap) - gap // 2 - 4
            draw.text((px - 2, y + 6), "", font=F_SMALL, fill=MUTED)


def chord_width(n: int) -> int:
    return n * 54 + (n - 1) * 8


def draw_window(draw: ImageDraw.ImageDraw, xy, title: str):
    x0, y0, x1, y1 = xy
    rounded_rect(draw, xy, 12, PANEL, BORDER, 2)
    # title bar
    draw.rectangle((x0, y0, x1, y0 + 36), fill=PANEL2)
    for i, c in enumerate([(255, 95, 86), (255, 189, 46), (39, 201, 63)]):
        draw.ellipse((x0 + 14 + i * 18, y0 + 12, x0 + 26 + i * 18, y0 + 24), fill=c)
    bbox = draw.textbbox((0, 0), title, font=F_SMALL)
    tw = bbox[2] - bbox[0]
    draw.text(((x0 + x1 - tw) / 2, y0 + 10), title, font=F_SMALL, fill=MUTED)


def draw_arrow(draw: ImageDraw.ImageDraw, x0: int, y0: int, x1: int, y1: int, color=ACCENT2, width: int = 3):
    draw.line((x0, y0, x1, y1), fill=color, width=width)
    ang = math.atan2(y1 - y0, x1 - x0)
    size = 12
    for da in (0.4, -0.4):
        ax = x1 - size * math.cos(ang + da)
        ay = y1 - size * math.sin(ang + da)
        draw.line((x1, y1, ax, ay), fill=color, width=width)


def progress_bar(draw: ImageDraw.ImageDraw, frame: int):
    t = frame / max(1, NFRAMES - 1)
    y = H - 18
    draw.rectangle((40, y, W - 40, y + 4), fill=PANEL2)
    draw.rectangle((40, y, 40 + int((W - 80) * t), y + 4), fill=ACCENT2)


def base_canvas() -> tuple[Image.Image, ImageDraw.ImageDraw]:
    img = Image.new("RGB", (W, H), BG)
    draw = ImageDraw.Draw(img)
    # subtle top rule
    draw.rectangle((0, 0, W, 4), fill=ACCENT2)
    draw.text((40, 24), "macos-screenshot-pipeline", font=F_H2, fill=TEXT)
    draw.text((40, 54), "Stock capture · finished handoff", font=F_SMALL, fill=MUTED)
    return img, draw


def frame_image(i: int) -> Image.Image:
    img, draw = base_canvas()
    t = i / FPS

    # --- Scene timeline (seconds) ---
    # 0.0-1.5  intro
    # 1.5-3.5  capture chord
    # 3.5-5.5  staging + dual path
    # 5.5-7.5  photos + clipboard
    # 7.5-9.0  markup
    # 9.0-10   paste / endcard

    # Center stage area
    stage = (60, 100, W - 60, H - 50)

    if t < 1.5:
        p = ease(scene_t(i, 0.0, 1.2))
        title = "staging → Photos → clipboard PNG"
        bbox = draw.textbbox((0, 0), title, font=F_TITLE)
        tw = bbox[2] - bbox[0]
        alpha_y = int(lerp(40, 0, p))
        draw.text(((W - tw) / 2, 280 + alpha_y), title, font=F_TITLE, fill=TEXT)
        sub = "Native · WatchPaths · HDR-honest dual path · MIT"
        bbox = draw.textbbox((0, 0), sub, font=F_BODY)
        sw = bbox[2] - bbox[0]
        draw.text(((W - sw) / 2, 340 + alpha_y), sub, font=F_BODY, fill=MUTED)

    elif t < 3.5:
        p = ease(scene_t(i, 1.5, 2.2))
        draw.text((80, 120), "1 · Capture with stock shortcuts", font=F_H1, fill=TEXT)
        # keyboard chord animation
        labels = ["⌘", "⇧", "4"]
        cw = chord_width(len(labels))
        x0 = (W - cw) // 2
        y0 = 280
        # pulse active key
        pulse = int((t * 4) % 3)
        for ki, lab in enumerate(labels):
            on = ki <= pulse or p > 0.85
            draw_keycap(draw, x0 + ki * 62, y0, lab, on=on)
        draw.text((x0 + cw + 24, y0 + 6), "selection / window / full screen", font=F_BODY, fill=MUTED)

        # fake screen selection rectangle
        sel_p = ease(scene_t(i, 2.0, 3.2))
        sx0, sy0 = 200, 380
        sx1 = int(lerp(sx0 + 40, 980, sel_p))
        sy1 = int(lerp(sy0 + 30, 560, sel_p))
        draw.rectangle((sx0, sy0, sx1, sy1), outline=ACCENT2, width=3)
        if sel_p > 0.2:
            draw.rectangle((sx0, sy0, min(sx0 + 120, sx1), sy0 + 28), fill=ACCENT2)
            draw.text((sx0 + 8, sy0 + 5), "Screenshot", font=F_TINY, fill=WHITE)

    elif t < 5.5:
        draw.text((80, 120), "2 · Staging folder (ephemeral)", font=F_H1, fill=TEXT)
        p = ease(scene_t(i, 3.5, 4.3))
        # folder panel
        fx0, fy0 = 100, 200
        draw_window(draw, (fx0, fy0, fx0 + 420, fy0 + 360), "Pictures / Camera Roll")
        # file appears
        if p > 0.2:
            rounded_rect(draw, (fx0 + 30, fy0 + 70, fx0 + 390, fy0 + 130), 8, PANEL2, ACCENT, 2)
            draw.text((fx0 + 50, fy0 + 88), "Screenshot 2026-07-19.png", font=F_BODY, fill=TEXT)
            draw.text((fx0 + 50, fy0 + 112), "original bytes (HDR → often HEIF)", font=F_TINY, fill=MUTED)

        # ordered handoff (not parallel “clipboard first”)
        mid = ease(scene_t(i, 4.2, 5.2))
        if mid > 0:
            ox = int(lerp(700, 660, mid))
            draw_arrow(draw, fx0 + 420, fy0 + 180, ox - 12, 300, ACCENT3)
            rounded_rect(draw, (ox, 220, ox + 480, 320), 12, PANEL, ACCENT3, 2)
            draw.text((ox + 24, 240), "1 · Archive", font=F_H2, fill=ACCENT3)
            draw.text((ox + 24, 275), "original → Photos / iCloud", font=F_BODY, fill=TEXT)

            rounded_rect(draw, (ox, 350, ox + 480, 450), 12, PANEL, ACCENT2, 2)
            draw.text((ox + 24, 370), "2 · Share", font=F_H2, fill=ACCENT2)
            draw.text((ox + 24, 405), "sips → PNG → clipboard", font=F_BODY, fill=TEXT)

            rounded_rect(draw, (ox, 480, ox + 480, 560), 12, PANEL, ACCENT, 2)
            draw.text((ox + 24, 505), "3 · Cleanup — delete staging", font=F_H2, fill=ACCENT)

    elif t < 7.5:
        draw.text((80, 120), "3 · Photos first, then pasteboard", font=F_H1, fill=TEXT)
        p = ease(scene_t(i, 5.5, 6.2))
        # Photos on the left (first), pasteboard on the right (second)
        left = (80, 200, 600, 580)
        right = (680, 200, 1200, 580)
        draw_window(draw, left, "Photos — step 1")
        draw_window(draw, right, "Pasteboard — step 2")

        for r in range(2):
            for c in range(3):
                x = 120 + c * 140
                y = 280 + r * 130
                col = (50 + c * 20, 45 + r * 15, 70 + c * 10)
                rounded_rect(draw, (x, y, x + 120, y + 110), 8, col, BORDER, 1)
        if p > 0.35:
            rounded_rect(draw, (120, 280, 240, 390), 8, (60, 90, 120), ACCENT3, 3)
            draw.text((135, 320), "NEW", font=F_H2, fill=WHITE)
            draw.text((135, 350), "Screenshot", font=F_TINY, fill=TEXT)

        rounded_rect(draw, (720, 270, 1160, 500), 10, (20, 40, 30), ACCENT, 2)
        draw.text((750, 300), "PNG ready", font=F_H1, fill=ACCENT)
        draw.text((750, 350), "After Photos import:", font=F_BODY, fill=TEXT)
        draw.text((750, 385), "Cmd+V in Discord, Notes, browsers.", font=F_BODY, fill=TEXT)
        draw.text((750, 430), "Tone-mapped when source is HDR.", font=F_SMALL, fill=MUTED)

        draw.text((80, 600), "Order: staging file → Photos (original) → clipboard PNG → delete staging.", font=F_SMALL, fill=WARN)

    elif t < 9.0:
        draw.text((80, 120), "4 · Markup — Cmd+Shift+E", font=F_H1, fill=TEXT)
        p = ease(scene_t(i, 7.5, 8.3))
        labels = ["⌘", "⇧", "E"]
        cw = chord_width(len(labels))
        x0 = 80
        for ki, lab in enumerate(labels):
            draw_keycap(draw, x0 + ki * 62, 180, lab, on=True)

        # Preview window
        draw_window(draw, (80, 240, 720, 620), "Preview")
        # image with annotation
        rounded_rect(draw, (120, 300, 680, 560), 8, (35, 42, 55), BORDER, 1)
        # circle annotation grows
        cx, cy = 400, 430
        rad = int(lerp(10, 70, p))
        draw.ellipse((cx - rad, cy - rad, cx + rad, cy + rad), outline=(255, 80, 80), width=4)
        draw.line((cx + rad - 5, cy - 10, cx + rad + 40, cy - 40), fill=(255, 80, 80), width=3)
        draw.text((cx + rad + 48, cy - 50), "note", font=F_BODY, fill=(255, 120, 120))

        # side steps
        rounded_rect(draw, (760, 260, 1200, 600), 12, PANEL, BORDER, 2)
        steps = [
            ("1", "Open clipboard image"),
            ("2", "Annotate in Preview"),
            ("3", "Cmd+A  ·  Cmd+C"),
            ("4", "Cmd+V anywhere"),
        ]
        for si, (num, label) in enumerate(steps):
            y = 300 + si * 70
            on = p > si * 0.2
            fill = ACCENT if on else PANEL2
            draw.ellipse((790, y, 830, y + 40), fill=fill)
            bbox = draw.textbbox((0, 0), num, font=F_H2)
            tw = bbox[2] - bbox[0]
            draw.text((790 + (40 - tw) / 2, y + 8), num, font=F_H2, fill=WHITE)
            draw.text((850, y + 8), label, font=F_BODY, fill=TEXT if on else MUTED)

    else:
        p = ease(scene_t(i, 9.0, 9.8))
        draw.text((80, 200), "Done.", font=F_TITLE, fill=TEXT)
        lines = [
            "Staging receives the capture first",
            "Photos keeps the original (HDR)",
            "Pasteboard gets a share PNG",
            "Staging file deleted — desk stays clean",
        ]
        for li, line in enumerate(lines):
            y = 280 + li * 48
            mark = "✓" if p > li * 0.15 else "·"
            color = ACCENT if p > li * 0.15 else MUTED
            draw.text((100, y), f"{mark}  {line}", font=F_H2, fill=color)
        draw.text((80, 520), "github.com/travisjneuman/macos-screenshot-pipeline", font=F_BODY, fill=ACCENT2)
        draw.text((80, 560), "MIT · native launchd · no telemetry", font=F_SMALL, fill=MUTED)

    progress_bar(draw, i)
    return img


def make_hero() -> Image.Image:
    """Static 1280x640 social/README hero."""
    img = Image.new("RGB", (1280, 640), BG)
    draw = ImageDraw.Draw(img)
    draw.rectangle((0, 0, 1280, 6), fill=ACCENT2)
    draw.text((64, 48), "macos-screenshot-pipeline", font=F_H2, fill=MUTED)
    draw.text((64, 120), "Stock macOS capture.", font=F_TITLE, fill=TEXT)
    draw.text((64, 175), "Finished handoff.", font=F_TITLE, fill=TEXT)
    draw.text((64, 250), "Staging → Photos (original) → clipboard PNG → cleanup", font=F_BODY, fill=MUTED)

    # three cards
    cards = [
        (64, 340, "1 · Staging", "Capture lands here", ACCENT2),
        (450, 340, "2 · Photos", "then clipboard PNG", ACCENT),
        (836, 340, "3 · Markup", "Cmd+Shift+E", ACCENT3),
    ]
    for x, y, top, bot, col in cards:
        rounded_rect(draw, (x, y, x + 360, y + 160), 16, PANEL, col, 3)
        draw.text((x + 28, y + 36), top, font=F_H2, fill=col)
        draw.text((x + 28, y + 90), bot, font=F_H1, fill=TEXT)

    draw.text((64, 560), "Native · WatchPaths · HDR-honest · MIT", font=F_SMALL, fill=MUTED)
    return img


def main() -> None:
    ASSETS.mkdir(parents=True, exist_ok=True)
    hero = make_hero()
    hero_path = ASSETS / "hero.png"
    hero.save(hero_path, "PNG", optimize=True)
    print(f"wrote {hero_path}")

    frames_dir = ASSETS / "_frames"
    frames_dir.mkdir(exist_ok=True)
    for i in range(NFRAMES):
        frame = frame_image(i)
        frame.save(frames_dir / f"frame_{i:04d}.png")
        if i % 15 == 0:
            print(f"frame {i}/{NFRAMES}")
    print(f"wrote {NFRAMES} frames → {frames_dir}")


if __name__ == "__main__":
    main()
