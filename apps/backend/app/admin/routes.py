import os
from datetime import datetime, timedelta
from functools import wraps
from uuid import uuid4

from flask import (
    Blueprint,
    current_app,
    flash,
    redirect,
    render_template,
    request,
    send_from_directory,
    session,
    url_for,
)
from werkzeug.security import check_password_hash
from werkzeug.utils import secure_filename
from sqlalchemy import func

from app.extensions import db
from app.models import Berita, Buku, Diskusi, KategoriBuku, Kelas, Materi, Modul, Quiz, Screener, Sertifikat, User

admin_bp = Blueprint("admin", __name__, url_prefix="/admin", template_folder="templates")


ENTITY_CONFIG = {
    "kelas": {
        "label": "Kelas",
        "model": Kelas,
        "fields": [
            {"name": "judul", "label": "Judul", "type": "text"},
            {"name": "deskripsi", "label": "Deskripsi", "type": "textarea"},
            {"name": "tingkat", "label": "Tingkat", "type": "text"},
        ],
    },
    "modul": {
        "label": "Modul",
        "model": Modul,
        "fields": [
            {"name": "kelas_id", "label": "Kelas", "type": "select", "model": Kelas, "option_label": "judul"},
            {"name": "judul", "label": "Judul", "type": "text"},
            {"name": "deskripsi", "label": "Deskripsi", "type": "textarea"},
            {"name": "urutan", "label": "Urutan", "type": "number"},
        ],
    },
    "materi": {
        "label": "Materi",
        "model": Materi,
        "fields": [
            {"name": "modul_id", "label": "Modul", "type": "select", "model": Modul, "option_label": "judul"},
            {"name": "judul", "label": "Judul", "type": "text"},
            {"name": "konten", "label": "Konten", "type": "textarea"},
            {"name": "url_video", "label": "URL Video", "type": "text"},
            {"name": "urutan", "label": "Urutan", "type": "number"},
        ],
    },
    "quiz": {
        "label": "Quiz",
        "model": Quiz,
        "fields": [
            {"name": "kelas_id", "label": "Kelas", "type": "select", "model": Kelas, "option_label": "judul"},
            {"name": "pertanyaan", "label": "Pertanyaan", "type": "textarea"},
            {"name": "pilihan_a", "label": "Pilihan A", "type": "text"},
            {"name": "pilihan_b", "label": "Pilihan B", "type": "text"},
            {"name": "pilihan_c", "label": "Pilihan C", "type": "text"},
            {"name": "pilihan_d", "label": "Pilihan D", "type": "text"},
            {"name": "jawaban_benar", "label": "Jawaban Benar (A/B/C/D)", "type": "text"},
        ],
    },
    "sertifikat": {
        "label": "Sertifikat",
        "model": Sertifikat,
        "fields": [
            {"name": "kelas_id", "label": "Kelas", "type": "select", "model": Kelas, "option_label": "judul"},
            {"name": "nama_template", "label": "Nama Template", "type": "text"},
            {"name": "deskripsi", "label": "Deskripsi", "type": "textarea"},
        ],
    },
    "buku": {
        "label": "Buku",
        "model": Buku,
        "fields": [
            {"name": "kategori_id", "label": "Kategori", "type": "select", "model": KategoriBuku, "option_label": "nama"},
            {"name": "judul", "label": "Judul", "type": "text"},
            {"name": "slug", "label": "Slug", "type": "text"},
            {"name": "penulis", "label": "Penulis", "type": "text"},
            {"name": "deskripsi", "label": "Deskripsi", "type": "textarea"},
            {"name": "drive_file_id", "label": "Google Drive File ID", "type": "text"},
            {
                "name": "status",
                "label": "Status Publish",
                "type": "choice",
                "options": [("draft", "Draft"), ("published", "Published"), ("archived", "Archived")],
            },
            {
                "name": "akses",
                "label": "Akses",
                "type": "choice",
                "options": [("gratis", "Gratis"), ("premium", "Premium"), ("internal", "Internal")],
            },
            {
                "name": "bahasa",
                "label": "Bahasa",
                "type": "choice",
                "options": [("id", "Indonesia"), ("en", "English")],
            },
            {"name": "is_featured", "label": "Unggulan", "type": "boolean"},
            {
                "name": "cover_key",
                "label": "Cover",
                "type": "file",
                "accept": "image/*",
                "upload_subdir": "pustaka/cover",
                "link_text": "Lihat Cover",
            },
            {
                "name": "file_key",
                "label": "File Ebook",
                "type": "file",
                "accept": ".pdf,.epub,application/pdf,application/epub+zip",
                "upload_subdir": "pustaka/ebook",
                "link_text": "Lihat File",
            },
        ],
    },
    "kategori_buku": {
        "label": "Kategori Buku",
        "model": KategoriBuku,
        "fields": [
            {"name": "nama", "label": "Nama", "type": "text"},
            {"name": "slug", "label": "Slug", "type": "text"},
            {"name": "urutan", "label": "Urutan", "type": "number"},
            {"name": "is_active", "label": "Aktif", "type": "boolean"},
        ],
    },
    "screener": {
        "label": "Screener",
        "model": Screener,
        "fields": [
            {"name": "nama_koin", "label": "Nama Koin", "type": "text"},
            {"name": "simbol", "label": "Simbol", "type": "text"},
            {"name": "status", "label": "Status", "type": "text"},
            {"name": "alasan", "label": "Alasan", "type": "textarea"},
        ],
    },
    "berita": {
        "label": "Berita",
        "model": Berita,
        "fields": [
            {"name": "judul", "label": "Judul", "type": "text"},
            {"name": "ringkasan", "label": "Ringkasan", "type": "textarea"},
            {"name": "konten", "label": "Konten", "type": "textarea"},
            {"name": "sumber_url", "label": "URL Sumber", "type": "text"},
        ],
    },
    "diskusi": {
        "label": "Diskusi",
        "model": Diskusi,
        "fields": [
            {"name": "user_id", "label": "Pengguna", "type": "select", "model": User, "option_label": "nama"},
            {"name": "judul", "label": "Judul", "type": "text"},
            {"name": "isi", "label": "Isi", "type": "textarea"},
        ],
    },
    "pengguna": {
        "label": "Pengguna",
        "model": User,
        "fields": [
            {"name": "nama", "label": "Nama", "type": "text"},
            {"name": "email", "label": "Email", "type": "text"},
            {"name": "role", "label": "Role", "type": "text"},
        ],
    },
}

