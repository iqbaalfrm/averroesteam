import os
from datetime import datetime, timedelta
from functools import wraps
from uuid import uuid4
from bson import ObjectId

from flask import (
    Blueprint, current_app, flash, redirect,
    render_template, request, send_from_directory, session, url_for
)
from werkzeug.security import check_password_hash
from werkzeug.utils import secure_filename

from app.extensions import mongo

admin_bp = Blueprint("admin", __name__, url_prefix="/admin", template_folder="templates")

ENTITY_CONFIG = {
    "kelas": {
        "label": "Kelas",
        "collection": "kelas",
        "fields": [
            {"name": "judul", "label": "Judul", "type": "text"},
            {"name": "deskripsi", "label": "Deskripsi", "type": "textarea"},
            {"name": "tingkat", "label": "Tingkat", "type": "text"},
        ],
    },
    "modul": {
        "label": "Modul",
        "collection": "modul",
        "fields": [
            {"name": "kelas_id", "label": "Kelas", "type": "select", "collection": "kelas", "option_label": "judul"},
            {"name": "judul", "label": "Judul", "type": "text"},
            {"name": "deskripsi", "label": "Deskripsi", "type": "textarea"},
            {"name": "urutan", "label": "Urutan", "type": "number"},
        ],
    },
    "materi": {
        "label": "Materi",
        "collection": "materi",
        "fields": [
            {"name": "modul_id", "label": "Modul", "type": "select", "collection": "modul", "option_label": "judul"},
            {"name": "judul", "label": "Judul", "type": "text"},
            {"name": "konten", "label": "Konten", "type": "textarea"},
            {"name": "url_video", "label": "URL Video", "type": "text"},
            {"name": "urutan", "label": "Urutan", "type": "number"},
        ],
    },
    "quiz": {
        "label": "Quiz",
        "collection": "quiz",
        "fields": [
            {"name": "kelas_id", "label": "Kelas", "type": "select", "collection": "kelas", "option_label": "judul"},
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
        "collection": "sertifikat",
        "fields": [
            {"name": "kelas_id", "label": "Kelas", "type": "select", "collection": "kelas", "option_label": "judul"},
            {"name": "nama_template", "label": "Nama Template", "type": "text"},
            {"name": "deskripsi", "label": "Deskripsi", "type": "textarea"},
        ],
    },
    "buku": {
        "label": "Buku",
        "collection": "buku",
        "fields": [
            {"name": "kategori_id", "label": "Kategori", "type": "select", "collection": "kategori_buku", "option_label": "nama"},
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
        "collection": "kategori_buku",
        "fields": [
            {"name": "nama", "label": "Nama", "type": "text"},
            {"name": "slug", "label": "Slug", "type": "text"},
            {"name": "urutan", "label": "Urutan", "type": "number"},
            {"name": "is_active", "label": "Aktif", "type": "boolean"},
        ],
    },
    "screener": {
        "label": "Screener",
        "collection": "screener",
        "fields": [
            {"name": "nama_koin", "label": "Nama Koin", "type": "text"},
            {"name": "simbol", "label": "Simbol", "type": "text"},
            {"name": "status", "label": "Status", "type": "text"},
            {"name": "alasan", "label": "Alasan", "type": "textarea"},
        ],
    },
    "berita": {
        "label": "Berita",
        "collection": "berita",
        "fields": [
            {"name": "judul", "label": "Judul", "type": "text"},
            {"name": "ringkasan", "label": "Ringkasan", "type": "textarea"},
            {"name": "konten", "label": "Konten", "type": "textarea"},
            {"name": "sumber_url", "label": "URL Sumber", "type": "text"},
        ],
    },
    "kajian": {
        "label": "Kajian",
        "collection": "kajian",
        "fields": [
            {"name": "judul", "label": "Judul", "type": "text"},
            {"name": "deskripsi", "label": "Deskripsi", "type": "textarea"},
            {"name": "youtube_url", "label": "Link YouTube", "type": "text"},
            {"name": "channel", "label": "Channel", "type": "text", "required": False},
            {"name": "kategori", "label": "Kategori", "type": "text", "required": False},
            {"name": "durasi_label", "label": "Durasi Label", "type": "text", "required": False},
            {"name": "urutan", "label": "Urutan", "type": "number", "required": False},
            {"name": "is_active", "label": "Aktif", "type": "boolean"},
        ],
    },
    "diskusi": {
        "label": "Diskusi",
        "collection": "diskusi",
        "fields": [
            {"name": "user_id", "label": "Pengguna", "type": "select", "collection": "users", "option_label": "nama"},
            {"name": "judul", "label": "Judul", "type": "text"},
            {"name": "isi", "label": "Isi", "type": "textarea"},
        ],
    },
    "pengguna": {
        "label": "Pengguna",
        "collection": "users",
        "fields": [
            {"name": "nama", "label": "Nama", "type": "text"},
            {"name": "email", "label": "Email", "type": "text"},
            {"name": "role", "label": "Role", "type": "text"},
        ],
    },
    "ahli_syariah": {
        "label": "Ahli Syariah",
        "collection": "ahli_syariah",
        "fields": [
            {"name": "nama", "label": "Nama", "type": "text"},
            {"name": "spesialis", "label": "Spesialis", "type": "text"},
            {"name": "harga_per_sesi", "label": "Harga / Sesi (IDR)", "type": "number"},
            {"name": "no_whatsapp", "label": "No WhatsApp", "type": "text"},
            {"name": "is_online", "label": "Online", "type": "boolean"},
            {"name": "is_verified", "label": "Verified", "type": "boolean"},
        ],
    },
    "sessions": {
        "label": "Transaksi Konsultasi",
        "collection": "sessions",
        "fields": [
            {"name": "user_id", "label": "Pengguna", "type": "select", "collection": "users", "option_label": "nama"},
            {"name": "ahli_id", "label": "Ahli Syariah", "type": "select", "collection": "ahli_syariah", "option_label": "nama"},
            {"name": "status", "label": "Status Bayar", "type": "text"},
            {"name": "harga", "label": "Nominal", "type": "number"},
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
    ("kajian", "Kajian"),
    ("diskusi", "Diskusi"),
    ("ahli_syariah", "Ahli Syariah"),
    ("sessions", "Transaksi"),
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
        admin = mongo.db.users.find_one({"email": email, "role": "admin"})

        if not admin or not admin.get("password_hash") or not check_password_hash(admin["password_hash"], password):
            flash("Email atau password admin salah", "danger")
            return render_template("admin/login.html")

        session["admin_id"] = str(admin["_id"])
        session["admin_nama"] = admin.get("nama")
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

    # Dummy trends for mongo rewrite, to avoid complex aggregation
    trend_data = {
        "users": [0]*7,
        "diskusi": [0]*7,
        "berita": [0]*7,
    }

    # Screener distro
    screener_dist = list(mongo.db.screener.aggregate([
        {"$group": {"_id": "$status", "count": {"$sum": 1}}}
    ]))
    screener_distribution = {str(item["_id"]).title(): item["count"] for item in screener_dist if item.get("_id")}

    latest_users = list(mongo.db.users.find().sort("created_at", -1).limit(5))
    latest_discussions = list(mongo.db.diskusi.find().sort("created_at", -1).limit(5))

    # map _id to id for old templates
    for o in latest_users + latest_discussions:
         o["id"] = str(o["_id"])

    summary = {
        "Pengguna": mongo.db.users.count_documents({}),
        "Kelas": mongo.db.kelas.count_documents({}),
        "Buku": mongo.db.buku.count_documents({}),
        "Screener": mongo.db.screener.count_documents({}),
        "Berita": mongo.db.berita.count_documents({}),
        "Kajian": mongo.db.kajian.count_documents({}),
        "Diskusi": mongo.db.diskusi.count_documents({}),
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
                "count": mongo.db[cfg["collection"]].count_documents({}),
            }
        )
    return render_template("admin/lms.html", title="LMS", active="lms", items=items)


def _get_config(entity_name):
    config = ENTITY_CONFIG.get(entity_name)
    if not config:
        raise KeyError("Entity tidak ditemukan")
    return config


def _coerce_value(field, value):
    if field["type"] == "number":
        return int(value) if value not in [None, ""] else None
    if field["type"] == "select":
        try:
            return ObjectId(value) if value not in [None, ""] else None
        except:
            return value
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
                data[name] = obj.get(name)
            else:
                data[name] = None
            continue

        raw_value = form.get(name)
        data[name] = _coerce_value(field, raw_value)
    return data


def _build_select_options(config):
    options_map = {}
    for field in config["fields"]:
        if field.get("type") != "select" or "collection" not in field:
            continue
        rel_col = field["collection"]
        label_key = field.get("option_label") or "nama"
        options = list(mongo.db[rel_col].find().sort("_id", 1))
        rows = []
        for opt in options:
            rows.append(
                {
                    "id": str(opt["_id"]),
                    "label": str(opt.get(label_key, opt.get("nama", opt.get("judul", "")))),
                }
            )
        options_map[field["name"]] = rows
    return options_map


@admin_bp.route("/<entity_name>")
@admin_login_required
def list_entity(entity_name):
    config = _get_config(entity_name)
    collection = config["collection"]
    query = {}
    
    rows = list(mongo.db[collection].find(query).sort("_id", -1))
    
    # Map _id -> id
    for r in rows:
        r["id"] = str(r["_id"])

    relation_maps = {}
    for field in config["fields"]:
        if field["type"] != "select" or "collection" not in field:
            continue
        
        rel_col = field["collection"]
        options = list(mongo.db[rel_col].find())
        relation_maps[field["name"]] = {
            # use _id since model relation
            str(opt["_id"]): str(opt.get(field.get("option_label"), opt.get("nama", opt.get("judul", "")))) for opt in options
        }

    return render_template(
        "admin/entity_list.html",
        title=config["label"],
        entity_name=entity_name,
        rows=rows,
        fields=config["fields"],
        active=entity_name,
        relation_maps=relation_maps,
        kelas_filter_enabled=False,
        kelas_options=[],
        selected_kelas_id=None,
        selected_kelas_title=None,
        filtered_count=len(rows),
    )


class DictObj(dict):
    def __getattr__(self, item):
         return self.get(item)


@admin_bp.route("/<entity_name>/tambah", methods=["GET", "POST"])
@admin_login_required
def create_entity(entity_name):
    config = _get_config(entity_name)
    collection = config["collection"]
    
    if request.method == "POST":
        data = _extract_form_data(config, request.form, request.files)
        data["created_at"] = datetime.utcnow()
        data["updated_at"] = datetime.utcnow()
        
        mongo.db[collection].insert_one(data)
        flash(f"Data {config['label']} berhasil ditambahkan", "success")
        return redirect(url_for("admin.list_entity", entity_name=entity_name))

    return render_template(
        "admin/entity_form.html",
        title=f"Tambah {config['label']}",
        entity_name=entity_name,
        fields=config["fields"],
        obj=None,
        select_options=_build_select_options(config),
        active=entity_name,
    )


@admin_bp.route("/<entity_name>/<string:item_id>/edit", methods=["GET", "POST"])
@admin_login_required
def edit_entity(entity_name, item_id):
    config = _get_config(entity_name)
    collection = config["collection"]
    
    try:
        obj = mongo.db[collection].find_one({"_id": ObjectId(item_id)})
    except:
        obj = None
    if not obj:
        flash("Data tidak ditemukan", "danger")
        return redirect(url_for("admin.list_entity", entity_name=entity_name))

    if request.method == "POST":
        data = _extract_form_data(config, request.form, request.files, obj=obj)
        data["updated_at"] = datetime.utcnow()
        
        mongo.db[collection].update_one({"_id": obj["_id"]}, {"$set": data})
        flash(f"Data {config['label']} berhasil diubah", "success")
        return redirect(url_for("admin.list_entity", entity_name=entity_name))

    # Convert object id fields for HTML form
    for k, v in obj.items():
        if isinstance(v, ObjectId):
             obj[k] = str(v)
             
    obj["id"] = str(obj["_id"])

    return render_template(
        "admin/entity_form.html",
        title=f"Edit {config['label']}",
        entity_name=entity_name,
        fields=config["fields"],
        obj=DictObj(obj),
        select_options=_build_select_options(config),
        active=entity_name,
    )


@admin_bp.post("/<entity_name>/<string:item_id>/hapus")
@admin_login_required
def delete_entity(entity_name, item_id):
    config = _get_config(entity_name)
    collection = config["collection"]
    try:
        mongo.db[collection].delete_one({"_id": ObjectId(item_id)})
        flash(f"Data {config['label']} berhasil dihapus", "success")
    except:
        flash("Gagal menghapus data", "danger")
    return redirect(url_for("admin.list_entity", entity_name=entity_name))
