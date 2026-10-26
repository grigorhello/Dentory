// MS-129 · Reading the five fixture invoices with their recorded answers (no key needed): what is read from each, the
// request the Claude API gets, the failures, and the tidying of an answer. live_check.ts asks the real API instead.
import { assert, assertEquals, assertFalse, assertRejects, assertStringIncludes } from "jsr:@std/assert@1";
import { fixtureInvoices, fixturePages, recordedAnswer } from "./fixture_invoices.ts";
import {
  base64,
  buildRequest,
  type Extraction,
  extractionSchema,
  instructions,
  type ModelAnswer,
  type ModelCall,
  parseExtraction,
  readerModel,
  readInvoice,
  ReadingFailure,
  type ReadingRequest,
} from "./reading.ts";

/** A model that answers what was recorded, and remembers what it was asked. */
function replay(answer: ModelAnswer, asked: ReadingRequest[] = []): ModelCall {
  return (request) => {
    asked.push(request);
    return Promise.resolve(answer);
  };
}

const live = () => new AbortController().signal;

async function read(name: string): Promise<{ extraction: Extraction; request: ReadingRequest }> {
  const invoice = fixtureInvoices.find((fixture) => fixture.name === name)!;
  const asked: ReadingRequest[] = [];
  const answer = { stopReason: "end_turn", text: await recordedAnswer(invoice) };
  const extraction = await readInvoice(await fixturePages(invoice), replay(answer, asked), live());
  return { extraction, request: asked[0] };
}

function header(extraction: Extraction) {
  const { supplier, invoice_number, invoice_date, currency, total, lines } = extraction;
  return { supplier, invoice_number, invoice_date, currency, total, lines: lines.length };
}

Deno.test("Northbridge's PDF reads to f23's four lines: Septocaine, the endo files, Temp-Bond and the surcharge", async () => {
  const { extraction } = await read("northbridge-inv-10092");
  assertEquals(header(extraction), {
    supplier: "Northbridge Dental Supply", invoice_number: "INV-10092", invoice_date: "2026-09-30", currency: "CAD",
    total: 520.03, lines: 4,
  });
  assertEquals(extraction.lines.map((line) => [line.raw, line.qty, line.unit, line.unit_price, line.line_total, line.kind]), [
    ["SEPTO 4% 1:100K 50/BX", 5, "box", 49.8, 249, "product"],
    ["ENDO FILE KIT 15-40 21MM", 4, "box", 45, 180, "product"],
    ["TEMPBOND NE 1PK", 1, "pack", 26.4, 26.4, "product"],
    ["HANDLING / FUEL SURCHARGE", 1, "each", 4.8, 4.8, "fee"],
  ]);
});

Deno.test("Lakeshore's photographed invoice reads to its supplier, number, total and lines, shipping as a fee", async () => {
  const { extraction } = await read("lakeshore-ls-58113");
  assertEquals(header(extraction), {
    supplier: "Lakeshore Dental Distributors", invoice_number: "LS-58113", invoice_date: "2026-10-14", currency: "CAD",
    total: 113.85, lines: 4,
  });
  assertEquals(extraction.lines.map((line) => line.kind), ["product", "product", "product", "fee"]);
  assertEquals(extraction.lines[3], {
    raw: "SHIPPING", qty: 1, unit: null, unit_price: 12, line_total: 12, lot: null, expiry: null, kind: "fee",
  });
});

Deno.test("Harbourview's two pages read to sixteen lines with their lots and expiry months", async () => {
  const { extraction } = await read("harbourview-hv-2207");
  assertEquals(header(extraction), {
    supplier: "Harbourview Dental Co.", invoice_number: "HV-2207", invoice_date: "2026-10-02", currency: "CAD",
    total: 744.5, lines: 16,
  });
  assertEquals(extraction.lines[0], {
    raw: "SEPTOCAINE 4% 1:100,000 CARTRIDGES 50/BX", qty: 2, unit: "box", unit_price: 52.4, line_total: 104.8,
    lot: "B552", expiry: "2028-03-01", kind: "product",
  });
  assertEquals(extraction.lines[3].lot, "PP3091");
  assertEquals(extraction.lines[3].expiry, null);
  assertEquals(extraction.lines.at(-1)?.raw, "ENVIRONMENTAL FEE");
  assertEquals(extraction.lines.at(-1)?.kind, "fee");
  const lineTotals = extraction.lines.reduce((sum, line) => sum + (line.line_total ?? 0), 0);
  assertEquals(Math.round(lineTotals * 100) / 100, 658.85, "the lines add up to the subtotal before tax");
});

