#!/usr/bin/env python3
import json
import sys
import time
import urllib.error
import urllib.request
import uuid


def http_json(method, url, payload=None, token=None):
    body = None
    headers = {"Accept": "application/json"}
    if payload is not None:
        body = json.dumps(payload).encode("utf-8")
        headers["Content-Type"] = "application/json"
    if token:
        headers["Authorization"] = f"Bearer {token}"

    req = urllib.request.Request(url, data=body, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=15) as resp:
            raw = resp.read().decode("utf-8")
            return resp.status, json.loads(raw) if raw else None
    except urllib.error.HTTPError as e:
        raw = e.read().decode("utf-8")
        try:
            parsed = json.loads(raw) if raw else None
        except json.JSONDecodeError:
            parsed = {"raw": raw}
        return e.code, parsed


def is_success(payload):
    if not isinstance(payload, dict):
        return False
    status = payload.get("status")
    return status is True or (isinstance(status, str) and status.lower() == "success")


def pick_message(payload, fallback=""):
    if isinstance(payload, dict):
        for key in ("pesan", "message"):
            value = payload.get(key)
            if isinstance(value, str) and value.strip():
                return value
    return fallback


def assert_ok(name, condition, detail=""):
    mark = "OK" if condition else "FAIL"
    print(f"[{mark}] {name}{': ' + detail if detail else ''}")
    if not condition:
        raise SystemExit(1)


