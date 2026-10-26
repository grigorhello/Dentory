// MS-129 · The opt-in live check: `make invoice-reading-live` with ANTHROPIC_API_KEY in the environment reads the five
// fixture invoices with the real Claude API, compares each reading with the recorded answer, checks that no personal
// data came back, and that the median reading took under 20 seconds (the ticket's p50; each well under the 60-second
// limit). It spends a few cents. Without the key it does not run. With RECORD=1 it writes the live answers over
// fixtures/*.json instead of comparing (then update 40_invoice_matching_test.sql's blocks: reading_test.ts says how).
// The file is not named *_test.ts, so `make functions-check` and CI never run it.
import { assert, assertEquals } from "jsr:@std/assert@1";
import { claudeCall } from "./claude.ts";
import { fixtureInvoices, fixturePages, fixturesFolder, recordedAnswer } from "./fixture_invoices.ts";
import { type Extraction, type ModelCall, parseExtraction, readInvoice } from "./reading.ts";

const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
const recording = Deno.env.get("RECORD") === "1";

/** Letters and digits only, lower case: the supplier and the line text compared as the matching compares them. */
const words = (text: string | null) => (text ?? "").toLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ").trim();

function sameReading(live: Extraction, recorded: Extraction, name: string) {
  assertEquals(words(live.supplier), words(recorded.supplier), `${name}: supplier`);
  assertEquals(live.invoice_number?.replace(/\s/g, ""), recorded.invoice_number?.replace(/\s/g, ""), `${name}: number`);
  assertEquals(live.invoice_date, recorded.invoice_date, `${name}: date`);
  assertEquals(live.currency, recorded.currency, `${name}: currency`);
  assertEquals(live.total, recorded.total, `${name}: total`);
  assertEquals(live.lines.length, recorded.lines.length, `${name}: lines`);
  live.lines.forEach((line, index) => {
    const expected = recorded.lines[index];
    const where = `${name}, line ${index + 1}`;
    assertEquals(words(line.raw), words(expected.raw), `${where}: text`);
    assertEquals([line.qty, line.unit, line.unit_price, line.line_total], [
      expected.qty, expected.unit, expected.unit_price, expected.line_total,
    ], `${where}: quantity, unit and prices`);
    assertEquals([line.lot, line.expiry, line.kind], [expected.lot, expected.expiry, expected.kind], `${where}: lot, expiry, kind`);
  });
}

Deno.test({
  name: "the fixture invoices read live as recorded, the median under 20 seconds",
  ignore: !apiKey,
  async fn() {
    const call = claudeCall(apiKey!);
    const seconds: number[] = [];
    for (const invoice of fixtureInvoices) {
      let answer = "";
      const recordingCall: ModelCall = async (request, signal) => {
        const result = await call(request, signal);
        answer = result.text;
        return result;
      };
      const started = performance.now();
      const live = await readInvoice(await fixturePages(invoice), recordingCall, AbortSignal.timeout(60_000));
      seconds.push((performance.now() - started) / 1000);
      console.log(`${invoice.name}: ${seconds.at(-1)!.toFixed(1)} s, ${live.lines.length} lines`);
      for (const personal of ["Daniel Kim", "Jordan Ellis", "555-0142"]) {
        assert(!answer.includes(personal), `${invoice.name}: the answer carries personal data (${personal})`);
      }
      if (recording) {
        const pretty = JSON.stringify(JSON.parse(answer), null, 2);
        await Deno.writeTextFile(new URL(`${invoice.name}.json`, fixturesFolder), `${pretty}\n`);
      } else {
        sameReading(live, parseExtraction(await recordedAnswer(invoice)), invoice.name);
      }
    }
    const median = [...seconds].sort((a, b) => a - b)[Math.floor(seconds.length / 2)];
    console.log(`median ${median.toFixed(1)} s, slowest ${Math.max(...seconds).toFixed(1)} s`);
    assert(median < 20, `the median reading took ${median.toFixed(1)} s; the target is under 20 s`);
  },
});
