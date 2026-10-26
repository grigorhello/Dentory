// Reading one invoice (MS-129, PRD §9 Invoice reading): the request the Claude API gets for an invoice's pages, and
// what is taken from its answer. The call itself is a `ModelCall`, so the tests replay recorded answers
// (fixtures/*.json) without a key; only claude.ts talks to the API. Matching the lines against the clinic's products
// happens afterwards in the database, without AI (invoice_reading_finish).
//
// Nothing here logs: a failure carries one of our own sentences, never the invoice's text.
import type Anthropic from "npm:@anthropic-ai/sdk@1.3.0";

/** The current Claude Sonnet model, as the ticket asks for invoice reading. */
export const readerModel = "claude-sonnet-5-5";

/** Enough for an answer of a few hundred lines. */
const maxAnswerTokens = 16_000;
/** More rows than any delivery's invoice has: an answer longer than this was not read from an invoice. */
const maxLines = 300;

export type PageKind = "jpg" | "pdf";

export interface InvoicePage {
  kind: PageKind;
  data: Uint8Array;
}

/** Why a reading failed, as `invoices.failure_reason` keeps it. */
export type FailureReason = "timeout" | "unreadable" | "refused" | "error";

export class ReadingFailure extends Error {
  constructor(readonly reason: FailureReason, detail: string) {
    super(detail);
  }
}

export type ReadingRequest = Anthropic.Beta.MessageCreateParamsNonStreaming;

/** What the model answered: why it stopped, the text it wrote (the schema's JSON) and the tokens it took. */
export interface ModelAnswer {
  stopReason: string | null;
  text: string;
  inputTokens?: number;
  outputTokens?: number;
}

/** One call to the model; it gives up when `signal` aborts. */
export type ModelCall = (request: ReadingRequest, signal: AbortSignal) => Promise<ModelAnswer>;

export interface ExtractedLine {
  raw: string;
  qty: number | null;
  unit: string | null;
  unit_price: number | null;
  line_total: number | null;
  lot: string | null;
  /** The first day of the expiry month, YYYY-MM-01. */
  expiry: string | null;
  kind: "product" | "fee";
}

/** What `invoice_reading_finish` receives (flow step 3's schema, checked and tidied). */
export interface Extraction {
  supplier: string | null;
  invoice_number: string | null;
  /** YYYY-MM-DD. */
  invoice_date: string | null;
  /** ISO 4217, upper case. */
  currency: string | null;
  total: number | null;
  lines: ExtractedLine[];
}

const nullable = (schema: Record<string, unknown>) => ({ anyOf: [schema, { type: "null" }] });

/** Flow step 3's strict JSON schema; structured outputs hold the answer to it. */
export const extractionSchema = {
  type: "object",
  properties: {
    supplier: nullable({ type: "string", description: "The company that issued the invoice." }),
    invoice_number: nullable({ type: "string", description: "The invoice's own number." }),
    invoice_date: nullable({ type: "string", format: "date", description: "The invoice date, YYYY-MM-DD." }),
    currency: nullable({ type: "string", description: "The ISO 4217 code the amounts are in." }),
    total: nullable({ type: "number", description: "The amount due for the whole invoice, taxes included." }),
    lines: {
      type: "array",
      description: "Every row of the invoice's item table, in order, across all pages.",
      items: {
        type: "object",
        properties: {
          raw: { type: "string", description: "The row's description exactly as printed." },
          qty: nullable({ type: "number", description: "The quantity shipped." }),
          unit: nullable({ type: "string", description: "What the quantity counts, one lowercase singular word." }),
          unit_price: nullable({ type: "number", description: "The price of one unit." }),
          line_total: nullable({ type: "number", description: "The row's amount." }),
          lot: nullable({ type: "string", description: "The lot number printed on the row." }),
          expiry: nullable({ type: "string", description: "The expiry month printed on the row, YYYY-MM." }),
          kind: { type: "string", enum: ["product", "fee"] },
        },
        required: ["raw", "qty", "unit", "unit_price", "line_total", "lot", "expiry", "kind"],
        additionalProperties: false,
      },
    },
  },
  required: ["supplier", "invoice_number", "invoice_date", "currency", "total", "lines"],
  additionalProperties: false,
};