Deno.test("Prairie's two scanned pages from a US supplier read in US dollars, the date written month first", async () => {
  const { extraction } = await read("prairie-pdw-90412");
  assertEquals(header(extraction), {
    supplier: "Prairie Dental Wholesale", invoice_number: "PDW-90412", invoice_date: "2026-10-20", currency: "USD",
    total: 384.75, lines: 9,
  });
  assertEquals(extraction.lines[2].raw, "ROOT CANAL SEALER KIT");
  assertEquals(extraction.lines[8].kind, "fee");
});

Deno.test("Rive-Sud's French invoice reads with its accents, decimal commas as points, and delivery as a fee", async () => {
  const { extraction } = await read("rive-sud-f-3381");
  assertEquals(header(extraction), {
    supplier: "Fournitures dentaires Rive-Sud", invoice_number: "F-3381", invoice_date: "2026-10-09", currency: "CAD",
    total: 100.31, lines: 4,
  });
  assertEquals(extraction.lines.map((line) => [line.raw, line.unit, line.unit_price]), [
    ["Gants nitrile moyens 100/bte", "box", 9.25],
    ["Pâte prophylactique menthe 200 g", "jar", 16.4],
    ["Hypochlorite de sodium 5,25 % 1 L", "bottle", 7.95],
    ["Frais de livraison", null, 9.5],
  ]);
  assertEquals(extraction.lines[3].kind, "fee");
});

Deno.test("no recorded answer carries the people the pages name", async () => {
  const answers = await Promise.all(fixtureInvoices.map(recordedAnswer));
  for (const text of ["Daniel Kim", "Jordan Ellis", "555-0142", "Attn"]) {
    assertFalse(answers.some((answer) => answer.includes(text)), `${text} is personal data`);
  }
});

Deno.test("a PDF goes as one document, a photo as one image, and scanned pages as images labelled in order", async () => {
  const pdf = (await read("northbridge-inv-10092")).request.messages[0].content as { type: string }[];
  assertEquals(pdf.map((block) => block.type), ["document", "text"]);
  const photo = (await read("lakeshore-ls-58113")).request.messages[0].content as { type: string }[];
  assertEquals(photo.map((block) => block.type), ["image", "text"]);
  const scans = (await read("prairie-pdw-90412")).request.messages[0].content as {
    type: string;
    text?: string;
    source?: { media_type: string };
  }[];
  assertEquals(scans.map((block) => block.text ?? block.source?.media_type), [
    "Page 1:", "image/jpeg", "Page 2:", "image/jpeg", "Read this invoice.",
  ]);
});

Deno.test("the pages are sent whole, in base64", async () => {
  const invoice = fixtureInvoices.find((fixture) => fixture.name === "harbourview-hv-2207")!;
  const [page] = await fixturePages(invoice);
  const [document] = buildRequest([page]).messages[0].content as { source: { media_type: string; data: string } }[];
  assertEquals(document.source.media_type, "application/pdf");
  const decoded = Uint8Array.from(atob(document.source.data), (character) => character.charCodeAt(0));
  assertEquals(decoded, page.data);
});

Deno.test("the request asks the current Sonnet for the schema's JSON, at low effort, with the server-side fallback", () => {
  const request = buildRequest([{ kind: "jpg", data: new Uint8Array([1, 2, 3]) }]);
  assertEquals(request.model, "claude-sonnet-5-5");
  assertEquals(readerModel, "claude-sonnet-5-5");
  assertEquals(request.output_config, { effort: "low", format: { type: "json_schema", schema: extractionSchema } });
  assertEquals(request.betas, ["server-side-fallback-2026-07-01"]);
  assertEquals(request.fallbacks, "default");
  assertEquals(request.system, instructions);
  assertEquals(request.max_tokens, 16_000);
  assertFalse("temperature" in request, "API version 2026-10-21 refuses sampling parameters");
});

