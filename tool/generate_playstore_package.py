#!/usr/bin/env python3
"""
Generate reusable Google Play publishing assets and a static website.

Defaults are set for the current project layout, but every path can be
overridden so the script can be reused from another app's assets folder.
"""

from __future__ import annotations

import argparse
import html
import shutil
import textwrap
from pathlib import Path
from typing import Iterable

from PIL import Image, ImageDraw, ImageFilter, ImageFont


SCRIPT_DIR = Path(__file__).resolve().parent
PROJECT_ROOT = SCRIPT_DIR.parent
DEFAULT_ASSETS_ROOT = PROJECT_ROOT / "App Code" / "assets"
DEFAULT_MASTER_DIR = DEFAULT_ASSETS_ROOT / "Play Store Assets-Master" / "Screenshots Taken from Phone" / "Google Play Screenshots"
DEFAULT_OUTPUT_ROOT = DEFAULT_ASSETS_ROOT / "Play Store Assets-Master"
DEFAULT_WEBSITE_BUILD = DEFAULT_ASSETS_ROOT / "Website" / "build"
DEFAULT_PRIVACY_FILE = DEFAULT_ASSETS_ROOT / "privacy_policy.md"
DEFAULT_ICON = DEFAULT_ASSETS_ROOT / "app_icon.png"
DEFAULT_FEATURES_FILE = DEFAULT_ASSETS_ROOT / "website_features.json"

FEATURE_SIZE = (1024, 500)
SEVEN_INCH_SIZE = (1920, 1080)
TEN_INCH_SIZE = (2560, 1440)

IMAGE_EXTENSIONS = {".jpg", ".jpeg", ".png", ".webp"}
DEFAULT_FEATURES = [
    ("Feature one", "Replace this text with a short description of an app feature."),
    ("Feature two", "Describe another capability your users will find useful."),
    ("Privacy", "Explain your app's actual data and privacy practices."),
    ("Open source", "Add a source code link if this app is open source."),
]


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Generate Play Store graphics and a static app website."
    )
    parser.add_argument("--app-name", default="Your App Name")
    parser.add_argument("--tagline", default="Add a short description of your app.")
    parser.add_argument("--source-code-url", default="", help="Optional public source repository URL")
    parser.add_argument("--assets-root", type=Path, default=DEFAULT_ASSETS_ROOT)
    parser.add_argument("--source-dir", type=Path, default=DEFAULT_MASTER_DIR)
    parser.add_argument("--output-root", type=Path, default=DEFAULT_OUTPUT_ROOT)
    parser.add_argument("--website-build", type=Path, default=DEFAULT_WEBSITE_BUILD)
    parser.add_argument("--privacy-file", type=Path, default=DEFAULT_PRIVACY_FILE)
    parser.add_argument("--app-icon", type=Path, default=DEFAULT_ICON)
    parser.add_argument("--features-file", type=Path, default=DEFAULT_FEATURES_FILE)
    parser.add_argument("--max-screenshots", type=int, default=9)
    return parser.parse_args()


def image_files(source_dir: Path, limit: int | None = None) -> list[Path]:
    files = sorted(
        [p for p in source_dir.iterdir() if p.is_file() and p.suffix.lower() in IMAGE_EXTENSIONS],
        key=lambda p: natural_key(p.name),
    )
    return files[:limit] if limit else files


def natural_key(value: str) -> list[object]:
    parts: list[object] = []
    current = ""
    for char in value:
        if char.isdigit():
            current += char
        else:
            if current:
                parts.append(int(current))
                current = ""
            parts.append(char.lower())
    if current:
        parts.append(int(current))
    return parts


def load_font(size: int, bold: bool = False) -> ImageFont.FreeTypeFont | ImageFont.ImageFont:
    candidates = [
        "/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf",
        "/usr/share/fonts/truetype/liberation2/LiberationSans-Bold.ttf" if bold else "/usr/share/fonts/truetype/liberation2/LiberationSans-Regular.ttf",
    ]
    for candidate in candidates:
        path = Path(candidate)
        if path.exists():
            return ImageFont.truetype(str(path), size)
    return ImageFont.load_default()


