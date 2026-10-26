// MS-136 · The reader on the local stack without a key: each fixture invoice's pages are read to its recorded answer,
// through the request the API would get; any other pages fail as a reading without a key did; and only the local
// stack's functions replay.
import { assert, assertEquals, assertFalse, assertRejects } from "jsr:@std/assert@1";
import { fixtureInvoices, fixturePages, recordedAnswer } from "./fixture_invoices.ts";
import { parseExtraction, readInvoice, ReadingFailure } from "./reading.ts";
import { isLocalStack, recordings, replayCall } from "./replay.ts";

const live = () => new AbortController().signal;

Deno.test("each fixture invoice reads to its recorded answer", async () => {
  for (const invoice of fixtureInvoices) {
    const extraction = await readInvoice(await fixturePages(invoice), replayCall, live());
    assertEquals(extraction, parseExtraction(await recordedAnswer(invoice)), invoice.name);
  }
  assertEquals(Object.keys(recordings).length, fixtureInvoices.length, "a recording for each fixture, and no other");
});

Deno.test("pages that are no fixture invoice fail with the reason error", async () => {
  const [northbridge, lakeshore] = await Promise.all(fixtureInvoices.slice(0, 2).map(fixturePages));
  const cases = [
    [{ kind: "pdf" as const, data: new TextEncoder().encode("%PDF-1.7 another invoice") }],
    // Two fixtures' pages together, and a page cut short, are other requests.
    [...lakeshore, ...northbridge],
    northbridge.map((page) => ({ ...page, data: page.data.slice(0, page.data.length - 1) })),
  ];
  for (const pages of cases) {
    const failure = await assertRejects(() => readInvoice(pages, replayCall, live()), ReadingFailure);
    assertEquals(failure.reason, "error");
  }
});

Deno.test("only the local stack's functions replay, whose SUPABASE_URL is the stack's gateway", () => {
  assert(isLocalStack("http://kong:8000"));
  for (const url of ["https://abcdefghijklmnopqrst.supabase.co", "http://127.0.0.1:54321", "", "kong"]) {
    assertFalse(isLocalStack(url), url);
  }
});
