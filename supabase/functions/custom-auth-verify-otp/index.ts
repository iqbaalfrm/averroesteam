import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import {
  consumeOtpChallenge,
  errorMessage,
  getSupabaseAdminClient,
  handleOptions,
  jsonResponse,
  normalizeEmail,
  normalizeMode,
  readJson,
  rpc,
  verifyOtpChallenge,
} from "../_shared/custom_auth.ts";

serve(async (req: Request) => {
  const preflight = handleOptions(req);
  if (preflight) {
    return preflight;
  }

  if (req.method !== "POST") {
    return jsonResponse({ success: false, message: "Method not allowed" }, 405);
  }

  try {
    const body = await readJson(req);
    const mode = normalizeMode(body.mode);
    const email = normalizeEmail(body.email);
    const otp = String(body.otp ?? "").trim();
    const admin = getSupabaseAdminClient();

    if (!mode) {
      return jsonResponse({ success: false, message: "Mode OTP tidak valid" });
    }
    if (!email) {
      return jsonResponse({ success: false, message: "Email wajib diisi" });
    }
    if (otp.length !== 4) {
      return jsonResponse({ success: false, message: "Kode OTP harus 4 digit" });
    }

    const verification = await verifyOtpChallenge(admin, {
      email,
      purpose: mode,
      otp,
      consume: false,
    });

    if (verification.valid !== true) {
      return jsonResponse({
        success: false,
        message: String(verification.message ?? "Kode OTP tidak valid"),
      });
    }

    if (mode === "signup") {
      const authUserId = String(verification.auth_user_id ?? "").trim();
      if (!authUserId) {
        return jsonResponse({ success: false, message: "Akun signup tidak ditemukan" });
      }

      const authUser = await rpc<Record<string, unknown> | null>(
        admin,
        "find_auth_user_by_email",
        { p_email: email },
      );
      const currentMeta = authUser?.user_metadata && typeof authUser.user_metadata === "object"
        ? authUser.user_metadata as Record<string, unknown>
        : {};
      const fullName = String(
        verification.full_name ?? currentMeta.full_name ?? currentMeta.name ?? "Pengguna",
      ).trim();

      const { error } = await admin.auth.admin.updateUserById(authUserId, {
        email_confirm: true,
        user_metadata: {
          ...currentMeta,
          full_name: fullName,
          name: fullName,
          email_verified: true,
        },
      });
      if (error) {
        throw new Error(error.message);
      }

      await consumeOtpChallenge(admin, {
        email,
        purpose: "signup",
      });

      return jsonResponse({
        success: true,
        message: "Email berhasil diverifikasi",
      });
    }

    return jsonResponse({
      success: true,
      message: "Kode OTP valid",
    });
  } catch (error) {
    return jsonResponse({
      success: false,
      message: errorMessage(error, "Verifikasi OTP gagal"),
    });
  }
});
