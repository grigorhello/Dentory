// MS-136 · The reader on the local stack without a key: each fixture invoice's pages are read to its recorded answer,
// through the request the API would get; any other pages fail as a reading without a key did; only the local stack's
// functions replay; and the choice between the API, the recordings and the failure never replays on a hosted project.
import { assert, assertEquals, assertFalse, assertRejects, assertStrictEquals, assertThrows } from "jsr:@std/assert@1";
import { fixtureInvoices, fixturePages, recordedAnswer } from "./fixture_invoices.ts";
import { type ModelCall, parseExtraction, readInvoice, ReadingFailure } from "./reading.ts";
import { isLocalStack } from "../_shared/environment.ts";
import { modelCallFor, recordings, replayCall } from "./replay.ts";

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

Deno.test("a key reads with the API anywhere, no key replays on the local stack only, else the reading fails", () => {
  const hosted = "https://abcdefghijklmnopqrst.supabase.co";
  const local = "http://kong:8000";
  const claudeReader: ModelCall = () => Promise.reject(new Error("not called"));
  const keys: string[] = [];
  const claude = (apiKey: string) => {
    keys.push(apiKey);
    return claudeReader;
  };
  const cases: [string | undefined, string | undefined, "claude" | "replay" | "error"][] = [
    ["sk-ant-test", hosted, "claude"],
    ["sk-ant-test", local, "claude"],
    ["sk-ant-test", undefined, "claude"],
    [undefined, local, "replay"],
    ["", local, "replay"],
    [undefined, hosted, "error"],
    ["", hosted, "error"],
    [undefined, "http://127.0.0.1:54321", "error"],
    [undefined, "kong", "error"],
    [undefined, "", "error"],
    [undefined, undefined, "error"],
  ];
  for (const [apiKey, supabaseURL, reader] of cases) {
    const name = `${apiKey === undefined ? "no key" : `key "${apiKey}"`} at ${supabaseURL ?? "no SUPABASE_URL"}`;
    if (reader === "error") {
      const failure = assertThrows(() => modelCallFor(apiKey, supabaseURL, claude), ReadingFailure, undefined, name);
      assertEquals(failure.reason, "error", name);
      continue;
    }
    const call = modelCallFor(apiKey, supabaseURL, claude);
    assertStrictEquals(call, reader === "claude" ? claudeReader : replayCall, name);
    if (reader === "claude") assertEquals(keys.at(-1), apiKey, name);
  }
});
