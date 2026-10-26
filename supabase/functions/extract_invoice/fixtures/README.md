# Fixture invoices (MS-129)

Five synthetic invoices for testing the invoice reader. They were made for Dentory's tests: the suppliers are
fictional, the customer is the demo clinic Smile Dental, phone numbers use the 555-01xx fiction range, web addresses
end in `.example`, and every page says it is a synthetic sample. No real customer, supplier or patient data is in them.

| Invoice | Files | What it tests |
|---|---|---|
| `northbridge-inv-10092` | one PDF page | f23's four lines (SEPTO 4% 1:100K 50/BX, ENDO FILE KIT 15-40 21MM, TEMPBOND NE 1PK, HANDLING / FUEL SURCHARGE), the ticket's matching acceptance criterion. |
| `lakeshore-ls-58113` | one phone photo (JPEG) | A page photographed on a desk at an angle, in uneven light; a shipping line with no unit. |
| `harbourview-hv-2207` | a two-page PDF | Sixteen lines running onto a second page under a repeated table header, lot and expiry columns, an environmental fee, and a person's name and phone number in the header that the reading must leave out. |
| `prairie-pdw-90412` | two scanned pages (JPEG) | A US supplier: amounts in US dollars, the date written month first (10/20/2026), the table continued on page 2, freight as a line. |
| `rive-sud-f-3381` | one PDF page | French: accents, decimal commas ("9,25 $"), "bte" and "pot" as units, delivery charges as a line, Quebec taxes in the totals. |

`<name>.json` is the reader's answer for each invoice: the JSON the extraction schema (`../reading.ts`) returns.
`reading_test.ts` replays these answers through the reading code, so the tests need no API key, and
`supabase/tests/database/40_invoice_matching_test.sql` matches the lines they give against the demo catalog.
The answers were written from the documents' known content, as the schema shapes them. `make invoice-reading-live`
(with `ANTHROPIC_API_KEY` set) reads the documents with the real API and compares; `RECORD=1 make
invoice-reading-live` writes the live answers here instead, after which `reading_test.ts` names any block of the
matching test to update.

## Making them again

`source/make_html.py` writes each invoice as HTML; headless Chrome prints the PDFs and screenshots the pages for the
images; `source/camera.swift` turns a screenshot into the phone photo or the scanned page:

```
python3 source/make_html.py html
chrome --headless=new --no-pdf-header-footer --print-to-pdf=out/northbridge-inv-10092.pdf html/northbridge-inv-10092.html
chrome --headless=new --hide-scrollbars --force-device-scale-factor=2.5 --window-size=816,1056 \
  --screenshot=out/lakeshore-ls-58113.png html/lakeshore-ls-58113-shot.html   # the page with a 56 px margin
swiftc -O source/camera.swift -o camera
./camera photo out/lakeshore-ls-58113.png lakeshore-ls-58113.jpg
./camera scan out/prairie-pdw-90412-page-1.png prairie-pdw-90412-page-1.jpg
```