def fit_cover(image: Image.Image, size: tuple[int, int]) -> Image.Image:
    width, height = size
    ratio = max(width / image.width, height / image.height)
    resized = image.resize((round(image.width * ratio), round(image.height * ratio)), Image.Resampling.LANCZOS)
    left = (resized.width - width) // 2
    top = (resized.height - height) // 2
    return resized.crop((left, top, left + width, top + height))


def fit_contain(image: Image.Image, max_size: tuple[int, int]) -> Image.Image:
    copy = image.copy()
    copy.thumbnail(max_size, Image.Resampling.LANCZOS)
    return copy


def rounded_mask(size: tuple[int, int], radius: int) -> Image.Image:
    mask = Image.new("L", size, 0)
    draw = ImageDraw.Draw(mask)
    draw.rounded_rectangle((0, 0, size[0], size[1]), radius=radius, fill=255)
    return mask


def paste_rounded(base: Image.Image, image: Image.Image, xy: tuple[int, int], radius: int) -> None:
    mask = rounded_mask(image.size, radius)
    base.paste(image, xy, mask)


def dominant_color(image: Image.Image) -> tuple[int, int, int]:
    thumb = image.convert("RGB").resize((1, 1), Image.Resampling.BOX)
    return thumb.getpixel((0, 0))


def blend(color: tuple[int, int, int], other: tuple[int, int, int], alpha: float) -> tuple[int, int, int]:
    return tuple(round(color[i] * (1 - alpha) + other[i] * alpha) for i in range(3))


def draw_wrapped_text(
    draw: ImageDraw.ImageDraw,
    text: str,
    xy: tuple[int, int],
    font: ImageFont.ImageFont,
    fill: tuple[int, int, int],
    max_width: int,
    line_gap: int,
) -> int:
    words = text.split()
    lines: list[str] = []
    line = ""
    for word in words:
        candidate = f"{line} {word}".strip()
        if draw.textbbox((0, 0), candidate, font=font)[2] <= max_width:
            line = candidate
        else:
            if line:
                lines.append(line)
            line = word
    if line:
        lines.append(line)

    x, y = xy
    for line in lines:
        draw.text((x, y), line, font=font, fill=fill)
        bbox = draw.textbbox((x, y), line, font=font)
        y = bbox[3] + line_gap
    return y


def create_feature_graphic(source: Path, output: Path, app_name: str, tagline: str, icon_path: Path | None, features: list[tuple[str, str]]) -> None:
    src = Image.open(source).convert("RGB")
    base_color = dominant_color(src)
    dark = blend(base_color, (7, 18, 20), 0.72)
    accent = (40, 198, 164)

    canvas = Image.new("RGB", FEATURE_SIZE, dark)
    background = fit_cover(src.filter(ImageFilter.GaussianBlur(9)), FEATURE_SIZE)
    overlay = Image.new("RGB", FEATURE_SIZE, blend(dark, (0, 0, 0), 0.18))
    canvas = Image.blend(background, overlay, 0.76)

    draw = ImageDraw.Draw(canvas)
    draw.rectangle((0, 0, 1024, 500), fill=(0, 0, 0, 0))
    draw.rounded_rectangle((50, 54, 974, 446), radius=28, fill=blend(dark, (255, 255, 255), 0.05), outline=blend(accent, (255, 255, 255), 0.18), width=2)

    phone = fit_contain(src, (232, 408))
    shadow = Image.new("RGBA", (phone.width + 34, phone.height + 34), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle((17, 17, phone.width + 17, phone.height + 17), radius=30, fill=(0, 0, 0, 90))
    shadow = shadow.filter(ImageFilter.GaussianBlur(12))
    canvas.paste(shadow.convert("RGB"), (666, 48), shadow)
    paste_rounded(canvas, phone, (683, 65), 22)

    if icon_path and icon_path.exists():
        icon = Image.open(icon_path).convert("RGBA")
        icon.thumbnail((74, 74), Image.Resampling.LANCZOS)
        paste_rounded(canvas, icon.convert("RGB"), (92, 92), 18)
        title_x = 186
    else:
        title_x = 92

    title_font = load_font(42, bold=True)
    sub_font = load_font(25)
    feature_font = load_font(21, bold=True)
    title_bottom = draw_wrapped_text(draw, app_name, (title_x, 87), title_font, (255, 255, 255), 450, 6)
    draw_wrapped_text(draw, tagline, (94, max(172, title_bottom + 18)), sub_font, (223, 239, 233), 520, 8)

    feature_labels = [feature[0] for feature in features[:4]]
    y = 282
    for feature in feature_labels:
        draw.rounded_rectangle((94, y, 118, y + 24), radius=12, fill=accent)
        draw.text((132, y - 2), feature, font=feature_font, fill=(245, 250, 248))
        y += 43

    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, "PNG", optimize=True)


