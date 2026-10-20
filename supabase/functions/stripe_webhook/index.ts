// POST /functions/v1/stripe_webhook, called by Stripe (MS-140). verify_jwt is off for it: the Stripe-Signature header,
// signed with STRIPE_WEBHOOK_SECRET, is the check. Subscription events set the clinic's status, next payment and card
// from the subscription as Stripe holds it now, so events arriving out of order do no harm; invoice events keep the
// invoices; Checkout completed links a new subscription to the clinic it was opened for. Other events are acknowledged.
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { errorResponse, HttpError, json } from "../_shared/http.ts";
import { serviceClient } from "../_shared/supabase.ts";
import {
  invoiceParams,
  periodEnd,
  type StripeConfig,
  stripeConfig,
  stripeID,
  type StripeInvoice,
  stripeRequest,
  type StripeSubscription,
  verifyStripeSignature,
} from "../_shared/stripe.ts";

interface StripeEvent {
  id: string;
  type: string;
  data: { object: Record<string, unknown> };
}

interface PaymentMethod {
  type: string;
  card?: { brand?: string; last4?: string } | null;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST.");
    const payload = await req.text();
    const secret = Deno.env.get("STRIPE_WEBHOOK_SECRET") ?? "";
    if (!(await verifyStripeSignature(payload, req.headers.get("Stripe-Signature"), secret))) {
      throw new HttpError(400, "invalid_signature", "Not a Stripe event.");
    }
    const event = JSON.parse(payload) as StripeEvent;
    await handle(event, stripeConfig(), serviceClient());
    return json({ received: true });
  } catch (error) {
    return errorResponse(error);
  }
});

async function handle(event: StripeEvent, config: StripeConfig, db: SupabaseClient) {
  const object = event.data.object;
  switch (event.type) {
    case "checkout.session.completed": {
      const subscriptionID = stripeID(object.subscription);
      const clinicID = typeof object.client_reference_id === "string" ? object.client_reference_id : null;
      if (subscriptionID) await applySubscription(config, db, subscriptionID, clinicID);
      return;
    }
    case "customer.subscription.created":
    case "customer.subscription.updated":
    case "customer.subscription.deleted":
    case "customer.subscription.paused":
    case "customer.subscription.resumed": {
      const metadata = object.metadata as Record<string, string> | undefined;
      await applySubscription(config, db, String(object.id), metadata?.clinic_id ?? null);
      return;
    }
    case "customer.updated": {
      const settings = object.invoice_settings as { default_payment_method?: unknown } | undefined;
      const methodID = stripeID(settings?.default_payment_method);
      if (methodID) await applyCard(config, db, String(object.id), methodID);
      return;
    }
    case "invoice.finalized":
    case "invoice.paid":
    case "invoice.payment_failed":
    case "invoice.voided":
    case "invoice.marked_uncollectible":
      await rpc(db, "billing_record_invoice", invoiceParams(object as unknown as StripeInvoice));
      return;
  }
}

/** The subscription as Stripe holds it now: its status and next payment, then the card it charges. */
async function applySubscription(config: StripeConfig, db: SupabaseClient, id: string, clinicID: string | null) {
  const subscription = await stripeRequest<StripeSubscription>(config, "GET", `/v1/subscriptions/${id}`);
  const customerID = stripeID(subscription.customer) ?? "";
  await rpc(db, "billing_apply_subscription", {
    p_customer_id: customerID,
    p_subscription_id: subscription.id,
    p_status: subscription.status,
    p_period_end: periodEnd(subscription),
    p_clinic_id: clinicID ?? subscription.metadata?.clinic_id ?? null,
  });
  const methodID = stripeID(subscription.default_payment_method);
  if (methodID && subscription.status !== "canceled") await applyCard(config, db, customerID, methodID);
}

/** The brand and last four digits of the payment method, or its type when it is not a card (Link). */
async function applyCard(config: StripeConfig, db: SupabaseClient, customerID: string, methodID: string) {
  const method = await stripeRequest<PaymentMethod>(config, "GET", `/v1/payment_methods/${methodID}`);
  await rpc(db, "billing_apply_card", {
    p_customer_id: customerID,
    p_brand: method.card?.brand ?? method.type,
    p_last4: method.card?.last4 ?? null,
  });
}

async function rpc(db: SupabaseClient, name: string, params: Record<string, unknown>) {
  const { error } = await db.rpc(name, params);
  if (error) throw new Error(`${name}: ${error.message}`);
}
