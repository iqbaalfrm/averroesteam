import { createClient, type SupabaseClient } from "https://esm.sh/@supabase/supabase-js@2.49.8";
import nodemailer from "npm:nodemailer@6.9.16";

export const corsHeaders = {
  "Access-Control-Allow-Origin": "*",
  "Access-Control-Allow-Headers": "authorization, x-client-info, apikey, content-type",
  "Access-Control-Allow-Methods": "POST, OPTIONS",
};

const brandName = Deno.env.get("APP_BRAND_NAME")?.trim() || "Averroes";
const brevoApiKey = Deno.env.get("BREVO_API_KEY")?.trim() || "";
const brevoSenderId = Number(Deno.env.get("BREVO_SENDER_ID")?.trim() || "0");
const brevoFromEmail = Deno.env.get("BREVO_FROM_EMAIL")?.trim() || "";
const brevoFromName = Deno.env.get("BREVO_FROM_NAME")?.trim() || brandName;
const resendApiKey = Deno.env.get("RESEND_API_KEY")?.trim() || "";
const resendFromEmail = Deno.env.get("RESEND_FROM_EMAIL")?.trim() || "";
const resendFromName = Deno.env.get("RESEND_FROM_NAME")?.trim() || brandName;
const smtpHost = Deno.env.get("MAIL_HOST")?.trim() || "";
const smtpPort = Number(Deno.env.get("MAIL_PORT")?.trim() || "0");
const smtpUsername = Deno.env.get("MAIL_USERNAME")?.trim() || "";
const smtpPassword = Deno.env.get("MAIL_PASSWORD")?.trim() || "";
const smtpFromEmail = Deno.env.get("MAIL_FROM_ADDRESS")?.trim() || "";
const smtpFromName = Deno.env.get("MAIL_FROM_NAME")?.trim() || brandName;
const smtpEncryption = Deno.env.get("MAIL_ENCRYPTION")?.trim().toLowerCase() ||
  Deno.env.get("MAIL_SCHEME")?.trim().toLowerCase() ||
  "";
const otpLength = 4;

type OtpMode = "signup" | "recovery";

type OtpChallengeRow = {
  id: string;
  email: string;
  purpose: OtpMode;
  auth_user_id: string | null;
  otp_hash: string;
  full_name: string | null;
  attempt_count: number;
  resend_count: number;
  max_attempts: number;
  expires_at: string;
  verified_at: string | null;
  consumed_at: string | null;
  metadata: Record<string, unknown> | null;
};

export function handleOptions(req: Request): Response | null {
  if (req.method === "OPTIONS") {
    return new Response("ok", { headers: corsHeaders });
  }
  return null;
}

export function jsonResponse(body: Record<string, unknown>, status = 200): Response {
  return new Response(JSON.stringify(body), {
    status,
    headers: {
      ...corsHeaders,
      "Content-Type": "application/json",
    },
  });
}

export async function readJson(req: Request): Promise<Record<string, unknown>> {
  try {
    const data = await req.json();
    if (data && typeof data === "object") {
      return data as Record<string, unknown>;
    }
  } catch (_) {}
  return {};
}

export function normalizeEmail(value: unknown): string {
  return String(value ?? "").trim().toLowerCase();
}

export function normalizeMode(value: unknown): "signup" | "recovery" | null {
  const mode = String(value ?? "").trim().toLowerCase();
  if (mode === "signup" || mode === "register") {
    return "signup";
  }
  if (mode === "recovery" || mode === "reset") {
    return "recovery";
  }
  return null;
}

function getOtpPepper(): string {
  return Deno.env.get("OTP_HASH_SECRET")?.trim() ||
    Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() ||
    brandName;
}

function nowIso(): string {
  return new Date().toISOString();
}

function addMinutesIso(minutes: number): string {
  return new Date(Date.now() + minutes * 60_000).toISOString();
}

function generateOtp(): string {
  return String(Math.floor(Math.random() * 10_000)).padStart(otpLength, "0");
}

