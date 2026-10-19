// POST /functions/v1/invite_member { clinic_id, email, role?, full_name? } as a signed-in admin.
// Creates or refreshes the invited membership through invitation_create (a fresh 7-day token, only its
// hash stored) and emails the invitee the link. Calling it again for the same address is the resend:
// the old link stops working (MS-112; PRD §6.1; MS-100 G4, D12).
import { errorResponse, HttpError, isUUID, json, looksLikeEmail, readJSON, text } from "../_shared/http.ts";
import { caller, rpcError, serviceClient } from "../_shared/supabase.ts";
import { sendEmail } from "../_shared/email.ts";
import { invitationEmail, invitationLink } from "../_shared/invitation-email.ts";

interface CreatedInvitation {
  membership_id: string;
  token: string;
  clinic_name: string;
  invited_by_name: string;
  member_role: string;
  expires_at: string;
}

Deno.serve(async (req) => {
  try {
    const body = await readJSON(req);
    const clinicID = text(body, "clinic_id");
    const email = text(body, "email").toLowerCase();
    const role = text(body, "role") || "staff";
    const fullName = text(body, "full_name");
    if (!isUUID(clinicID)) throw new HttpError(400, "validation", "A clinic is required.");
    if (!looksLikeEmail(email)) throw new HttpError(400, "validation", "Enter a valid email", "email");
    if (role !== "staff" && role !== "admin") {
      throw new HttpError(400, "validation", "Role must be Staff or Admin", "role");
    }
    if (fullName.length > 120) throw new HttpError(400, "validation", "The name is too long", "full_name");

    const admin = await caller(req);
    const db = serviceClient();
    const { data, error } = await db
      .rpc("invitation_create", {
        p_clinic_id: clinicID,
        p_email: email,
        p_role: role,
        p_full_name: fullName,
        p_invited_by: admin.id,
      })
      .single<CreatedInvitation>();
    if (error) throw rpcError(error, "email");

    const delivery = await sendEmail(invitationEmail({
      to: email,
      replyTo: admin.email || undefined,
      inviterName: data.invited_by_name,
      clinicName: data.clinic_name,
      role: data.member_role,
      fullName,
      link: invitationLink(data.token),
    }));

    return json({
      ok: true,
      membership_id: data.membership_id,
      expires_at: data.expires_at,
      delivery,
    });
  } catch (error) {
    return errorResponse(error);
  }
});
