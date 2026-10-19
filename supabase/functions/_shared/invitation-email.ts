// The invitation email (ticket MS-112): one subject, one button, the link in plain text as well.
import type { Email } from "./email.ts";

export interface InvitationEmailInput {
  to: string;
  replyTo?: string;
  inviterName: string;
  clinicName: string;
  /** "admin" | "staff" */
  role: string;
  /** The invitee's name when the admin gave one. */
  fullName: string;
  link: string;
}

/** `https://app.dentory.ca/invite?token=…`: a universal link that opens the app (MS-100 D12). */
export function invitationLink(token: string): string {
  const base = (Deno.env.get("APP_LINK_BASE") || "https://app.dentory.ca").replace(/\/+$/, "");
  return `${base}/invite?token=${encodeURIComponent(token)}`;
}

export function invitationEmail(input: InvitationEmailInput): Email {
  const role = input.role === "admin" ? "Admin" : "Staff";
  const greeting = input.fullName ? `Hi ${input.fullName},` : "Hi,";
  const subject = `${input.inviterName} invited you to ${input.clinicName} on Dentory`;
  const intro = `${input.inviterName} invited you to join ${input.clinicName} on Dentory as ${role}. ` +
    "Dentory is the app the clinic uses to track its supplies.";
  const expiry = "The link works for 7 days. If you were not expecting this, you can ignore this email.";
  const text = [
    greeting,
    "",
    intro,
    "",
    `Join ${input.clinicName}: ${input.link}`,
    "",
    expiry,
  ].join("\n");
  const html = `<!doctype html>
<html lang="en">
<body style="margin:0;padding:0;background:#f7f5f2;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;color:#201515;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f7f5f2;padding:32px 16px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:480px;background:#ffffff;border-radius:12px;padding:32px;">
        <tr><td style="font-size:14px;letter-spacing:1px;text-transform:uppercase;color:#7a6f6f;padding-bottom:8px;">Invitation</td></tr>
        <tr><td style="font-size:24px;font-weight:600;padding-bottom:16px;">Join ${escapeHTML(input.clinicName)}</td></tr>
        <tr><td style="font-size:16px;line-height:24px;padding-bottom:8px;">${escapeHTML(greeting)}</td></tr>
        <tr><td style="font-size:16px;line-height:24px;padding-bottom:24px;">${escapeHTML(intro)}</td></tr>
        <tr><td style="padding-bottom:24px;">
          <a href="${escapeAttribute(input.link)}" style="display:inline-block;background:#1a63d6;color:#ffffff;text-decoration:none;font-size:16px;font-weight:600;padding:14px 24px;border-radius:8px;">Join ${escapeHTML(input.clinicName)}</a>
        </td></tr>
        <tr><td style="font-size:14px;line-height:20px;color:#7a6f6f;padding-bottom:8px;">${escapeHTML(expiry)}</td></tr>
        <tr><td style="font-size:12px;line-height:18px;color:#7a6f6f;word-break:break-all;">If the button does not open the app, copy this link: ${escapeHTML(input.link)}</td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
  return { to: input.to, replyTo: input.replyTo, subject, html, text };
}

function escapeHTML(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}

function escapeAttribute(value: string): string {
  return escapeHTML(value);
}
