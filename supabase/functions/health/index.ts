// Answers `GET /functions/v1/health` so the stack and the Deno toolchain can be checked end to end.
// The real functions (invoice reading, billing, push) arrive with their tickets.
Deno.serve(() =>
  new Response(JSON.stringify({ ok: true }), {
    headers: { "Content-Type": "application/json" },
  }),
);
