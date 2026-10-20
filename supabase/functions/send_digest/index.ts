// POST /functions/v1/send_digest, called each hour by pg_cron (engine.digest_dispatch, MS-145) with the service role
// key. Claims the weekly digests that are due (digest_claim), emails each to its clinic's active admins through Resend,
// and records each as soon as it went out (digest_finish), so a run the runtime cuts short never sends one twice. A
// digest that reached at least one admin counts as sent; one that reached none stays claimed and is retried by a later
// hour of the same morning. Without RESEND_API_KEY (the local
// stack) each email is written to the function log instead (PRD §8).
//
// With `{ "clinic_id": "…" }` it sends that clinic's digest as it reads now to the clinic's admins, whatever the day
// and the switch, and records nothing: how to try the email on a hosted project (supabase/README.md).
import { errorResponse, HttpError, json } from "../_shared/http.ts";
import { requireServiceRole, serviceClient } from "../_shared/supabase.ts";
import { sendEmail } from "../_shared/email.ts";
import { type Digest, digestEmail, digestLink } from "../_shared/digest-email.ts";

/** Digests claimed at a time, and how long one call keeps claiming before leaving the rest to the next hour. */
const batchSize = 5;
const budgetMs = 90_000;
/** Resend accepts 2 requests a second by default. */
const pauseMs = 600;

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST.");
    requireServiceRole(req);
    const body = await req.json().catch(() => ({})) as { clinic_id?: unknown };
    const db = serviceClient();

    if (typeof body.clinic_id === "string") {
      const { data, error } = await db.rpc("digest_preview", { p_clinic_id: body.clinic_id });
      if (error) throw new Error(`digest_preview: ${error.message}`);
      if (!data) throw new HttpError(404, "not_found", "No clinic has this id.", "clinic_id");
      const emails = await send(data as Digest);
      return json({ ok: true, preview: true, emails });
    }

    const started = Date.now();
    let claimed = 0;
    let emails = 0;
    while (Date.now() - started < budgetMs) {
      const { data, error } = await db.rpc("digest_claim", { p_limit: batchSize });
      if (error) throw new Error(`digest_claim: ${error.message}`);
      const digests = (data ?? []) as Digest[];
      for (const digest of digests) {
        const reached = await send(digest);
        emails += reached;
        if (reached > 0 || digest.recipients.length === 0) {
          const finish = await db.rpc("digest_finish", { p_sent: [digest.id], p_recipients: [reached] });
          if (finish.error) throw new Error(`digest_finish: ${finish.error.message}`);
        }
      }
      claimed += digests.length;
      if (digests.length < batchSize) break;
    }
    return json({ ok: true, claimed, emails });
  } catch (error) {
    return errorResponse(error);
  }
});

/** Emails the digest to each of its admins; answers how many it reached. */
async function send(digest: Digest): Promise<number> {
  const link = digestLink(Deno.env.get("APP_LINK_BASE"));
  let reached = 0;
  for (const recipient of digest.recipients) {
    try {
      const delivery = await sendEmail(digestEmail(digest, recipient.email, link));
      reached += 1;
      if (delivery === "sent") await new Promise((resolve) => setTimeout(resolve, pauseMs));
    } catch (error) {
      console.error(JSON.stringify({ digest: digest.id ?? "preview", error: String(error) }));
    }
  }
  return reached;
}
