from __future__ import annotations

import argparse
from pathlib import Path

from PIL import Image


def _ensure_square(im: Image.Image, size: int) -> Image.Image:
    im = im.convert("RGBA")
    src_w, src_h = im.size
    if src_w == src_h:
        resized = im.resize((size, size), Image.LANCZOS)
    else:
        scale = min(size / src_w, size / src_h)
        new_w = max(1, int(round(src_w * scale)))
        new_h = max(1, int(round(src_h * scale)))
        resized_src = im.resize((new_w, new_h), Image.LANCZOS)
        canvas = Image.new("RGBA", (size, size), (0, 0, 0, 0))
        x = (size - new_w) // 2
        y = (size - new_h) // 2
        canvas.alpha_composite(resized_src, (x, y))
        resized = canvas
    return resized


def generate_windows_ico(src_png: Path, out_ico: Path) -> None:
    sizes = [16, 24, 32, 48, 64, 128, 256]
    base = _ensure_square(Image.open(src_png), 256)
    out_ico.parent.mkdir(parents=True, exist_ok=True)
    base.save(out_ico, format="ICO", sizes=[(s, s) for s in sizes])


def generate_android_icons(src_png: Path, res_dir: Path) -> None:
    mapping = {
        "mipmap-mdpi": 48,
        "mipmap-hdpi": 72,
        "mipmap-xhdpi": 96,
        "mipmap-xxhdpi": 144,
        "mipmap-xxxhdpi": 192,
    }
    for folder, size in mapping.items():
        out = res_dir / folder / "ic_launcher.png"
        out.parent.mkdir(parents=True, exist_ok=True)
        img = _ensure_square(Image.open(src_png), size)
        img.save(out, format="PNG", optimize=True)


def main() -> None:
    project_root = Path(__file__).resolve().parents[1]

    parser = argparse.ArgumentParser(description="Generate Windows/Android icons.")
    parser.add_argument(
        "--src",
        type=Path,
        default=project_root / "assets" / "branding" / "FS.png",
        help="Source PNG path (default: assets/branding/FS.png)",
    )
    args = parser.parse_args()

    src: Path = args.src
    if not src.exists():
        raise SystemExit(f"FS.png not found: {src}")

    generate_windows_ico(
        src_png=src,
        out_ico=project_root / "windows" / "runner" / "resources" / "app_icon.ico",
    )
    generate_android_icons(
        src_png=src,
        res_dir=project_root / "android" / "app" / "src" / "main" / "res",
    )
    print("OK: icons updated")


if __name__ == "__main__":
    main()
