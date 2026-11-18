// Which model should read invoices: `make invoice-model-compare`, with ANTHROPIC_API_KEY typed at its hidden prompt,
// reads every sample invoice with each reader below through the real Claude API, compares each reading with what the
// invoice says (its known content, not another model's answer), and prints a table and the cost of each reader per
// invoice from the tokens the API reports. The full report, with every difference, goes to REPORT as JSON. The samples
// are the five fixture invoices, the demo invoice (PDF and photo), and harder pages made from them
// (fixtures/hard/make_hard.py): a tilted photo, a dim photo, low-resolution photos and scans, and the French invoice
// photographed at an angle in poor light. All are synthetic, from fictional suppliers. It spends well under a dollar.
// The file is not named *_test.ts, so `make functions-check` and CI only type-check it.
import { claudeCall } from "./claude.ts";
import {
  type Extraction,
  type InvoicePage,
  parseExtraction,
  readInvoice,
  type Reader,
  ReadingFailure,
} from "./reading.ts";

interface Sample {
  name: string;
  /** Paths from this folder, in page order. */
  files: string[];
  /** The invoice's known content, in the extraction schema. */
  truth: string;
}

const demoTruth = "../../../docs/demo/northbridge-inv-10418.json";
const fixture = (file: string) => `fixtures/${file}`;
const harder = (file: string) => `fixtures/hard/${file}`;
const truthOf = (invoice: string) => fixture(`${invoice}.json`);

export const samples: Sample[] = [
  { name: "northbridge, PDF", files: [fixture("northbridge-inv-10092.pdf")], truth: truthOf("northbridge-inv-10092") },
  { name: "lakeshore, phone photo", files: [fixture("lakeshore-ls-58113.jpg")], truth: truthOf("lakeshore-ls-58113") },
  { name: "harbourview, 2pp PDF", files: [fixture("harbourview-hv-2207.pdf")], truth: truthOf("harbourview-hv-2207") },
  {
    name: "prairie, 2 scans, US",
    files: [fixture("prairie-pdw-90412-page-1.jpg"), fixture("prairie-pdw-90412-page-2.jpg")],
    truth: truthOf("prairie-pdw-90412"),
  },
  { name: "rive-sud, French PDF", files: [fixture("rive-sud-f-3381.pdf")], truth: truthOf("rive-sud-f-3381") },
  { name: "demo 10418, PDF", files: ["../../../docs/demo/northbridge-inv-10418.pdf"], truth: demoTruth },
  { name: "demo 10418, photo", files: [harder("northbridge-inv-10418-photo.jpg")], truth: demoTruth },
  { name: "demo 10418, tilted", files: [harder("northbridge-inv-10418-tilted.jpg")], truth: demoTruth },
  { name: "demo 10418, dim", files: [harder("northbridge-inv-10418-dim.jpg")], truth: demoTruth },
  { name: "demo 10418, 1000 px", files: [harder("northbridge-inv-10418-small.jpg")], truth: demoTruth },
  { name: "rive-sud, dim photo", files: [harder("rive-sud-f-3381-photo.jpg")], truth: truthOf("rive-sud-f-3381") },
  {
    name: "harbourview, 100 dpi pages",
    files: [harder("harbourview-hv-2207-small-page-1.jpg"), harder("harbourview-hv-2207-small-page-2.jpg")],
    truth: truthOf("harbourview-hv-2207"),
  },
  {
    name: "prairie, 1000 px scans",
    files: [harder("prairie-pdw-90412-small-page-1.jpg"), harder("prairie-pdw-90412-small-page-2.jpg")],
    truth: truthOf("prairie-pdw-90412"),
  },
];

/** Dollars per million tokens, input and output, for prompts under 100K tokens (an invoice's are a few thousand). */
const prices: Record<string, [number, number]> = {
  "claude-sonnet-5-5": [2, 10],
  "claude-haiku-5-5": [0.1, 0.5],
};

/** The current reader first, then Claude Haiku 5.5 at the same effort twice (its answers vary) and one step higher. */
export const readers: { label: string; reader: Reader; runs: number }[] = [
  { label: "Sonnet 5.5, low (current)", reader: { model: "claude-sonnet-5-5", effort: "low" }, runs: 1 },
  { label: "Haiku 5.5, low", reader: { model: "claude-haiku-5-5", effort: "low" }, runs: 2 },
  { label: "Haiku 5.5, medium", reader: { model: "claude-haiku-5-5", effort: "medium" }, runs: 1 },
];

/** Letters and digits only, lower case, as the matching compares the supplier and the line text. */
const words = (text: string | null) => (text ?? "").toLowerCase().replace(/[^\p{L}\p{N}]+/gu, " ").trim();
const compact = (text: string | null) => (text ?? "").replace(/\s/g, "").toUpperCase();

export interface Differences {
  /** What would put wrong stock in the app: the line count, a quantity, unit, lot, expiry or kind. */
  stock: string[];
  /** What the admin would correct on Review invoice: the header, a line's text or prices. */
  other: string[];
}