LMS_ENTITY_KEYS = ("kelas", "modul", "materi", "quiz", "sertifikat")

SIDEBAR_ITEMS = [
    ("dashboard", "Dashboard"),
    ("lms", "LMS"),
    ("buku", "Buku"),
    ("kategori_buku", "Kategori Buku"),
    ("screener", "Screener"),
    ("berita", "Berita"),
    ("diskusi", "Diskusi"),
    ("pengguna", "Pengguna"),
]


@admin_bp.app_context_processor
def inject_sidebar():
    return {"sidebar_items": SIDEBAR_ITEMS, "lms_entity_keys": LMS_ENTITY_KEYS}


def admin_login_required(view_func):
    @wraps(view_func)
    def wrapper(*args, **kwargs):
        if not session.get("admin_id"):
            return redirect(url_for("admin.login_admin"))
        return view_func(*args, **kwargs)

    return wrapper


@admin_bp.route("/uploads/<path:filename>")
@admin_login_required
def uploaded_file(filename):
    return send_from_directory(current_app.config["UPLOAD_FOLDER"], filename)


@admin_bp.route("/login", methods=["GET", "POST"])
def login_admin():
    if request.method == "POST":
        email = (request.form.get("email") or "").strip().lower()
        password = request.form.get("password") or ""
        admin = User.query.filter_by(email=email, role="admin").first()

        if not admin or not admin.password_hash or not check_password_hash(admin.password_hash, password):
            flash("Email atau password admin salah", "danger")
            return render_template("admin/login.html")

        session["admin_id"] = admin.id
        session["admin_nama"] = admin.nama
        return redirect(url_for("admin.dashboard"))

    return render_template("admin/login.html")


