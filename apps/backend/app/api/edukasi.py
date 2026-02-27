from flask import Blueprint, request
from flask_jwt_extended import jwt_required

from app.extensions import db
from app.models import Kelas, Materi, MateriProgress, Modul, Quiz, QuizSubmission, Sertifikat

from .common import current_user_id, response_error, response_success

edukasi_bp = Blueprint("edukasi_api", __name__, url_prefix="/api")


def _kelas_structure(kelas: Kelas):
    modul_rows = sorted(kelas.modul, key=lambda x: (x.urutan, x.id))
    modul_data = []
    materi_ids = []
    for modul in modul_rows:
        materi_rows = Materi.query.filter_by(modul_id=modul.id).order_by(Materi.urutan.asc(), Materi.id.asc()).all()
        materi_ids.extend([m.id for m in materi_rows])
        modul_item = modul.to_dict()
        modul_item["materi"] = [m.to_dict() for m in materi_rows]
        modul_item["materi_count"] = len(materi_rows)
        modul_data.append(modul_item)
    return modul_data, materi_ids


def _quiz_latest_by_user(kelas_id: int, user_id: int):
    rows = (
        QuizSubmission.query.join(Quiz, QuizSubmission.quiz_id == Quiz.id)
        .filter(Quiz.kelas_id == kelas_id, QuizSubmission.user_id == user_id)
        .order_by(QuizSubmission.created_at.desc(), QuizSubmission.id.desc())
        .all()
    )
    latest = {}
    for item in rows:
        if item.quiz_id not in latest:
            latest[item.quiz_id] = item
    return latest


