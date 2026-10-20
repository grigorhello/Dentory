// deno test supabase/functions (make functions-check): the weekly digest email (MS-145).
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { batchLine, daysText, type Digest, digestEmail, digestLink, digestSubject, quantity } from "./digest-email.ts";

const digest: Digest = {
  id: "00000000-0000-4000-8000-000000019901",
  clinic_name: "Smile Dental <Toronto>",
  week: "2026-10-19",
  window: 90,
  to_buy: 3,
  expiring: 7,
  soonest: [
    { name: "Alginate", qty: 2, unit: "bags", lot: null, expiry_month: "2026-08-01", days: -50 },
    { name: "Bonding agent", qty: 1, unit: "bottles", lot: "BA7", expiry_month: "2026-10-01", days: 12 },
    { name: "Composite A2", qty: 4, unit: "syringes", lot: "C1", expiry_month: "2026-11-01", days: 42 },
    { name: "Septocaine 4%", qty: 30, unit: "cartridges", lot: "S1", expiry_month: "2026-11-01", days: 42 },
    { name: "Gloves", qty: 2.5, unit: "boxes", lot: "", expiry_month: "2026-12-01", days: 72 },
  ],
  missing_expiry: 1,
  procedures: 14,
  recipients: [{ email: "sarah@dentory.test", name: "Sarah Mitchell" }],
};

Deno.test("the subject is the ticket's, numbers first", () => {
  assertEquals(digestSubject(digest), "This week at Smile Dental <Toronto>: 3 to buy, 7 expiring");
  assertEquals(
    digestSubject({ ...digest, clinic_name: "Smile\nDental", to_buy: 0, expiring: 0 }),
    "This week at Smile Dental: 0 to buy, 0 expiring",
    "a header carries no line break",
  );
});

Deno.test("the text says Home's counts, last week's procedures and the five soonest", () => {
  const email = digestEmail(digest, "sarah@dentory.test", "https://app.dentory.ca/open");
  assertEquals(email.to, "sarah@dentory.test");
  const lines = email.text.split("\n");
  assertEquals(lines.slice(0, 8), [
    "This week at Smile Dental <Toronto>",
    "Monday, October 19",
    "",
    "3 to buy",
    "7 expiring within 90 days",
    "1 missing expiry",
    "14 procedures last week (Oct 12 to Oct 18)",
    "",
  ]);
  assertEquals(lines.slice(8, 15), [
    "Expiring soon",
    "- Alginate: 2 bags · Aug 2026 · Expired",
    "- Bonding agent: 1 bottle · lot BA7 · Oct 2026 · 12 days",
    "- Composite A2: 4 syringes · lot C1 · Nov 2026 · 42 days",
    "- Septocaine 4%: 30 cartridges · lot S1 · Nov 2026 · 42 days",
    "- Gloves: 2.5 boxes · Dec 2026 · 72 days",
    "2 more on Expiring soon in the app.",
  ]);
  assertStringIncludes(email.text, "Open Dentory: https://app.dentory.ca/open");
  assertStringIncludes(email.text, "An admin can turn it off there.");
});

Deno.test("the HTML escapes the clinic's and products' names and has one button", () => {
  const email = digestEmail(
    { ...digest, soonest: [{ ...digest.soonest[0], name: 'Wipes "XL" & <b>' }] },
    "sarah@dentory.test",
    "https://app.dentory.ca/open",
  );
  assertStringIncludes(email.html, "This week at Smile Dental &lt;Toronto&gt;");
  assertStringIncludes(email.html, "Wipes &quot;XL&quot; &amp; &lt;b&gt;");
  assert(!email.html.includes("<b>"), "no markup from a name");
  assertEquals(email.html.match(/<a /g)?.length, 1, "one link, the button");
  assertStringIncludes(email.html, 'href="https://app.dentory.ca/open"');
  assertStringIncludes(email.html, ">Open Dentory</a>");
  assertStringIncludes(email.html, "background:#1a63d6", "the brand's blue button");
  assertStringIncludes(email.html, "background:#fffefb", "on the cream canvas");
  assertStringIncludes(email.html, "6 more on Expiring soon in the app.");
});

Deno.test("a quiet week: no expiring list, one procedure", () => {
  const email = digestEmail(
    { ...digest, expiring: 0, soonest: [], procedures: 1 },
    "sarah@dentory.test",
    "https://app.dentory.ca/open",
  );
  assert(!email.text.includes("Expiring soon\n"), "no list without batches");
  assert(!email.html.includes(">Expiring soon</td>"), "nor its heading");
  assertStringIncludes(email.text, "1 procedure last week");
  assertStringIncludes(email.text, "0 expiring within 90 days");
});

Deno.test("days and quantities read as the app's Expiring soon cards", () => {
  assertEquals([-1, 0, 1, 59].map(daysText), ["Expired", "Today", "1 day", "59 days"]);
  assertEquals(quantity(1, "boxes"), "1 box");
  assertEquals(quantity(1, "batteries"), "1 battery");
  assertEquals(quantity(1250, "gloves"), "1,250 gloves");
  assertEquals(quantity(0.25, "bottles"), "0.25 bottles");
  assertEquals(
    batchLine({ name: "x", qty: 1, unit: "bottles", lot: " ", expiry_month: "2027-01-01", days: 90 }),
    "1 bottle · Jan 2027",
    "a blank lot is left out",
  );
});

Deno.test("the button opens the app through the universal link, on the function's base when set", () => {
  assertEquals(digestLink(undefined), "https://app.dentory.ca/open");
  assertEquals(digestLink(""), "https://app.dentory.ca/open");
  assertEquals(digestLink("https://staging.dentory.ca/"), "https://staging.dentory.ca/open");
});