def create_tablet_screenshot(source: Path, output: Path, size: tuple[int, int], app_name: str, tagline: str, icon_path: Path | None, features: list[tuple[str, str]]) -> None:
    src = Image.open(source).convert("RGB")
    base_color = dominant_color(src)
    dark = blend(base_color, (8, 20, 22), 0.7)
    canvas = Image.new("RGB", size, dark)
    background = fit_cover(src.filter(ImageFilter.GaussianBlur(18)), size)
    wash = Image.new("RGB", size, blend(dark, (13, 33, 35), 0.35))
    canvas = Image.blend(background, wash, 0.78)
    draw = ImageDraw.Draw(canvas)

    margin = round(size[0] * 0.06)
    panel = (margin, round(size[1] * 0.08), size[0] - margin, round(size[1] * 0.92))
    draw.rounded_rectangle(panel, radius=42, fill=blend(dark, (255, 255, 255), 0.06), outline=blend((35, 196, 117), (255, 255, 255), 0.08), width=3)

    phone_max = (round(size[0] * 0.29), round(size[1] * 0.78))
    phone = fit_contain(src, phone_max)
    phone_x = panel[2] - phone.width - round(size[0] * 0.08)
    phone_y = (size[1] - phone.height) // 2
    paste_rounded(canvas, phone, (phone_x, phone_y), max(24, round(size[0] * 0.014)))

    text_x = panel[0] + round(size[0] * 0.065)
    y = panel[1] + round(size[1] * 0.16)
    if icon_path and icon_path.exists():
        icon = Image.open(icon_path).convert("RGBA")
        icon.thumbnail((round(size[0] * 0.055), round(size[0] * 0.055)), Image.Resampling.LANCZOS)
        paste_rounded(canvas, icon.convert("RGB"), (text_x, y - round(size[1] * 0.01)), round(size[0] * 0.012))
        text_x += icon.width + round(size[0] * 0.024)

    title_font = load_font(max(52, round(size[0] * 0.038)), bold=True)
    sub_font = load_font(max(27, round(size[0] * 0.019)))
    badge_font = load_font(max(25, round(size[0] * 0.017)), bold=True)
    draw_wrapped_text(draw, app_name, (text_x, y), title_font, (255, 255, 255), round(size[0] * 0.42), 12)
    y += round(size[1] * 0.2)
    draw_wrapped_text(
        draw,
        tagline,
        (panel[0] + round(size[0] * 0.065), y),
        sub_font,
        (225, 238, 233),
        round(size[0] * 0.44),
        12,
    )
    y += round(size[1] * 0.18)
    for label, _ in features[:3]:
        draw.rounded_rectangle(
            (panel[0] + round(size[0] * 0.065), y, panel[0] + round(size[0] * 0.34), y + round(size[1] * 0.055)),
            radius=round(size[1] * 0.028),
            fill=blend((35, 196, 117), (255, 255, 255), 0.03),
        )
        draw.text(
            (panel[0] + round(size[0] * 0.085), y + round(size[1] * 0.012)),
            label,
            font=badge_font,
            fill=(244, 255, 250),
        )
        y += round(size[1] * 0.077)

    output.parent.mkdir(parents=True, exist_ok=True)
    canvas.save(output, "PNG", optimize=True)


