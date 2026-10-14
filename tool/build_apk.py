#!/usr/bin/env python3
"""Build a starter Flutter APK and place it in the sibling local-output folder."""

import argparse
import re
import shutil
import subprocess
from pathlib import Path


UPLOAD_ROOT = Path(__file__).resolve().parents[1]
TEMPLATE_ROOT = UPLOAD_ROOT.parent
APP_ROOT = UPLOAD_ROOT / "App Code"
OUTPUT_ROOT = TEMPLATE_ROOT / "Not Uploaded to Github" / "APK's (Test,Uploaded and To be Uploaded)"

parser = argparse.ArgumentParser(description="Build an APK from App Code")
parser.add_argument("mode", choices=("test", "production"))
parser.add_argument(
    "--app-slug",
    default="new-app",
    help="Output filename prefix, for example my-app",
)
args = parser.parse_args()

if not re.fullmatch(r"[a-z0-9]+(?:-[a-z0-9]+)*", args.app_slug):
    parser.error("--app-slug must use lowercase letters, numbers, and hyphens")
if not (APP_ROOT / "pubspec.yaml").is_file():
    raise SystemExit(f"Flutter project not found: {APP_ROOT}")

build_type = "debug" if args.mode == "test" else "release"
output_folder = "Test" if args.mode == "test" else "To be Uploaded"
subprocess.run(
    ["flutter", "build", "apk", f"--{build_type}"],
    cwd=APP_ROOT,
    check=True,
)

source = APP_ROOT / "build" / "app" / "outputs" / "flutter-apk" / f"app-{build_type}.apk"
target_dir = OUTPUT_ROOT / output_folder
target_dir.mkdir(parents=True, exist_ok=True)
target = target_dir / f"{args.app_slug}-{args.mode}.apk"
shutil.copy2(source, target)
print(target)