/** The system prompt: what to read and how, and the personal data to leave out (the ticket's Privacy section). */
export const instructions = `You read supplier invoices for a dental clinic's inventory app. The user message holds one \
invoice for a delivery the clinic received: a PDF, or photos or scans of its pages in order.

Return the invoice in the JSON schema you are given:
- supplier: the company that issued the invoice, as printed in its header.
- invoice_number: the invoice's own number, not an order, account, customer or purchase order number.
- invoice_date: the invoice date as YYYY-MM-DD, whatever the printed format (10/20/2026 on a US invoice is October 20).
- currency: the ISO 4217 code of the amounts (CAD, USD, EUR), from a currency label, a "Total CAD" row or the \
supplier's country; null when nothing says.
- total: the amount due for the whole invoice, taxes included.
- lines: every row of the item table, in order, across all pages. Not the subtotal, tax, total or payment rows \
printed below the table.
  - raw: the row's description exactly as printed, in its own case and punctuation, without the item number, \
quantity, unit or prices.
  - qty: the quantity shipped on this invoice; 0 for a backordered row.
  - unit: what the quantity counts, as one lowercase English word in the singular: box for BX or bte, pack for PK, \
case for CS, bag for BG, bottle for BT or bouteille, kit for KT, jar for JR or pot, each for EA; null when the row \
shows none.
  - unit_price and line_total: the price of one unit and the row's amount.
  - lot and expiry: the lot number and the expiry month (YYYY-MM) when the row prints them.
  - kind: fee for shipping, freight, handling, fuel and environmental fees, other fees and surcharges, taxes, \
discounts, credits and returns; product for everything else, the things the clinic stocks.
Write numbers as plain numbers with a decimal point, without currency signs or thousands separators (9,25 $ is 9.25). \
Use null for anything the pages do not show, and never guess a value.

The pages may show people's names, signatures, phone numbers, email addresses or details about a patient. Ignore all \
personal data: leave it out of every field, and leave a person's name out of raw.

If the pages hold no invoice or packing slip with item rows, answer null for every field and an empty lines array.`;

/** Base64 without a dependency, in chunks small enough for `String.fromCharCode`. */
export function base64(data: Uint8Array): string {
  let binary = "";
  for (let offset = 0; offset < data.length; offset += 0x8000) {
    binary += String.fromCharCode(...data.subarray(offset, offset + 0x8000));
  }
  return btoa(binary);
}

/**
 * The request for an invoice's pages: a PDF as a document, JPEG pages as images labelled in order, then the ask.
 * Adaptive thinking at low effort keeps the reading quick (the target is under 20 seconds), structured outputs hold
 * the answer to the schema, and the server-side fallback answers a declined request from another model.
 */
export function buildRequest(pages: InvoicePage[]): ReadingRequest {
  const content: Anthropic.Beta.BetaContentBlockParam[] = [];
  pages.forEach((page, index) => {
    if (page.kind === "pdf") {
      content.push({
        type: "document",
        source: { type: "base64", media_type: "application/pdf", data: base64(page.data) },
      });
      return;
    }
    if (pages.length > 1) content.push({ type: "text", text: `Page ${index + 1}:` });
    content.push({ type: "image", source: { type: "base64", media_type: "image/jpeg", data: base64(page.data) } });
  });
  content.push({ type: "text", text: "Read this invoice." });
  return {
    model: readerModel,
    max_tokens: maxAnswerTokens,
    betas: ["server-side-fallback-2026-07-01"],
    fallbacks: "default",
    system: instructions,
    output_config: { effort: "low", format: { type: "json_schema", schema: extractionSchema } },
    messages: [{ role: "user", content }],
  };
}

/** Reads the invoice on `pages` through `call`; throws a `ReadingFailure` when it cannot. */
export async function readInvoice(pages: InvoicePage[], call: ModelCall, signal: AbortSignal): Promise<Extraction> {
  if (pages.length === 0) throw new ReadingFailure("error", "no pages to read");
  let answer: ModelAnswer;
  try {
    answer = await call(buildRequest(pages), signal);
  } catch (error) {
    if (signal.aborted) throw new ReadingFailure("timeout", "no answer within the time limit");
    if (error instanceof ReadingFailure) throw error;
    throw new ReadingFailure("error", `the call failed (${errorName(error)})`);
  }
  if (answer.stopReason === "refusal") throw new ReadingFailure("refused", "the model declined the pages");
  if (answer.stopReason === "max_tokens") throw new ReadingFailure("unreadable", "the answer was cut short");
  return parseExtraction(answer.text);
}