def extract_policy_lines(policy_path: Path) -> list[str]:
    if not policy_path.exists():
        return []
    return [line.strip() for line in policy_path.read_text(encoding="utf-8").splitlines() if line.strip()]


def privacy_html(paragraphs: Iterable[str]) -> str:
    blocks: list[str] = []
    for text in paragraphs:
        if text.startswith("## "):
            blocks.append(f"<h2>{html.escape(text[3:])}</h2>")
        elif text.startswith("# "):
            blocks.append(f"<h1>{html.escape(text[2:])}</h1>")
        else:
            blocks.append(f"<p>{html.escape(text)}</p>")
    return "\n".join(blocks)


def copy_site_images(files: list[Path], icon_path: Path, website_build: Path) -> tuple[list[str], str | None]:
    media_dir = website_build / "media"
    media_dir.mkdir(parents=True, exist_ok=True)
    copied: list[str] = []
    for file in files:
        target = media_dir / file.name
        shutil.copy2(file, target)
        copied.append(f"media/{target.name}")
    icon_rel = None
    if icon_path.exists():
        target = media_dir / icon_path.name
        shutil.copy2(icon_path, target)
        icon_rel = f"media/{target.name}"
    return copied, icon_rel


def build_website(
    website_build: Path,
    app_name: str,
    tagline: str,
    source_files: list[Path],
    icon_path: Path,
    privacy_paragraphs: list[str],
    features: list[tuple[str, str]],
    source_code_url: str,
) -> None:
    website_build.mkdir(parents=True, exist_ok=True)
    image_refs, icon_ref = copy_site_images(source_files, icon_path, website_build)
    hero_image = f'<img src="{image_refs[0]}" alt="{html.escape(app_name)} app preview" class="hero-bg">' if image_refs else ""
    icon_markup = f'<img src="{icon_ref}" alt="{html.escape(app_name)} icon" class="brand-icon">' if icon_ref else ""
    gallery = "\n".join(
        f'<figure class="screen"><img src="{ref}" alt="{html.escape(app_name)} screenshot {idx}"></figure>'
        for idx, ref in enumerate(image_refs, start=1)
    )
    feature_cards = "\n".join(
        f'<article><span>{idx:02}</span><h3>{html.escape(title)}</h3><p>{html.escape(description)}</p></article>'
        for idx, (title, description) in enumerate(features, start=1)
    )
    source_link = (
        f'<a href="{html.escape(source_code_url, quote=True)}" target="_blank" rel="noopener">Find our source code here.</a>'
        if source_code_url
        else "Add a link to the public source repository here, or remove this sentence."
    )
    gallery_section = (
        f'<div class="screenshot-strip">{gallery}</div>'
        if gallery
        else '<p>Add phone screenshots to the Google Play Screenshots folder, then regenerate this site.</p>'
    )

    index = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>{html.escape(app_name)}</title>
  <meta name="description" content="{html.escape(tagline)}">
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
  <link rel="stylesheet" href="styles.css">
