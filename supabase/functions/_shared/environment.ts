// Where the functions run. The CLI points the local stack's functions at its own gateway, kong; a hosted project's
// SUPABASE_URL is the project's own URL, and Supabase reserves the SUPABASE_ names (`supabase secrets set` skips
// them), so no secret can make a hosted project pass for the local stack.

/** Whether these functions run on the local stack (`supabase start`, `supabase functions serve`). */
export function isLocalStack(supabaseURL = Deno.env.get("SUPABASE_URL") ?? ""): boolean {
  return URL.canParse(supabaseURL) && new URL(supabaseURL).hostname === "kong";
}