def main():
    base_url = (sys.argv[1] if len(sys.argv) > 1 else "http://127.0.0.1:5000").rstrip("/")
    email = f"smoke_{uuid.uuid4().hex[:8]}@example.com"
    password = "Password123"
    new_password = "PasswordBaru123"

    print(f"Base URL: {base_url}")
    print(f"Smoke user: {email}")

    status, payload = http_json("GET", f"{base_url}/")
    assert_ok("GET /", status == 200, str(status))

    status, payload = http_json("POST", f"{base_url}/api/auth/register", {
        "nama": "Smoke User",
        "email": email,
        "password": password,
    })
    assert_ok("POST /api/auth/register", status in (200, 201) and is_success(payload), pick_message(payload, str(status)))
    register_payload = payload.get("data") or {}
    assert_ok("register requires verification", register_payload.get("requires_verification") is True)
    register_otp = register_payload.get("otp_debug")
    assert_ok("register returns otp_debug (dev)", isinstance(register_otp, str) and len(register_otp) == 6)

    status, payload = http_json("POST", f"{base_url}/api/auth/login", {"email": email, "password": password})
    assert_ok("POST /api/auth/login blocked before verification", status == 403 and not is_success(payload), pick_message(payload, str(status)))

    status, payload = http_json("POST", f"{base_url}/api/auth/verifikasi-otp-register", {"email": email, "kode": register_otp})
    assert_ok("POST /api/auth/verifikasi-otp-register", status == 200 and is_success(payload), pick_message(payload, str(status)))
    token = payload.get("data", {}).get("token")
    assert_ok("register verification returns token", isinstance(token, str) and len(token) > 10)

    status, payload = http_json("POST", f"{base_url}/api/auth/google", {"email": email})
    assert_ok("POST /api/auth/google stub", status == 501 and not is_success(payload), pick_message(payload, str(status)))

    status, payload = http_json("POST", f"{base_url}/api/auth/lupa-password", {"email": email})
    assert_ok("POST /api/auth/lupa-password", status == 200 and is_success(payload), pick_message(payload, str(status)))
    otp = (payload or {}).get("data", {}).get("otp_debug")
    assert_ok("lupa-password returns otp_debug (dev)", isinstance(otp, str) and len(otp) == 6)

    status, payload = http_json("POST", f"{base_url}/api/auth/verifikasi-otp", {"email": email, "kode": otp})
    assert_ok("POST /api/auth/verifikasi-otp", status == 200 and is_success(payload), pick_message(payload, str(status)))

    status, payload = http_json("POST", f"{base_url}/api/auth/reset-password", {
        "email": email,
        "kode": otp,
        "password_baru": new_password,
    })
    assert_ok("POST /api/auth/reset-password", status == 200 and is_success(payload), pick_message(payload, str(status)))

    status, payload = http_json("POST", f"{base_url}/api/auth/login", {"email": email, "password": new_password})
    assert_ok("POST /api/auth/login (new password)", status == 200 and is_success(payload), pick_message(payload, str(status)))
    token = payload.get("data", {}).get("token")
    assert_ok("login returns token", isinstance(token, str) and len(token) > 10)

    status, payload = http_json("GET", f"{base_url}/api/berita?limit=10")
    assert_ok("GET /api/berita?limit=10", status == 200 and is_success(payload), pick_message(payload, str(status)))

    status, payload = http_json("GET", f"{base_url}/api/screener")
    assert_ok("GET /api/screener", status == 200 and is_success(payload), pick_message(payload, str(status)))

    status, payload = http_json("GET", f"{base_url}/api/kelas")
    assert_ok("GET /api/kelas", status == 200 and is_success(payload), pick_message(payload, str(status)))
    kelas_list = payload.get("data") or []
    assert_ok("kelas available", isinstance(kelas_list, list) and len(kelas_list) > 0)
    kelas_id = kelas_list[0]["id"]

    status, payload = http_json("GET", f"{base_url}/api/kelas/{kelas_id}")
    assert_ok("GET /api/kelas/{id}", status == 200 and is_success(payload), pick_message(payload, str(status)))
    kelas_detail = payload.get("data") or {}
    modul = kelas_detail.get("modul") or []
    quiz_items = kelas_detail.get("quiz") or []
    materi_ids = []
    for m in modul:
        for materi in (m.get("materi") or []):
            materi_ids.append(materi.get("id"))
    assert_ok("kelas detail has materi", len(materi_ids) > 0)
    assert_ok("kelas detail has quiz", len(quiz_items) > 0)

    for materi_id in materi_ids:
        status, payload = http_json("POST", f"{base_url}/api/materi/complete", {"materi_id": materi_id}, token=token)
        assert_ok(f"POST /api/materi/complete ({materi_id})", status == 200 and is_success(payload), pick_message(payload, str(status)))

    for quiz in quiz_items:
        quiz_id = quiz["id"]
        jawaban_benar = None
        for choice in ("A", "B", "C", "D"):
            status, payload = http_json("POST", f"{base_url}/api/quiz/submit", {"quiz_id": quiz_id, "jawaban": choice}, token=token)
            assert_ok(f"POST /api/quiz/submit ({quiz_id}, {choice})", status == 200 and is_success(payload), pick_message(payload, str(status)))
            data = payload.get("data") or {}
            if data.get("benar") is True:
                break
            jawaban_benar = data.get("jawaban_benar")
            if isinstance(jawaban_benar, str) and jawaban_benar in ("A", "B", "C", "D"):
                # Resubmit correct answer so latest submission counts as correct for progress.
                status, payload = http_json(
                    "POST",
                    f"{base_url}/api/quiz/submit",
                    {"quiz_id": quiz_id, "jawaban": jawaban_benar},
                    token=token,
                )
                assert_ok(f"POST /api/quiz/submit ({quiz_id}, corrected)", status == 200 and is_success(payload), pick_message(payload, str(status)))
                break

    status, payload = http_json("GET", f"{base_url}/api/kelas/{kelas_id}/progress", token=token)
    assert_ok("GET /api/kelas/{id}/progress", status == 200 and is_success(payload), pick_message(payload, str(status)))
    progress = payload.get("data") or {}
    assert_ok("eligible certificate", progress.get("is_eligible_certificate") is True, str(progress.get("score_percent")))

    status, payload = http_json("POST", f"{base_url}/api/sertifikat/generate", {"kelas_id": kelas_id}, token=token)
    assert_ok("POST /api/sertifikat/generate", status == 200 and is_success(payload), pick_message(payload, str(status)))

    print("Smoke test completed successfully.")


if __name__ == "__main__":
    main()
