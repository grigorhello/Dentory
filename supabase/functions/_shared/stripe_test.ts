// deno test supabase/functions (make functions-check): the Stripe pieces that need no network.
import { assert, assertEquals } from "jsr:@std/assert@1";
import {
  checkoutTrialEnd,
  formEncode,
  invoiceParams,
  liveSubscription,
  paidAt,
  paymentFailed,
  periodEnd,
  stripeID,
  verifyStripeSignature,
} from "./stripe.ts";

const secret = "whsec_test_secret";
const payload = JSON.stringify({ id: "evt_1", type: "invoice.paid" });

async function signature(body: string, timestamp: number, key = secret): Promise<string> {
  const cryptoKey = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(key),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", cryptoKey, new TextEncoder().encode(`${timestamp}.${body}`));
  return Array.from(new Uint8Array(mac), (byte) => byte.toString(16).padStart(2, "0")).join("");
}

Deno.test("a signature from the endpoint's secret is accepted", async () => {
  const now = 1_790_933_260;
  const header = `t=${now},v1=${await signature(payload, now)},v0=ignored`;
  assert(await verifyStripeSignature(payload, header, secret, now));
});

Deno.test("another secret, a changed body, an old event or no header is refused", async () => {
  const now = 1_790_933_260;
  const header = `t=${now},v1=${await signature(payload, now, "whsec_other")}`;
  assert(!(await verifyStripeSignature(payload, header, secret, now)));
  const good = `t=${now},v1=${await signature(payload, now)}`;
  assert(!(await verifyStripeSignature(payload + " ", good, secret, now)));
  assert(!(await verifyStripeSignature(payload, good, secret, now + 301)));
  assert(!(await verifyStripeSignature(payload, null, secret, now)));
  assert(!(await verifyStripeSignature(payload, good, "", now)));
});

Deno.test("Checkout gets the trial's end only when it is more than 48 hours away", () => {
  const now = Date.UTC(2026, 9, 2, 13, 41);
  assertEquals(checkoutTrialEnd("2027-01-06T13:41:00Z", now), Date.UTC(2027, 0, 6, 13, 41) / 1000);
  assertEquals(checkoutTrialEnd("2026-10-04T12:00:00Z", now), undefined);
  assertEquals(checkoutTrialEnd("not a date", now), undefined);
});

Deno.test("the next payment is read from the subscription or, in newer API versions, its item", () => {
  assertEquals(periodEnd({ id: "sub", customer: "cus", status: "active", current_period_end: 1_800_000_000 }),
    "2027-01-15T08:00:00.000Z");
  assertEquals(
    periodEnd({ id: "sub", customer: "cus", status: "active", items: { data: [{ current_period_end: 1_800_000_000 }] } }),
    "2027-01-15T08:00:00.000Z",
  );
  assertEquals(periodEnd({ id: "sub", customer: "cus", status: "canceled" }), null);
});

Deno.test("an invoice keeps its number, total, currency, status and links", () => {
  assertEquals(
    invoiceParams({
      id: "in_1",
      customer: { id: "cus_1" },
      number: "DENT-0001",
      created: 1_800_000_000,
      total: 4950,
      currency: "usd",
      status: "paid",
      hosted_invoice_url: "https://invoice.stripe.com/i/1",
      invoice_pdf: "https://pay.stripe.com/invoice/1/pdf",
    }),
    {
      p_customer_id: "cus_1",
      p_stripe_invoice_id: "in_1",
      p_number: "DENT-0001",
      p_issued_at: "2027-01-15T08:00:00.000Z",
      p_amount_cents: 4950,
      p_currency: "usd",
      p_status: "paid",
      p_hosted_url: "https://invoice.stripe.com/i/1",
      p_pdf_url: "https://pay.stripe.com/invoice/1/pdf",
    },
  );
});

Deno.test("Stripe ids come as text or expanded objects; form keys keep their brackets", () => {
  assertEquals(stripeID("pm_1"), "pm_1");
  assertEquals(stripeID({ id: "pm_2", type: "card" }), "pm_2");
  assertEquals(stripeID(null), null);
  assertEquals(
    formEncode({ "line_items[0][price]": "price_1", "line_items[0][quantity]": 1, skipped: undefined }),
    "line_items%5B0%5D%5Bprice%5D=price_1&line_items%5B0%5D%5Bquantity%5D=1",
  );
});

Deno.test("a live subscription stops a second Checkout; an ended one does not", () => {
  const ended = { id: "sub_old", customer: "cus", status: "canceled" };
  const trialing = { id: "sub_new", customer: "cus", status: "trialing" };
  assertEquals(liveSubscription([ended, trialing])?.id, "sub_new");
  assertEquals(liveSubscription([ended, { id: "sub_x", customer: "cus", status: "incomplete_expired" }]), undefined);
  assertEquals(liveSubscription([]), undefined);
});

Deno.test("an open invoice Stripe tried to charge is a failed payment; a paid one never is", () => {
  const invoice = { id: "in_1", customer: "cus_1", created: 1_799_244_000, currency: "usd" };
  assert(paymentFailed({ ...invoice, status: "open", attempted: true }, "invoice.finalized"));
  assert(paymentFailed({ ...invoice, status: "open", attempted: false }, "invoice.payment_failed"));
  assert(!paymentFailed({ ...invoice, status: "open", attempted: false }, "invoice.finalized"), "Not tried yet");
  assert(!paymentFailed({ ...invoice, status: "paid", attempted: true }, "invoice.payment_failed"), "Paid since");
});

Deno.test("the day an invoice was paid comes from its status transitions", () => {
  const invoice = { id: "in_1", customer: "cus_1", created: 1_799_244_000, currency: "usd", status: "paid" };
  assertEquals(paidAt({ ...invoice, status_transitions: { paid_at: 1_799_503_200 } }), "2027-01-09T14:00:00.000Z");
  assertEquals(paidAt(invoice), null);
});
