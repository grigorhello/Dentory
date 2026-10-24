// Apple Push Notification service with a token-based key (MS-144): no third-party push service. The .p8 key, its id
// and the Apple team id are Supabase secrets (APNS_KEY, APNS_KEY_ID, APNS_TEAM_ID); APNS_ENVIRONMENT=production sends
// to App Store and TestFlight builds, anything else to development builds. Without the key, apnsConfig() is null and
// send_push logs each push instead, as the local stack logs emails.

export interface ApnsConfig {
  key: CryptoKey;
  keyID: string;
  teamID: string;
  topic: string;
  host: string;
}

/** What APNs said about one device: delivered, a token it no longer knows, or a failure worth retrying. */
export type DeviceResult = "sent" | "dead" | "retry";

export interface PushMessage {
  title: string;
  body: string;
  link: string;
}

/** Where the function's instances share their provider token: `push_provider_token` and `push_provider_token_save`. */
export interface ProviderTokenStore {
  /** The shared token while it is younger than 50 minutes, else null. */
  load(keyID: string): Promise<string | null>;
  /** Keeps a newly signed token unless another instance kept one first; answers the token to use. */
  save(keyID: string, token: string): Promise<string>;
}

export async function apnsConfig(): Promise<ApnsConfig | null> {
  const pem = Deno.env.get("APNS_KEY");
  const keyID = Deno.env.get("APNS_KEY_ID");
  const teamID = Deno.env.get("APNS_TEAM_ID");
  if (!pem || !keyID || !teamID) return null;
  return {
    key: await importSigningKey(pem),
    keyID,
    teamID,
    topic: Deno.env.get("APNS_TOPIC") || "ca.dentory.app",
    host: Deno.env.get("APNS_ENVIRONMENT") === "production" ? "api.push.apple.com" : "api.sandbox.push.apple.com",
  };
}

/** The notification as the app reads it: the alert's sentence under the clinic's name, and the link it opens. */
export function payload(message: PushMessage): Record<string, unknown> {
  return {
    aps: { alert: { title: message.title, body: message.body }, sound: "default" },
    link: message.link,
  };
}

export async function sendToDevice(
  config: ApnsConfig,
  bearer: string,
  token: string,
  message: PushMessage,
): Promise<DeviceResult> {
  const response = await fetch(`https://${config.host}/3/device/${token}`, {
    method: "POST",
    headers: {
      "authorization": `bearer ${bearer}`,
      "apns-topic": config.topic,
      "apns-push-type": "alert",
      "apns-priority": "10",
      "content-type": "application/json",
    },
    body: JSON.stringify(payload(message)),
  });
  if (response.ok) return "sent";
  const reason = await response.json().then((body) => String(body?.reason ?? "")).catch(() => "");
  if (response.status === 410 || ["BadDeviceToken", "Unregistered", "DeviceTokenNotForTopic"].includes(reason)) {
    return "dead";
  }
  console.error(`APNs ${response.status} ${reason}`);
  return "retry";
}

// APNs accepts a provider token for up to an hour and refuses one renewed more often than every 20 minutes, which
// counts every instance of this function: they share one token through the database, each also keeping it in memory,
// and a new one is signed only when the shared one is 50 minutes old.
let cached: { token: string; issuedAt: number; keyID: string } | null = null;

export async function providerToken(config: ApnsConfig, store: ProviderTokenStore): Promise<string> {
  const now = Math.floor(Date.now() / 1000);
  if (cached && cached.keyID === config.keyID && now - cached.issuedAt < 50 * 60) return cached.token;
  const token = (await store.load(config.keyID)) ??
    (await store.save(config.keyID, await signProviderToken(config, now)));
  cached = { token, issuedAt: issuedAt(token) ?? now, keyID: config.keyID };
  return token;
}

async function signProviderToken(config: ApnsConfig, now: number): Promise<string> {
  const header = base64url(JSON.stringify({ alg: "ES256", kid: config.keyID }));
  const claims = base64url(JSON.stringify({ iss: config.teamID, iat: now }));
  const signature = await crypto.subtle.sign(
    { name: "ECDSA", hash: "SHA-256" },
    config.key,
    new TextEncoder().encode(`${header}.${claims}`),
  );
  return `${header}.${claims}.${base64url(new Uint8Array(signature))}`;
}

/** The `iat` of a provider token, so one kept by another instance expires on time here too. */
function issuedAt(token: string): number | null {
  try {
    const claims = token.split(".")[1].replace(/-/g, "+").replace(/_/g, "/");
    const iat = JSON.parse(atob(claims.padEnd(Math.ceil(claims.length / 4) * 4, "="))).iat;
    return typeof iat === "number" ? iat : null;
  } catch {
    return null;
  }
}

/** The .p8 file's PKCS #8 key; the secret may keep its header lines and line breaks or not. */
async function importSigningKey(pem: string): Promise<CryptoKey> {
  const base64 = pem.replace(/-----[^-]+-----/g, "").replace(/\s+/g, "");
  const der = Uint8Array.from(atob(base64), (character) => character.charCodeAt(0));
  return await crypto.subtle.importKey("pkcs8", der, { name: "ECDSA", namedCurve: "P-256" }, false, ["sign"]);
}

function base64url(value: string | Uint8Array): string {
  const bytes = typeof value === "string" ? new TextEncoder().encode(value) : value;
  let binary = "";
  for (const byte of bytes) binary += String.fromCharCode(byte);
  return btoa(binary).replace(/\+/g, "-").replace(/\//g, "_").replace(/=+$/, "");
}
