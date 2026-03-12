from dataclasses import dataclass
from pathlib import Path
from uuid import uuid4

from flask import current_app, send_file
from itsdangerous import BadSignature, SignatureExpired, URLSafeTimedSerializer
from werkzeug.datastructures import FileStorage
from werkzeug.utils import secure_filename


@dataclass
class StoredObject:
    key: str
    filename: str
    size_bytes: int


def _serializer() -> URLSafeTimedSerializer:
    secret = current_app.config.get("SECRET_KEY") or "dev-insecure-secret-key"
    return URLSafeTimedSerializer(secret_key=secret, salt="pustaka-file-access")


def save_upload(file_obj: FileStorage, *, subdir: str, allowed_exts: set[str]) -> StoredObject:
    original_name = secure_filename(file_obj.filename or "")
    ext = Path(original_name).suffix.lower()
    if ext not in allowed_exts:
        raise ValueError(f"Ekstensi file tidak didukung: {ext or '(tanpa ekstensi)'}")

    base_dir = Path(current_app.config["UPLOAD_FOLDER"]).resolve()
    target_dir = (base_dir / subdir).resolve()
    target_dir.mkdir(parents=True, exist_ok=True)

    generated = f"{uuid4().hex}{ext}"
    abs_path = (target_dir / generated).resolve()
    if base_dir not in abs_path.parents and abs_path != base_dir:
        raise ValueError("Lokasi simpan file tidak valid")

    file_obj.save(str(abs_path))
    size = abs_path.stat().st_size if abs_path.exists() else 0
    rel_key = abs_path.relative_to(base_dir).as_posix()
    return StoredObject(key=rel_key, filename=original_name or generated, size_bytes=size)


def make_signed_file_token(*, buku_id: int, file_key: str, filename: str) -> str:
    payload = {"buku_id": int(buku_id), "file_key": file_key, "filename": filename}
    return _serializer().dumps(payload)


def parse_signed_file_token(token: str) -> dict:
    max_age = int(current_app.config.get("PUSTAKA_SIGNED_URL_EXPIRES_SECONDS", 600))
    try:
        payload = _serializer().loads(token, max_age=max_age)
    except SignatureExpired as exc:
        raise PermissionError("Tautan file kedaluwarsa") from exc
    except BadSignature as exc:
        raise PermissionError("Tautan file tidak valid") from exc
    if not isinstance(payload, dict):
        raise PermissionError("Payload file tidak valid")
    return payload


def send_local_object(
    file_key: str,
    *,
    download_name: str | None = None,
    as_attachment: bool = True,
):
    base_dir = Path(current_app.config["UPLOAD_FOLDER"]).resolve()
    abs_path = (base_dir / file_key).resolve()
    if base_dir not in abs_path.parents and abs_path != base_dir:
        raise FileNotFoundError("Path file di luar storage")
    if not abs_path.exists():
        raise FileNotFoundError("File tidak ditemukan")
    mimetype = _guess_mime(abs_path.suffix.lower())
    return send_file(
        abs_path,
        as_attachment=as_attachment,
        download_name=download_name or abs_path.name,
        mimetype=mimetype,
        conditional=False,
    )


def _guess_mime(ext: str) -> str:
    if ext == ".pdf":
        return "application/pdf"
    if ext == ".epub":
        return "application/epub+zip"
    if ext in {".jpg", ".jpeg"}:
        return "image/jpeg"
    if ext == ".png":
        return "image/png"
    if ext == ".webp":
        return "image/webp"
    return "application/octet-stream"