</head>
<body>
  <nav class="navbar navbar-expand-lg fixed-top app-nav">
    <div class="container">
      <a class="navbar-brand d-flex align-items-center gap-2" href="index.html">{icon_markup}<span>{html.escape(app_name)}</span></a>
      <button class="navbar-toggler" type="button" data-bs-toggle="collapse" data-bs-target="#nav" aria-controls="nav" aria-expanded="false" aria-label="Toggle navigation">
        <span class="navbar-toggler-icon"></span>
      </button>
      <div class="collapse navbar-collapse" id="nav">
        <ul class="navbar-nav ms-auto">
          <li class="nav-item"><a class="nav-link" href="#features">Features</a></li>
          <li class="nav-item"><a class="nav-link" href="#screenshots">Screenshots</a></li>
          <li class="nav-item"><a class="nav-link" href="privacy.html">Privacy Policy</a></li>
        </ul>
      </div>
    </div>
  </nav>

  <header class="hero">
    <img src="{hero_image}" alt="{html.escape(app_name)} app preview" class="hero-bg">
    <div class="hero-shade"></div>
    <div class="container hero-content">
      <div class="hero-copy">
        {icon_markup}
        <h1>{html.escape(app_name)}</h1>
        <p>{html.escape(tagline)}</p>
        <div class="hero-actions">
          <a href="#features" class="btn btn-primary">View features</a>
          <a href="privacy.html" class="btn btn-outline-light">Privacy policy</a>
        </div>
      </div>
    </div>
  </header>

  <main>
    <section class="section" id="features">
      <div class="container">
        <div class="section-heading">
          <p class="eyebrow">App features</p>
          <h2>Discover what {html.escape(app_name)} can do.</h2>
        </div>
        <div class="feature-grid">{feature_cards}</div>
      </div>
    </section>

    <section class="section muted" id="screenshots">
      <div class="container">
        <div class="section-heading">
          <p class="eyebrow">Screenshots</p>
          <h2>See the app in action.</h2>
        </div>
        {gallery_section}
      </div>
    </section>

    <section class="section transparency" id="transparency">
      <div class="container">
        <div class="section-heading">
          <p class="eyebrow">Privacy and transparency</p>
          <h2>Privacy and transparency</h2>
          <p>Review how {html.escape(app_name)} handles information in the <a href="privacy.html">privacy policy</a>. {source_link}</p>
        </div>
      </div>
    </section>
  </main>

  <footer class="footer">
    <div class="container d-flex flex-column flex-md-row justify-content-between gap-3">
      <span>{html.escape(app_name)}</span>
      <a href="privacy.html">Privacy Policy</a>
    </div>
  </footer>

  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
  <script src="script.js"></script>
</body>
</html>
"""

    privacy = f"""<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <title>Privacy Policy | {html.escape(app_name)}</title>
  <link href="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/css/bootstrap.min.css" rel="stylesheet">
  <link rel="stylesheet" href="styles.css">
</head>
<body class="policy-body">
  <nav class="navbar navbar-expand-lg app-nav policy-nav">
    <div class="container">
      <a class="navbar-brand d-flex align-items-center gap-2" href="index.html">{icon_markup}<span>{html.escape(app_name)}</span></a>
      <a class="btn btn-sm btn-primary" href="index.html">Home</a>
    </div>
  </nav>
  <main class="policy-page">
    <div class="container">
      <article class="policy-content">
        {privacy_html(privacy_paragraphs)}
      </article>
    </div>
  </main>
  <script src="https://cdn.jsdelivr.net/npm/bootstrap@5.3.3/dist/js/bootstrap.bundle.min.js"></script>
</body>
</html>
"""

    css = """@import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&display=swap');

:root {
  --green: #28c6a4;
  --green-dark: #07896d;
  --ink: #14233d;
  --surface: #f5f7fb;
  --muted: #e1e7ef;
  --text: #14233d;
}

* { box-sizing: border-box; }
body {
  margin: 0;
  font-family: 'Inter', system-ui, -apple-system, BlinkMacSystemFont, 'Segoe UI', sans-serif;
  color: var(--text);
  background: #ffffff;
}

