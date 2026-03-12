from datetime import datetime

from flask import Blueprint, make_response, request
from flask_jwt_extended import jwt_required
from bson import ObjectId

from app.extensions import mongo
from .common import current_user_id, response_error, response_success, format_doc

edukasi_bp = Blueprint("edukasi_api", __name__, url_prefix="/api")


def _kelas_structure(kelas):
    modul_rows = list(mongo.db.modul.find({"kelas_id": kelas["_id"]}).sort([("urutan", 1), ("_id", 1)]))
    modul_data = []
    materi_ids = []
    
    for modul in modul_rows:
        materi_rows = list(mongo.db.materi.find({"modul_id": modul["_id"]}).sort([("urutan", 1), ("_id", 1)]))
        materi_ids.extend([m["_id"] for m in materi_rows])
        modul_item = format_doc(modul)
        modul_item["materi"] = [format_doc(m) for m in materi_rows]
        modul_item["materi_count"] = len(materi_rows)
        modul_data.append(modul_item)
        
    return modul_data, materi_ids


def _quiz_latest_by_user(kelas_id, user_id):
    quiz_rows = list(mongo.db.quiz.find({"kelas_id": kelas_id}))
    quiz_ids = [q["_id"] for q in quiz_rows]
    
    submissions = list(mongo.db.quiz_submissions.find({
        "quiz_id": {"$in": quiz_ids}, 
        "user_id": user_id
    }).sort([("created_at", -1), ("_id", -1)]))
    
    latest = {}
    for item in submissions:
        qid = item["quiz_id"]
        if qid not in latest:
            latest[qid] = item
    return latest


def _kelas_progress_data(kelas, user_id):
    modul_data, materi_ids = _kelas_structure(kelas)
    total_materi = len(materi_ids)

    completed_ids = set()
    if materi_ids:
        progress_rows = list(mongo.db.materi_progress.find({
            "user_id": user_id,
            "materi_id": {"$in": materi_ids}
        }))
        completed_ids = {str(p["materi_id"]) for p in progress_rows}

    total_quiz = mongo.db.quiz.count_documents({"kelas_id": kelas["_id"]})
    latest_quiz = _quiz_latest_by_user(kelas["_id"], user_id) if total_quiz else {}
    answered_quiz = len(latest_quiz)
    correct_quiz = sum(1 for sub in latest_quiz.values() if sub.get("benar"))
    score_percent = int((correct_quiz / total_quiz) * 100) if total_quiz else 0

    completed_materi = len(completed_ids)
    materi_complete = total_materi > 0 and completed_materi == total_materi
    quiz_complete = total_quiz > 0 and answered_quiz == total_quiz
    lulus = materi_complete and quiz_complete and score_percent >= 95

    return {
        "kelas_id": str(kelas["_id"]),
        "kelas_judul": kelas.get("judul"),
        "modul": modul_data,
        "total_materi": total_materi,
        "completed_materi": completed_materi,
        "completed_materi_ids": sorted(list(completed_ids)),
        "progress_materi_percent": int((completed_materi / total_materi) * 100) if total_materi else 0,
        "total_quiz": total_quiz,
        "answered_quiz": answered_quiz,
        "correct_quiz": correct_quiz,
        "score_percent": score_percent,
        "is_materi_complete": materi_complete,
        "is_quiz_complete": quiz_complete,
        "is_eligible_certificate": lulus,
    }


@edukasi_bp.get("/kelas")
def list_kelas():
    rows = list(mongo.db.kelas.find().sort("_id", -1))
    return response_success("Berhasil mengambil data kelas", [format_doc(row) for row in rows])


