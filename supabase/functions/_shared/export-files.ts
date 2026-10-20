// The export's three files (MS-143, PRD §6.9 Export CSV), from the rows export_data answers: the ticket's columns in
// its order, the dates as the database wrote them (ISO 8601, at the clinic's time).
import { type Column, csv, numberCell, textCell } from "./csv.ts";
import type { ZipEntry } from "./zip.ts";

export interface ProductRow {
  name: string;
  category: string | null;
  unit: string;
  pack_unit: string | null;
  pack_size: number | null;
  tracking: string;
  minimum: number;
  target: number;
  supplier: string | null;
  location: string | null;
  quantity: number;
  unopened: number;
  open: number;
  last_unit_cost: number | null;
  status: string;
  archived: string | null;
}

export interface BatchRow {
  product: string;
  expiry_month: string | null;
  lot: string | null;
  qty: number;
}

export interface TransactionRow {
  date: string;
  type: string;
  product: string;
  delta: number;
  before: number;
  after: number;
  user: string;
  reference: string | null;
  reason: string | null;
  note: string | null;
}

const productColumns: Column<ProductRow>[] = [
  { header: "Name", cell: (row) => textCell(row.name) },
  { header: "Category", cell: (row) => textCell(row.category) },
  { header: "Unit", cell: (row) => textCell(row.unit) },
  { header: "Pack unit", cell: (row) => textCell(row.pack_unit) },
  { header: "Pack size", cell: (row) => numberCell(row.pack_size) },
  { header: "Tracking", cell: (row) => textCell(row.tracking) },
  { header: "Minimum", cell: (row) => numberCell(row.minimum) },
  { header: "Target", cell: (row) => numberCell(row.target) },
  { header: "Supplier", cell: (row) => textCell(row.supplier) },
  { header: "Location", cell: (row) => textCell(row.location) },
  { header: "Quantity", cell: (row) => numberCell(row.quantity) },
  { header: "Unopened", cell: (row) => numberCell(row.unopened) },
  { header: "Open", cell: (row) => numberCell(row.open) },
  { header: "Last unit cost", cell: (row) => numberCell(row.last_unit_cost) },
  { header: "Status", cell: (row) => textCell(row.status) },
  { header: "Archived", cell: (row) => textCell(row.archived) },
];

const batchColumns: Column<BatchRow>[] = [
  { header: "Product", cell: (row) => textCell(row.product) },
  { header: "Expiry month", cell: (row) => textCell(row.expiry_month) },
  { header: "Lot", cell: (row) => textCell(row.lot) },
  { header: "Qty", cell: (row) => numberCell(row.qty) },
];

const transactionColumns: Column<TransactionRow>[] = [
  { header: "Date", cell: (row) => textCell(row.date) },
  { header: "Type", cell: (row) => textCell(row.type) },
  { header: "Product", cell: (row) => textCell(row.product) },
  { header: "Delta", cell: (row) => numberCell(row.delta) },
  { header: "Before", cell: (row) => numberCell(row.before) },
  { header: "After", cell: (row) => numberCell(row.after) },
  { header: "User", cell: (row) => textCell(row.user) },
  { header: "Reference", cell: (row) => textCell(row.reference) },
  { header: "Reason", cell: (row) => textCell(row.reason) },
  { header: "Note", cell: (row) => textCell(row.note) },
];

export interface ExportData {
  products: ProductRow[];
  batches: BatchRow[];
  transactions: TransactionRow[];
}

/** products.csv, batches.csv and transactions.csv, for the zip. */
export function exportFiles(data: ExportData): ZipEntry[] {
  return [
    { name: "products.csv", data: csv(productColumns, data.products) },
    { name: "batches.csv", data: csv(batchColumns, data.batches) },
    { name: "transactions.csv", data: csv(transactionColumns, data.transactions) },
  ];
}