async function hashOtp(email: string, purpose: OtpMode, otp: string): Promise<string> {
  const payload = `${email}|${purpose}|${otp}|${getOtpPepper()}`;
  const bytes = new TextEncoder().encode(payload);
  const digest = await crypto.subtle.digest("SHA-256", bytes);
  return Array.from(new Uint8Array(digest))
    .map((part) => part.toString(16).padStart(2, "0"))
    .join("");
}

async function getOtpChallenge(
  client: SupabaseClient,
  email: string,
  purpose: OtpMode,
): Promise<OtpChallengeRow | null> {
  const { data, error } = await client
    .from("auth_otp_challenges")
    .select(
      "id,email,purpose,auth_user_id,otp_hash,full_name,attempt_count,resend_count,max_attempts,expires_at,verified_at,consumed_at,metadata",
    )
    .eq("email", email)
    .eq("purpose", purpose)
    .maybeSingle();
  if (error) {
    throw new Error(error.message);
  }
  return data as OtpChallengeRow | null;
}

export async function issueOtpChallenge(
  client: SupabaseClient,
  args: {
    email: string;
    purpose: OtpMode;
    authUserId?: string | null;
    fullName?: string | null;
    ttlMinutes?: number;
  },
): Promise<Record<string, unknown>> {
  const email = normalizeEmail(args.email);
  const purpose = args.purpose;
  const ttlMinutes = Math.max(args.ttlMinutes ?? 10, 1);
  const fullName = String(args.fullName ?? "").trim() || null;
  const current = await getOtpChallenge(client, email, purpose);
  const otp = generateOtp();
  const otpHash = await hashOtp(email, purpose, otp);
  const payload = {
    email,
    purpose,
    auth_user_id: args.authUserId ?? current?.auth_user_id ?? null,
    otp_hash: otpHash,
    full_name: fullName ?? current?.full_name ?? null,
    attempt_count: 0,
    resend_count: current ? (Number(current.resend_count ?? 0) + 1) : 0,
    max_attempts: 5,
    expires_at: addMinutesIso(ttlMinutes),
    last_sent_at: nowIso(),
    verified_at: null,
    consumed_at: null,
    metadata: {
      otp_length: otpLength,
      hash_algo: "sha256-v1",
    },
    updated_at: nowIso(),
  };
  const { data, error } = await client
    .from("auth_otp_challenges")
    .upsert(payload, { onConflict: "email,purpose" })
    .select("id,email,purpose,expires_at")
    .single();
  if (error) {
    throw new Error(error.message);
  }
  return {
    challenge_id: data.id,
    email: data.email,
    purpose: data.purpose,
    otp,
    expires_at: data.expires_at,
    otp_length: otpLength,
  };
}

export async function verifyOtpChallenge(
  client: SupabaseClient,
  args: {
    email: string;
    purpose: OtpMode;
    otp: string;
    consume?: boolean;
  },
): Promise<Record<string, unknown>> {
  const email = normalizeEmail(args.email);
  const purpose = args.purpose;
  const otp = String(args.otp ?? "").trim();
  const row = await getOtpChallenge(client, email, purpose);

  if (!row) {
    return {
      valid: false,
      reason: "otp_not_found",
      message: "Kode OTP tidak ditemukan",
    };
  }

  if (row.consumed_at) {
    return {
      valid: false,
      reason: "otp_already_used",
      message: "Kode OTP sudah digunakan",
    };
  }

  if (new Date(row.expires_at).getTime() < Date.now()) {
    return {
      valid: false,
      reason: "otp_expired",
      message: "Kode OTP sudah kedaluwarsa",
    };
  }

  if ((row.attempt_count ?? 0) >= (row.max_attempts ?? 5)) {
    return {
      valid: false,
      reason: "otp_attempts_exceeded",
      message: "Percobaan OTP melebihi batas",
    };
  }

  const expectedHash = await hashOtp(email, purpose, otp);
  if (expectedHash === row.otp_hash) {
    const updatePayload: Record<string, unknown> = {
      verified_at: row.verified_at ?? nowIso(),
      updated_at: nowIso(),
    };
    if (args.consume === true) {
      updatePayload.consumed_at = nowIso();
    }
    const { data, error } = await client
      .from("auth_otp_challenges")
      .update(updatePayload)
      .eq("id", row.id)
      .select(
        "id,email,purpose,auth_user_id,full_name,expires_at,verified_at,consumed_at",
      )
      .single();
    if (error) {
      throw new Error(error.message);
    }
    return {
      valid: true,
      challenge_id: data.id,
      auth_user_id: data.auth_user_id,
      email: data.email,
      purpose: data.purpose,
      full_name: data.full_name,
      expires_at: data.expires_at,
    };
  }

  const nextAttemptCount = Number(row.attempt_count ?? 0) + 1;
  const remainingAttempts = Math.max(Number(row.max_attempts ?? 5) - nextAttemptCount, 0);
  const { error } = await client
    .from("auth_otp_challenges")
    .update({
      attempt_count: nextAttemptCount,
      updated_at: nowIso(),
    })
    .eq("id", row.id);
  if (error) {
    throw new Error(error.message);
  }
  return {
    valid: false,
    reason: "otp_invalid",
    message: "Kode OTP tidak valid",
    remaining_attempts: remainingAttempts,
  };
}

