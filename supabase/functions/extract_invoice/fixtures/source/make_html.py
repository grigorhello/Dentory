"""Writes the HTML of the five synthetic invoices (fictional suppliers, no real customer data)."""
import html, sys, os

OUT = sys.argv[1]
os.makedirs(OUT, exist_ok=True)

CSS = """
@page { size: letter; margin: 14mm 14mm 16mm 14mm; }
* { box-sizing: border-box; }
body { font-family: 'Helvetica Neue', Arial, sans-serif; color: #1d1d1d; font-size: 10.5pt; margin: 0; }
.sheet { width: 100%; }
.top { display: flex; justify-content: space-between; align-items: flex-start; border-bottom: 2px solid ACCENT; padding-bottom: 10px; }
.brand { font-size: 19pt; font-weight: 700; color: ACCENT; letter-spacing: 0.3px; }
.addr { font-size: 9pt; color: #444; line-height: 1.35; margin-top: 4px; }
.doc { text-align: right; }
.doc h1 { margin: 0; font-size: 20pt; letter-spacing: 3px; color: #222; }
.meta { margin-top: 6px; border-collapse: collapse; font-size: 9.5pt; margin-left: auto; }
.meta td { padding: 2px 6px; border: 1px solid #bbb; }
.meta td.k { background: #f1f1f1; font-weight: 600; }
.parties { display: flex; gap: 24px; margin: 14px 0 12px; }
.party { flex: 1; border: 1px solid #ccc; padding: 8px 10px; font-size: 9.5pt; line-height: 1.4; }
.party .k { font-size: 8pt; font-weight: 700; color: #666; letter-spacing: 1px; text-transform: uppercase; }
table.lines { width: 100%; border-collapse: collapse; font-size: 9.5pt; }
table.lines thead { display: table-header-group; }
table.lines th { background: ACCENT; color: white; text-align: left; padding: 5px 6px; font-size: 8.5pt; letter-spacing: 0.5px; }
table.lines td { padding: 6px 6px; border-bottom: 1px solid #ddd; vertical-align: top; }
table.lines tr { page-break-inside: avoid; }
td.num, th.num { text-align: right; white-space: nowrap; }
td.code { font-family: 'Courier New', monospace; font-size: 9pt; color: #333; white-space: nowrap; }
td.desc { font-family: 'Courier New', monospace; font-size: 9.5pt; }
.totals { margin-top: 10px; margin-left: auto; border-collapse: collapse; font-size: 10pt; min-width: 240px; }
.totals td { padding: 4px 8px; }
.totals td.v { text-align: right; }
.totals tr.grand td { border-top: 2px solid #222; font-weight: 700; font-size: 11.5pt; }
.notes { margin-top: 18px; font-size: 8.5pt; color: #555; line-height: 1.45; }
.sample { margin-top: 10px; font-size: 7.5pt; color: #999; }
.pagebreak { page-break-before: always; }
"""

def money(v, fr=False):
    s = f"{v:,.2f}"
    if fr:
        return s.replace(",", " ").replace(".", ",") + " $"
    return s

def page(accent, body):
    return "<!doctype html><html><head><meta charset='utf-8'><style>" + CSS.replace("ACCENT", accent) + "</style></head><body><div class='sheet'>" + body + "</div></body></html>"

# The invoices photographed or scanned are screenshot as a letter page with its margins (816 x 1056 CSS pixels).
SHOT = "body{padding:56px 58px;width:816px;min-height:1056px;background:white}"
IMAGES = {"lakeshore-ls-58113", "prairie-pdw-90412-page-1", "prairie-pdw-90412-page-2"}

def write(name, accent, body):
    with open(os.path.join(OUT, name + ".html"), "w", encoding="utf-8") as f:
        f.write(page(accent, body))
    if name in IMAGES:
        with open(os.path.join(OUT, name + "-shot.html"), "w", encoding="utf-8") as f:
            f.write(page(accent, body).replace("</style>", SHOT + "</style>", 1))

