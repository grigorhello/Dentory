# Sample delivery invoice

A supplier invoice for trying Receive delivery end to end on a clinic that holds the general-practice catalog
(`supabase/catalogs/general-practice.sql`), made for Smile Groove on production after its demo history (2026-11-09):
upload it, review the lines, confirm, and watch stock, To buy and Expiring soon change. Every product line names a
catalog product, priced at the demo history's unit costs.

The supplier, Northbridge Dental Supply, is fictional, as in the reader's test invoices
(`supabase/functions/extract_invoice/fixtures`): its phone number is in the 555-01xx range, its web address ends in
`.example`, and the page says it is a synthetic sample. The customer is written as the app names the demo clinic,
"Smile Groove", with no address. No real company, person or patient is on it.

| File | What it is |
|---|---|
| `northbridge-inv-10418.pdf` | The invoice, one letter page. The cleanest upload. |
| `northbridge-inv-10418-photo.png` | The printed page photographed on a desk at a slight angle, as a phone photo. |
| `northbridge-inv-10418.json` | What the reader should return for it, in `reading.ts`'s extraction schema. |
| `source/make_invoice.py` | Makes all three again (`python3 docs/demo/source/make_invoice.py`; Pillow, NumPy and Chrome). |

## Before you upload

Reading needs the Claude API key on the project the app talks to: `supabase secrets set --project-ref <ref>
ANTHROPIC_API_KEY=…`, typed in a terminal (`docs/runbooks/release.md`, step 5; `build-state.md`, open item 13).
Without it the reading fails at once and the screen offers Try again and Receive manually.

## Uploading it on an iPhone

1. Put the PDF in Files: AirDrop it from a Mac, or open it on the phone and use Share, Save to Files.
2. In Dentory, as an Admin: Home, Receive delivery, Upload PDF or image, and pick the file. The PNG works the same
   way from Files. Take a photo opens the document scanner on an iPhone, not Photos, so a picture saved to Photos goes
   through Files instead; or show the PNG on a computer screen and scan it with Take a photo.
3. Reading takes up to a minute, usually under 20 seconds. The screen may be left meanwhile: the invoice then waits
   on Receive delivery under Continue reviewing.

## What Review invoice shows

| # | Line as printed | Read as | Becomes | Received |
|---|---|---|---|---|
| 1 | SEPTOCAINE 4% 1:100,000 50/BX, 2 BX | Matched | Septocaine 4% 1:100,000 | 100 cartridges |
| 2 | NEEDLE 30G SHORT 100/BX, 1 BX | Matched | Needle 30g short | 100 needles |
| 3 | COMPOSITE A2 SYRINGE 4G, 4 SYR | Possible match, "Is this Composite A2?": tap Yes, match | Composite A2 | 4 syringes |
| 4 | ETCH GEL 37% SYRINGE, 4 SYR, exp. 2027-01 | Matched | Etch gel 37% | 4 syringes, Expiring |
| 5 | MATRIX BAND, 72 BAND | Matched | Matrix band | 72 bands |
| 6 | RUBBER DAM LATEX FREE, 36 SHEET | Matched | Rubber dam latex-free | 36 sheets |
| 7 | EARLOOP MASK LEVEL 3 50/BX, 8 BX | Matched | Earloop masks level 3 | 8 boxes |
| 8 | NITRILE GLOVES M 10 BX/CS, 1 CS | Matched | Nitrile gloves M | 10 boxes (a case of 10) |
| 9 | HEMOSTATIC GEL SYRINGE, 2 SYR, exp. 2026-12 | Matched | Hemostatic gel | 2 syringes, Expiring |
| 10 | FREIGHT, 14.95 | Needs review, "Looks like a fee, not a product": tap Ignore | not added | |

Once lines 3 and 10 are settled the summary reads "9 of 10 lines will increase inventory." Every product line carries
its lot and expiry month, so nothing lands under Missing expiry. Line 3 is a Possible match on purpose ("4G" is a
number Composite A2's name does not have), to show the review step. The other descriptions are each product's name
in the supplier's capitals, with at most a pack count or a form word that matching leaves out, so they match by
trigram similarity of 0.87 to 1 (Matched needs 0.75 and the same numbers); a description with more words would read
as a Possible match. Matching was checked with the engine's own functions against the 74 catalog names, and three
blind readings of these files (two of the photo, one of the PDF), done as the reader's instructions say, returned
exactly `northbridge-inv-10418.json`.

Products received in packs are invoiced by the pack (boxes of 50 cartridges or 100 needles, a case of 10 glove
boxes) and converted on receipt; the others are invoiced in the unit the clinic counts, since a line for a product
without a pack size is received as it is (`engine.invoice_counted_per_unit`). Those units are spelled SYR, BAND and
SHEET rather than EA: Review invoice shows a line read in "each" as "4 eaches" (a known issue).

## After Confirm & receive on Smile Groove

Starting from the demo history's end state (`supabase/catalogs/README.md`, "Demo history"):

- **To buy**: 3 to 1, Fluoride varnish 5% left. Composite A2 and Rubber dam latex-free, and the ordered Earloop masks
  level 3 and Matrix band, move to Received.
- **Inventory**: Composite A2, Earloop masks level 3 and Matrix band are no longer Low, Rubber dam latex-free no longer
  Out of stock; Root canal no longer reads "1 not available".
- **Expiring soon**: 3 to 5, with Etch gel 37% (expires end of January 2027) and Hemostatic gel (end of December 2026).
- **Inventory value**: about $782 more, at the same unit costs as before; the amount at risk within 90 days about $132
  more (the etch gel and the hemostatic gel).
- **Activity**: the receipts in History, named "Invoice INV-10418", which opens the invoice read-only.

Undo, on the toast for 10 seconds, puts it all back, the supplier's words the confirmation learned included. After
that the receipt is part of the append-only ledger, as every delivery is, so the before and after can be shown once
per clinic: rehearse by confirming and tapping Undo, or by discarding the invoice from Review invoice. Once it is
confirmed for good, the clinic knows Northbridge's words, so a later upload reads line 3 as Matched and skips the
review step, and receives the same stock again: discard such a second invoice instead of confirming it.

The expiry months are fixed. Lines 4 and 9 are within the clinic's 90 days now (83 and 52 days on 2026-11-09); after
December 2026 or January 2027 the batch would be received already expired. For a later demo, change the months in
`source/make_invoice.py`, run it again, and update this file's table.
