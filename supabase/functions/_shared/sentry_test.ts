// deno test supabase/functions (make functions-check): what a function sends Sentry (MS-150), with a fake fetch.
import { assert, assertEquals, assertFalse } from "jsr:@std/assert@1";
import { type Fetcher, type Issue, report, sentryTarget, stackFrames } from "./sentry.ts";

const dsn = "https://0123456789abcdef@o4508.ingest.us.sentry.io/4509";
const supabaseURL = "https://abcdefghijklmnopqrst.supabase.co";

/** A fetch that keeps what it was sent and answers `status`, or throws when `status` is null. */
function fakeFetch(status: number | null = 200) {
  const sent: { url: string; init: RequestInit }[] = [];
  const fetcher: Fetcher = (url, init) => {
    sent.push({ url, init });
    if (status === null) return Promise.reject(new TypeError("error sending request"));
    return Promise.resolve(new Response(null, { status }));
  };
  return { sent, fetcher };
}

/** The envelope's three lines: its header, the item's header and the event. */
function lines(init: RequestInit): Record<string, unknown>[] {
  const body = String(init.body);
  assert(body.endsWith("\n"));
  return body.trimEnd().split("\n").map((line) => JSON.parse(line));
}

Deno.test("a DSN names the envelope endpoint and the key; anything else sends nothing", () => {
  assertEquals(sentryTarget(dsn), {
    dsn,
    url: "https://o4508.ingest.us.sentry.io/api/4509/envelope/",
    publicKey: "0123456789abcdef",
  });
  const relayed = sentryTarget("https://key@sentry.example.com/relay/42");
  assertEquals(relayed?.url, "https://sentry.example.com/relay/api/42/envelope/");
  const notDSNs = [undefined, "", "not a dsn", "https://o4508.ingest.us.sentry.io/4509", "https://key@sentry.io/"];
  for (const value of [...notDSNs, "ftp://key@sentry.io/1"]) assertEquals(sentryTarget(value), null, String(value));
});

Deno.test("without a DSN nothing is sent", async () => {
  const { sent, fetcher } = fakeFetch();
  assertFalse(await report({ fn: "extract_invoice", kind: "timeout" }, { dsn: "", supabaseURL, fetcher }));
  assertEquals(sent.length, 0);
});

Deno.test("an error goes as one event: its function, kind, class and frames, never its message", async () => {
  const { sent, fetcher } = fakeFetch();
  const error = new TypeError("could not email priya@smile.ca about Septocaine 4%");
  const issue: Issue = { fn: "export_csv", kind: "unexpected", error, tags: { pages: "2" } };
  assert(await report(issue, { dsn, supabaseURL, fetcher }));

  assertEquals(sent.length, 1);
  assertEquals(sent[0].url, "https://o4508.ingest.us.sentry.io/api/4509/envelope/");
  const headers = new Headers(sent[0].init.headers);
  assertEquals(headers.get("Content-Type"), "application/x-sentry-envelope");
  assert(headers.get("X-Sentry-Auth")?.includes("sentry_key=0123456789abcdef"));
  const body = String(sent[0].init.body);
  for (const secret of ["priya", "smile.ca", "Septocaine"]) assertFalse(body.includes(secret), secret);

  const [header, item, event] = lines(sent[0].init);
  assertEquals(header.dsn, dsn);
  assert(/^[0-9a-f]{32}$/.test(String(header.event_id)));
  assertEquals(item, { type: "event" });
  assertEquals(event.event_id, header.event_id);
  assertEquals(event.level, "error");
  assertEquals(event.transaction, "export_csv");
  assertEquals(event.fingerprint, ["export_csv", "unexpected"]);
  assertEquals(event.tags, { pages: "2", project: "abcdefghijklmnopqrst", function: "export_csv", kind: "unexpected" });
  const [exception] = (event.exception as { values: Record<string, unknown>[] }).values;
  assertEquals(exception.type, "TypeError");
  assertEquals(exception.value, "unexpected in export_csv");
  const frames = (exception.stacktrace as { frames: { filename: string }[] }).frames;
  assert(frames.length > 0);
  assert(frames.at(-1)?.filename.endsWith("sentry_test.ts"), "The newest frame comes last");
});

Deno.test("a time limit with no error behind it is named by its kind, and its HTTP status rides along", async () => {
  const { sent, fetcher } = fakeFetch();
  const options = { dsn, supabaseURL, fetcher };
  assert(await report({ fn: "extract_invoice", kind: "timeout", tags: { reason: "timeout" } }, options));
  const [, , timeout] = lines(sent[0].init);
  const [exception] = (timeout.exception as { values: Record<string, unknown>[] }).values;
  assertEquals(exception, { type: "timeout", value: "timeout in extract_invoice" });

  const overloaded = Object.assign(new Error("Overloaded: the request quoted the invoice"), {
    name: "APIError",
    status: 529,
  });
  assert(await report({ fn: "extract_invoice", kind: "reading_error", error: overloaded }, options));
  const [, , reading] = lines(sent[1].init);
  assertEquals((reading.tags as Record<string, string>).status, "529");
  assertFalse(String(sent[1].init.body).includes("quoted the invoice"));
});

Deno.test("Sentry down or refusing never fails the function", async () => {
  const issue: Issue = { fn: "send_push", kind: "unexpected", error: new Error("boom") };
  assertFalse(await report(issue, { dsn, supabaseURL, fetcher: fakeFetch(null).fetcher }));
  assertFalse(await report(issue, { dsn, supabaseURL, fetcher: fakeFetch(429).fetcher }));
});

Deno.test("a V8 stack becomes frames, oldest first, without the message lines", () => {
  const error = new Error("first line\nsecond line with a name");
  error.stack = [
    "Error: first line",
    "second line with a name",
    "    at read (file:///functions/extract_invoice/index.ts:70:11)",
    "    at async Promise.all (index 0)",
    "    at file:///functions/extract_invoice/index.ts:40:5",
  ].join("\n");
  assertEquals(stackFrames(error), [
    { function: "<anonymous>", filename: "file:///functions/extract_invoice/index.ts", lineno: 40, colno: 5 },
    { function: "read", filename: "file:///functions/extract_invoice/index.ts", lineno: 70, colno: 11 },
  ]);
  assertEquals(stackFrames("a string"), []);
});
