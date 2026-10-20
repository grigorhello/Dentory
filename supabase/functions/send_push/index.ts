// POST /functions/v1/send_push, called each minute by pg_cron (engine.push_dispatch, MS-144) with the service role key.
// Claims the pushes that are due (push_claim), sends each to its members' devices through APNs, then records what went
// out and the device tokens APNs no longer knows (push_finish). A push that reached no device because APNs failed is
// left claimed and retried later; one that reached at least one device counts as sent. Without the APNs secrets (the
// local stack) each push is logged instead of sent (PRD §8).
import { errorResponse, HttpError, json } from "../_shared/http.ts";
import { serviceClient } from "../_shared/supabase.ts";
import {
  apnsConfig,
  type ApnsConfig,
  providerToken,
  type ProviderTokenStore,
  type PushMessage,
  sendToDevice,
} from "../_shared/apns.ts";

interface DuePush extends PushMessage {
  outbox_id: string;
  tokens: string[] | null;
}

Deno.serve(async (req) => {
  try {
    if (req.method !== "POST") throw new HttpError(405, "method_not_allowed", "Use POST.");
    requireServiceRole(req);

    const db = serviceClient();
    const { data, error } = await db.rpc("push_claim", { p_limit: 50 });
    if (error) throw new Error(`push_claim: ${error.message}`);
    const due = (data ?? []) as DuePush[];
    const config = await apnsConfig();
    const bearer = config && due.length > 0 ? await providerToken(config, tokenStore(db)) : "";

    const sent: string[] = [];
    const dead: string[] = [];
    let delivered = 0;
    for (const push of due) {
      const tokens = push.tokens ?? [];
      if (!config) {
        console.log(JSON.stringify({ push: push.outbox_id, title: push.title, body: push.body, link: push.link,
          devices: tokens.length }));
        sent.push(push.outbox_id);
        continue;
      }
      const results = await send(config, bearer, push, tokens);
      delivered += results.filter((result) => result === "sent").length;
      tokens.forEach((token, index) => {
        if (results[index] === "dead") dead.push(token);
      });
      if (results.length === 0 || results.some((result) => result !== "retry")) sent.push(push.outbox_id);
    }

    const finish = await db.rpc("push_finish", { p_sent: sent, p_dead_tokens: dead });
    if (finish.error) throw new Error(`push_finish: ${finish.error.message}`);
    return json({ ok: true, claimed: due.length, sent: sent.length, delivered, dead: dead.length, logged: !config });
  } catch (error) {
    return errorResponse(error);
  }
});

/** Only the database's cron job may send: the bearer must be this project's service role key. */
function requireServiceRole(req: Request) {
  const expected = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice("Bearer ".length).trim() : "";
  if (!expected || !sameText(token, expected)) throw new HttpError(401, "unauthorized", "Not allowed.");
}

function sameText(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let index = 0; index < a.length; index++) difference |= a.charCodeAt(index) ^ b.charCodeAt(index);
  return difference === 0;
}

/** The provider token every instance of this function shares, kept in the database. */
function tokenStore(db: ReturnType<typeof serviceClient>): ProviderTokenStore {
  return {
    async load(keyID) {
      const { data, error } = await db.rpc("push_provider_token", { p_key_id: keyID });
      if (error) throw new Error(`push_provider_token: ${error.message}`);
      return (data as string | null) ?? null;
    },
    async save(keyID, token) {
      const { data, error } = await db.rpc("push_provider_token_save", { p_key_id: keyID, p_token: token });
      if (error) throw new Error(`push_provider_token_save: ${error.message}`);
      return (data as string | null) ?? token;
    },
  };
}

async function send(config: ApnsConfig, bearer: string, push: DuePush, tokens: string[]) {
  const message: PushMessage = { title: push.title, body: push.body, link: push.link };
  const results = [];
  for (const token of tokens) {
    try {
      results.push(await sendToDevice(config, bearer, token, message));
    } catch (error) {
      console.error(error);
      results.push("retry" as const);
    }
  }
  return results;
}
