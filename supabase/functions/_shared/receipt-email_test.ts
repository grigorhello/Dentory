// deno test supabase/functions (make functions-check): the receipt copy for the billing emails after the primary.
import { assert, assertEquals, assertStringIncludes } from "jsr:@std/assert@1";
import { receiptAmount, receiptCopyEmail, receiptDay } from "./receipt-email.ts";

const copy = {
  clinic_name: "Smile <Dental>",
  emails: ["books@smile.ca"],
  number: "DEN-0001",
  issued_at: "2027-01-06T14:00:00+00:00",
  amount_cents: 4950,
  currency: "usd",
  hosted_url: "https://invoice.stripe.com/i/acct_1?x=1&y=2",
  time_zone: "America/Toronto",
};

Deno.test("the amount in the invoice's currency and the day at the clinic", () => {
  assertEquals(receiptAmount(4950, "usd"), "$49.50");
  assertEquals(receiptAmount(9900, "usd"), "$99.00");
  assertEquals(receiptDay("2027-01-06T14:00:00+00:00", "America/Toronto"), "January 6, 2027");
  assertEquals(receiptDay("2027-01-07T02:00:00+00:00", "America/Toronto"), "January 6, 2027", "Still the 6th there");
});

Deno.test("the copy says who paid what, why it arrives, and links the invoice", () => {
  const email = receiptCopyEmail(copy, "books@smile.ca");
  assertEquals(email.to, "books@smile.ca");
  assertEquals(email.subject, "Receipt for Smile <Dental>'s Dentory subscription, January 6, 2027");
  assertStringIncludes(email.text, "Smile <Dental> paid $49.50 for its Dentory subscription on January 6, 2027");
  assertStringIncludes(email.text, "(invoice DEN-0001)");
  assertStringIncludes(email.text, "The invoice and the receipt: https://invoice.stripe.com/i/acct_1?x=1&y=2");
  assertStringIncludes(email.html, "Smile &lt;Dental&gt;");
  assertStringIncludes(email.html, 'href="https://invoice.stripe.com/i/acct_1?x=1&amp;y=2"');
});

Deno.test("without a hosted invoice the copy has no link", () => {
  const email = receiptCopyEmail({ ...copy, hosted_url: null, number: null }, "books@smile.ca");
  assertStringIncludes(email.text, "(the invoice)");
  assert(!email.text.includes("https://"));
  assert(!email.html.includes("href"));
});