def _kelas_progress_data(kelas: Kelas, user_id: int):
    modul_data, materi_ids = _kelas_structure(kelas)
    total_materi = len(materi_ids)

    completed_ids = set()
    if materi_ids:
        progress_rows = (
            MateriProgress.query.filter(
                MateriProgress.user_id == user_id,
                MateriProgress.materi_id.in_(materi_ids),
            ).all()
        )
        completed_ids = {p.materi_id for p in progress_rows}

    quiz_rows = Quiz.query.filter_by(kelas_id=kelas.id).all()
    total_quiz = len(quiz_rows)
    latest_quiz = _quiz_latest_by_user(kelas.id, user_id) if total_quiz else {}
    answered_quiz = len(latest_quiz)
    correct_quiz = sum(1 for sub in latest_quiz.values() if sub.benar)
    score_percent = int((correct_quiz / total_quiz) * 100) if total_quiz else 0

    completed_materi = len(completed_ids)
    materi_complete = total_materi > 0 and completed_materi == total_materi
    quiz_complete = total_quiz > 0 and answered_quiz == total_quiz
    lulus = materi_complete and quiz_complete and score_percent >= 70

    return {
        "kelas_id": kelas.id,
        "kelas_judul": kelas.judul,
        "modul": modul_data,
        "total_materi": total_materi,
        "completed_materi": completed_materi,
        "completed_materi_ids": sorted(completed_ids),
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
    rows = Kelas.query.order_by(Kelas.id.desc()).all()
    return response_success("Berhasil mengambil data kelas", [row.to_dict() for row in rows])


@edukasi_bp.get("/kelas/<int:kelas_id>")
def detail_kelas(kelas_id):
    kelas = Kelas.query.get_or_404(kelas_id)
    data = kelas.to_dict()
    modul_data, _ = _kelas_structure(kelas)
    data["modul"] = modul_data
    data["quiz"] = [q.to_dict() for q in kelas.quiz]
    data["sertifikat"] = [s.to_dict() for s in kelas.sertifikat]
    return response_success("Berhasil mengambil detail kelas", data)


@edukasi_bp.get("/modul")
def list_modul():
    kelas_id = request.args.get("kelas_id", type=int)
    query = Modul.query
    if kelas_id:
        query = query.filter_by(kelas_id=kelas_id)
    rows = query.order_by(Modul.urutan.asc()).all()
    return response_success("Berhasil mengambil data modul", [row.to_dict() for row in rows])


@edukasi_bp.get("/materi")
def list_materi():
    modul_id = request.args.get("modul_id", type=int)
    query = Materi.query
    if modul_id:
        query = query.filter_by(modul_id=modul_id)
    rows = query.order_by(Materi.urutan.asc()).all()
    return response_success("Berhasil mengambil data materi", [row.to_dict() for row in rows])


@edukasi_bp.post("/quiz/submit")
@jwt_required()
def submit_quiz():
    user_id = current_user_id()
    payload = request.get_json() or {}
    quiz_id = payload.get("quiz_id")
    jawaban = (payload.get("jawaban") or "").upper().strip()

    quiz = Quiz.query.get(quiz_id)
    if not quiz:
        return response_error("Quiz tidak ditemukan", 404)
    if jawaban not in ["A", "B", "C", "D"]:
        return response_error("Jawaban tidak valid", 400)

    benar = quiz.jawaban_benar.upper() == jawaban
    submission = QuizSubmission(
        user_id=user_id, quiz_id=quiz.id, jawaban=jawaban, benar=benar
    )
    db.session.add(submission)
    db.session.commit()

    return response_success(
        "Jawaban quiz berhasil disimpan",
        {
            "quiz_id": quiz.id,
            "jawaban_benar": quiz.jawaban_benar,
            "jawaban_pengguna": jawaban,
            "benar": benar,
        },
    )


@edukasi_bp.post("/materi/complete")
@jwt_required()
def complete_materi():
    user_id = current_user_id()
    payload = request.get_json() or {}
    materi_id = payload.get("materi_id")

    materi = Materi.query.get(materi_id)
    if not materi:
        return response_error("Materi tidak ditemukan", 404)

    existing = MateriProgress.query.filter_by(user_id=user_id, materi_id=materi.id).first()
    if not existing:
        db.session.add(MateriProgress(user_id=user_id, materi_id=materi.id))
        db.session.commit()

    return response_success(
        "Progress materi berhasil disimpan",
        {"materi_id": materi.id, "status": "completed"},
    )


@edukasi_bp.get("/kelas/<int:kelas_id>/progress")
@jwt_required()
def progress_kelas(kelas_id):
    user_id = current_user_id()
    kelas = Kelas.query.get(kelas_id)
    if not kelas:
        return response_error("Kelas tidak ditemukan", 404)

    data = _kelas_progress_data(kelas, user_id)
    return response_success("Berhasil mengambil progress kelas", data)


@edukasi_bp.get("/kelas/last-learning")
@jwt_required()
def last_learning():
    user_id = current_user_id()

    latest_progress = (
        MateriProgress.query.join(Materi, MateriProgress.materi_id == Materi.id)
        .join(Modul, Materi.modul_id == Modul.id)
        .join(Kelas, Modul.kelas_id == Kelas.id)
        .filter(MateriProgress.user_id == user_id)
        .order_by(MateriProgress.completed_at.desc(), MateriProgress.id.desc())
        .first()
    )

    kelas = None
    last_materi = None
    if latest_progress:
        last_materi = latest_progress.materi
        if last_materi:
            kelas = Kelas.query.get(last_materi.modul.kelas_id) if last_materi.modul else None

    if kelas is None:
        kelas = Kelas.query.order_by(Kelas.id.asc()).first()
        if not kelas:
            return response_error("Belum ada kelas tersedia", 404)

    progress = _kelas_progress_data(kelas, user_id)
    next_materi_index = min(progress["completed_materi"] + 1, progress["total_materi"] or 1)

    data = {
        "kelas_id": kelas.id,
        "kelas_judul": kelas.judul,
        "completed_materi": progress["completed_materi"],
        "total_materi": progress["total_materi"],
        "progress_materi_percent": progress["progress_materi_percent"],
        "next_materi_index": next_materi_index,
        "last_materi_id": last_materi.id if last_materi else None,
        "last_materi_judul": last_materi.judul if last_materi else None,
    }
    return response_success("Berhasil mengambil kelas terakhir dipelajari", data)


@edukasi_bp.post("/sertifikat/generate")
@jwt_required()
def generate_sertifikat():
    user_id = current_user_id()
    payload = request.get_json() or {}
    kelas_id = payload.get("kelas_id")

    kelas = Kelas.query.get(kelas_id)
    if not kelas:
        return response_error("Kelas tidak ditemukan", 404)

    progress = _kelas_progress_data(kelas, user_id)
    if not progress["is_eligible_certificate"]:
        return response_error(
            "Sertifikat belum bisa dibuat. Selesaikan semua materi dan quiz dengan nilai minimal 70.",
            400,
        )

    template = Sertifikat.query.filter_by(kelas_id=kelas_id).first()
    nama_template = template.nama_template if template else "Sertifikat Kelulusan Averroes"

    return response_success(
        "Sertifikat dummy berhasil dibuat",
        {
            "user_id": user_id,
            "kelas": kelas.judul,
            "nama_sertifikat": nama_template,
            "nomor": f"AVR-{user_id}-{kelas.id}",
            "score_percent": progress["score_percent"],
        },
    )
