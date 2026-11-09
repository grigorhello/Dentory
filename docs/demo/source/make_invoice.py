"""Makes the sample delivery invoice in docs/demo: a one-page PDF and a phone photo of the printed page.

The invoice is made for trying Receive delivery on a clinic that holds the general-practice catalog
(supabase/catalogs/general-practice.sql), such as Smile Groove after its demo history: every product line names a
catalog product, so the reading matches it (docs/demo/README.md says what each line becomes). The supplier is
fictional, as in the reader's test invoices: phone numbers in the 555-01xx range, a web address ending in .example,
and the page says it is a synthetic sample.

    python3 docs/demo/source/make_invoice.py            # from the repository root

writes docs/demo/northbridge-inv-10418.pdf, docs/demo/northbridge-inv-10418-photo.png and
docs/demo/northbridge-inv-10418.json (the answer the reader should give, in reading.ts's extraction schema, before
parseExtraction). It needs Python 3 with Pillow and NumPy, and Chrome or Chromium: CHROME names the binary when it is
not `google-chrome` (on a Mac, CHROME="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome").
"""
import html
import json
import os
import subprocess
import sys
import tempfile
from decimal import ROUND_HALF_UP, Decimal

import numpy as np
from PIL import Image, ImageDraw, ImageFilter

HERE = os.path.dirname(os.path.abspath(__file__))
OUT = os.path.dirname(HERE)
NAME = "northbridge-inv-10418"
CHROME = os.environ.get("CHROME", "google-chrome")

SUPPLIER = "Northbridge Dental Supply"
NUMBER = "INV-10418"
DATE_PRINTED = "Nov 9, 2026"
DATE_ISO = "2026-11-09"
HST = Decimal("0.13")

# Item, description as printed, lot, expiry month (YYYY-MM), quantity, unit of measure, unit price, kind.
# Products the catalog receives in packs (cartridges and needles in boxes, gloves in cases) are invoiced by the pack;
# the others are invoiced in the unit the clinic counts them in, since a line for a product without a pack size is
# received as it is (engine.invoice_counted_per_unit); their U/M is that unit (SYR, BAND, SHEET), so Review invoice
# reads "4 syringes". Each description matches its product's name closely (docs/demo/README.md), except line 3,
# whose "4G" makes it a Possible match on purpose.
LINES = [
    ("300-1450", "SEPTOCAINE 4% 1:100,000 50/BX", "B6412", "2028-09", 2, "BX", "71.00", "product"),
    ("304-3016", "NEEDLE 30G SHORT 100/BX", "N30-5521", "2031-08", 1, "BX", "19.00", "product"),
    ("220-1802", "COMPOSITE A2 SYRINGE 4G", "7741A2", "2029-04", 4, "SYR", "56.00", "product"),
    ("223-3307", "ETCH GEL 37% SYRINGE", "EG27015", "2027-01", 4, "SYR", "12.50", "product"),
    ("245-0120", "MATRIX BAND", "MB8820", "2031-11", 72, "BAND", "0.48", "product"),
    ("260-3610", "RUBBER DAM LATEX FREE", "RD6633", "2030-06", 36, "SHEET", "0.56", "product"),
    ("550-0315", "EARLOOP MASK LEVEL 3 50/BX", "EM3-2290", "2031-10", 8, "BX", "14.50", "product"),
    ("551-0920", "NITRILE GLOVES M 10 BX/CS", "NG4471", "2030-09", 1, "CS", "94.00", "product"),
    ("470-1120", "HEMOSTATIC GEL SYRINGE", "HG1186", "2026-12", 2, "SYR", "41.00", "product"),
    ("FRT-01", "FREIGHT", "", "", 1, "", "14.95", "fee"),
]

UNIT_WORDS = {"BX": "box", "CS": "case", "SYR": "syringe", "BAND": "band", "SHEET": "sheet", "": None}