.app-nav {
  background: rgba(9, 20, 21, 0.9);
  backdrop-filter: blur(14px);
  border-bottom: 1px solid rgba(255,255,255,0.08);
}
.navbar-brand, .app-nav .nav-link { color: #f7fffb; }
.app-nav .nav-link:hover, .navbar-brand:hover { color: var(--green); }
.navbar-toggler { border-color: rgba(255,255,255,0.35); }
.navbar-toggler-icon { filter: invert(1); }
.brand-icon {
  width: 38px;
  height: 38px;
  border-radius: 10px;
  object-fit: cover;
}

.hero {
  min-height: 92vh;
  position: relative;
  display: flex;
  align-items: center;
  overflow: hidden;
  background: var(--ink);
}
.hero-bg {
  position: absolute;
  inset: 0;
  width: 100%;
  height: 100%;
  object-fit: cover;
  filter: blur(8px) saturate(0.95);
  transform: scale(1.04);
  opacity: 0.5;
}
.hero-shade {
  position: absolute;
  inset: 0;
  background: linear-gradient(90deg, rgba(9,20,21,0.95), rgba(9,20,21,0.72) 48%, rgba(9,20,21,0.38));
}
.hero-content { position: relative; padding-top: 86px; }
.hero-copy { max-width: 650px; color: #fff; }
.hero-copy .brand-icon {
  width: 76px;
  height: 76px;
  border-radius: 18px;
  margin-bottom: 28px;
}
h1 {
  font-size: 4.4rem;
  line-height: 1.02;
  font-weight: 800;
  margin: 0 0 20px;
}
.hero p {
  max-width: 560px;
  color: #dbeae4;
  font-size: 1.25rem;
  line-height: 1.65;
}
.hero-actions { display: flex; gap: 14px; flex-wrap: wrap; margin-top: 34px; }
.btn-primary {
  --bs-btn-bg: var(--green);
  --bs-btn-border-color: var(--green);
  --bs-btn-hover-bg: var(--green-dark);
  --bs-btn-hover-border-color: var(--green-dark);
  color: #062014;
  font-weight: 700;
}

.section { padding: 92px 0; }
.muted { background: var(--surface); }
.section-heading { max-width: 720px; margin-bottom: 38px; }
.eyebrow {
  color: var(--green-dark);
  font-weight: 800;
  text-transform: uppercase;
  font-size: 0.82rem;
  margin-bottom: 12px;
}
h2 {
  font-size: 2.55rem;
  line-height: 1.15;
  font-weight: 800;
  margin: 0;
}
.feature-grid {
  display: grid;
  grid-template-columns: repeat(3, minmax(0, 1fr));
  gap: 18px;
}
.feature-grid article {
  border: 1px solid var(--muted);
  border-radius: 8px;
  padding: 26px;
  background: #fff;
  min-height: 220px;
}
.feature-grid span {
  color: var(--green-dark);
  font-weight: 800;
}
h3 {
  font-size: 1.2rem;
  margin: 16px 0 10px;
  font-weight: 800;
}
.feature-grid p {
  line-height: 1.65;
  color: #4b5a57;
  margin: 0;
}
.screenshot-strip {
  display: grid;
  grid-template-columns: repeat(6, minmax(150px, 1fr));
  gap: 16px;
  align-items: start;
}
.screen {
  margin: 0;
  background: #0d1b1d;
  border-radius: 8px;
  padding: 10px;
  box-shadow: 0 18px 44px rgba(7, 18, 19, 0.14);
}
.screen img {
  display: block;
  width: 100%;
  aspect-ratio: 9 / 20;
  object-fit: contain;
  border-radius: 6px;
}
.footer {
  background: var(--ink);
  color: #dbeae4;
  padding: 28px 0;
}
.footer a { color: var(--green); text-decoration: none; }

.policy-body { background: var(--surface); }
.policy-nav { position: sticky; top: 0; z-index: 10; }
.policy-page { padding: 54px 0 88px; }
.policy-content {
  background: #fff;
  border: 1px solid var(--muted);
  border-radius: 8px;
  padding: 48px;
  max-width: 980px;
  margin: 0 auto;
}
.policy-content h1 {
  color: var(--ink);
  font-size: 2.7rem;
}
.policy-content h2 {
  font-size: 1.45rem;
  margin-top: 34px;
}
.policy-content h3 {
  font-size: 1.08rem;
  margin-top: 24px;
}
.policy-content p {
  line-height: 1.75;
  color: #394844;
}

@media (max-width: 991px) {
  h1 { font-size: 3.2rem; }
  h2 { font-size: 2rem; }
  .feature-grid { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .screenshot-strip { grid-template-columns: repeat(3, minmax(0, 1fr)); }
}

@media (max-width: 640px) {
  .hero { min-height: 86vh; }
  h1 { font-size: 2.35rem; }
  .hero p { font-size: 1.05rem; }
  .section { padding: 64px 0; }
  .feature-grid { grid-template-columns: 1fr; }
  .screenshot-strip { grid-template-columns: repeat(2, minmax(0, 1fr)); }
  .policy-content { padding: 28px 20px; }
}
"""

    js = """document.querySelectorAll('a[href^="#"]').forEach((link) => {
  link.addEventListener('click', (event) => {
    const target = document.querySelector(link.getAttribute('href'));
    if (!target) return;
    event.preventDefault();
    target.scrollIntoView({ behavior: 'smooth', block: 'start' });
  });
});
"""

    (website_build / "index.html").write_text(index, encoding="utf-8")
    (website_build / "privacy.html").write_text(privacy, encoding="utf-8")
    (website_build / "styles.css").write_text(css, encoding="utf-8")
    (website_build / "script.js").write_text(js, encoding="utf-8")


def clean_generated_dirs(output_root: Path, website_build: Path) -> None:
    for folder in [
        output_root / "Feature graphic",
        output_root / "7-inch tablet screenshots",
        output_root / "10-inch tablet screenshots",
        website_build,
    ]:
        if folder.exists():
            shutil.rmtree(folder)


def main() -> None:
    args = parse_args()
    source_dir = args.source_dir.expanduser().resolve()
    output_root = args.output_root.expanduser().resolve()
    website_build = args.website_build.expanduser().resolve()
    privacy_file = args.privacy_file.expanduser().resolve()
    app_icon = args.app_icon.expanduser().resolve()

    source_dir.mkdir(parents=True, exist_ok=True)

    sources = image_files(source_dir, args.max_screenshots)
    features_file = args.features_file.expanduser().resolve()
    features = DEFAULT_FEATURES
    if features_file.exists():
        import json
        raw_features = json.loads(features_file.read_text(encoding="utf-8"))
        features = [(str(item["title"]), str(item["description"])) for item in raw_features]

    clean_generated_dirs(output_root, website_build)

    feature_dir = output_root / "Feature graphic"
    seven_dir = output_root / "7-inch tablet screenshots"
    ten_dir = output_root / "10-inch tablet screenshots"

    for index, source in enumerate(sources, start=1):
        create_feature_graphic(source, feature_dir / f"feature-graphic-{index}.png", args.app_name, args.tagline, app_icon, features)
        create_tablet_screenshot(source, seven_dir / f"7-inch-tablet-{index}.png", SEVEN_INCH_SIZE, args.app_name, args.tagline, app_icon, features)
        create_tablet_screenshot(source, ten_dir / f"10-inch-tablet-{index}.png", TEN_INCH_SIZE, args.app_name, args.tagline, app_icon, features)

    privacy_paragraphs = extract_policy_lines(privacy_file)
    if not privacy_paragraphs:
        privacy_paragraphs = [
            "# Privacy Policy",
            args.app_name,
            "Privacy policy content was not found. Provide a Markdown file with --privacy-file.",
        ]

    build_website(website_build, args.app_name, args.tagline, sources, app_icon, privacy_paragraphs, features, args.source_code_url)

    print(
        textwrap.dedent(
            f"""
            Generated {len(sources)} feature graphics in: {feature_dir}
            Generated {len(sources)} 7-inch tablet screenshots in: {seven_dir}
            Generated {len(sources)} 10-inch tablet screenshots in: {ten_dir}
            Generated website in: {website_build}
            """
        ).strip()
    )


if __name__ == "__main__":
    main()