/** An error's class and HTTP status, never its message: an API error can quote what it was sent. */
export function errorName(error: unknown): string {
  if (!(error instanceof Error)) return typeof error;
  const status = (error as { status?: unknown }).status;
  return typeof status === "number" ? `${error.name} ${status}` : error.name;
}

/** The model's JSON, checked and tidied; an answer with no lines is unreadable. */
export function parseExtraction(text: string): Extraction {
  let value: unknown;
  try {
    value = JSON.parse(text);
  } catch {
    // JSON.parse's message quotes the text it read, which is the invoice: leave it out.
    throw new ReadingFailure("unreadable", "the answer is not JSON");
  }
  if (!isObject(value) || !Array.isArray(value.lines)) {
    throw new ReadingFailure("unreadable", "the answer has no lines");
  }
  const lines = value.lines.flatMap((line) => {
    const tidy = isObject(line) ? tidyLine(line) : null;
    return tidy ? [tidy] : [];
  });
  if (lines.length === 0) throw new ReadingFailure("unreadable", "no invoice lines on the pages");
  if (lines.length > maxLines) throw new ReadingFailure("unreadable", "more lines than an invoice has");
  return {
    supplier: words(value.supplier, 200),
    invoice_number: words(value.invoice_number, 60),
    invoice_date: day(value.invoice_date),
    currency: currency(value.currency),
    total: amount(value.total, 2),
    lines,
  };
}

function tidyLine(line: Record<string, unknown>): ExtractedLine | null {
  const raw = words(line.raw, 300);
  if (!raw) return null;
  return {
    raw,
    qty: amount(line.qty, 2),
    unit: unit(line.unit),
    unit_price: amount(line.unit_price, 4),
    line_total: amount(line.line_total, 2),
    lot: words(line.lot, 60),
    expiry: month(line.expiry),
    kind: line.kind === "fee" ? "fee" : "product",
  };
}

function isObject(value: unknown): value is Record<string, unknown> {
  return typeof value === "object" && value !== null && !Array.isArray(value);
}

/** Text trimmed, its runs of spaces one space, at most `limit` characters; null when empty. */
function words(value: unknown, limit: number): string | null {
  if (typeof value !== "string") return null;
  const text = value.replace(/\s+/g, " ").trim().slice(0, limit).trim();
  return text === "" ? null : text;
}

/** A number rounded to `digits` decimals that fits the database's columns; null otherwise. */
function amount(value: unknown, digits: number): number | null {
  if (typeof value !== "number" || !Number.isFinite(value) || Math.abs(value) >= 1e9) return null;
  const factor = 10 ** digits;
  return Math.round(value * factor) / factor;
}

function currency(value: unknown): string | null {
  return typeof value === "string" && /^[A-Za-z]{3}$/.test(value.trim()) ? value.trim().toUpperCase() : null;
}

/** A real day of the years 2000 to 2100 as YYYY-MM-DD. */
function day(value: unknown): string | null {
  if (typeof value !== "string" || !/^\d{4}-\d{2}-\d{2}$/.test(value.trim())) return null;
  const [year, month, date] = value.trim().split("-").map(Number);
  const parsed = new Date(Date.UTC(year, month - 1, date));
  const real = parsed.getUTCFullYear() === year && parsed.getUTCMonth() === month - 1 && parsed.getUTCDate() === date;
  return real && year >= 2000 && year <= 2100 ? value.trim() : null;
}

/** An expiry month, written YYYY-MM (or a day of it), as the first of the month. */
function month(value: unknown): string | null {
  const match = typeof value === "string" ? /^(\d{4})-(\d{2})(-\d{2})?$/.exec(value.trim()) : null;
  if (!match) return null;
  const year = Number(match[1]);
  const monthNumber = Number(match[2]);
  return year >= 2000 && year <= 2100 && monthNumber >= 1 && monthNumber <= 12 ? `${match[1]}-${match[2]}-01` : null;
}

/** The unit spelled out in the singular, as the prompt asks; the common abbreviations still read right. */
const unitWords: Record<string, string> = {
  bx: "box", boxes: "box", bte: "box", pk: "pack", pkg: "pack", packs: "pack", cs: "case", cases: "case",
  bg: "bag", bags: "bag", bt: "bottle", btl: "bottle", bottles: "bottle", kt: "kit", kits: "kit", jr: "jar",
  jars: "jar", ea: "each", pc: "each", pcs: "each",
};

function unit(value: unknown): string | null {
  const text = words(value, 30)?.toLowerCase().replace(/\.$/, "") ?? null;
  return text ? unitWords[text] ?? text : null;
}