export async function consumeOtpChallenge(
  client: SupabaseClient,
  args: {
    email: string;
    purpose: OtpMode;
  },
): Promise<void> {
  const { error } = await client
    .from("auth_otp_challenges")
    .update({
      consumed_at: nowIso(),
      updated_at: nowIso(),
    })
    .eq("email", normalizeEmail(args.email))
    .eq("purpose", args.purpose);
  if (error) {
    throw new Error(error.message);
  }
}

export function getSupabaseAdminClient(): SupabaseClient {
  const supabaseUrl = Deno.env.get("SUPABASE_URL")?.trim() || "";
  const serviceRoleKey = Deno.env.get("SUPABASE_SERVICE_ROLE_KEY")?.trim() || "";

  if (!supabaseUrl || !serviceRoleKey) {
    throw new Error("SUPABASE_URL atau SUPABASE_SERVICE_ROLE_KEY belum diisi");
  }

  return createClient(supabaseUrl, serviceRoleKey, {
    auth: {
      persistSession: false,
      autoRefreshToken: false,
    },
  });
}

export async function rpc<T>(
  client: SupabaseClient,
  fn: string,
  params: Record<string, unknown>,
): Promise<T> {
  const { data, error } = await client.rpc(fn, params);
  if (error) {
    throw new Error(error.message);
  }
  return data as T;
}

export function errorMessage(error: unknown, fallback: string): string {
  if (error instanceof Error) {
    const message = error.message.trim();
    if (message.length > 0) {
      return message;
    }
  }
  const raw = String(error ?? "").trim();
  return raw.length > 0 ? raw : fallback;
}

