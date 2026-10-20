// Supabase clients for the functions: the service client for the token RPCs (they are granted to
// service_role only) and the caller's identity from the Authorization header the app sends.
import { createClient, type SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { HttpError, sameText } from "./http.ts";

function env(name: string): string {
  const value = Deno.env.get(name);
  if (!value) throw new Error(`${name} is not set`);
  return value;
}

/** Bypasses RLS; use it only for the RPCs that check the caller themselves. */
export function serviceClient(): SupabaseClient {
  return createClient(env("SUPABASE_URL"), env("SUPABASE_SERVICE_ROLE_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
}

/** For the calls only Dentory makes (the cron job, Grigor's billing links): the bearer must be the service role key. */
export function requireServiceRole(req: Request) {
  const expected = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY") ?? "";
  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice("Bearer ".length).trim() : "";
  if (!expected || !sameText(token, expected)) throw new HttpError(401, "unauthorized", "Not allowed.");
}

export interface Caller {
  id: string;
  email: string;
}

/** The signed-in user behind the request's bearer token, or a 401. */
export async function caller(req: Request): Promise<Caller> {
  const header = req.headers.get("Authorization") ?? "";
  const token = header.startsWith("Bearer ") ? header.slice("Bearer ".length).trim() : "";
  if (!token) throw new HttpError(401, "unauthorized", "Sign in first.");
  const anon = createClient(env("SUPABASE_URL"), env("SUPABASE_ANON_KEY"), {
    auth: { persistSession: false, autoRefreshToken: false },
  });
  const { data, error } = await anon.auth.getUser(token);
  if (error || !data.user) throw new HttpError(401, "unauthorized", "Sign in first.");
  return { id: data.user.id, email: data.user.email ?? "" };
}

interface PostgrestFailure {
  code?: string | null;
  message?: string | null;
}

/**
 * Maps a refused RPC to the HTTP error the app understands: 42501 is forbidden (or read-only when the
 * message says so), 22023 and 23505 carry a sentence for the user, the rest is a 500.
 */
export function rpcError(error: PostgrestFailure, field?: string): HttpError {
  const message = error.message ?? "";
  switch (error.code) {
    case "42501":
      return message.toLowerCase().includes("read-only")
        ? new HttpError(403, "read_only", message)
        : new HttpError(403, "forbidden", message);
    case "22023":
      return new HttpError(400, "validation", message, field);
    case "23505":
      return new HttpError(409, "conflict", message, field);
    default:
      console.error("rpc failed", error.code, message);
      return new HttpError(500, "unknown", "Couldn't save. Try again.");
  }
}
