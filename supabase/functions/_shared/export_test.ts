// deno test supabase/functions (make functions-check): the export's files and email.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { exportEmail, exportFailedEmail } from "./export-email.ts";
import { exportFiles } from "./export-files.ts";

function lines(data: Uint8Array): string[] {
  return new TextDecoder().decode(data.slice(3)).split("\r\n");
}

Deno.test("the three files carry the ticket's columns in its order", () => {
  const files = exportFiles({
    products: [{
      name: 'Septocaine 4% "épi"',
      category: "Anesthetic",
      unit: "cartridges",
      pack_unit: "box",
      pack_size: 50,
      tracking: "Countable",
      minimum: 20,
      target: 100,
      supplier: "Patterson",
      location: "Op 1",
      quantity: 30,
      unopened: 30,
      open: 0,
      last_unit_cost: 1.8,
      status: "Healthy",
      archived: null,
    }],
    batches: [{ product: "Septocaine", expiry_month: "2027-03", lot: "S1", qty: 30 }],
    transactions: [{
      date: "2026-10-02 10:30",
      type: "Adjustment",
      product: "Septocaine",
      delta: -10,
      before: 40,
      after: 30,
      user: "Michael Reyes",
      reference: "Manual",
      reason: "Damaged",
      note: 'Dropped, "cracked"',
    }],
  });
  assertEquals(files.map((file) => file.name), ["products.csv", "batches.csv", "transactions.csv"]);
  const [products, batches, transactions] = files.map((file) => lines(file.data));
  assertEquals(
    products[0],
    "Name,Category,Unit,Pack unit,Pack size,Tracking,Minimum,Target,Supplier,Location,Quantity,Unopened,Open," +
      "Last unit cost,Status,Archived",
  );
  assertEquals(
    products[1],
    '"Septocaine 4% ""épi""",Anesthetic,cartridges,box,50,Countable,20,100,Patterson,Op 1,30,30,0,1.8,Healthy,',
  );
  assertEquals(batches, ["Product,Expiry month,Lot,Qty", "Septocaine,2027-03,S1,30", ""]);
  assertEquals(transactions[0], "Date,Type,Product,Delta,Before,After,User,Reference,Reason,Note");
  assertEquals(
    transactions[1],
    '2026-10-02 10:30,Adjustment,Septocaine,-10,40,30,Michael Reyes,Manual,Damaged,"Dropped, ""cracked"""',
  );
});

Deno.test("an empty clinic still gets its three headers", () => {
  const files = exportFiles({ products: [], batches: [], transactions: [] });
  assertEquals(files.map((file) => lines(file.data).length), [2, 2, 2]);
});

Deno.test("the email names the clinic, links the zip and says how long the link works", () => {
  const email = exportEmail({
    to: "sarah@dentory.test",
    clinicName: "Smile <Dental> & Co",
    day: "2026-10-20",
    link: "https://example.test/sign/exports/a.zip?token=x&download=dentory-export-2026-10-20.zip",
  });
  assertEquals(email.to, "sarah@dentory.test");
  assertEquals(email.subject, "Smile <Dental> & Co's data from Dentory");
  assertStringIncludes(email.text, "on 2026-10-20: products, batches and transactions, as 3 CSV files in one zip.");
  assertStringIncludes(email.text, "Download the export: https://example.test/sign/exports/a.zip?token=x&download=");
  assertStringIncludes(email.text, "The link works for 7 days.");
  assertStringIncludes(email.html, "Smile &lt;Dental&gt; &amp; Co&#39;s data");
  assertStringIncludes(email.html, 'href="https://example.test/sign/exports/a.zip?token=x&amp;download=');
  assert(!email.html.includes("<Dental>"));
});

Deno.test("an export that failed says so, with no link", () => {
  const email = exportFailedEmail({ to: "sarah@dentory.test", clinicName: "Smile <Dental>" });
  assertEquals(email.to, "sarah@dentory.test");
  assertEquals(email.subject, "Smile <Dental>'s export from Dentory didn't go through");
  assertStringIncludes(email.text, "Export again from Account in the app.");
  assertStringIncludes(email.html, "Smile &lt;Dental&gt;&#39;s export");
  assert(!email.html.includes("href"));
});
