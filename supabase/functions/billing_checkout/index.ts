// POST /functions/v1/billing_checkout { clinic_id } as a signed-in admin (MS-140, MS-100 D11). Answers { url }: Stripe
// Checkout in subscription mode for the clinic's customer (created the first time), the $99 monthly price, the 50%
// lifetime coupon for a clinic with the promotion, and the trial's end, so nothing is charged before the free months
// are over. A clinic that already has a subscription changes its card on the Customer Portal (billing_portal).
import { errorResponse, HttpError, json } from "../_shared/http.ts";
import { billingRequest, customerFor } from "../_shared/billing.ts";
import { checkoutTrialEnd, stripeRequest } from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  try {
    const request = await billingRequest(req);
    const { clinicID, config, account } = request;
    if (account.stripe_subscription_id) {
      throw new HttpError(409, "conflict", "This clinic already has a subscription. Change its card instead.");
    }
    if (account.promo_lifetime_50 && !config.promoCouponID) {
      throw new HttpError(503, "billing_unavailable", "Billing isn't set up yet. Try again later.");
    }
    const customerID = await customerFor(request);
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
