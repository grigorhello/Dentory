// Stripe for billing (MS-140, MS-100 D11): the REST API over fetch, no SDK, and the webhook signature check. The keys are
// Supabase secrets: STRIPE_SECRET_KEY (a test key on staging), STRIPE_PRICE_ID (the $99 monthly price, USD),
// STRIPE_PROMO_COUPON_ID (50% off forever, for clinics with promo_lifetime_50) and STRIPE_WEBHOOK_SECRET (the
// signing secret of the stripe_webhook endpoint). Without the secret key the billing functions refuse with
// "billing_unavailable", as the local stack has none.
import { HttpError, sameText } from "./http.ts";

export interface StripeConfig {
  secretKey: string;
  priceID: string;
  promoCouponID: string | null;
  /** Where Checkout and the Customer Portal send the admin back: a page saying to tap Done (`applinks/billing`). */
  returnURL: string;
}

export function stripeConfig(): StripeConfig {
  const secretKey = Deno.env.get("STRIPE_SECRET_KEY");
  const priceID = Deno.env.get("STRIPE_PRICE_ID");
  if (!secretKey || !priceID) {
    throw new HttpError(503, "billing_unavailable", "Billing isn't set up yet. Try again later.");
  }
  return {
    secretKey,
    priceID,
    promoCouponID: Deno.env.get("STRIPE_PROMO_COUPON_ID") || null,
    returnURL: Deno.env.get("BILLING_RETURN_URL") || "https://app.dentory.ca/billing/done",
  };
}

/** Stripe's form encoding: nested keys in brackets, as `line_items[0][price]`. */
export function formEncode(params: Record<string, string | number | undefined>): string {
  const body = new URLSearchParams();
  for (const [key, value] of Object.entries(params)) {
    if (value !== undefined) body.append(key, String(value));
  }
  return body.toString();
}

export async function stripeRequest<T>(
  config: StripeConfig,
  method: "GET" | "POST",
  path: string,
  params: Record<string, string | number | undefined> = {},
  idempotencyKey?: string,
): Promise<T> {
  const query = method === "GET" ? formEncode(params) : "";
  const headers: Record<string, string> = { authorization: `Bearer ${config.secretKey}` };
  if (method === "POST") headers["content-type"] = "application/x-www-form-urlencoded";
  if (idempotencyKey) headers["idempotency-key"] = idempotencyKey;
  const response = await fetch(`https://api.stripe.com${path}${query ? `?${query}` : ""}`, {
    method,
    headers,
    body: method === "POST" ? formEncode(params) : undefined,
  });
  const body = await response.json().catch(() => ({}));
  if (!response.ok) {
    console.error(`Stripe ${method} ${path}: ${response.status} ${body?.error?.type ?? ""} ${body?.error?.message ?? ""}`);
    throw new HttpError(502, "billing_failed", "Couldn't reach the payment service. Try again.");
  }
  return body as T;
}

/** The checks of Stripe's `Stripe-Signature` header: a v1 HMAC-SHA256 of `t.payload`, at most `tolerance` seconds old. */
export async function verifyStripeSignature(
  payload: string,
  header: string | null,
  secret: string,
  now = Math.floor(Date.now() / 1000),
  tolerance = 300,
): Promise<boolean> {
  if (!header || !secret) return false;
  const parts = header.split(",").map((part) => part.trim().split("="));
  const timestamp = Number(parts.find(([key]) => key === "t")?.[1]);
  const signatures = parts.filter(([key]) => key === "v1").map(([, value]) => value ?? "");
  if (!Number.isFinite(timestamp) || signatures.length === 0 || Math.abs(now - timestamp) > tolerance) return false;
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(secret),
    { name: "HMAC", hash: "SHA-256" },
    false,
    ["sign"],
  );
  const mac = await crypto.subtle.sign("HMAC", key, new TextEncoder().encode(`${timestamp}.${payload}`));
  const expected = Array.from(new Uint8Array(mac), (byte) => byte.toString(16).padStart(2, "0")).join("");
  return signatures.some((signature) => sameText(signature, expected));
}


/** The Unix second the trial ends for Checkout, or nothing when it is less than the 48 hours Stripe requires away. */
export function checkoutTrialEnd(trialEndsAt: string, now = Date.now()): number | undefined {
  const end = Math.floor(new Date(trialEndsAt).getTime() / 1000);
  if (!Number.isFinite(end)) return undefined;
  return end - Math.floor(now / 1000) > 48 * 60 * 60 + 60 ? end : undefined;
}

/** A Stripe id or an expanded object's id. */
export function stripeID(value: unknown): string | null {
  if (typeof value === "string") return value;
  if (value && typeof value === "object" && typeof (value as { id?: unknown }).id === "string") {
    return (value as { id: string }).id;
  }
  return null;
}

export interface StripeSubscription {
  id: string;
  customer: unknown;
  status: string;
  current_period_end?: number | null;
  items?: { data?: { current_period_end?: number | null }[] };
  default_payment_method?: unknown;
  metadata?: Record<string, string>;
}

/** A subscription that still bills or will: Checkout must not open a second one beside it. */
export function liveSubscription(subscriptions: StripeSubscription[]): StripeSubscription | undefined {
  const live = ["trialing", "active", "past_due", "unpaid", "incomplete", "paused"];
  return subscriptions.find((subscription) => live.includes(subscription.status));
}

/** The next payment: on the subscription in older API versions, on its item since 2025-03-31. */
export function periodEnd(subscription: StripeSubscription): string | null {
  const seconds = subscription.current_period_end ?? subscription.items?.data?.[0]?.current_period_end ?? null;
  return seconds ? new Date(seconds * 1000).toISOString() : null;
}

export interface StripeInvoice {
  id: string;
  customer: unknown;
  /** The address Stripe sent the invoice and its receipt to. */
  customer_email?: string | null;
  number?: string | null;
  created: number;
  total?: number | null;
  amount_due?: number | null;
  currency: string;
  status?: string | null;
  /** Stripe tried to charge it (an open invoice it tried is one whose charge failed). */
  attempted?: boolean | null;
  status_transitions?: { paid_at?: number | null } | null;
  hosted_invoice_url?: string | null;
  invoice_pdf?: string | null;
}

/** Still open after Stripe tried to charge it: the payment failed, and Invoices says Failed until it is paid. */
export function paymentFailed(invoice: StripeInvoice, eventType: string): boolean {
  return invoice.status === "open" && (invoice.attempted === true || eventType === "invoice.payment_failed");
}

/** When the invoice was paid, which is not when it was issued once Stripe had to retry or the card changed. */
export function paidAt(invoice: StripeInvoice): string | null {
  const seconds = invoice.status_transitions?.paid_at ?? null;
  return seconds ? new Date(seconds * 1000).toISOString() : null;
}

/** What billing_record_invoice keeps of an invoice. */
export function invoiceParams(invoice: StripeInvoice) {
  return {
    p_customer_id: stripeID(invoice.customer) ?? "",
    p_stripe_invoice_id: invoice.id,
    p_number: invoice.number ?? null,
    p_issued_at: new Date(invoice.created * 1000).toISOString(),
    p_amount_cents: invoice.total ?? invoice.amount_due ?? 0,
    p_currency: invoice.currency,
    p_status: invoice.status ?? "draft",
    p_hosted_url: invoice.hosted_invoice_url ?? null,
    p_pdf_url: invoice.invoice_pdf ?? null,
  };
}
