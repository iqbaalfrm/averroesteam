import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import {
  consumeOtpChallenge,
  errorMessage,
  getSupabaseAdminClient,
  handleOptions,
  jsonResponse,
  normalizeEmail,
  readJson,
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
    const email = normalizeEmail(body.email);
    const otp = String(body.otp ?? "").trim();
    const newPassword = String(body.new_password ?? "");
    const admin = getSupabaseAdminClient();

    if (!email) {
      return jsonResponse({ success: false, message: "Email wajib diisi" });
    }
    if (otp.length != 4) {
      return jsonResponse({ success: false, message: "Kode OTP harus 4 digit" });
    }
    if (newPassword.trim().length < 8) {
      return jsonResponse({ success: false, message: "Password baru minimal 8 karakter" });
    }

    const verification = await verifyOtpChallenge(admin, {
      email,
      purpose: "recovery",
      otp,
      consume: false,
    });

    if (verification.valid !== true) {
      return jsonResponse({
        success: false,
        message: String(verification.message ?? "Kode OTP tidak valid"),
      });
    }

    const authUserId = String(verification.auth_user_id ?? "").trim();
    if (!authUserId) {
      return jsonResponse({ success: false, message: "Akun tidak ditemukan" });
    }

    const { error } = await admin.auth.admin.updateUserById(authUserId, {
      password: newPassword,
    });
    if (error) {
      throw new Error(error.message);
    }

    await consumeOtpChallenge(admin, {
      email,
      purpose: "recovery",
    });

    return jsonResponse({
      success: true,
      message: "Password berhasil diubah",
    });
  } catch (error) {
    return jsonResponse({
      success: false,
      message: errorMessage(error, "Gagal mengubah password"),
    });
  }
});