Deno.test("the schema is strict: every object closes its properties and requires each of them", () => {
  const visit = (node: unknown, path: string) => {
    if (Array.isArray(node)) return node.forEach((child, index) => visit(child, `${path}[${index}]`));
    if (typeof node !== "object" || node === null) return;
    const schema = node as Record<string, unknown>;
    if (schema.type === "object") {
      assertEquals(schema.additionalProperties, false, `${path} closes its properties`);
      assertEquals(
        [...(schema.required as string[])].sort(),
        Object.keys(schema.properties as object).sort(),
        `${path} requires them all`,
      );
    }
    for (const [key, child] of Object.entries(schema)) visit(child, `${path}.${key}`);
  };
  visit(extractionSchema, "schema");
  const line = (extractionSchema.properties.lines.items.properties as Record<string, unknown>).kind;
  assertEquals(line, { type: "string", enum: ["product", "fee"] });
});

Deno.test("the prompt tells the reader to leave personal data out", () => {
  assertStringIncludes(instructions, "Ignore all personal data");
  assertStringIncludes(instructions, "leave a person's name out of raw");
  assertStringIncludes(instructions, "never guess a value");
});

Deno.test("a declined request fails as refused, and an answer cut short as unreadable", async () => {
  const pages = [{ kind: "jpg" as const, data: new Uint8Array([1]) }];
  const refused = await assertRejects(() => readInvoice(pages, replay({ stopReason: "refusal", text: "" }), live()), ReadingFailure);
  assertEquals(refused.reason, "refused");
  const cut = await assertRejects(
    () => readInvoice(pages, replay({ stopReason: "max_tokens", text: '{"lines": [' }), live()),
    ReadingFailure,
  );
  assertEquals(cut.reason, "unreadable");
});

Deno.test("an answer that is not JSON is unreadable, and the failure does not quote it", async () => {
  const pages = [{ kind: "jpg" as const, data: new Uint8Array([1]) }];
  const failure = await assertRejects(
    () => readInvoice(pages, replay({ stopReason: "end_turn", text: "SEPTO 4% 1:100K, five boxes" }), live()),
    ReadingFailure,
  );
  assertEquals(failure.reason, "unreadable");
  assertFalse(failure.message.includes("SEPTO"), "invoice contents stay out of the logs");
});

Deno.test("pages without invoice lines are unreadable", () => {
  for (const text of ['{"supplier": null, "lines": []}', '{"lines": [{"raw": "   ", "kind": "product"}]}', "[]", "{}"]) {
    const failure = (() => {
      try {
        parseExtraction(text);
      } catch (error) {
        return error;
      }
    })();
    assert(failure instanceof ReadingFailure, text);
    assertEquals(failure.reason, "unreadable");
  }
  const tooMany = JSON.stringify({ lines: Array.from({ length: 301 }, (_, n) => ({ raw: `ITEM ${n}`, kind: "product" })) });
  assertEquals((() => {
    try {
      parseExtraction(tooMany);
    } catch (error) {
      return (error as ReadingFailure).reason;
    }
  })(), "unreadable");
});

Deno.test("a call still running at the deadline fails as timeout; any other failure is an error, named without its message", async () => {
  const pages = [{ kind: "pdf" as const, data: new Uint8Array([1]) }];
  const deadline = new AbortController();
  const slow: ModelCall = (_request, signal) =>
    new Promise((_resolve, reject) => signal.addEventListener("abort", () => reject(new Error("aborted"))));
  setTimeout(() => deadline.abort(), 5);
  const late = await assertRejects(() => readInvoice(pages, slow, deadline.signal), ReadingFailure);
  assertEquals(late.reason, "timeout");

  class APIError extends Error {
    status = 529;
    override name = "OverloadedError";
  }
  const broken: ModelCall = () => Promise.reject(new APIError("overloaded: SEPTO 4% 1:100K"));
  const failure = await assertRejects(() => readInvoice(pages, broken, live()), ReadingFailure);
  assertEquals(failure.reason, "error");
  assertEquals(failure.message, "the call failed (OverloadedError 529)");
});