@admin_bp.get("/logout")
def logout_admin():
    session.clear()
    return redirect(url_for("admin.login_admin"))


@admin_bp.get("/")
@admin_login_required
def dashboard():
    today = datetime.utcnow().date()
    trend_labels = [(today - timedelta(days=offset)).strftime("%d %b") for offset in reversed(range(6, -1, -1))]

    user_daily = (
        db.session.query(func.date(User.created_at), func.count(User.id))
        .group_by(func.date(User.created_at))
        .all()
    )
    diskusi_daily = (
        db.session.query(func.date(Diskusi.created_at), func.count(Diskusi.id))
        .group_by(func.date(Diskusi.created_at))
        .all()
    )
    berita_daily = (
        db.session.query(func.date(Berita.published_at), func.count(Berita.id))
        .group_by(func.date(Berita.published_at))
        .all()
    )

    def _to_map(rows):
        out = {}
        for raw_date, count in rows:
            key = str(raw_date)
            out[key] = int(count)
        return out

    user_map = _to_map(user_daily)
    diskusi_map = _to_map(diskusi_daily)
    berita_map = _to_map(berita_daily)

    trend_dates = [(today - timedelta(days=offset)).isoformat() for offset in reversed(range(6, -1, -1))]
    trend_data = {
        "users": [user_map.get(d, 0) for d in trend_dates],
        "diskusi": [diskusi_map.get(d, 0) for d in trend_dates],
        "berita": [berita_map.get(d, 0) for d in trend_dates],
    }

    screener_rows = db.session.query(Screener.status, func.count(Screener.id)).group_by(Screener.status).all()
    screener_distribution = {str(status).title(): int(count) for status, count in screener_rows}

    latest_users = User.query.order_by(User.created_at.desc()).limit(5).all()
    latest_discussions = Diskusi.query.order_by(Diskusi.created_at.desc()).limit(5).all()

    summary = {
        "Pengguna": User.query.count(),
        "Kelas": Kelas.query.count(),
        "Buku": Buku.query.count(),
        "Screener": Screener.query.count(),
        "Berita": Berita.query.count(),
        "Diskusi": Diskusi.query.count(),
    }
    return render_template(
        "admin/dashboard.html",
        summary=summary,
        active="dashboard",
        trend_labels=trend_labels,
        trend_data=trend_data,
        screener_distribution=screener_distribution,
        latest_users=latest_users,
        latest_discussions=latest_discussions,
    )


@admin_bp.get("/lms")
@admin_login_required
def lms():
    items = []
    for key in LMS_ENTITY_KEYS:
        cfg = ENTITY_CONFIG[key]
        items.append(
            {
                "key": key,
                "label": cfg["label"],
                "count": cfg["model"].query.count(),
            }
        )
    return render_template("admin/lms.html", title="LMS", active="lms", items=items)


def _get_config(entity_name):
    config = ENTITY_CONFIG.get(entity_name)
    if not config:
        raise KeyError("Entity tidak ditemukan")
    return config


def _coerce_value(field, value):
    if field["type"] in ["number", "select"]:
        return int(value) if value not in [None, ""] else None
    if field["type"] == "boolean":
        return str(value).strip().lower() in {"1", "true", "yes", "on"}
    return value


