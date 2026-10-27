// Transactional email through Resend (MS-100 D1, D12). Without RESEND_API_KEY nothing is sent. On the local stack the
// message is written to the function log instead, link included, so the flow can be tried from the simulator
// (`make invite-links`); a hosted project's log only says how many went unsent, since an invitation or export link in
// it would let anyone who reads the log join the clinic or download its data (MS-151).
import { isLocalStack } from "./environment.ts";

export interface Email {
  to: string;
  replyTo?: string;
  subject: string;
  html: string;
  text: string;
}

export type Delivery = "sent" | "logged";

const defaultFrom = "Dentory <invites@dentory.ca>";

/** Several emails in one Resend call (its batch endpoint, up to 100), so they go out together or not at all. */
export async function sendEmails(emails: Email[]): Promise<Delivery> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) {
    unsentEmailsLog(emails).forEach((line) => console.log(line));
    return "logged";
  }
  const from = Deno.env.get("EMAIL_FROM") || defaultFrom;
  const response = await fetch("https://api.resend.com/emails/batch", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify(emails.map((email) => ({
      from,
      to: [email.to],
      reply_to: email.replyTo ? [email.replyTo] : undefined,
      subject: email.subject,
      html: email.html,
      text: email.text,
    }))),
  });
  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    throw new Error(`Resend answered ${response.status}: ${detail}`);
  }
  return "sent";
}

export async function sendEmail(email: Email): Promise<Delivery> {
  const apiKey = Deno.env.get("RESEND_API_KEY");
  if (!apiKey) {
    unsentEmailsLog([email]).forEach((line) => console.log(line));
    return "logged";
  }
  const response = await fetch("https://api.resend.com/emails", {
    method: "POST",
    headers: {
      "Authorization": `Bearer ${apiKey}`,
      "Content-Type": "application/json",
    },
    body: JSON.stringify({
      from: Deno.env.get("EMAIL_FROM") || defaultFrom,
      to: [email.to],
      reply_to: email.replyTo ? [email.replyTo] : undefined,
      subject: email.subject,
      html: email.html,
      text: email.text,
    }),
  });
  if (!response.ok) {
    const detail = await response.text().catch(() => "");
    throw new Error(`Resend answered ${response.status}: ${detail}`);
  }
  return "sent";
}

/**
 * What the log says of emails that went unsent for want of RESEND_API_KEY: each whole email on the local stack, and on
 * a hosted project one line with their number, without an address, a subject (it names people) or a body (it holds
 * the links).
 */
export function unsentEmailsLog(emails: Email[], local = isLocalStack()): string[] {
  if (!local) {
    return [`[email not sent: RESEND_API_KEY is not set] ${emails.length} ${emails.length === 1 ? "email" : "emails"}`];
  }
  return emails.map((email) =>
    `[email not sent: RESEND_API_KEY is not set]\nTo: ${email.to}\nSubject: ${email.subject}\n\n${email.text}`
  );
}