def rows(lines, with_lot=False, fr=False):
    out = []
    for code, desc, qty, um, price, lot, exp in lines:
        amount = round(qty * price, 2)
        cells = [f"<td class='code'>{html.escape(code)}</td>", f"<td class='desc'>{html.escape(desc)}</td>"]
        if with_lot:
            cells += [f"<td class='code'>{html.escape(lot or '')}</td>", f"<td class='code'>{html.escape(exp or '')}</td>"]
        cells += [f"<td class='num'>{qty}</td>", f"<td>{html.escape(um)}</td>", f"<td class='num'>{money(price, fr)}</td>", f"<td class='num'>{money(amount, fr)}</td>"]
        out.append("<tr>" + "".join(cells) + "</tr>")
    return "\n".join(out)

SAMPLE = "<div class='sample'>Synthetic sample made for software testing. Not a real invoice; the supplier is fictional.</div>"

# 1. Northbridge Dental Supply: the four lines of frame f23, one page, PDF.
n_lines = [("300-1450", "SEPTO 4% 1:100K 50/BX", 5, "BX", 49.80, None, None),
           ("512-2040", "ENDO FILE KIT 15-40 21MM", 4, "BX", 45.00, None, None),
           ("640-0118", "TEMPBOND NE 1PK", 1, "PK", 26.40, None, None),
           ("FRT-01", "HANDLING / FUEL SURCHARGE", 1, "EA", 4.80, None, None)]
write("northbridge-inv-10092", "#1f4e79", f"""
<div class='top'><div><div class='brand'>Northbridge Dental Supply</div>
<div class='addr'>48 Quarry Lane, Unit 7 &middot; Milton, ON L9T 0X1<br>1-800-555-0119 &middot; orders@northbridge-dental.example<br>HST # 81234 5678 RT0001</div></div>
<div class='doc'><h1>INVOICE</h1><table class='meta'>
<tr><td class='k'>Invoice no.</td><td>INV-10092</td></tr><tr><td class='k'>Date</td><td>Sep 30, 2026</td></tr>
<tr><td class='k'>Account</td><td>SD-2231</td></tr><tr><td class='k'>Terms</td><td>Net 30</td></tr></table></div></div>
<div class='parties'><div class='party'><div class='k'>Bill to</div>Smile Dental<br>215 Lakeshore Road East<br>Oakville, ON L6J 1H7</div>
<div class='party'><div class='k'>Ship to</div>Smile Dental<br>215 Lakeshore Road East<br>Oakville, ON L6J 1H7</div></div>
<table class='lines'><thead><tr><th>Item</th><th>Description</th><th class='num'>Qty</th><th>U/M</th><th class='num'>Unit price</th><th class='num'>Amount</th></tr></thead>
<tbody>{rows(n_lines)}</tbody></table>
<table class='totals'><tr><td>Subtotal</td><td class='v'>460.20</td></tr><tr><td>HST 13%</td><td class='v'>59.83</td></tr>
<tr class='grand'><td>Total CAD</td><td class='v'>$520.03</td></tr></table>
<div class='notes'>Payment due within 30 days. Questions about this invoice: 1-800-555-0119.</div>{SAMPLE}""")

# 2. Lakeshore Dental Distributors: one page, photographed on a desk.
l_lines = [("NDL-27S", "NEEDLE 27G SHORT 100/BX", 2, "BX", 18.50, None, None),
           ("PA-100D", "PROPHY ANGLE DISPOSABLE 100/BX", 1, "BX", 32.00, None, None),
           ("GZ-2288", "GAUZE SPONGES 2X2 8-PLY 200/PK", 5, "PK", 3.95, None, None),
           ("SHIP", "SHIPPING", 1, "", 12.00, None, None)]