def _extract_form_data(config, form, files=None, obj=None):
    data = {}
    for field in config["fields"]:
        name = field["name"]
        if field["type"] == "file":
            file_obj = files.get(name) if files else None
            if file_obj and file_obj.filename:
                ext = os.path.splitext(file_obj.filename)[1]
                filename = secure_filename(f"{uuid4().hex}{ext}")
                subdir = field.get("upload_subdir", "").strip().replace("/", os.sep)
                upload_root = current_app.config["UPLOAD_FOLDER"]
                target_dir = os.path.join(upload_root, subdir) if subdir else upload_root
                os.makedirs(target_dir, exist_ok=True)
                path = os.path.join(target_dir, filename)
                file_obj.save(path)
                rel_path = os.path.relpath(path, upload_root).replace("\\", "/")
                data[name] = rel_path
                if name == "file_key":
                    data["file_pdf"] = rel_path if ext.lower() == ".pdf" else None
                    data["file_nama"] = secure_filename(file_obj.filename)
                    try:
                        data["ukuran_file_bytes"] = os.path.getsize(path)
                    except OSError:
                        data["ukuran_file_bytes"] = None
                    data["format_file"] = "epub" if ext.lower() == ".epub" else "pdf"
                    data["storage_provider"] = "local"
            elif obj is not None:
                data[name] = getattr(obj, name)
            else:
                data[name] = None
            continue

        raw_value = form.get(name)
        data[name] = _coerce_value(field, raw_value)
    return data


def _slugify_text(value: str) -> str:
    import re

    slug = re.sub(r"[^a-z0-9]+", "-", (value or "").strip().lower()).strip("-")
    return slug or "buku"


def _ensure_buku_slug_unique(slug: str, *, ignore_id=None):
    candidate = _slugify_text(slug)
    base = candidate
    i = 2
    query = Buku.query.filter(Buku.slug == candidate)
    if ignore_id is not None:
        query = query.filter(Buku.id != ignore_id)
    while query.first() is not None:
        candidate = f"{base}-{i}"
        i += 1
        query = Buku.query.filter(Buku.slug == candidate)
        if ignore_id is not None:
            query = query.filter(Buku.id != ignore_id)
    return candidate


def _prepare_buku_before_save(obj: Buku):
    obj.slug = _ensure_buku_slug_unique(obj.slug or obj.judul or "buku", ignore_id=obj.id)
    obj.storage_provider = obj.storage_provider or "local"
    if obj.file_key and not obj.file_nama:
        obj.file_nama = os.path.basename(obj.file_key)
    if obj.file_key and not obj.format_file:
        obj.format_file = "epub" if obj.file_key.lower().endswith(".epub") else "pdf"
    if (obj.status or "").lower() == "published":
        if not (obj.file_key or obj.file_pdf or getattr(obj, "drive_file_id", None)):
            raise ValueError("Buku tidak bisa dipublish tanpa file ebook atau Drive File ID")
        obj.published_at = obj.published_at or datetime.utcnow()
    elif (obj.status or "").lower() == "draft":
        obj.published_at = None