Deno.test("an answer is tidied: spaces, rounding, currency, units, real days and expiry months", () => {
  const extraction = parseExtraction(JSON.stringify({
    supplier: "  Northbridge   Dental Supply ", invoice_number: " INV-1 ", invoice_date: "2026-02-30", currency: "cad",
    total: 12.3456, lines: [
      { raw: " GAUZE  2X2 ", qty: 2.004, unit: "BX", unit_price: 1.23456, line_total: 1e12, lot: " L1 ", expiry: "2027-11", kind: "x" },
      { raw: "ETCH GEL", qty: "2", unit: "Pk.", unit_price: null, line_total: 3, lot: "", expiry: "2027-13", kind: "fee" },
      { raw: "BIB", qty: 1, unit: "ea", unit_price: 1, line_total: 1, lot: null, expiry: "2028-04-17", kind: "product" },
    ],
  }));
  assertEquals(extraction, {
    supplier: "Northbridge Dental Supply", invoice_number: "INV-1", invoice_date: null, currency: "CAD", total: 12.35,
    lines: [
      { raw: "GAUZE 2X2", qty: 2, unit: "box", unit_price: 1.2346, line_total: null, lot: "L1", expiry: "2027-11-01", kind: "product" },
      { raw: "ETCH GEL", qty: null, unit: "pack", unit_price: null, line_total: 3, lot: null, expiry: null, kind: "fee" },
      { raw: "BIB", qty: 1, unit: "each", unit_price: 1, line_total: 1, lot: null, expiry: "2028-04-01", kind: "product" },
    ],
  });
});

Deno.test("a unit price from 100,000,000 up, too big for its column, is left out and the reading goes on", () => {
  const extraction = parseExtraction(JSON.stringify({
    total: 123456789, lines: [
      { raw: "SEPTOCAINE", qty: 1, unit: "box", unit_price: 123456789, line_total: 123456789, kind: "product" },
      { raw: "NEEDLES", qty: 1, unit: "box", unit_price: 99999999.9999, line_total: 99999999.99, kind: "product" },
      { raw: "GAUZE", qty: 1, unit: "box", unit_price: 99999999.99996, line_total: 1, kind: "product" },
    ],
  }));
  assertEquals(extraction.total, 123456789);
  assertEquals(extraction.lines.map(({ unit_price, line_total }) => ({ unit_price, line_total })), [
    { unit_price: null, line_total: 123456789 },
    { unit_price: 99999999.9999, line_total: 99999999.99 },
    { unit_price: null, line_total: 1 },
  ]);
});

Deno.test("base64 encodes pages larger than one chunk", () => {
  const data = Uint8Array.from({ length: 100_003 }, (_, index) => (index * 7919) % 256);
  assertEquals(Uint8Array.from(atob(base64(data)), (character) => character.charCodeAt(0)), data);
});

// The pgTAP test 40_invoice_matching_test.sql matches the readings the database gets from these fixtures; its
// `-- fixture:` blocks must be exactly what reading.ts makes of the recorded answers.
Deno.test("the matching test's readings are the recorded answers as reading.ts tidies them", async () => {
  const sql = await Deno.readTextFile(new URL("../../tests/database/40_invoice_matching_test.sql", import.meta.url));
  const blocks = [...sql.matchAll(/-- fixture: ([\w-]+)\n[^$]*\$fixture\$([\s\S]*?)\$fixture\$/g)];
  assertEquals(blocks.map((block) => block[1]), fixtureInvoices.map((invoice) => invoice.name));
  for (const [, name, json] of blocks) {
    const invoice = fixtureInvoices.find((fixture) => fixture.name === name)!;
    assertEquals(JSON.parse(json), parseExtraction(await recordedAnswer(invoice)), name);
  }
});