write("lakeshore-ls-58113", "#2e6b3a", f"""
<div class='top'><div><div class='brand'>Lakeshore Dental Distributors</div>
<div class='addr'>1180 Harvester Court &middot; Burlington, ON L7L 0B3<br>905-555-0177 &middot; lakeshore-dental.example</div></div>
<div class='doc'><h1>INVOICE</h1><table class='meta'>
<tr><td class='k'>Invoice #</td><td>LS-58113</td></tr><tr><td class='k'>Invoice date</td><td>2026-10-14</td></tr>
<tr><td class='k'>Customer #</td><td>C-4471</td></tr></table></div></div>
<div class='parties'><div class='party'><div class='k'>Sold to</div>Smile Dental<br>215 Lakeshore Road East<br>Oakville, ON L6J 1H7</div>
<div class='party'><div class='k'>Shipped</div>Oct 14, 2026 &middot; Ground</div></div>
<table class='lines'><thead><tr><th>Item</th><th>Description</th><th class='num'>Qty</th><th>U/M</th><th class='num'>Price</th><th class='num'>Ext. price</th></tr></thead>
<tbody>{rows(l_lines)}</tbody></table>
<table class='totals'><tr><td>Subtotal</td><td class='v'>100.75</td></tr><tr><td>HST (13%)</td><td class='v'>13.10</td></tr>
<tr class='grand'><td>Amount due (CAD)</td><td class='v'>113.85</td></tr></table>{SAMPLE}""")

# 3. Harbourview Dental Co.: sixteen lines with lot and expiry over two pages, PDF; names a person and a phone number
#    that the reading must leave out.
h_lines = [("10-4410", "SEPTOCAINE 4% 1:100,000 CARTRIDGES 50/BX", 2, "BX", 52.40, "B552", "03/2028"),
           ("22-1802", "COMPOSITE A2 SYRINGE 4G", 3, "EA", 38.90, "7731A", "11/2027"),
           ("22-3307", "ETCH GEL 37% 3ML SYRINGE 2PK", 2, "PK", 14.25, "EG2210", "06/2027"),
           ("31-0030", "PAPER POINTS #30 120/BX", 2, "BX", 9.80, "PP3091", ""),
           ("40-1101", "RETRACTION CORD #1 KNITTED", 1, "EA", 21.40, "", ""),
           ("40-2144", "MATRIX BANDS UNIVERSAL 144/PK", 1, "PK", 17.60, "", ""),
           ("31-2260", "GUTTA PERCHA POINTS F2 60/BX", 3, "BX", 11.20, "GP552", "09/2029"),
           ("55-0915", "NITRILE GLOVES MEDIUM 100/BX", 10, "BX", 8.95, "N0915", "08/2030"),
           ("47-1120", "HEMOSTATIC GEL 1.2ML SYRINGE", 4, "EA", 12.40, "HG118", "01/2028"),
           ("22-5005", "BONDING AGENT 5ML", 1, "BT", 64.00, "BA9012", "12/2027"),
           ("60-2002", "COTTON ROLLS #2 MEDIUM 2000/BX", 1, "BX", 15.90, "", ""),
           ("60-4040", "ARTICULATING PAPER 40 MICRON 144/BX", 1, "BX", 11.75, "", ""),
           ("60-7100", "SALIVA EJECTORS CLEAR 100/BG", 3, "BG", 6.40, "", ""),
           ("35-0101", "ALGINATE IMPRESSION MATERIAL 1LB", 2, "BG", 18.30, "AL7710", "02/2028"),
           ("70-2424", "SURFACE DISINFECTANT SPRAY 24OZ", 2, "EA", 13.80, "SD4471", "10/2028"),
           ("ENV", "ENVIRONMENTAL FEE", 1, "EA", 2.50, "", "")]
filler = "".join(f"<p style='margin:4px 0;color:#666;font-size:8.5pt'>{t}</p>" for t in [
  "Please check each carton against this invoice on arrival. Report damaged or missing items within 5 business days.",
  "Lot numbers and expiry dates are printed as supplied by the manufacturer.",
  "Returns require an authorization number and must be unopened. A 15% restocking charge applies to non-defective returns."])