@edukasi_bp.get("/kelas/<string:kelas_id>")
def detail_kelas(kelas_id):
    try:
        kelas = mongo.db.kelas.find_one({"_id": ObjectId(kelas_id)})
    except Exception:
        return response_error("Kelas tidak valid", 400)
        
    if not kelas:
        return response_error("Kelas tidak ditemukan", 404)
        
    data = format_doc(kelas)
    modul_data, _ = _kelas_structure(kelas)
    data["modul"] = modul_data
    
    quiz_rows = list(mongo.db.quiz.find({"kelas_id": kelas["_id"]}))
    data["quiz"] = [format_doc(q) for q in quiz_rows]
    
    sertifikat_rows = list(mongo.db.sertifikat.find({"kelas_id": kelas["_id"]}))
    data["sertifikat"] = [format_doc(s) for s in sertifikat_rows]
    
    return response_success("Berhasil mengambil detail kelas", data)


@edukasi_bp.get("/modul")
def list_modul():
    kelas_id = request.args.get("kelas_id", type=str)
    filters = {}
    if kelas_id:
        try:
            filters["kelas_id"] = ObjectId(kelas_id)
        except Exception:
            pass
            
    rows = list(mongo.db.modul.find(filters).sort("urutan", 1))
    return response_success("Berhasil mengambil data modul", [format_doc(row) for row in rows])


@edukasi_bp.get("/materi")
def list_materi():
    modul_id = request.args.get("modul_id", type=str)
    filters = {}
    if modul_id:
        try:
            filters["modul_id"] = ObjectId(modul_id)
        except Exception:
            pass
            
    rows = list(mongo.db.materi.find(filters).sort("urutan", 1))
    return response_success("Berhasil mengambil data materi", [format_doc(row) for row in rows])


@edukasi_bp.post("/quiz/submit")
@jwt_required()
def submit_quiz():
    from datetime import datetime
    user_id = current_user_id()
    payload = request.get_json() or {}
    quiz_id = payload.get("quiz_id")
    jawaban = (payload.get("jawaban") or "").upper().strip()

    try:
        quiz = mongo.db.quiz.find_one({"_id": ObjectId(quiz_id)})
    except Exception:
         return response_error("Quiz tidak valid", 400)
         
    if not quiz:
        return response_error("Quiz tidak ditemukan", 404)
    if jawaban not in ["A", "B", "C", "D"]:
        return response_error("Jawaban tidak valid", 400)

    benar = quiz.get("jawaban_benar", "").upper() == jawaban
    
    submission = {
        "user_id": user_id,
        "quiz_id": quiz["_id"],
        "jawaban": jawaban,
        "benar": benar,
        "created_at": datetime.utcnow()
    }
    mongo.db.quiz_submissions.insert_one(submission)

    return response_success(
        "Jawaban quiz berhasil disimpan",
        {
            "quiz_id": str(quiz["_id"]),
            "jawaban_benar": quiz.get("jawaban_benar"),
            "jawaban_pengguna": jawaban,
            "benar": benar,
        },
    )


@edukasi_bp.post("/materi/complete")
@jwt_required()
def complete_materi():
    from datetime import datetime
    user_id = current_user_id()
    payload = request.get_json() or {}
    materi_id = payload.get("materi_id")

    try:
        materi = mongo.db.materi.find_one({"_id": ObjectId(materi_id)})
    except Exception:
        return response_error("Materi tidak valid", 400)
        
    if not materi:
        return response_error("Materi tidak ditemukan", 404)

    existing = mongo.db.materi_progress.find_one({
        "user_id": user_id, 
        "materi_id": materi["_id"]
    })
    
    if not existing:
        progress = {
            "user_id": user_id,
            "materi_id": materi["_id"],
            "completed_at": datetime.utcnow()
        }
        mongo.db.materi_progress.insert_one(progress)

    return response_success(
        "Progress materi berhasil disimpan",
        {"materi_id": str(materi["_id"]), "status": "completed"},
    )


@edukasi_bp.get("/kelas/<string:kelas_id>/progress")
@jwt_required()
def progress_kelas(kelas_id):
    user_id = current_user_id()
    try:
        kelas = mongo.db.kelas.find_one({"_id": ObjectId(kelas_id)})
    except Exception:
         return response_error("Kelas tidak valid", 400)
         
    if not kelas:
        return response_error("Kelas tidak ditemukan", 404)

    data = _kelas_progress_data(kelas, user_id)
    return response_success("Berhasil mengambil progress kelas", data)


