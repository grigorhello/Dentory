// deno test supabase/functions (make functions-check): what the log keeps of an email sent without RESEND_API_KEY
// (MS-151). The local stack's log holds the whole email, as `make invite-links` reads it; a hosted project's log holds
// no address, name or link, so reading the log never lets anyone join a clinic or download its export.
import { assertEquals, assertFalse, assertStringIncludes } from "jsr:@std/assert@1";
import { unsentEmailsLog } from "./email.ts";
import { exportEmail } from "./export-email.ts";
import { invitationEmail } from "./invitation-email.ts";

const invitation = invitationEmail({
  to: "priya@smile.ca",
  inviterName: "Sarah Mitchell",
  clinicName: "Smile Dental",
  role: "staff",
  fullName: "Priya Patel",
  link: "https://app.dentory.ca/invite?token=t0k3n-only-the-email-carries",
});
const download = exportEmail({
  to: "sarah@smile.ca",
  clinicName: "Smile Dental",
  day: "2026-10-26",
  link: "https://abcdefghijklmnopqrst.supabase.co/storage/v1/object/sign/exports/c/j.zip?token=s1gned",
});

Deno.test("a hosted project's log says how many emails went unsent, and nothing of them", () => {
  const lines = unsentEmailsLog([invitation, download], false);
  assertEquals(lines, ["[email not sent: RESEND_API_KEY is not set] 2 emails"]);
  for (const secret of ["priya@smile.ca", "sarah@smile.ca", "Priya", "Sarah", "t0k3n", "s1gned", "invite?token"]) {
    assertFalse(lines.join("\n").includes(secret), secret);
  }
  assertEquals(unsentEmailsLog([invitation], false), ["[email not sent: RESEND_API_KEY is not set] 1 email"]);
});

Deno.test("the local stack's log keeps the whole email, link included", () => {
  const [line] = unsentEmailsLog([invitation], true);
  assertStringIncludes(line, "To: priya@smile.ca");
  assertStringIncludes(line, "https://app.dentory.ca/invite?token=t0k3n-only-the-email-carries");
});
