// The export email (MS-143): the clinic's data as one zip, a button to download it and the link in plain text,
// laid out as the invitation email is.
import type { Email } from "./email.ts";

export interface ExportEmailInput {
  to: string;
  clinicName: string;
  /** The clinic's date the export was made, YYYY-MM-DD. */
  day: string;
  link: string;
}

export function exportEmail(input: ExportEmailInput): Email {
  const subject = `${input.clinicName}'s data from Dentory`;
  const intro = `Here is ${input.clinicName}'s data from Dentory on ${input.day}: products, batches and transactions, ` +
    "as 3 CSV files in one zip. Excel and Numbers open them.";
  const expiry = "The link works for 7 days. Export again from Account in the app for a newer copy.";
  const text = [intro, "", `Download the export: ${input.link}`, "", expiry].join("\n");
  const html = `<!doctype html>
<html lang="en">
<body style="margin:0;padding:0;background:#f7f5f2;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;color:#201515;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f7f5f2;padding:32px 16px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:480px;background:#ffffff;border-radius:12px;padding:32px;">
        <tr><td style="font-size:14px;letter-spacing:1px;text-transform:uppercase;color:#7a6f6f;padding-bottom:8px;">Export</td></tr>
        <tr><td style="font-size:24px;font-weight:600;padding-bottom:16px;">${escapeHTML(input.clinicName)}'s data</td></tr>
        <tr><td style="font-size:16px;line-height:24px;padding-bottom:24px;">${escapeHTML(intro)}</td></tr>
        <tr><td style="padding-bottom:24px;">
          <a href="${escapeHTML(input.link)}" style="display:inline-block;background:#1a63d6;color:#ffffff;text-decoration:none;font-size:16px;font-weight:600;padding:14px 24px;border-radius:8px;">Download the export</a>
        </td></tr>
        <tr><td style="font-size:14px;line-height:20px;color:#7a6f6f;padding-bottom:8px;">${escapeHTML(expiry)}</td></tr>
        <tr><td style="font-size:12px;line-height:18px;color:#7a6f6f;word-break:break-all;">If the button does not work, copy this link: ${escapeHTML(input.link)}</td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
  return { to: input.to, subject, html, text };
}

/** When the export could not be made: no link, and how to try again. */
export function exportFailedEmail(input: { to: string; clinicName: string }): Email {
  const subject = `${input.clinicName}'s export from Dentory didn't go through`;
  const text = `Dentory couldn't make ${input.clinicName}'s export this time, and nothing was sent. ` +
    "Export again from Account in the app.";
  const html = `<!doctype html>
<html lang="en">
<body style="margin:0;padding:0;background:#f7f5f2;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;color:#201515;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f7f5f2;padding:32px 16px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:480px;background:#ffffff;border-radius:12px;padding:32px;">
        <tr><td style="font-size:14px;letter-spacing:1px;text-transform:uppercase;color:#7a6f6f;padding-bottom:8px;">Export</td></tr>
        <tr><td style="font-size:16px;line-height:24px;">${escapeHTML(text)}</td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
  return { to: input.to, subject, html, text };
}

function escapeHTML(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
