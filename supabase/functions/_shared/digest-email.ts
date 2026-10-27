// The weekly digest (MS-145, PRD §8): Monday 7 am at the clinic, to each active admin while Clinic settings' Email
// digest is on. Home's counts (To buy, Expiring soon, Missing expiry), the five batches expiring soonest, last week's
// procedures and one button that opens the app, laid out as the invitation and export emails are.
import type { Email } from "./email.ts";

/** A batch expiring within the clinic's window, as digest_claim answers it. */
export interface DigestBatch {
  name: string;
  qty: number;
  unit: string;
  lot: string | null;
  /** The first day of its expiry month, YYYY-MM-DD. */
  expiry_month: string;
  /** Days to the last day of its expiry month at the clinic; negative once expired. */
  days: number;
}

export interface DigestRecipient {
  email: string;
  name: string | null;
}

/** One clinic's digest, as digest_claim (with its id) or digest_preview (without) answers it. */
export interface Digest {
  id?: string;
  clinic_name: string;
  /** The Monday it is for, YYYY-MM-DD. */
  week: string;
  /** The largest expiry threshold in days (30, 60 or 90). */
  window: number;
  to_buy: number;
  expiring: number;
  soonest: DigestBatch[];
  missing_expiry: number;
  procedures: number;
  recipients: DigestRecipient[];
}

/** `https://app.dentory.ca/open`: a universal link that opens the app (MS-100 D12), on the function's
 * `APP_LINK_BASE` when it has one. */
export function digestLink(base: string | undefined): string {
  return `${(base || "https://app.dentory.ca").replace(/\/+$/, "")}/open`;
}

/** "This week at Smile Dental: 3 to buy, 2 expiring", the ticket's subject. */
export function digestSubject(digest: Digest): string {
  return `This week at ${oneLine(digest.clinic_name)}: ${digest.to_buy} to buy, ${digest.expiring} expiring`;
}

interface Figure {
  count: number;
  label: string;
  caption?: string;
}

const muted = "#7a6f6f";

export function digestEmail(digest: Digest, to: string, link: string): Email {
  const clinic = oneLine(digest.clinic_name);
  const day = longDay(digest.week);
  const lastWeek = `${shortDay(addDays(digest.week, -7))} to ${shortDay(addDays(digest.week, -1))}`;
  const figures: Figure[] = [
    { count: digest.to_buy, label: "To buy" },
    { count: digest.expiring, label: "Expiring soon", caption: `Within ${digest.window} days` },
    { count: digest.missing_expiry, label: "Missing expiry" },
    { count: digest.procedures, label: "Procedures last week", caption: lastWeek },
  ];
  const more = digest.expiring - digest.soonest.length;
  const moreLine = more > 0 ? `${more} more on Expiring soon in the app.` : "";
  const footer = "You get this email because Email digest is on in Clinic settings. An admin can turn it off there.";

  const expiringText = digest.soonest.length === 0 ? [] : [
    "",
    "Expiring soon",
    ...digest.soonest.map((batch) => `- ${oneLine(batch.name)}: ${batchLine(batch)} · ${daysText(batch.days)}`),
    ...(moreLine ? [moreLine] : []),
  ];
  const text = [
    `This week at ${clinic}`,
    day,
    "",
    `${digest.to_buy} to buy`,
    `${digest.expiring} expiring within ${digest.window} days`,
    `${digest.missing_expiry} missing expiry`,
    `${plural(digest.procedures, "procedure", "procedures")} last week (${lastWeek})`,
    ...expiringText,
    "",
    `Open Dentory: ${link}`,
    "",
    footer,
  ].join("\n");

  const expiringHTML = digest.soonest.length === 0 ? "" : `
        <tr><td style="font-size:18px;line-height:24px;font-weight:600;padding:24px 0 8px;">Expiring soon</td></tr>
        <tr><td>
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0">${digest.soonest.map(batchRow).join("")}
          </table>
        </td></tr>${moreLine ? `
        <tr><td style="font-size:14px;line-height:20px;color:${muted};padding-top:8px;">${escapeHTML(moreLine)}</td></tr>` : ""}`;
  const html = `<!doctype html>
<html lang="en">
<head>
  <meta charset="utf-8">
  <meta name="viewport" content="width=device-width, initial-scale=1">
  <meta name="color-scheme" content="light">
  <title>${escapeHTML(digestSubject(digest))}</title>
</head>
<body style="margin:0;padding:0;background:#f7f5f2;font-family:-apple-system,BlinkMacSystemFont,'Segoe UI',Helvetica,Arial,sans-serif;color:#201515;">
  <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="background:#f7f5f2;padding:32px 16px;">
    <tr><td align="center">
      <table role="presentation" width="100%" cellspacing="0" cellpadding="0" style="max-width:480px;background:#fffefb;border-radius:12px;padding:32px;">
        <tr><td style="font-size:14px;letter-spacing:1px;text-transform:uppercase;color:${muted};padding-bottom:8px;">${escapeHTML(day)}</td></tr>
        <tr><td style="font-size:24px;line-height:32px;font-weight:600;padding-bottom:8px;">This week at ${escapeHTML(clinic)}</td></tr>
        <tr><td>
          <table role="presentation" width="100%" cellspacing="0" cellpadding="0">${figures.map(figureRow).join("")}
          </table>
        </td></tr>${expiringHTML}
        <tr><td style="padding:32px 0 24px;">
          <a href="${escapeHTML(link)}" style="display:inline-block;background:#1a63d6;color:#ffffff;text-decoration:none;font-size:16px;font-weight:600;padding:14px 24px;border-radius:8px;">Open Dentory</a>
        </td></tr>
        <tr><td style="font-size:12px;line-height:18px;color:${muted};">${escapeHTML(footer)}</td></tr>
      </table>
    </td></tr>
  </table>
</body>
</html>`;
  return { to, subject: digestSubject(digest), html, text };
}