CSS = """
@page { size: letter; margin: 14mm 14mm 16mm 14mm; }
* { box-sizing: border-box; }
body { font-family: 'Helvetica Neue', Arial, sans-serif; color: #1d1d1d; font-size: 10.5pt; margin: 0; }
.top { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid #1f4e79; padding-bottom: 10px; }
.brand { font-size: 19pt; font-weight: 700; color: #1f4e79; letter-spacing: 0.3px; }
.addr { font-size: 9pt; color: #444; line-height: 1.35; margin-top: 4px; }
.doc { text-align: right; }
.doc h1 { margin: 0; font-size: 20pt; letter-spacing: 3px; color: #222; }
.meta { margin-top: 6px; border-collapse: collapse; font-size: 9.5pt; margin-left: auto; }
.meta td { padding: 2px 6px; border: 1px solid #bbb; text-align: left; }
.meta td.k { background: #f1f1f1; font-weight: 600; }
.parties { display: flex; gap: 24px; margin: 14px 0 12px; }
.party { flex: 1; border: 1px solid #ccc; padding: 8px 10px; font-size: 9.5pt; line-height: 1.4; }
.party .k { font-size: 8pt; font-weight: 700; color: #666; letter-spacing: 1px; text-transform: uppercase; }
table.lines { width: 100%; border-collapse: collapse; font-size: 9.5pt; }
table.lines th { background: #1f4e79; color: white; text-align: left; padding: 5px 6px; font-size: 8.5pt; letter-spacing: 0.5px; }
table.lines td { padding: 7px 6px; border-bottom: 1px solid #ddd; vertical-align: top; }
td.num, th.num { text-align: right; white-space: nowrap; }
td.code { font-family: 'Courier New', monospace; font-size: 9pt; color: #333; white-space: nowrap; }
td.desc { font-family: 'Courier New', monospace; font-size: 9.5pt; }
.totals { margin-top: 10px; margin-left: auto; border-collapse: collapse; font-size: 10pt; min-width: 240px; }
.totals td { padding: 4px 8px; }
.totals td.v { text-align: right; }
.totals tr.grand td { border-top: 2px solid #222; font-weight: 700; font-size: 11.5pt; }
.notes { margin-top: 18px; font-size: 8.5pt; color: #555; line-height: 1.45; }
.sample { margin-top: 10px; font-size: 7.5pt; color: #999; }
"""
# The page as the camera sees it: a letter sheet with its margins, 816 x 1056 CSS pixels.
SHOT = "body{padding:56px 58px;width:816px;min-height:1056px;background:white}"


def cents(value):
    return value.quantize(Decimal("0.01"), rounding=ROUND_HALF_UP)


def money(value):
    return f"{value:,.2f}"


def amounts():
    rows = [(line, cents(Decimal(line[4]) * Decimal(line[6]))) for line in LINES]
    subtotal = sum((amount for _, amount in rows), Decimal("0"))
    tax = cents(subtotal * HST)
    return rows, subtotal, tax, subtotal + tax


def page_html(shot):
    rows, subtotal, tax, total = amounts()
    body_rows = "\n".join(
        "<tr>"
        f"<td class='code'>{html.escape(item)}</td><td class='desc'>{html.escape(desc)}</td>"
        f"<td class='code'>{html.escape(lot)}</td><td class='code'>{html.escape(exp)}</td>"
        f"<td class='num'>{qty}</td><td>{html.escape(um)}</td>"
        f"<td class='num'>{money(Decimal(price))}</td><td class='num'>{money(amount)}</td>"
        "</tr>"
        for (item, desc, lot, exp, qty, um, price, _), amount in rows
    )
    style = CSS + (SHOT if shot else "")
    return f"""<!doctype html><html><head><meta charset='utf-8'><style>{style}</style></head><body>
<div class='top'><div><div class='brand'>{SUPPLIER}</div>
<div class='addr'>48 Quarry Lane, Unit 7 &middot; Milton, ON L9T 0X1<br>1-800-555-0119 &middot; orders@northbridge-dental.example<br>HST # 81234 5678 RT0001</div></div>
<div class='doc'><h1>INVOICE</h1><table class='meta'>
<tr><td class='k'>Invoice no.</td><td>{NUMBER}</td></tr><tr><td class='k'>Date</td><td>{DATE_PRINTED}</td></tr>
<tr><td class='k'>Account</td><td>SG-0105</td></tr><tr><td class='k'>Your PO</td><td>1106</td></tr>
<tr><td class='k'>Terms</td><td>Net 30</td></tr></table></div></div>
<div class='parties'><div class='party'><div class='k'>Bill to</div>Smile Groove<br>Accounts payable</div>
<div class='party'><div class='k'>Ship to</div>Smile Groove<br>Receiving</div>
<div class='party'><div class='k'>Shipped</div>{DATE_PRINTED}<br>Courier &middot; 3 cartons</div></div>
<table class='lines'><thead><tr><th>Item</th><th>Description</th><th>Lot</th><th>Exp.</th><th class='num'>Qty</th><th>U/M</th><th class='num'>Unit price</th><th class='num'>Amount</th></tr></thead>
<tbody>
{body_rows}
</tbody></table>
<table class='totals'><tr><td>Subtotal</td><td class='v'>{money(subtotal)}</td></tr><tr><td>HST 13%</td><td class='v'>{money(tax)}</td></tr>
<tr class='grand'><td>Total CAD</td><td class='v'>${money(total)}</td></tr></table>
<div class='notes'>Payment due within 30 days. Lot numbers and expiry dates are printed as supplied by the manufacturer.<br>
Report damaged or missing items within 5 business days: 1-800-555-0119.</div>
<div class='sample'>Synthetic sample made for software testing. Not a real invoice; the supplier is fictional.</div>
</body></html>"""


def expected_answer():
    """What the reader should answer for this invoice, in reading.ts's extraction schema, before parseExtraction tidies it
    (which turns an expiry month YYYY-MM into YYYY-MM-01, the form invoice_reading_finish takes)."""
    rows, _, _, total = amounts()
    return {
        "supplier": SUPPLIER,
        "invoice_number": NUMBER,
        "invoice_date": DATE_ISO,
        "currency": "CAD",
        "total": float(total),
        "lines": [
            {
                "raw": desc,
                "qty": qty,
                "unit": UNIT_WORDS[um],
                "unit_price": float(Decimal(price)),
                "line_total": float(amount),
                "lot": lot or None,
                "expiry": exp or None,
                "kind": kind,
            }
            for (_, desc, lot, exp, qty, um, price, kind), amount in rows
        ],
    }


