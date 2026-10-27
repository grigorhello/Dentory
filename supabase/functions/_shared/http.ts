// Request parsing and the one JSON error shape every Dentory function answers with:
// { "error": { "code": "…", "message": "…", "field": "email" | undefined } }.
// The app maps the status and the field to AppError (Core/Data/AppError+Functions.swift).
import { reportLater } from "./sentry.ts";

export class HttpError extends Error {
  constructor(
    readonly status: number,
    readonly code: string,
    message: string,
    readonly field?: string,
  ) {
    super(message);
  }
}

export function json(body: unknown, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: { "Content-Type": "application/json" },
  });
}

/** The answer for `error`; a 500, the function's own or an unexpected one, also goes to Sentry (`_shared/sentry.ts`). */
export function errorResponse(error: unknown, fn: string): Response {
  if (error instanceof HttpError) {
    if (error.status >= 500) reportLater({ fn, kind: error.code, error });
    return json(
      { error: { code: error.code, message: error.message, field: error.field } },
      error.status,
    );
  }
  console.error(error);
  reportLater({ fn, kind: "unexpected", error });
  return json({ error: { code: "unknown", message: "Couldn't save. Try again." } }, 500);
}

/** The JSON object of a POST body; anything else is a 400. */
export async function readJSON(req: Request): Promise<Record<string, unknown>> {
  if (req.method !== "POST") {
    throw new HttpError(405, "method_not_allowed", "Use POST.");
  }
  let body: unknown;
  try {
    body = await req.json();
  } catch {
    throw new HttpError(400, "invalid_body", "The request body must be JSON.");
  }
  if (typeof body !== "object" || body === null || Array.isArray(body)) {
    throw new HttpError(400, "invalid_body", "The request body must be a JSON object.");
  }
  return body as Record<string, unknown>;
}

/** A string field, trimmed; "" when absent. */
export function text(body: Record<string, unknown>, key: string): string {
  const value = body[key];
  return typeof value === "string" ? value.trim() : "";
}

/** Compares in constant time, so the answer's timing says nothing about a key or a signature. */
export function sameText(a: string, b: string): boolean {
  if (a.length !== b.length) return false;
  let difference = 0;
  for (let index = 0; index < a.length; index++) difference |= a.charCodeAt(index) ^ b.charCodeAt(index);
  return difference === 0;
}

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isUUID(value: string): boolean {
  return uuidPattern.test(value);
}

/** The same shape check as the database: one @, a dot in the domain, no spaces. */
export function looksLikeEmail(value: string): boolean {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value);
}
