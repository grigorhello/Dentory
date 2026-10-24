// What billing_checkout and billing_portal share (MS-140, MS-100 D18): the request { clinic_id } with the service role
// key (Grigor at onboarding, the billing emails; the app never calls them), the Stripe configuration, and the clinic's
// billing account.
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { HttpError, isUUID, readJSON, text } from "./http.ts";
import { requireServiceRole, rpcError, serviceClient } from "./supabase.ts";
import { type StripeConfig, stripeConfig, stripeRequest } from "./stripe.ts";

export interface BillingAccount {
  clinic_name: string;
  stripe_customer_id: string | null;
  stripe_subscription_id: string | null;
  trial_ends_at: string;
  promo_lifetime_50: boolean;
  billing_email: string | null;
}

export interface BillingRequest {
  clinicID: string;
  config: StripeConfig;
  db: SupabaseClient;
  account: BillingAccount;
}

export async function billingRequest(req: Request): Promise<BillingRequest> {
  requireServiceRole(req);
  const body = await readJSON(req);
  const clinicID = text(body, "clinic_id");
  if (!isUUID(clinicID)) throw new HttpError(400, "validation", "A clinic is required.");
  const config = stripeConfig();
  const db = serviceClient();
  const { data, error } = await db.rpc("billing_account", { p_clinic_id: clinicID }).single<BillingAccount>();
  if (error) throw rpcError(error);
  return { clinicID, config, db, account: data };
}

/** The clinic's Stripe customer, created the first time with the clinic's name and billing email. */
export async function customerFor({ clinicID, config, db, account }: BillingRequest): Promise<string> {
  if (account.stripe_customer_id) return account.stripe_customer_id;
  const customer = await stripeRequest<{ id: string }>(config, "POST", "/v1/customers", {
    name: account.clinic_name,
    email: account.billing_email ?? undefined,
    "metadata[clinic_id]": clinicID,
  }, `customer-${clinicID}`);
  const { data, error } = await db.rpc("billing_set_customer", { p_clinic_id: clinicID, p_customer_id: customer.id });
  if (error) throw new Error(`billing_set_customer: ${error.message}`);
  return (data as string | null) ?? customer.id;
}