def chrome(*args):
    subprocess.run([CHROME, "--headless=new", "--no-sandbox", "--disable-gpu", *args], check=True,
                   stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL)


def perspective_coefficients(output_quad, input_quad):
    """PIL's PERSPECTIVE data: maps each output pixel of `output_quad` back to the input point of `input_quad`."""
    matrix, vector = [], []
    for (x, y), (u, v) in zip(output_quad, input_quad):
        matrix.append([x, y, 1, 0, 0, 0, -u * x, -u * y])
        matrix.append([0, 0, 0, x, y, 1, -v * x, -v * y])
        vector += [u, v]
    return np.linalg.solve(np.array(matrix, dtype=float), np.array(vector, dtype=float)).tolist()


def photo(screenshot_path, out_path):
    """The printed page lying on a desk, shot from above at a slight angle, in warm uneven light."""
    page = Image.open(screenshot_path).convert("RGB")
    width, height = 1800, 2400
    rng = np.random.default_rng(10418)

    # A wooden desk: a warm gradient with a horizontal grain.
    yy, xx = np.mgrid[0:height, 0:width].astype(np.float32)
    t = (xx / width + (height - yy) / height) / 2
    desk = np.stack([0.36 - 0.14 * t, 0.27 - 0.11 * t, 0.20 - 0.08 * t], axis=-1) * 255
    grain = np.clip(rng.normal(128, 40, (height, width // 8)), 0, 255).astype(np.uint8)
    grain = Image.fromarray(grain).resize((width, height), Image.BILINEAR).filter(ImageFilter.GaussianBlur(3))
    desk += (np.asarray(grain).astype(np.float32)[..., None] - 128) / 40 * 9
    canvas = Image.fromarray(np.clip(desk, 0, 255).astype(np.uint8))

    # The page, held at a slight angle: its top edge a little farther from the camera than its bottom edge.
    quad = [(205, 150), (1585, 118), (1690, 2215), (110, 2262)]
    corners = [(0, 0), (page.width, 0), (page.width, page.height), (0, page.height)]
    tilted = page.transform((width, height), Image.PERSPECTIVE, perspective_coefficients(quad, corners),
                            Image.BICUBIC)
    mask = Image.new("L", (width, height), 0)
    ImageDraw.Draw(mask).polygon(quad, fill=255)

    # Its shadow on the desk, cast down and to the right.
    shadow = Image.new("L", (width, height), 0)
    ImageDraw.Draw(shadow).polygon([(x + 26, y + 34) for x, y in quad], fill=150)
    shadow = shadow.filter(ImageFilter.GaussianBlur(28))
    canvas = Image.composite(Image.new("RGB", (width, height), (18, 12, 8)), canvas, shadow)
    canvas = Image.composite(tilted, canvas, mask)

    # Uneven light: brighter at the top left where the lamp is, falling off to the bottom right, slightly warm.
    pixels = np.asarray(canvas).astype(np.float32)
    distance = np.sqrt(((xx - 350) / width) ** 2 + ((yy - 250) / height) ** 2)
    light = 1.04 - 0.24 * np.clip(distance, 0, 1.2)
    pixels *= light[..., None]
    pixels *= np.array([1.0, 0.975, 0.93], dtype=np.float32)
    # The phone's sensor noise.
    pixels += rng.normal(0, 3.2, pixels.shape).astype(np.float32)
    result = Image.fromarray(np.clip(pixels, 0, 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(0.7))
    result.save(out_path, optimize=True)


def main():
    with tempfile.TemporaryDirectory() as work:
        pdf_html = os.path.join(work, f"{NAME}.html")
        shot_html = os.path.join(work, f"{NAME}-shot.html")
        with open(pdf_html, "w", encoding="utf-8") as f:
            f.write(page_html(shot=False))
        with open(shot_html, "w", encoding="utf-8") as f:
            f.write(page_html(shot=True))
        chrome("--no-pdf-header-footer", f"--print-to-pdf={os.path.join(OUT, NAME + '.pdf')}", pdf_html)
        screenshot = os.path.join(work, "page.png")
        chrome("--hide-scrollbars", "--force-device-scale-factor=2.5", "--window-size=816,1056",
               f"--screenshot={screenshot}", shot_html)
        photo(screenshot, os.path.join(OUT, f"{NAME}-photo.png"))
    with open(os.path.join(OUT, f"{NAME}.json"), "w", encoding="utf-8") as f:
        json.dump(expected_answer(), f, indent=2)
        f.write("\n")
    _, subtotal, tax, total = amounts()
    print(f"{NAME}: {len(LINES)} lines, subtotal {subtotal}, HST {tax}, total {total} CAD")


if __name__ == "__main__":
    sys.exit(main())