@edukasi_bp.get("/kelas/last-learning")
@jwt_required()
def last_learning():
    user_id = current_user_id()

    latest_progress = list(mongo.db.materi_progress.find({"user_id": user_id}).sort([("completed_at", -1), ("_id", -1)]).limit(1))
    
    kelas = None
    last_materi = None
    if latest_progress:
        progress = latest_progress[0]
        last_materi = mongo.db.materi.find_one({"_id": progress["materi_id"]})
        if last_materi:
            modul = mongo.db.modul.find_one({"_id": last_materi.get("modul_id")})
            if modul:
                kelas = mongo.db.kelas.find_one({"_id": modul.get("kelas_id")})

    if kelas is None:
        kelas = list(mongo.db.kelas.find().sort("_id", 1).limit(1))
        if not kelas:
            return response_error("Belum ada kelas tersedia", 404)
        kelas = kelas[0]

    progress_data = _kelas_progress_data(kelas, user_id)
    next_materi_index = min(progress_data["completed_materi"] + 1, progress_data["total_materi"] or 1)

    data = {
        "kelas_id": str(kelas["_id"]),
        "kelas_judul": kelas.get("judul"),
        "completed_materi": progress_data["completed_materi"],
        "total_materi": progress_data["total_materi"],
        "progress_materi_percent": progress_data["progress_materi_percent"],
        "next_materi_index": next_materi_index,
        "last_materi_id": str(last_materi["_id"]) if last_materi else None,
        "last_materi_judul": last_materi.get("judul") if last_materi else None,
    }
    return response_success("Berhasil mengambil kelas terakhir dipelajari", data)


@edukasi_bp.post("/sertifikat/generate")
@jwt_required()
def generate_sertifikat():
    user_id = current_user_id()
    payload = request.get_json() or {}
    kelas_id = payload.get("kelas_id")

    try:
        kelas = mongo.db.kelas.find_one({"_id": ObjectId(kelas_id)})
    except Exception:
         return response_error("Kelas tidak valid", 400)
         
    if not kelas:
        return response_error("Kelas tidak ditemukan", 404)

    progress = _kelas_progress_data(kelas, user_id)
    if not progress["is_eligible_certificate"]:
        return response_error(
            "Sertifikat belum bisa dibuat. Selesaikan semua materi dan quiz dengan nilai minimal 95.",
            400,
        )

    template = mongo.db.sertifikat.find_one({"kelas_id": kelas["_id"]})
    nama_template = template.get("nama_template") if template else "Sertifikat Kelulusan Averroes"
    nomor = f"AVR-{user_id}-{str(kelas['_id'])}"
    generated = {
        "user_id": user_id,
        "kelas_id": kelas["_id"],
        "kelas": kelas.get("judul"),
        "nama_sertifikat": nama_template,
        "nomor": nomor,
        "score_percent": progress["score_percent"],
        "generated_at": datetime.utcnow(),
        "download_url": f"/api/sertifikat/download/{user_id}/{str(kelas['_id'])}",
    }
    mongo.db.sertifikat_user.update_one(
        {"user_id": user_id, "kelas_id": kelas["_id"]},
        {"$set": generated},
        upsert=True,
    )

    return response_success(
        "Sertifikat berhasil dibuat",
        {
            "user_id": user_id,
            "kelas_id": str(kelas["_id"]),
            "kelas": kelas.get("judul"),
            "nama_sertifikat": nama_template,
            "nomor": nomor,
            "score_percent": progress["score_percent"],
            "generated_at": generated["generated_at"],
            "download_url": generated["download_url"],
        },
    )


@edukasi_bp.get("/sertifikat/saya")
@jwt_required()
def list_sertifikat_saya():
    user_id = current_user_id()
    rows = list(
        mongo.db.sertifikat_user.find({"user_id": user_id}).sort([("generated_at", -1), ("_id", -1)])
    )
    return response_success("Berhasil mengambil sertifikat saya", [format_doc(row) for row in rows])


