// POST /functions/v1/export_csv { clinic_id } as a signed-in admin (MS-143, PRD §6.9 Export CSV). Answers at once with
// the address the link goes to; then, in the background, writes products.csv, batches.csv and transactions.csv,
// zips them into the private exports bucket and emails the admin a signed link valid 7 days. One export per clinic
// every 10 minutes (export_job_start); a read-only clinic may export too. Each export also removes the clinic's
// files whose links have expired. Without RESEND_API_KEY, as on the local stack, the email goes to the log.
import type { SupabaseClient } from "jsr:@supabase/supabase-js@2";
import { errorResponse, HttpError, isUUID, json, readJSON, text } from "../_shared/http.ts";
import { caller, rpcError, serviceClient } from "../_shared/supabase.ts";
import { sendEmail } from "../_shared/email.ts";
import { exportEmail } from "../_shared/export-email.ts";
import { type ExportData, exportFiles } from "../_shared/export-files.ts";
import { zip } from "../_shared/zip.ts";

/** Supabase's runtime keeps the function alive for work handed to it after the answer. */
declare const EdgeRuntime: { waitUntil(promise: Promise<unknown>): void } | undefined;

interface StartedExport {
  job_id: string;
  email: string;
  clinic_name: string;
  day: string;
}

const linkSeconds = 7 * 24 * 60 * 60;

Deno.serve(async (req) => {
  try {
    const body = await readJSON(req);
    const clinicID = text(body, "clinic_id");
    if (!isUUID(clinicID)) throw new HttpError(400, "validation", "A clinic is required.");
    const admin = await caller(req);
    const db = serviceClient();
    const { data, error } = await db
      .rpc("export_job_start", { p_clinic_id: clinicID, p_user_id: admin.id })
      .single<StartedExport>();
    if (error) throw rpcError(error);
    const work = run(db, clinicID, data);
    if (typeof EdgeRuntime !== "undefined") EdgeRuntime.waitUntil(work);
    else await work;
    return json({ email: data.email });
  } catch (error) {
    return errorResponse(error);
  }
});

/** Builds, stores and sends the export, then closes its job: done with the file's path, or failed. */
async function run(db: SupabaseClient, clinicID: string, job: StartedExport) {
  let sentPath: string | null = null;
  try {
    const { data, error } = await db.rpc("export_data", { p_clinic_id: clinicID });
    if (error) throw new Error(`export_data: ${error.message}`);
    const archive = await zip(exportFiles(data as ExportData));
    const path = `${clinicID}/${job.job_id}.zip`;
    const bucket = db.storage.from("exports");
    const upload = await bucket.upload(path, archive, { contentType: "application/zip" });
    if (upload.error) throw new Error(`upload: ${upload.error.message}`);
    const signed = await bucket.createSignedUrl(path, linkSeconds, { download: `dentory-export-${job.day}.zip` });
    if (signed.error || !signed.data) throw new Error(`signed link: ${signed.error?.message ?? "none"}`);
    const email = exportEmail({ to: job.email, clinicName: job.clinic_name, day: job.day, link: signed.data.signedUrl });
    await sendEmail(email);
    sentPath = path;
    await removeExpired(db, clinicID);
  } catch (error) {
    console.error("export failed", error);
  } finally {
    const { error } = await db.rpc("export_job_finish", { p_job_id: job.job_id, p_file_path: sentPath });
    if (error) console.error("export_job_finish", error.message);
  }
}

/** The clinic's earlier exports whose links no longer work: nobody can download them, so they go. */
async function removeExpired(db: SupabaseClient, clinicID: string) {
  const bucket = db.storage.from("exports");
  const { data, error } = await bucket.list(clinicID, { limit: 100, sortBy: { column: "created_at", order: "asc" } });
  if (error) return console.error("list exports", error.message);
  const cutoff = Date.now() - linkSeconds * 1000;
  const expired = (data ?? [])
    .filter((file) => file.created_at && Date.parse(file.created_at) < cutoff)
    .map((file) => `${clinicID}/${file.name}`);
  if (expired.length === 0) return;
  const removed = await bucket.remove(expired);
  if (removed.error) console.error("remove exports", removed.error.message);
}