export async function sendOtpEmail(args: {
  to: string;
  otp: string;
  mode: "signup" | "recovery";
}): Promise<void> {
  const subject = args.mode === "signup"
    ? `Verifikasi Email ${brandName}`
    : `Reset Password ${brandName}`;
  const html = otpEmailHtml({
    otp: args.otp,
    mode: args.mode,
  });

  if (brevoApiKey && (brevoSenderId > 0 || brevoFromEmail)) {
    const sender = brevoSenderId > 0
      ? { id: brevoSenderId }
      : { name: brevoFromName, email: brevoFromEmail };
    const response = await fetch("https://api.brevo.com/v3/smtp/email", {
      method: "POST",
      headers: {
        "api-key": brevoApiKey,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        sender,
        to: [{ email: args.to }],
        subject,
        htmlContent: html,
      }),
    });

    if (!response.ok) {
      const detail = await response.text();
      throw new Error(`Gagal mengirim email OTP via Brevo: ${detail}`);
    }
    return;
  }

  if (resendApiKey && resendFromEmail) {
    const response = await fetch("https://api.resend.com/emails", {
      method: "POST",
      headers: {
        Authorization: `Bearer ${resendApiKey}`,
        "Content-Type": "application/json",
      },
      body: JSON.stringify({
        from: `${resendFromName} <${resendFromEmail}>`,
        to: [args.to],
        subject,
        html,
      }),
    });

    if (!response.ok) {
      const detail = await response.text();
      throw new Error(`Gagal mengirim email OTP: ${detail}`);
    }
    return;
  }

  if (smtpHost && smtpPort > 0 && smtpUsername && smtpPassword && smtpFromEmail) {
    const secure = smtpEncryption === "ssl" ||
      smtpEncryption === "tls" ||
      smtpEncryption === "smtps" ||
      smtpPort === 465;
    const transporter = nodemailer.createTransport({
      host: smtpHost,
      port: smtpPort,
      secure,
      auth: {
        user: smtpUsername,
        pass: smtpPassword,
      },
    });

    await transporter.sendMail({
      from: `${smtpFromName} <${smtpFromEmail}>`,
      to: args.to,
      subject,
      html,
    });
    return;
  }

  throw new Error(
    "Secret email provider belum diisi. Gunakan BREVO_*, RESEND_*, atau MAIL_* di Supabase Edge Functions",
  );
}

function otpEmailHtml(args: {
  otp: string;
  mode: "signup" | "recovery";
}): string {
  const headline = args.mode === "signup"
    ? "Verifikasi Email Kamu"
    : "Reset Password Kamu";
  const intro = args.mode === "signup"
    ? `Gunakan kode OTP 4 digit berikut untuk menyelesaikan pendaftaran akun ${brandName}.`
    : `Gunakan kode OTP 4 digit berikut untuk mengatur ulang password akun ${brandName}.`;

  return `<!DOCTYPE html>
<html lang="id">
  <body style="margin:0;padding:0;background:#f6f8f7;font-family:Arial,Helvetica,sans-serif;color:#183153;">
    <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="background:#f6f8f7;padding:32px 16px;">
      <tr>
        <td align="center">
          <table role="presentation" width="100%" cellpadding="0" cellspacing="0" style="max-width:560px;background:#ffffff;border-radius:20px;overflow:hidden;border:1px solid #dde7e3;">
            <tr>
              <td style="background:linear-gradient(135deg,#0f766e,#1f8a70);padding:28px 32px;color:#ffffff;">
                <div style="font-size:12px;letter-spacing:2px;font-weight:700;opacity:.9;">${brandName.toUpperCase()}</div>
                <h1 style="margin:10px 0 0;font-size:28px;line-height:1.2;">${headline}</h1>
                <p style="margin:10px 0 0;font-size:14px;line-height:1.6;color:#dff7f1;">Kode berlaku selama 10 menit.</p>
              </td>
            </tr>
            <tr>
              <td style="padding:32px;">
                <p style="margin:0 0 14px;font-size:15px;line-height:1.7;">Assalamu'alaikum,</p>
                <p style="margin:0 0 20px;font-size:15px;line-height:1.7;">${intro}</p>
                <div style="margin:0 0 24px;padding:18px 20px;border-radius:16px;background:#f0fdfa;border:1px solid #bfe8df;text-align:center;">
                  <div style="font-size:12px;font-weight:700;letter-spacing:2px;color:#0f766e;margin-bottom:8px;">KODE OTP</div>
                  <div style="font-size:34px;font-weight:800;letter-spacing:10px;color:#134e4a;">${args.otp}</div>
                </div>
                <p style="margin:0 0 12px;font-size:14px;line-height:1.7;">Kode ini bersifat rahasia dan hanya berlaku sementara. Jangan bagikan kode ini kepada siapa pun.</p>
                <p style="margin:0;font-size:12px;line-height:1.7;color:#5b6b67;">Email ini dikirim otomatis oleh sistem ${brandName}.</p>
              </td>
            </tr>
          </table>
        </td>
      </tr>
    </table>
  </body>
</html>`;
}
