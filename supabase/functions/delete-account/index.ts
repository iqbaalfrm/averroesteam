import { serve } from "https://deno.land/std@0.224.0/http/server.ts";

import {
  errorMessage,
  getSupabaseAdminClient,
  handleOptions,
  jsonResponse,
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
    const authHeader = req.headers.get("Authorization")?.trim() || "";
    if (!authHeader.toLowerCase().startsWith("bearer ")) {
      return jsonResponse({ success: false, message: "Unauthorized" }, 401);
    }

    const jwt = authHeader.slice(7).trim();
    if (!jwt) {
      return jsonResponse({ success: false, message: "Unauthorized" }, 401);
    }

    const admin = getSupabaseAdminClient();
    const { data: userData, error: userError } = await admin.auth.getUser(jwt);
    if (userError || !userData.user) {
      return jsonResponse({ success: false, message: "Session tidak valid" }, 401);
    }

    const authUserId = userData.user.id;

    const { error: profileDeleteError } = await admin
      .from("profiles")
      .delete()
      .or(`auth_user_id.eq.${authUserId},id.eq.${authUserId}`);
    if (profileDeleteError) {
      throw new Error(profileDeleteError.message);
    }

    const { error: authDeleteError } = await admin.auth.admin.deleteUser(authUserId);
    if (authDeleteError) {
      throw new Error(authDeleteError.message);
    }

    return jsonResponse({
      success: true,
      message: "Akun berhasil dihapus",
    });
  } catch (error) {
    return jsonResponse({
      success: false,
      message: errorMessage(error, "Gagal menghapus akun"),
    }, 500);
  }
});