@edukasi_bp.get("/sertifikat/download/<string:user_id>/<string:kelas_id>")
@jwt_required()
def download_sertifikat(user_id: str, kelas_id: str):
    current_user = current_user_id()
    if str(current_user) != user_id:
        return response_error("Akses ditolak", 403)
    try:
        kelas_oid = ObjectId(kelas_id)
    except Exception:
        return response_error("Kelas tidak valid", 400)

    row = mongo.db.sertifikat_user.find_one({"user_id": current_user, "kelas_id": kelas_oid})
    if not row:
        return response_error("Sertifikat tidak ditemukan", 404)

    user = mongo.db.users.find_one({"_id": ObjectId(current_user)}) if ObjectId.is_valid(current_user) else None
    if not user:
        user = mongo.db.users.find_one({"_id": current_user})
    nama_user = (user.get("nama") or user.get("Nama") or "Pengguna") if user else "Pengguna"

    nama_sertifikat = row.get("nama_sertifikat", "Sertifikat Kelulusan")
    kelas_nama = row.get("kelas", "-")
    nomor = row.get("nomor", "-")
    score = row.get("score_percent", 0)
    generated = row.get("generated_at", "")
    if hasattr(generated, "strftime"):
        generated = generated.strftime("%d %B %Y")
    else:
        generated = str(generated)[:10] if generated else "-"

    html = f"""<!DOCTYPE html>
<html lang="id">
<head>
<meta charset="UTF-8">
<meta name="viewport" content="width=device-width, initial-scale=1.0">
<title>Sertifikat - {nama_sertifikat}</title>
<style>
  @import url('https://fonts.googleapis.com/css2?family=Inter:wght@400;600;700;800&family=Playfair+Display:wght@700&display=swap');
  * {{ margin: 0; padding: 0; box-sizing: border-box; }}
  body {{ font-family: 'Inter', sans-serif; background: #f0fdf4; display: flex; justify-content: center; align-items: center; min-height: 100vh; padding: 20px; }}
  .cert {{ width: 100%; max-width: 720px; background: #fff; border-radius: 24px; border: 3px solid #065f46; position: relative; overflow: hidden; padding: 48px 40px; }}
  .cert::before {{ content: ''; position: absolute; top: 0; left: 0; right: 0; height: 8px; background: linear-gradient(90deg, #065f46, #13ECB9, #065f46); }}
  .cert::after {{ content: ''; position: absolute; bottom: 0; left: 0; right: 0; height: 8px; background: linear-gradient(90deg, #065f46, #13ECB9, #065f46); }}
  .corner {{ position: absolute; width: 60px; height: 60px; border: 3px solid #13ECB9; }}
  .corner.tl {{ top: 16px; left: 16px; border-right: none; border-bottom: none; border-radius: 12px 0 0 0; }}
  .corner.tr {{ top: 16px; right: 16px; border-left: none; border-bottom: none; border-radius: 0 12px 0 0; }}
  .corner.bl {{ bottom: 16px; left: 16px; border-right: none; border-top: none; border-radius: 0 0 0 12px; }}
  .corner.br {{ bottom: 16px; right: 16px; border-left: none; border-top: none; border-radius: 0 0 12px 0; }}
  .header {{ text-align: center; margin-bottom: 24px; }}
  .logo {{ font-size: 14px; font-weight: 800; color: #065f46; letter-spacing: 3px; text-transform: uppercase; }}
  .title {{ font-family: 'Playfair Display', serif; font-size: 32px; font-weight: 700; color: #065f46; margin: 16px 0 8px; }}
  .subtitle {{ font-size: 13px; color: #6b7280; font-weight: 600; }}
  .body {{ text-align: center; margin: 28px 0; }}
  .label {{ font-size: 12px; color: #9ca3af; font-weight: 600; text-transform: uppercase; letter-spacing: 1.5px; margin-bottom: 8px; }}
  .nama {{ font-family: 'Playfair Display', serif; font-size: 28px; font-weight: 700; color: #0d1b18; border-bottom: 2px solid #13ECB9; display: inline-block; padding-bottom: 4px; }}
  .kelas {{ font-size: 15px; font-weight: 700; color: #065f46; margin-top: 20px; }}
  .score {{ display: inline-block; margin-top: 12px; background: #ecfdf5; border: 1px solid #a7f3d0; border-radius: 999px; padding: 8px 20px; font-size: 14px; font-weight: 700; color: #065f46; }}
  .footer {{ display: flex; justify-content: space-between; align-items: flex-end; margin-top: 36px; padding-top: 20px; border-top: 1px dashed #d1d5db; }}
  .footer-col {{ text-align: center; }}
  .footer-col .val {{ font-size: 12px; font-weight: 700; color: #374151; }}
  .footer-col .lbl {{ font-size: 10px; color: #9ca3af; font-weight: 600; margin-top: 4px; }}
  .seal {{ width: 60px; height: 60px; background: linear-gradient(135deg, #065f46, #13ECB9); border-radius: 50%; display: flex; align-items: center; justify-content: center; color: #fff; font-size: 10px; font-weight: 800; letter-spacing: 1px; }}
</style>
</head>
<body>
<div class="cert">
  <div class="corner tl"></div>
  <div class="corner tr"></div>
  <div class="corner bl"></div>
  <div class="corner br"></div>
  <div class="header">
    <div class="logo">✦ AVERROES ✦</div>
    <div class="title">{nama_sertifikat}</div>
    <div class="subtitle">Platform Edukasi Aset Kripto Syariah</div>
  </div>
  <div class="body">
    <div class="label">Diberikan kepada</div>
    <div class="nama">{nama_user}</div>
    <div class="kelas">Telah menyelesaikan kelas:<br><strong>{kelas_nama}</strong></div>
    <div class="score">Nilai: {score}%</div>
  </div>
  <div class="footer">
    <div class="footer-col">
      <div class="val">{generated}</div>
      <div class="lbl">Tanggal Terbit</div>
    </div>
    <div class="seal">LULUS</div>
    <div class="footer-col">
      <div class="val">{nomor}</div>
      <div class="lbl">Nomor Sertifikat</div>
    </div>
  </div>
</div>
</body>
</html>"""
    resp = make_response(html)
    resp.headers["Content-Type"] = "text/html; charset=utf-8"
    return resp


