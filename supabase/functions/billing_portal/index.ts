// POST /functions/v1/billing_portal { clinic_id } as a signed-in admin (MS-140, MS-100 D11). Answers { url }: the Stripe
// Customer Portal of the clinic's customer, where the admin changes the card. A clinic with no subscription yet adds
// one through Checkout instead (billing_checkout).
import { errorResponse, HttpError, json } from "../_shared/http.ts";
import { billingRequest } from "../_shared/billing.ts";
import { stripeRequest } from "../_shared/stripe.ts";

Deno.serve(async (req) => {
  try {
    const { config, account } = await billingRequest(req);
    if (!account.stripe_customer_id || !account.stripe_subscription_id) {
      throw new HttpError(409, "conflict", "Add a payment method first.");
    }
    const session = await stripeRequest<{ url: string }>(config, "POST", "/v1/billing_portal/sessions", {
      customer: account.stripe_customer_id,
      return_url: `${config.returnURL}?portal=done`,
    });
    return json({ url: session.url });
  } catch (error) {
    return errorResponse(error);
  }
});
