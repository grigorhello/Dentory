// Dentory's copy of a paid invoice's receipt (MS-141), for every billing email but the one Stripe sent its own receipt
// to, the one address its API keeps per customer. Laid out as the invitation email is.
import type { Email } from "./email.ts";

export interface ReceiptCopy {
  clinic_name: string;
  emails: string[];
  number: string | null;
  issued_at: string;
  amount_cents: number;
  currency: string;
  hosted_url: string | null;
  time_zone: string;
  /** When it was paid (Stripe's status_transitions.paid_at); the issue date stands in when Stripe has none. */
  paid_at?: string | null;
}

/** "$49.50" for 4950 cents in usd. */
export function receiptAmount(cents: number, currency: string): string {
  return new Intl.NumberFormat("en-US", { style: "currency", currency: currency.toUpperCase() }).format(cents / 100);
}

/** "January 6, 2027", a day at the clinic. */
export function receiptDay(issuedAt: string, timeZone: string): string {
  return new Intl.DateTimeFormat("en-US", { dateStyle: "long", timeZone }).format(new Date(issuedAt));
}

export function receiptCopyEmail(copy: ReceiptCopy, to: string): Email {
  const amount = receiptAmount(copy.amount_cents, copy.currency);
  const day = receiptDay(copy.paid_at ?? copy.issued_at, copy.time_zone);
  const invoice = copy.number ? `invoice ${copy.number}` : "the invoice";
  const subject = `Receipt for ${copy.clinic_name}'s Dentory subscription, ${day}`;
  const intro = `${copy.clinic_name} paid ${amount} for its Dentory subscription on ${day} (${invoice}). ` +
    "You get this copy because the clinic lists your address under Billing emails.";
  const link = copy.hosted_url ? `The invoice and the receipt: ${copy.hosted_url}` : "";
  const text = [intro, link].filter(Boolean).join("\n\n");
  const button = copy.hosted_url
    ? `<tr><td style="padding-top:24px;"><a href="${escapeHTML(copy.hosted_url)}" style="display:inline-block;background:#1a63d6;color:#ffffff;text-decoration:none;font-size:16px;font-weight:600;padding:14px 24px;border-radius:8px;">View the invoice</a></td></tr>`
    : "";
  const html = `<!doctype html>
<html lang="en">
<body style="margin:0;padding:0;background:#f7f5f2;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;color:#201515;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f7f5f2;padding:32px 16px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:480px;background:#ffffff;border-radius:12px;padding:32px;">
        <tr><td style="font-size:14px;letter-spacing:1px;text-transform:uppercase;color:#7a6f6f;padding-bottom:8px;">Receipt</td></tr>
        <tr><td style="font-size:24px;font-weight:600;padding-bottom:16px;">${escapeHTML(amount)} paid</td></tr>
        <tr><td style="font-size:16px;line-height:24px;">${escapeHTML(intro)}</td></tr>
        ${button}
      </table>
    </td></tr>
  </table>
</body>
</html>`;
  return { to, subject, html, text };
}

function escapeHTML(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
