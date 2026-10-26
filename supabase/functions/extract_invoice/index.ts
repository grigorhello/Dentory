// POST /functions/v1/extract_invoice { invoice_id } as a signed-in admin, right after invoice_create (MS-129, PRD §6.5
// Reading state, §9 Invoice reading). Claims the reading (invoice_reading_start: the caller is an admin of the
// invoice's clinic, the clinic may write, and the invoice was not read yet) and answers 202 at once, so the admin may
// leave the screen. Then, in the background: downloads the pages from the invoices bucket, reads them with the Claude
// API (reading.ts, claude.ts) and hands the result to invoice_reading_finish, which matches the lines without AI and
// marks the invoice ready, opening its alert and the admins' push; or marks it failed with the reason
// (invoice_reading_fail). The reading gives up 60 seconds after its claim (reason timeout). Calling it again for an
// invoice already claimed or read changes nothing.
//
// Needs ANTHROPIC_API_KEY (`supabase secrets set`); without it, as on the local stack, every reading fails with the
// reason error. Invoice contents are never logged: only ids, page counts, sizes, timings, tokens and reasons.
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { errorResponse, HttpError, isUUID, json, readJSON, text } from "../_shared/http.ts";
import { caller, rpcError, serviceClient } from "../_shared/supabase.ts";
import { claudeCall } from "./claude.ts";
import { errorName, type InvoicePage, type PageKind, readInvoice, ReadingFailure } from "./reading.ts";

/** Supabase's runtime keeps the function alive for work handed to it after the answer. */
declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void } | undefined;

/** "Timeout at 60 s sets status failed" (the ticket's acceptance criteria). */
const readingLimitMs = 60_000;

interface Claim {
  clinic_id: string;
  storage_path: string;
  file_kind: PageKind;
  file_count: number;
}

Deno.serve(async (req) => {
  try {
    const body = await readJSON(req);
    const invoiceID = text(body, "invoice_id").toLowerCase();
    if (!isUUID(invoiceID)) throw new HttpError(400, "validation", "An invoice is required.", "invoice_id");
    const admin = await caller(req);
    const db = serviceClient();
    const { data, error } = await db.rpc("invoice_reading_start", { p_invoice_id: invoiceID, p_user_id: admin.id });
    if (error) throw rpcError(error);
    const claim = (data as Claim[] | null)?.[0];
    if (claim) {
      const work = read(db, invoiceID, claim);
      if (typeof EdgeRuntime !== "undefined") EdgeRuntime.waitUntil(work);
      else await work;
    }
    return json({ status: "reading" }, 202);
  } catch (error) {
    return errorResponse(error);
  }
});

/** Reads the claimed invoice and records the outcome; never throws. */
async function read(db: SupabaseClient, invoiceID: string, claim: Claim) {
  const started = Date.now();
  const signal = AbortSignal.timeout(readingLimitMs);
  const facts: Record<string, unknown> = { invoice: invoiceID, pages: claim.file_count };
  try {
    const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
    if (!apiKey) throw new ReadingFailure("error", "ANTHROPIC_API_KEY is not set");
    const pages = await download(db, claim);
    facts.bytes = pages.reduce((sum, page) => sum + page.data.length, 0);
    const call = claudeCall(apiKey);
    const extraction = await readInvoice(pages, async (request, abort) => {
      const answer = await call(request, abort);
      facts.tokens = `${answer.inputTokens ?? "?"} in, ${answer.outputTokens ?? "?"} out`;
      return answer;
    }, signal);
    const { error } = await db.rpc("invoice_reading_finish", { p_invoice_id: invoiceID, p_extraction: extraction });
    if (error) throw new ReadingFailure("error", `invoice_reading_finish refused (${error.code})`);
    log({ ...facts, outcome: "ready", lines: extraction.lines.length, ms: Date.now() - started });
  } catch (failure) {
    const reason = failure instanceof ReadingFailure ? failure.reason : signal.aborted ? "timeout" : "error";
    const detail = failure instanceof ReadingFailure ? failure.message : errorName(failure);
    log({ ...facts, outcome: "failed", reason, detail, ms: Date.now() - started });
    const { error } = await db.rpc("invoice_reading_fail", { p_invoice_id: invoiceID, p_reason: reason });
    if (error) console.error(JSON.stringify({ function: "extract_invoice", invoice: invoiceID, fail: error.code }));
  }
}

/** The invoice's files, page-1 to page-n, in order. */
async function download(db: SupabaseClient, claim: Claim): Promise<InvoicePage[]> {
  const pages: InvoicePage[] = [];
  for (let n = 1; n <= claim.file_count; n++) {
    const { data, error } = await db.storage.from("invoices").download(`${claim.storage_path}/page-${n}.${claim.file_kind}`);
    if (error || !data) throw new ReadingFailure("error", `page ${n} could not be downloaded`);
    pages.push({ kind: claim.file_kind, data: new Uint8Array(await data.arrayBuffer()) });
  }
  return pages;
}

function log(entry: Record<string, unknown>) {
  console.log(JSON.stringify({ function: "extract_invoice", ...entry }));
}
