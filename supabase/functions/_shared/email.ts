// Transactional email through Resend (MS-100 D1, D12). Without RESEND_API_KEY, as on the local stack,
// nothing is sent: the message is written to the function log instead, link included, so the flow can
// be tried from the simulator (`make invite-links`).

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
    for (const email of emails) {
      console.log(`[email not sent: RESEND_API_KEY is not set]\nTo: ${email.to}\nSubject: ${email.subject}\n\n${email.text}`);
    }
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
    console.log(`[email not sent: RESEND_API_KEY is not set]\nTo: ${email.to}\nSubject: ${email.subject}\n\n${email.text}`);
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
