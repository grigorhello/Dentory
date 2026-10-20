// POST /functions/v1/billing_checkout { clinic_id } with the service role key (MS-140, MS-100 D18): Grigor at onboarding
// and the billing emails; the app opens no payment page. Answers { url }: Stripe Checkout in subscription mode for the
// clinic's customer (created the first time), the $99 monthly price, the 50% lifetime coupon for a clinic with the
// promotion, and the trial's end, so nothing is charged before the free months are over. A clinic that already has a
// live subscription, even one the webhook has not reported yet, is refused: its card changes on the Customer Portal
// (billing_portal), and a second Checkout would bill it twice.
import { errorResponse, HttpError, json } from "../_shared/http.ts";
import { billingRequest, customerFor } from "../_shared/billing.ts";
import {
  checkoutTrialEnd,
  liveSubscription,
  periodEnd,
  stripeRequest,
  type StripeSubscription,
} from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  try {
    const request = await billingRequest(req);
    const { clinicID, config, db, account } = request;
    if (account.stripe_subscription_id) {
      throw new HttpError(409, "conflict", "This clinic already has a subscription. Send the billing_portal link.");
    }
    if (account.promo_lifetime_50 && !config.promoCouponID) {
      throw new HttpError(503, "billing_unavailable", "Billing isn't set up yet. Try again later.");
    }
    const customerID = await customerFor(request);
    const existing = await stripeRequest<{ data: StripeSubscription[] }>(config, "GET", "/v1/subscriptions", {
      customer: customerID,
      status: "all",
      limit: 10,
    });
    const live = liveSubscription(existing.data);
    if (live) {
      // Paid before the webhook landed: link it now, as the webhook will.
      const { error } = await db.rpc("billing_apply_subscription", {
        p_customer_id: customerID,
        p_subscription_id: live.id,
        p_status: live.status,
        p_period_end: periodEnd(live),
        p_clinic_id: clinicID,
      });
      if (error) throw new Error(`billing_apply_subscription: ${error.message}`);
      throw new HttpError(409, "conflict", "This clinic already has a subscription. Send the billing_portal link.");
    }
    const session = await stripeRequest<{ url: string }>(config, "POST", "/v1/checkout/sessions", {
      mode: "subscription",
      customer: customerID,
      client_reference_id: clinicID,
      "line_items[0][price]": config.priceID,
      "line_items[0][quantity]": 1,
      "discounts[0][coupon]": account.promo_lifetime_50 ? config.promoCouponID ?? undefined : undefined,
      "subscription_data[trial_end]": checkoutTrialEnd(account.trial_ends_at),
      "subscription_data[metadata][clinic_id]": clinicID,
      success_url: `${config.returnURL}?checkout=done`,
      cancel_url: `${config.returnURL}?checkout=canceled`,
    });
    return json({ url: session.url });
  } catch (error) {
    return errorResponse(error);
  }
});
