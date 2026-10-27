// POST /functions/v1/accept_invitation { token, full_name, password } from the Join screen (f5), before
// the invitee has an account. The token is the credential: the link reached the invited address, so the
// account is created confirmed (or, when the address already has one, its password is set to the new one),
// and invitation_accept makes the membership active. The app then signs in with the address and password.
import { errorResponse, HttpError, json, readJSON, text } from "../_shared/http.ts";
import { rpcError, serviceClient } from "../_shared/supabase.ts";

interface Invitation {
  clinic_name: string;
  invited_by_name: string;
  member_role: string;
  email: string;
  full_name: string;
  expires_at: string;
}

const expired = () =>
  new HttpError(410, "invitation_expired", "This invitation has expired. Ask your admin to resend.");

Deno.serve(async (req) => {
  try {
    const body = await readJSON(req);
    const token = text(body, "token");
    const fullName = text(body, "full_name");
    const password = typeof body.password === "string" ? body.password : "";
    if (!token) throw new HttpError(400, "validation", "The invitation link is incomplete.");
    if (password.length < 8) throw new HttpError(400, "validation", "At least 8 characters.", "password");
    if (fullName.length > 120) throw new HttpError(400, "validation", "The name is too long", "full_name");

    const db = serviceClient();
    const lookup = await db.rpc("invitation_lookup", { p_token: token });
    if (lookup.error) throw rpcError(lookup.error);
    const invitation = (lookup.data as Invitation[] | null)?.[0];
    if (!invitation) throw expired();

    const existing = await db.rpc("auth_user_id_for_email", { p_email: invitation.email });
    if (existing.error) throw rpcError(existing.error);
    const existingID = typeof existing.data === "string" ? existing.data : null;
    const metadata = { full_name: fullName || invitation.full_name };

    let userID: string;
    let created = false;
    if (existingID) {
      // The address already has an account (another clinic revoked it, or the admin's own test account):
      // the link proves the address, so the new password replaces the old one, as a reset link would.
      // Only once the server says this account may join; a refusal must leave the account untouched.
      const check = await db.rpc("invitation_check", { p_token: token, p_user_id: existingID });
      if (check.error) throw refusal(check.error);
      const { error } = await db.auth.admin.updateUserById(existingID, {
        password,
        email_confirm: true,
        user_metadata: metadata,
      });
      if (error) throw authError(error);
      userID = existingID;
    } else {
      const { data, error } = await db.auth.admin.createUser({
        email: invitation.email,
        password,
        email_confirm: true,
        user_metadata: metadata,
      });
      if (error || !data.user) throw authError(error);
      userID = data.user.id;
      created = true;
    }

    const accepted = await db.rpc("invitation_accept", {
      p_token: token,
      p_user_id: userID,
      p_full_name: fullName,
    });
    if (accepted.error) {
      if (created) await db.auth.admin.deleteUser(userID).catch((e) => console.error(e));
      throw refusal(accepted.error);
    }
    return json({ ok: true, email: invitation.email, clinic_id: accepted.data });
  } catch (error) {
    return errorResponse(error, "accept_invitation");
  }
});

/**
 * A refusal of invitation_check or invitation_accept, with the sentence the invitee should read: an
 * expired, used or unknown token is 410 (the app shows the expired state); another clinic, another
 * address or a seat already taken is 409 with the server's sentence (the app shows it as it is).
 */
function refusal(error: { code?: string | null; message?: string | null }): HttpError {
  const message = error.message ?? "";
  if (error.code === "22023" && message.startsWith("This invitation has expired")) return expired();
  if (error.code === "42501" || error.code === "23505") {
    return new HttpError(409, "cannot_join", message);
  }
  return rpcError(error);
}

function authError(error: { code?: string; message?: string } | null): HttpError {
  if (error?.code === "weak_password") {
    return new HttpError(400, "validation", "At least 8 characters.", "password");
  }
  console.error("auth admin call failed", error?.code, error?.message);
  return new HttpError(500, "unknown", "Couldn't save. Try again.");
}
