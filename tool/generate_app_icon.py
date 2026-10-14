#!/usr/bin/env python3
"""Resize a supplied app icon into Android launcher density assets."""

import argparse
from pathlib import Path

from PIL import Image, ImageOps


UPLOAD_ROOT = Path(__file__).resolve().parents[1]
DEFAULT_ICON = UPLOAD_ROOT / "App Code" / "assets" / "app_icon.png"
RESOURCES = UPLOAD_ROOT / "App Code" / "android" / "app" / "src" / "main" / "res"

parser = argparse.ArgumentParser(description=__doc__)
parser.add_argument("--icon", type=Path, default=DEFAULT_ICON)
args = parser.parse_args()
icon_path = args.icon.expanduser().resolve()
if not icon_path.is_file():
    raise SystemExit(
        f"Add a square PNG app icon at {icon_path} or pass --icon PATH."
    )

with Image.open(icon_path) as source:
    icon = ImageOps.fit(source.convert("RGBA"), (512, 512), method=Image.Resampling.LANCZOS)

for density, size in {
    "mipmap-mdpi": 48,
    "mipmap-hdpi": 72,
    "mipmap-xhdpi": 96,
    "mipmap-xxhdpi": 144,
    "mipmap-xxxhdpi": 192,
}.items():
    folder = RESOURCES / density
    folder.mkdir(parents=True, exist_ok=True)
    icon.resize((size, size), Image.Resampling.LANCZOS).save(
        folder / "ic_launcher.png", "PNG", optimize=True
    )

print(f"Updated Android launcher icons from {icon_path}")
