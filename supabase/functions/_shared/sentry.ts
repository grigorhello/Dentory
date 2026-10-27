// Function errors in Sentry (MS-150, docs/runbooks/monitoring.md). With the SENTRY_DSN function secret set
// (`supabase secrets set SENTRY_DSN=…`), an unexpected error, or a time limit a function gave up at, goes to Sentry as
// one event, posted to the project's envelope endpoint with a plain fetch (no SDK); without the secret nothing is sent.
// An event names the function, a closed kind and the error's class with its stack frames, never the error's message,
// the request or anything a clinic sent: a message can quote an invoice, an email address or a database row. A
// function the platform stops at its own wall-clock limit cannot report itself; only Supabase's logs show that.

/** Supabase's runtime keeps the function alive for work handed to it after the answer. */
declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void } | undefined;

export interface Issue {
  /** The function, as deployed: `extract_invoice`. */
  fn: string;
  /** What happened, in a closed word: `unexpected`, `timeout`. */
  kind: string;
  /** The error behind it, if any: its class and stack frames are sent, never its message. */
  error?: unknown;
  /** Closed facts to filter by (a reason, a count, a code), never text a person wrote. */
  tags?: Record<string, string>;
}

export interface SentryTarget {
  dsn: string;
  /** https://<host>/api/<project>/envelope/ */
  url: string;
  publicKey: string;
}

export interface Frame {
  function: string;
  filename: string;
  lineno: number;
  colno: number;
}

export type Fetcher = (url: string, init: RequestInit) => Promise<Response>;

export interface ReportOptions {
  /** The DSN; the SENTRY_DSN secret when left out. */
  dsn?: string;
  /** The project's URL, whose first label names the Supabase project on the event; SUPABASE_URL when left out. */
  supabaseURL?: string;
  fetcher?: Fetcher;
  /** Gives up on Sentry after this long, so a report never holds a function up: 3 s. */
  timeoutMs?: number;
}

/** Where a DSN (`https://<key>@<host>/<project>`) sends its events; null for anything else, an empty secret too. */
export function sentryTarget(dsn: string | undefined): SentryTarget | null {
  if (!dsn || !URL.canParse(dsn)) return null;
  const url = new URL(dsn);
  const path = url.pathname.replace(/\/+$/, "");
  const slash = path.lastIndexOf("/");
  const project = path.slice(slash + 1);
  if (!["https:", "http:"].includes(url.protocol) || !url.username || !/^\d+$/.test(project)) return null;
  return {
    dsn,
    url: `${url.protocol}//${url.host}${path.slice(0, slash)}/api/${project}/envelope/`,
    publicKey: url.username,
  };
}

/** The frames of a V8 stack, oldest call first as Sentry lists them; the lines with the message are left out. */
export function stackFrames(error: unknown): Frame[] {
  if (!(error instanceof Error) || typeof error.stack !== "string") return [];
  const frames = error.stack.split("\n").flatMap((line) => {
    const match = /^\s+at (?:(.+?) \()?(\S+?):(\d+):(\d+)\)?$/.exec(line);
    if (!match) return [];
    const [, fn, filename, lineno, colno] = match;
    return [{ function: fn ?? "<anonymous>", filename, lineno: Number(lineno), colno: Number(colno) }];
  });
  return frames.reverse();
}

/** The envelope holding one event for `issue` (develop.sentry.dev/sdk/envelopes). */
export function envelope(
  target: SentryTarget,
  issue: Issue,
  context: { eventID: string; now: Date; project?: string },
): string {
  const error = issue.error;
  const status = (error as { status?: unknown } | undefined)?.status;
  const tags: Record<string, string> = {
    ...issue.tags,
    ...(typeof status === "number" ? { status: String(status) } : {}),
    ...(context.project ? { project: context.project } : {}),
    function: issue.fn,
    kind: issue.kind,
  };
  const frames = stackFrames(error);
  const event = {
    event_id: context.eventID,
    timestamp: context.now.getTime() / 1000,
    platform: "javascript",
    level: "error",
    logger: issue.fn,
    transaction: issue.fn,
    tags,
    fingerprint: [issue.fn, issue.kind],
    exception: {
      values: [{
        type: error instanceof Error ? error.name : error === undefined ? issue.kind : typeof error,
        value: `${issue.kind} in ${issue.fn}`,
        ...(frames.length > 0 ? { stacktrace: { frames } } : {}),
      }],
    },
  };
  const header = { event_id: context.eventID, sent_at: context.now.toISOString(), dsn: target.dsn };
  return [JSON.stringify(header), JSON.stringify({ type: "event" }), JSON.stringify(event)].join("\n") + "\n";
}

/** Sends `issue` when a DSN is set; never throws. True once Sentry took it. */
export async function report(issue: Issue, options: ReportOptions = {}): Promise<boolean> {
  const target = sentryTarget(options.dsn ?? secret("SENTRY_DSN"));
  if (!target) return false;
  const supabaseURL = options.supabaseURL ?? secret("SUPABASE_URL") ?? "";
  const project = URL.canParse(supabaseURL) ? new URL(supabaseURL).hostname.split(".")[0] : undefined;
  const body = envelope(target, issue, { eventID: crypto.randomUUID().replaceAll("-", ""), now: new Date(), project });
  const timeout = AbortSignal.timeout(options.timeoutMs ?? 3_000);
  try {
    const response = await (options.fetcher ?? fetch)(target.url, {
      method: "POST",
      headers: {
        "Content-Type": "application/x-sentry-envelope",
        "X-Sentry-Auth": `Sentry sentry_version=7, sentry_key=${target.publicKey}, sentry_client=dentory-functions/1`,
      },
      body,
      signal: timeout,
    });
    await response.body?.cancel();
    if (!response.ok) console.error(`Sentry answered ${response.status}`);
    return response.ok;
  } catch (error) {
    console.error(`Sentry unreachable (${error instanceof Error ? error.name : typeof error})`);
    return false;
  }
}

/** Reports after the answer: the runtime keeps the function alive until Sentry has the event. */
export function reportLater(issue: Issue, options?: ReportOptions): void {
  const sending = report(issue, options);
  if (typeof EdgeRuntime !== "undefined") EdgeRuntime.waitUntil(sending);
}

/** A secret, or undefined where the environment cannot be read (the Deno tests run without --allow-env). */
function secret(name: string): string | undefined {
  try {
    return Deno.env.get(name);
  } catch {
    return undefined;
  }
}