@admin_bp.route("/<entity_name>")
@admin_login_required
def list_entity(entity_name):
    config = _get_config(entity_name)
    model = config["model"]
    query = model.query

    selected_kelas_id = request.args.get("kelas_id", type=int)
    selected_kelas_title = None
    kelas_filter_enabled = entity_name in {"modul", "materi", "quiz", "sertifikat"}
    if kelas_filter_enabled and selected_kelas_id:
        selected = Kelas.query.get(selected_kelas_id)
        selected_kelas_title = selected.judul if selected else None
        if entity_name in {"modul", "quiz", "sertifikat"}:
            query = query.filter_by(kelas_id=selected_kelas_id)
        elif entity_name == "materi":
            query = query.join(Modul).filter(Modul.kelas_id == selected_kelas_id)

    rows = query.order_by(model.id.desc()).all()

    relation_maps = {}
    for field in config["fields"]:
        if field["type"] != "select" or "model" not in field:
            continue
        if entity_name == "materi" and field["name"] == "modul_id":
            modul_rows = (
                Modul.query.join(Kelas, Modul.kelas_id == Kelas.id)
                .add_columns(Kelas.judul.label("kelas_judul"))
                .all()
            )
            relation_maps[field["name"]] = {
                modul.id: f"{kelas_judul} / {modul.judul}" for modul, kelas_judul in modul_rows
            }
            continue

        options = field["model"].query.order_by(field["model"].id.asc()).all()
        relation_maps[field["name"]] = {
            opt.id: getattr(opt, field["option_label"], f"#{opt.id}") for opt in options
        }

    kelas_options = Kelas.query.order_by(Kelas.judul.asc()).all() if kelas_filter_enabled else []

    return render_template(
        "admin/entity_list.html",
        title=config["label"],
        entity_name=entity_name,
        rows=rows,
        fields=config["fields"],
        active=entity_name,
        relation_maps=relation_maps,
        kelas_filter_enabled=kelas_filter_enabled,
        kelas_options=kelas_options,
        selected_kelas_id=selected_kelas_id,
        selected_kelas_title=selected_kelas_title,
        filtered_count=len(rows),
    )


@admin_bp.route("/<entity_name>/tambah", methods=["GET", "POST"])
@admin_login_required
def create_entity(entity_name):
    config = _get_config(entity_name)
    model = config["model"]

    if request.method == "POST":
        data = _extract_form_data(config, request.form, request.files)
        try:
            obj = model(**data)
            if entity_name == "buku":
                _prepare_buku_before_save(obj)
        except ValueError as exc:
            flash(str(exc), "danger")
            return render_template(
                "admin/entity_form.html",
                title=f"Tambah {config['label']}",
                entity_name=entity_name,
                fields=config["fields"],
                obj=model(**{k: v for k, v in data.items() if hasattr(model, k)}),
                active=entity_name,
            )
        db.session.add(obj)
        db.session.commit()
        flash(f"Data {config['label']} berhasil ditambahkan", "success")
        return redirect(url_for("admin.list_entity", entity_name=entity_name))

    return render_template(
        "admin/entity_form.html",
        title=f"Tambah {config['label']}",
        entity_name=entity_name,
        fields=config["fields"],
        obj=None,
        active=entity_name,
    )


@admin_bp.route("/<entity_name>/<int:item_id>/edit", methods=["GET", "POST"])
@admin_login_required
def edit_entity(entity_name, item_id):
    config = _get_config(entity_name)
    model = config["model"]
    obj = model.query.get_or_404(item_id)

    if request.method == "POST":
        data = _extract_form_data(config, request.form, request.files, obj=obj)
        try:
            for key, value in data.items():
                setattr(obj, key, value)
            if entity_name == "buku":
                _prepare_buku_before_save(obj)
        except ValueError as exc:
            db.session.rollback()
            flash(str(exc), "danger")
            return render_template(
                "admin/entity_form.html",
                title=f"Edit {config['label']}",
                entity_name=entity_name,
                fields=config["fields"],
                obj=obj,
                active=entity_name,
            )
        db.session.commit()
        flash(f"Data {config['label']} berhasil diubah", "success")
        return redirect(url_for("admin.list_entity", entity_name=entity_name))

    return render_template(
        "admin/entity_form.html",
        title=f"Edit {config['label']}",
        entity_name=entity_name,
        fields=config["fields"],
        obj=obj,
        active=entity_name,
    )


@admin_bp.post("/<entity_name>/<int:item_id>/hapus")
@admin_login_required
def delete_entity(entity_name, item_id):
    config = _get_config(entity_name)
    model = config["model"]
    obj = model.query.get_or_404(item_id)

    db.session.delete(obj)
    db.session.commit()
    flash(f"Data {config['label']} berhasil dihapus", "success")
    return redirect(url_for("admin.list_entity", entity_name=entity_name))
