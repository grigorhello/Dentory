// The five synthetic fixture invoices (fixtures/README.md) for reading_test.ts and live_check.ts: each one's pages as
// the app uploads them, and the recorded answer of the reader for it.
import type { InvoicePage, PageKind } from "./reading.ts";

export interface FixtureInvoice {
  name: string;
  /** The files, in page order. */
  files: string[];
}

export const fixtureInvoices: FixtureInvoice[] = [
  { name: "northbridge-inv-10092", files: ["northbridge-inv-10092.pdf"] },
  { name: "lakeshore-ls-58113", files: ["lakeshore-ls-58113.jpg"] },
  { name: "harbourview-hv-2207", files: ["harbourview-hv-2207.pdf"] },
  { name: "prairie-pdw-90412", files: ["prairie-pdw-90412-page-1.jpg", "prairie-pdw-90412-page-2.jpg"] },
  { name: "rive-sud-f-3381", files: ["rive-sud-f-3381.pdf"] },
];

export const fixturesFolder = new URL("./fixtures/", import.meta.url);

export async function fixturePages(invoice: FixtureInvoice): Promise<InvoicePage[]> {
  return await Promise.all(invoice.files.map(async (file) => ({
    kind: (file.endsWith(".pdf") ? "pdf" : "jpg") as PageKind,
    data: await Deno.readFile(new URL(file, fixturesFolder)),
  })));
}

/** The recorded answer: the JSON the schema returns for the invoice. */
export async function recordedAnswer(invoice: FixtureInvoice): Promise<string> {
  return await Deno.readTextFile(new URL(`${invoice.name}.json`, fixturesFolder));
}