write("harbourview-hv-2207", "#7a3b1f", f"""
<style>table.lines td {{ padding: 16px 6px; }}</style>
<div class='top'><div><div class='brand'>Harbourview Dental Co.</div>
<div class='addr'>9 Wharf Street &middot; Hamilton, ON L8L 0A6<br>Customer care 905-555-0163 &middot; harbourview-dental.example</div></div>
<div class='doc'><h1>INVOICE</h1><table class='meta'>
<tr><td class='k'>Invoice</td><td>HV-2207</td></tr><tr><td class='k'>Date</td><td>October 2, 2026</td></tr>
<tr><td class='k'>Your PO</td><td>7781</td></tr><tr><td class='k'>Sales rep</td><td>Jordan Ellis &middot; 905-555-0142</td></tr></table></div></div>
<div class='parties'><div class='party'><div class='k'>Bill to</div>Smile Dental<br>215 Lakeshore Road East<br>Oakville, ON L6J 1H7</div>
<div class='party'><div class='k'>Ship to</div>Smile Dental, Attn: Dr. Daniel Kim<br>215 Lakeshore Road East<br>Oakville, ON L6J 1H7</div></div>
{filler}
<table class='lines'><thead><tr><th>Item</th><th>Description</th><th>Lot</th><th>Exp</th><th class='num'>Qty</th><th>U/M</th><th class='num'>Price</th><th class='num'>Amount</th></tr></thead>
<tbody>{rows(h_lines, with_lot=True)}</tbody></table>
<table class='totals'><tr><td>Subtotal</td><td class='v'>658.85</td></tr><tr><td>HST 13%</td><td class='v'>85.65</td></tr>
<tr class='grand'><td>Total (CAD)</td><td class='v'>$744.50</td></tr></table>
<div class='parties' style='margin-top:22px'><div class='party'><div class='k'>Remit to</div>Harbourview Dental Co.<br>PO Box 2207, Station A<br>Hamilton, ON L8N 0A1</div>
<div class='party'><div class='k'>Pay online</div>harbourview-dental.example/pay<br>Reference HV-2207</div></div>
<div class='notes'>Thank you for your order.</div>{SAMPLE}""")

# 4. Prairie Dental Wholesale: a US supplier, two pages scanned as images, dates written month first.
p_lines1 = [("FV-5050", "FLUORIDE VARNISH 5% 50/BX", 2, "BX", 42.00, None, None),
            ("TAG-20B", "TOPICAL ANESTHETIC GEL 20% BENZOCAINE 1OZ", 3, "JR", 6.75, None, None),
            ("RCS-KIT", "ROOT CANAL SEALER KIT", 1, "KT", 96.50, None, None),
            ("PPM-200", "PROPHY PASTE MINT MEDIUM 200/BX", 2, "BX", 24.80, None, None),
            ("MB-F100", "MICROBRUSH FINE 100/BX", 3, "BX", 7.20, None, None),
            ("PB-2P500", "PATIENT BIBS 2-PLY 500/CS", 1, "CS", 39.00, None, None)]
p_lines2 = [("ST-HVE", "SUCTION TIPS HVE VENTED 100/BG", 2, "BG", 11.40, None, None),
            ("TC-NE", "TEMPORARY CEMENT NON-EUGENOL KIT", 1, "KT", 33.00, None, None),
            ("FRT", "FREIGHT", 1, "", 18.00, None, None)]
