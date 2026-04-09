import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import {
  consumeOtpChallenge,
  errorMessage,
  getSupabaseAdminClient,
  handleOptions,
  issueOtpChallenge,
  jsonResponse,
  normalizeEmail,
  normalizeMode,
  readJson,
  rpc,
  sendOtpEmail,
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
    const fullName = String(body.full_name ?? "").trim();
    const password = String(body.password ?? "");
    const admin = getSupabaseAdminClient();

    if (!mode) {
      return jsonResponse({ success: false, message: "Mode OTP tidak valid" });
    }
    if (!email) {
      return jsonResponse({ success: false, message: "Email wajib diisi" });
    }

    if (otp) {
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
        const verifiedName = String(
          verification.full_name ?? currentMeta.full_name ?? currentMeta.name ?? "Pengguna",
        ).trim();

        const { error } = await admin.auth.admin.updateUserById(authUserId, {
          email_confirm: true,
          user_metadata: {
            ...currentMeta,
            full_name: verifiedName,
            name: verifiedName,
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
    }

    const authUser = await rpc<Record<string, unknown> | null>(
      admin,
      "find_auth_user_by_email",
      { p_email: email },
    );

    if (mode === "signup") {
      if (!password && !authUser) {
        return jsonResponse({ success: false, message: "Password wajib diisi" });
      }

      if (authUser?.is_confirmed === true) {
        return jsonResponse({ success: false, message: "Email sudah terdaftar" });
      }

      let authUserId = String(authUser?.id ?? "").trim();
      if (authUserId) {
        const currentMeta = authUser?.user_metadata && typeof authUser.user_metadata === "object"
          ? authUser.user_metadata as Record<string, unknown>
          : {};
        const updatePayload: Record<string, unknown> = {
          user_metadata: {
            ...currentMeta,
            full_name: fullName || String(currentMeta.full_name ?? "Pengguna"),
            name: fullName || String(currentMeta.name ?? currentMeta.full_name ?? "Pengguna"),
          },
        };
        if (password) {
          updatePayload.password = password;
        }
        const { error } = await admin.auth.admin.updateUserById(authUserId, updatePayload);
        if (error) {
          throw new Error(error.message);
        }
      } else {
        const { data, error } = await admin.auth.admin.createUser({
          email,
          password,
          email_confirm: false,
          user_metadata: {
            full_name: fullName || "Pengguna",
            name: fullName || "Pengguna",
            role: "user",
          },
          app_metadata: {
            provider: "email",
          },
        });
        if (error) {
          throw new Error(error.message);
        }
        authUserId = data.user?.id ?? "";
      }

      const challenge = await issueOtpChallenge(admin, {
        email,
        purpose: "signup",
        authUserId: authUserId || null,
        fullName: fullName || null,
      });

      await sendOtpEmail({
        to: email,
        otp: String(challenge.otp ?? ""),
        mode: "signup",
      });

      return jsonResponse({
        success: true,
        message: "Registrasi berhasil. Kode OTP 4 digit telah dikirim ke email Anda",
      });
    }

    if (!authUser || authUser.is_anonymous === true) {
      return jsonResponse({ success: false, message: "Email belum terdaftar" });
    }

    const challenge = await issueOtpChallenge(admin, {
      email,
      purpose: "recovery",
      authUserId: String(authUser.id ?? "").trim() || null,
    });

    await sendOtpEmail({
      to: email,
      otp: String(challenge.otp ?? ""),
      mode: "recovery",
    });

    return jsonResponse({
      success: true,
      message: "Kode OTP 4 digit telah dikirim ke email Anda",
    });
  } catch (error) {
    return jsonResponse({
      success: false,
      message: errorMessage(error, "Gagal mengirim OTP"),
    });
  }
});