export function compare(read: Extraction, truth: Extraction): Differences {
  const stock: string[] = [];
  const other: string[] = [];
  const check = (list: string[], where: string, got: unknown, want: unknown) => {
    if (got !== want) list.push(`${where}: ${JSON.stringify(got)}, should be ${JSON.stringify(want)}`);
  };
  check(other, "supplier", words(read.supplier), words(truth.supplier));
  check(other, "invoice number", compact(read.invoice_number), compact(truth.invoice_number));
  check(other, "date", read.invoice_date, truth.invoice_date);
  check(other, "currency", read.currency, truth.currency);
  check(other, "total", read.total, truth.total);
  check(stock, "line count", read.lines.length, truth.lines.length);
  truth.lines.forEach((want, index) => {
    const got = read.lines[index];
    const where = `line ${index + 1}`;
    if (!got) return;
    check(other, `${where} text`, words(got.raw), words(want.raw));
    check(stock, `${where} qty`, got.qty, want.qty);
    check(stock, `${where} unit`, got.unit, want.unit);
    check(stock, `${where} lot`, compact(got.lot), compact(want.lot));
    check(stock, `${where} expiry`, got.expiry, want.expiry);
    check(stock, `${where} kind`, got.kind, want.kind);
    check(other, `${where} unit price`, got.unit_price, want.unit_price);
    check(other, `${where} line total`, got.line_total, want.line_total);
  });
  return { stock, other };
}

/** The personal data on the fixture invoices, which no answer may carry. */
const personal = ["Daniel Kim", "Jordan Ellis", "555-0142"];

interface Run {
  sample: string;
  reader: string;
  run: number;
  seconds: number;
  inputTokens: number;
  outputTokens: number;
  dollars: number;
  failure?: string;
  personalData?: string[];
  differences?: Differences;
}

async function main() {
  const apiKey = Deno.env.get("ANTHROPIC_API_KEY");
  if (!apiKey) {
    console.error("ANTHROPIC_API_KEY is not set.");
    Deno.exit(1);
  }
  const reportPath = Deno.env.get("REPORT") ?? "invoice-model-compare.json";
  const call = claudeCall(apiKey);
  const here = new URL("./", import.meta.url);
  const runs: Run[] = [];

  for (const sample of samples) {
    const pages: InvoicePage[] = await Promise.all(sample.files.map(async (file) => ({
      kind: file.endsWith(".pdf") ? "pdf" as const : "jpg" as const,
      data: await Deno.readFile(new URL(file, here)),
    })));
    const truth = parseExtraction(await Deno.readTextFile(new URL(sample.truth, here)));
    for (const { label, reader, runs: count } of readers) {
      for (let run = 1; run <= count; run++) {
        let text = "";
        let inputTokens = 0;
        let outputTokens = 0;
        const started = performance.now();
        const result: Run = { sample: sample.name, reader: label, run, seconds: 0, inputTokens, outputTokens, dollars: 0 };
        try {
          const read = await readInvoice(pages, async (request, signal) => {
            const answer = await call(request, signal);
            text = answer.text;
            inputTokens = answer.inputTokens ?? 0;
            outputTokens = answer.outputTokens ?? 0;
            return answer;
          }, AbortSignal.timeout(60_000), reader);
          result.differences = compare(read, truth);
          const leaked = personal.filter((value) => text.includes(value));
          if (leaked.length > 0) result.personalData = leaked;
        } catch (error) {
          result.failure = error instanceof ReadingFailure ? `${error.reason}: ${error.message}` : String(error);
        }
        const [inPrice, outPrice] = prices[reader.model];
        Object.assign(result, {
          seconds: Math.round((performance.now() - started) / 100) / 10,
          inputTokens,
          outputTokens,
          dollars: (inputTokens * inPrice + outputTokens * outPrice) / 1e6,
        });
        runs.push(result);
        const stock = result.differences?.stock.length ?? "-";
        const other = result.differences?.other.length ?? "-";
        const outcome = result.failure ? `FAILED ${result.failure}` : `stock diffs ${stock}, other ${other}`;
        console.log(
          `${sample.name.padEnd(28)} ${label.padEnd(26)} #${run}  ${outcome}` +
            `  ${result.seconds}s  ${inputTokens} in / ${outputTokens} out  $${result.dollars.toFixed(4)}` +
            (result.personalData ? `  PERSONAL DATA ${result.personalData.join(", ")}` : ""),
        );
      }
    }
  }

  console.log("\nPer reader:");
  const summary = readers.map(({ label }) => {
    const mine = runs.filter((run) => run.reader === label);
    const clean = mine.filter((run) => !run.failure && run.differences!.stock.length === 0 && !run.personalData);
    const perInvoice = mine.reduce((sum, run) => sum + run.dollars, 0) / mine.length;
    const seconds = mine.map((run) => run.seconds).sort((a, b) => a - b);
    const line = {
      reader: label,
      readings: mine.length,
      exactStock: clean.length,
      otherDiffs: mine.reduce((sum, run) => sum + (run.differences?.other.length ?? 0), 0),
      failures: mine.filter((run) => run.failure).length,
      dollarsPerInvoice: Math.round(perInvoice * 1e5) / 1e5,
      medianSeconds: seconds[Math.floor(seconds.length / 2)],
    };
    console.log(
      `${label.padEnd(26)} stock exact on ${line.exactStock}/${line.readings}, other diffs ${line.otherDiffs}, ` +
        `failures ${line.failures}, $${perInvoice.toFixed(4)} per invoice, median ${line.medianSeconds}s`,
    );
    return line;
  });
  await Deno.writeTextFile(reportPath, `${JSON.stringify({ at: new Date().toISOString(), summary, runs }, null, 2)}\n`);
  console.log(`\nReport: ${reportPath}`);
}

if (import.meta.main) await main();