/** A count as Home's tile shows it: the number first, then what it counts. */
function figureRow(figure: Figure): string {
  const caption = figure.caption
    ? `
            <div style="font-size:14px;line-height:20px;color:${muted};">${escapeHTML(figure.caption)}</div>`
    : "";
  return `
        <tr>
          <td style="width:56px;padding:8px 0;font-size:28px;line-height:32px;font-weight:600;vertical-align:top;">${figure.count}</td>
          <td style="padding:8px 0 8px 12px;vertical-align:top;">
            <div style="font-size:16px;line-height:24px;font-weight:600;">${escapeHTML(figure.label)}</div>${caption}
          </td>
        </tr>`;
}

/** A batch as its Expiring soon card reads: the name and line on the left, the days on the right in their tone. */
function batchRow(batch: DigestBatch): string {
  const border = "border-top:1px solid #e6e1d6;vertical-align:top;";
  return `
            <tr>
              <td style="padding:10px 0;${border}">
                <div style="font-size:16px;line-height:24px;">${escapeHTML(oneLine(batch.name))}</div>
                <div style="font-size:14px;line-height:20px;color:${muted};">${escapeHTML(batchLine(batch))}</div>
              </td>
              <td align="right" style="padding:10px 0 10px 12px;${border}white-space:nowrap;font-size:14px;line-height:24px;font-weight:600;color:${daysTone(batch.days)};">${escapeHTML(daysText(batch.days))}</td>
            </tr>`;
}

/** "30 cartridges · lot S1 · Dec 2026", as an Expiring soon card's line: the month, since a batch expires on its
 * month's last day. */
export function batchLine(batch: DigestBatch): string {
  const lot = batch.lot?.trim() ? `lot ${oneLine(batch.lot)}` : null;
  return [quantity(batch.qty, batch.unit), lot, shortMonth(batch.expiry_month)].filter(Boolean).join(" · ");
}

/** "59 days", "1 day", "Today", "Expired", as an Expiring soon card's days. */
export function daysText(days: number): string {
  if (days < 0) return "Expired";
  if (days === 0) return "Today";
  return days === 1 ? "1 day" : `${days} days`;
}

/** Danger within 30 days or once expired, warning further out (PRD §6.7), in the app's colours. */
function daysTone(days: number): string {
  return days <= 30 ? "#bf372b" : "#a15c00";
}

/** "30 cartridges", "1 box", "2.5 bags": as the app's ClinicFormatters.quantity. */
export function quantity(amount: number, unit: string): string {
  const number = new Intl.NumberFormat("en-US", { maximumFractionDigits: 2 }).format(amount);
  return `${number} ${amount === 1 ? singular(unit) : unit}`;
}

/** "bottle" for "bottles", "box" for "boxes", "battery" for "batteries", as ClinicFormatters.singular(of:). */
export function singular(unit: string): string {
  const lowercased = unit.toLowerCase();
  if (lowercased.endsWith("ies")) return unit.slice(0, -3) + "y";
  if (["xes", "ches", "shes", "sses"].some((ending) => lowercased.endsWith(ending))) return unit.slice(0, -2);
  if (lowercased.endsWith("s") && !lowercased.endsWith("ss")) return unit.slice(0, -1);
  return unit;
}

function plural(count: number, one: string, many: string): string {
  return `${count} ${count === 1 ? one : many}`;
}

/** "Monday, October 19" for a YYYY-MM-DD day. */
function longDay(day: string): string {
  return new Intl.DateTimeFormat("en-US", { weekday: "long", month: "long", day: "numeric", timeZone: "UTC" })
    .format(utcDate(day));
}

/** "Dec 2026" for a YYYY-MM-DD day. */
function shortMonth(day: string): string {
  return new Intl.DateTimeFormat("en-US", { month: "short", year: "numeric", timeZone: "UTC" }).format(utcDate(day));
}

/** "Oct 12" for a YYYY-MM-DD day. */
function shortDay(day: string): string {
  return new Intl.DateTimeFormat("en-US", { month: "short", day: "numeric", timeZone: "UTC" }).format(utcDate(day));
}

function addDays(day: string, days: number): string {
  const date = utcDate(day);
  date.setUTCDate(date.getUTCDate() + days);
  return date.toISOString().slice(0, 10);
}

function utcDate(day: string): Date {
  const [year, month, date] = day.split("-").map(Number);
  return new Date(Date.UTC(year, month - 1, date));
}

/** A name on one line: an email header cannot carry a line break. */
function oneLine(value: string): string {
  return value.replace(/\s+/g, " ").trim();
}

function escapeHTML(value: string): string {
  return value
    .replaceAll("&", "&amp;")
    .replaceAll("<", "&lt;")
    .replaceAll(">", "&gt;")
    .replaceAll('"', "&quot;")
    .replaceAll("'", "&#39;");
}