head = """<div class='top'><div><div class='brand'>Prairie Dental Wholesale</div>
<div class='addr'>3400 Sheyenne Street &middot; West Fargo, ND 58078 &middot; USA<br>(701) 555-0185 &middot; prairie-dental.example</div></div>
<div class='doc'><h1>INVOICE</h1><table class='meta'><tr><td class='k'>Invoice No.</td><td>PDW-90412</td></tr>
<tr><td class='k'>Invoice Date</td><td>10/20/2026</td></tr><tr><td class='k'>Page</td><td>PAGE</td></tr></table></div></div>"""
cols = "<thead><tr><th>Item</th><th>Description</th><th class='num'>Qty</th><th>U/M</th><th class='num'>Unit price</th><th class='num'>Ext.</th></tr></thead>"
write("prairie-pdw-90412-page-1", "#5b4a8b", head.replace("PAGE", "1 of 2") + f"""
<div class='parties'><div class='party'><div class='k'>Bill to</div>Smile Dental<br>215 Lakeshore Road East<br>Oakville, ON L6J 1H7, Canada</div>
<div class='party'><div class='k'>Terms</div>Prepaid &middot; Currency USD</div></div>
<table class='lines'>{cols}<tbody>{rows(p_lines1)}</tbody></table>
<div class='notes'>Continued on page 2.</div>{SAMPLE}""")
write("prairie-pdw-90412-page-2", "#5b4a8b", head.replace("PAGE", "2 of 2") + f"""
<table class='lines' style='margin-top:14px'>{cols}<tbody>{rows(p_lines2)}</tbody></table>
<table class='totals'><tr><td>Merchandise</td><td class='v'>366.75</td></tr><tr><td>Freight</td><td class='v'>included above</td></tr>
<tr><td>Sales tax (export)</td><td class='v'>0.00</td></tr><tr class='grand'><td>Total USD</td><td class='v'>$384.75</td></tr></table>
<div class='notes'>All amounts in US dollars.</div>{SAMPLE}""")

# 5. Fournitures dentaires Rive-Sud: in French, with decimal commas and Quebec taxes, PDF.
r_lines = [("GN-M100", "Gants nitrile moyens 100/bte", 4, "bte", 9.25, None, None),
           ("PP-M200", "Pâte prophylactique menthe 200 g", 2, "pot", 16.40, None, None),
           ("HS-525", "Hypochlorite de sodium 5,25 % 1 L", 1, "bouteille", 7.95, None, None),
           ("LIV", "Frais de livraison", 1, "", 9.50, None, None)]
write("rive-sud-f-3381", "#0f5f73", f"""
<div class='top'><div><div class='brand'>Fournitures dentaires Rive-Sud</div>
<div class='addr'>715, boulevard des Érables &middot; Longueuil (Québec) J4K 0B2<br>450 555-0131 &middot; rive-sud-dentaire.example</div></div>
<div class='doc'><h1>FACTURE</h1><table class='meta'><tr><td class='k'>N° de facture</td><td>F-3381</td></tr>
<tr><td class='k'>Date</td><td>9 octobre 2026</td></tr><tr><td class='k'>Client</td><td>Smile Dental</td></tr></table></div></div>
<div class='parties'><div class='party'><div class='k'>Facturé à</div>Smile Dental<br>215 Lakeshore Road East<br>Oakville (Ontario) L6J 1H7</div>
<div class='party'><div class='k'>Conditions</div>Net 30 jours</div></div>
<table class='lines'><thead><tr><th>Code</th><th>Description</th><th class='num'>Qté</th><th>Unité</th><th class='num'>Prix unitaire</th><th class='num'>Montant</th></tr></thead>
<tbody>{rows(r_lines, fr=True)}</tbody></table>
<table class='totals'><tr><td>Sous-total</td><td class='v'>87,25 $</td></tr><tr><td>TPS (5 %)</td><td class='v'>4,36 $</td></tr>
<tr><td>TVQ (9,975 %)</td><td class='v'>8,70 $</td></tr><tr class='grand'><td>Total</td><td class='v'>100,31 $</td></tr></table>
<div class='notes'>Merci de votre confiance.</div>{SAMPLE}""")
print("ok")
