// CSV for spreadsheets (MS-143): UTF-8 with a byte order mark, so Excel reads accents; CRLF line ends; every text cell
// quoted when it holds a comma, a quote or a line break; a text cell that starts like a formula (= + - @, tab, return)
// is prefixed with an apostrophe, so a product named "=1+1" stays text when the file is opened.

const formulaStart = /^[=+\-@\t\r]/;

/** A text cell: escaped, and kept from being read as a formula. */
export function textCell(value: string | null | undefined): string {
  if (value === null || value === undefined || value === "") return "";
  const safe = formulaStart.test(value) ? `'${value}` : value;
  return /[",\r\n]/.test(safe) ? `"${safe.replace(/"/g, '""')}"` : safe;
}

/** A number cell, written with a point and no thousands separator, as Excel and Numbers read it. */
export function numberCell(value: number | string | null | undefined): string {
  if (value === null || value === undefined || value === "") return "";
  const number = typeof value === "number" ? value : Number(value);
  return Number.isFinite(number) ? String(number) : "";
}

export interface Column<Row> {
  header: string;
  cell: (row: Row) => string;
}

/** The whole file: the byte order mark, the header row and one row per item. */
export function csv<Row>(columns: Column<Row>[], rows: Row[]): Uint8Array {
  const lines = [columns.map((column) => textCell(column.header)).join(",")];
  for (const row of rows) lines.push(columns.map((column) => column.cell(row)).join(","));
  return new TextEncoder().encode(`\uFEFF${lines.join("\r\n")}\r\n`);
}
