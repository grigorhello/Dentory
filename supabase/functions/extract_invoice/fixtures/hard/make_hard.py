"""Makes the harder sample pages for the model comparison (model_compare.ts) from the fixture invoices and the demo
invoice: a tilted photo, a dim photo, low-resolution photos and scans, and a French invoice photographed at an angle in
poor light. Each is a JPEG as the app uploads it (quality 0.8 unless the variant is about compression, long edge at most
2,576 px). Fixed seeds, so running it again gives the same files.

    python3 supabase/functions/extract_invoice/fixtures/hard/make_hard.py   # Pillow, NumPy, pdftoppm (poppler)
"""
import pathlib
import subprocess
import tempfile

import numpy as np
from PIL import Image, ImageEnhance, ImageFilter

HERE = pathlib.Path(__file__).resolve().parent
FIXTURES = HERE.parent
DEMO = HERE.parents[4] / "docs" / "demo"
DESK = (92, 78, 64)


def save(image: Image.Image, name: str, quality: int = 80) -> None:
    image = image.convert("RGB")
    if max(image.size) > 2576:
        scale = 2576 / max(image.size)
        image = image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)
    image.save(HERE / name, "JPEG", quality=quality, optimize=True)
    print(f"{name}: {image.size[0]}x{image.size[1]}, {(HERE / name).stat().st_size // 1024} KB")


def pdf_pages(pdf: pathlib.Path, dpi: int) -> list[Image.Image]:
    with tempfile.TemporaryDirectory() as folder:
        subprocess.run(["pdftoppm", "-r", str(dpi), "-png", str(pdf), f"{folder}/page"], check=True)
        return [Image.open(path).convert("RGB") for path in sorted(pathlib.Path(folder).glob("page-*.png"))]


def tilt(image: Image.Image, degrees: float) -> Image.Image:
    """The page turned on a desk, with a margin of desk around it and a slight keystone."""
    margin = image.width // 12
    framed = Image.new("RGB", (image.width + 2 * margin, image.height + 2 * margin), DESK)
    framed.paste(image, (margin, margin))
    turned = framed.rotate(degrees, resample=Image.BICUBIC, expand=False, fillcolor=DESK)
    w, h = turned.size
    k = w * 0.035  # top edge narrower than the bottom, as from a phone held above the page
    quad = (k, 0, -k / 2, h, w + k / 2, h, w - k, 0)
    return turned.transform((w, h), Image.QUAD, quad, resample=Image.BICUBIC, fillcolor=DESK)


def dim(image: Image.Image, seed: int, light: float = 0.42) -> Image.Image:
    """A dark room: less light, less contrast, a light falling off to one corner, sensor noise and a little blur."""
    pixels = np.asarray(image).astype(np.float32) / 255
    h, w = pixels.shape[:2]
    y, x = np.mgrid[0:h, 0:w]
    falloff = 1 - 0.35 * ((x / w) * 0.6 + (y / h) * 0.4)
    pixels = 0.5 + (pixels - 0.5) * 0.7
    pixels = pixels * light * falloff[..., None]
    pixels += np.random.default_rng(seed).normal(0, 0.035, pixels.shape)
    out = Image.fromarray((np.clip(pixels, 0, 1) * 255).astype(np.uint8))
    return out.filter(ImageFilter.GaussianBlur(1.2))


def small(image: Image.Image, long_edge: int) -> Image.Image:
    scale = long_edge / max(image.size)
    return image.resize((round(image.width * scale), round(image.height * scale)), Image.LANCZOS)


photo = Image.open(DEMO / "northbridge-inv-10418-photo.png").convert("RGB")
save(photo, "northbridge-inv-10418-photo.jpg")
save(tilt(photo, 9), "northbridge-inv-10418-tilted.jpg")
save(dim(photo, seed=1), "northbridge-inv-10418-dim.jpg")
save(small(photo, 1000), "northbridge-inv-10418-small.jpg", quality=50)

french = pdf_pages(FIXTURES / "rive-sud-f-3381.pdf", 200)[0]
save(dim(tilt(french, -6), seed=2, light=0.55), "rive-sud-f-3381-photo.jpg")

for n, page in enumerate(pdf_pages(FIXTURES / "harbourview-hv-2207.pdf", 100), start=1):
    save(page, f"harbourview-hv-2207-small-page-{n}.jpg", quality=55)

for n in (1, 2):
    scan = Image.open(FIXTURES / f"prairie-pdw-90412-page-{n}.jpg").convert("RGB")
    save(small(scan, 1000), f"prairie-pdw-90412-small-page-{n}.jpg", quality=50)
