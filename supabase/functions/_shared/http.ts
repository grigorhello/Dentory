// Request parsing and the one JSON error shape every Dentory function answers with:
// { "error": { "code": "…", "message": "…", "field": "email" | undefined } }.
// The app maps the status and the field to AppError (Core/Data/AppError+Functions.swift).

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

export function errorResponse(error: unknown): Response {
  if (error instanceof HttpError) {
    return json(
      { error: { code: error.code, message: error.message, field: error.field } },
      error.status,
    );
  }
  console.error(error);
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

const uuidPattern = /^[0-9a-f]{8}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{4}-[0-9a-f]{12}$/i;

export function isUUID(value: string): boolean {
  return uuidPattern.test(value);
}

/** The same shape check as the database: one @, a dot in the domain, no spaces. */
export function looksLikeEmail(value: string): boolean {
  return /^[^@\s]+@[^@\s]+\.[^@\s]+$/.test(value);
}