@edukasi_bp.get("/sertifikat/view/<string:user_id>/<string:kelas_id>")
@jwt_required()
def view_sertifikat_json(user_id: str, kelas_id: str):
    """Return certificate data as JSON for the Flutter app preview."""
    current_user = current_user_id()
    if str(current_user) != user_id:
        return response_error("Akses ditolak", 403)
    try:
        kelas_oid = ObjectId(kelas_id)
    except Exception:
        return response_error("Kelas tidak valid", 400)

    row = mongo.db.sertifikat_user.find_one({"user_id": current_user, "kelas_id": kelas_oid})
    if not row:
        return response_error("Sertifikat tidak ditemukan", 404)

    user = mongo.db.users.find_one({"_id": ObjectId(current_user)}) if ObjectId.is_valid(current_user) else None
    if not user:
        user = mongo.db.users.find_one({"_id": current_user})
    nama_user = (user.get("nama") or user.get("Nama") or "Pengguna") if user else "Pengguna"

    return response_success("Berhasil mengambil data sertifikat", {
        "nama_user": nama_user,
        "nama_sertifikat": row.get("nama_sertifikat", "-"),
        "kelas": row.get("kelas", "-"),
        "nomor": row.get("nomor", "-"),
        "score_percent": row.get("score_percent", 0),
        "generated_at": str(row.get("generated_at", "")),
        "download_url": row.get("download_url", ""),
    })

