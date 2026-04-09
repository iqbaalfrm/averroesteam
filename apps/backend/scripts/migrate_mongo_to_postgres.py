from __future__ import annotations

import argparse
import os
import secrets
import sys
import uuid
from dataclasses import dataclass, field
from datetime import UTC, datetime
from decimal import Decimal
from pathlib import Path
from typing import Any

import requests
from bson import ObjectId
from dotenv import load_dotenv

try:
    from pymongo import MongoClient
except ImportError as exc:  # pragma: no cover
    raise SystemExit("pymongo belum terpasang. Jalankan pip install -r requirements.txt") from exc

try:
    import psycopg
    from psycopg import sql
    from psycopg.types.json import Jsonb
except ImportError:  # pragma: no cover
    psycopg = None
    sql = None
    Jsonb = None


ROOT_DIR = Path(__file__).resolve().parents[3]
DEFAULT_SCHEMA_PATH = Path(__file__).resolve().parent / "sql" / "supabase_schema.sql"
DEFAULT_NAMESPACE = uuid.UUID("2e31dd0f-3b2c-46ef-9d36-c9a5d7d40d46")


def _parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Migrasi data MongoDB Averroes ke PostgreSQL/Supabase.",
    )
    parser.add_argument(
        "--apply-schema",
        action="store_true",
        help="Jalankan file schema SQL sebelum proses migrasi.",
    )
    parser.add_argument(
        "--schema-path",
        default=str(DEFAULT_SCHEMA_PATH),
        help="Path file schema SQL PostgreSQL.",
    )
    parser.add_argument(
        "--create-auth-users",
        action="store_true",
        help="Buat user Supabase Auth via Admin API jika email tersedia.",
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="Hanya validasi koneksi dan hitung data, tanpa menulis ke PostgreSQL.",
    )
    return parser.parse_args()


def _env_bool(name: str, default: bool = False) -> bool:
    raw = os.getenv(name)
    if raw is None:
        return default
    return raw.strip().lower() in {"1", "true", "yes", "on"}


def _utc(dt: Any) -> datetime | None:
    if dt is None:
        return None
    if isinstance(dt, datetime):
        if dt.tzinfo is None:
            return dt.replace(tzinfo=UTC)
        return dt.astimezone(UTC)
    return None


def _serialize_json(value: Any) -> Any:
    if isinstance(value, ObjectId):
        return str(value)
    if isinstance(value, datetime):
        return (_utc(value) or value).isoformat()
    if isinstance(value, Decimal):
        return str(value)
    if isinstance(value, uuid.UUID):
        return str(value)
    if isinstance(value, dict):
        return {str(k): _serialize_json(v) for k, v in value.items()}
    if isinstance(value, (list, tuple, set)):
        return [_serialize_json(v) for v in value]
    return value


def _jsonb(value: Any) -> Any:
    payload = _serialize_json(value)
    if Jsonb is None:
        return payload
    return Jsonb(payload)


def _text(value: Any) -> str | None:
    if value is None:
        return None
    text = str(value).strip()
    return text or None


def _email(value: Any) -> str | None:
    text = _text(value)
    return text.lower() if text else None


def _int(value: Any, default: int = 0) -> int:
    if value in (None, ""):
        return default
    try:
        return int(value)
    except (TypeError, ValueError):
        try:
            return int(float(value))
        except (TypeError, ValueError):
            return default


def _decimal(value: Any, default: str = "0") -> Decimal:
    if value in (None, ""):
        return Decimal(default)
    try:
        return Decimal(str(value))
    except Exception:
        return Decimal(default)


def _bool(value: Any, default: bool = False) -> bool:
    if value is None:
        return default
    if isinstance(value, bool):
        return value
    if isinstance(value, str):
        return value.strip().lower() in {"1", "true", "yes", "on"}
    return bool(value)


def _uuid_from_text(value: Any) -> uuid.UUID | None:
    text = _text(value)
    if not text:
        return None
    try:
        return uuid.UUID(text)
    except ValueError:
        return None


def _extra_data(document: dict[str, Any], consumed: set[str]) -> dict[str, Any]:
    return {
        key: _serialize_json(value)
        for key, value in document.items()
        if key not in consumed
    }


def _legacy_id(document: dict[str, Any], fallback_key: str | None = None) -> str:
    if document.get("_id") is not None:
        return str(document["_id"])
    if fallback_key:
        return fallback_key
    raise ValueError("Dokumen tidak memiliki _id")


class UpsertWriter:
    def __init__(self, connection):
        self.connection = connection

    def upsert(
        self,
        table_name: str,
        row: dict[str, Any],
        *,
        conflict_columns: tuple[str, ...] = ("legacy_mongo_id",),
        update_exclude: tuple[str, ...] = ("id",),
    ) -> None:
        if self.connection is None:
            return

        columns = list(row.keys())
        updates = [
            col
            for col in columns
            if col not in conflict_columns and col not in update_exclude
        ]
        query = sql.SQL(
            "insert into public.{table} ({cols}) values ({vals}) "
            "on conflict ({conflict}) do update set {updates}"
        ).format(
            table=sql.Identifier(table_name),
            cols=sql.SQL(", ").join(sql.Identifier(col) for col in columns),
            vals=sql.SQL(", ").join(sql.Placeholder() for _ in columns),
            conflict=sql.SQL(", ").join(sql.Identifier(col) for col in conflict_columns),
            updates=sql.SQL(", ").join(
                sql.SQL("{col} = excluded.{col}").format(col=sql.Identifier(col))
                for col in updates
            ),
        )
        values = [row[col] for col in columns]
        with self.connection.cursor() as cursor:
            cursor.execute(query, values)


class SupabaseAdminClient:
    def __init__(self, base_url: str, service_role_key: str):
        self.base_url = base_url.rstrip("/")
        self.service_role_key = service_role_key
        self._users_by_email: dict[str, dict[str, Any]] = {}
        self._users_by_id: dict[str, dict[str, Any]] = {}
        self._loaded = False

    @property
    def _headers(self) -> dict[str, str]:
        return {
            "apikey": self.service_role_key,
            "Authorization": f"Bearer {self.service_role_key}",
            "Content-Type": "application/json",
        }

    def _load_users(self) -> None:
        if self._loaded:
            return
        page = 1
        per_page = 1000
        while True:
            response = requests.get(
                f"{self.base_url}/auth/v1/admin/users",
                headers=self._headers,
                params={"page": page, "per_page": per_page},
                timeout=30,
            )
            response.raise_for_status()
            payload = response.json() or {}
            users = payload.get("users") or []
            if not isinstance(users, list):
                break
            for user in users:
                email = _email(user.get("email"))
                user_id = _text(user.get("id"))
                if email:
                    self._users_by_email[email] = user
                if user_id:
                    self._users_by_id[user_id] = user
            if len(users) < per_page:
                break
            page += 1
        self._loaded = True

    def find_user_id(self, *, email: str | None = None, user_id: str | None = None) -> uuid.UUID | None:
        self._load_users()
        if user_id and user_id in self._users_by_id:
            return _uuid_from_text(user_id)
        if email:
            user = self._users_by_email.get(email.lower())
            if user:
                return _uuid_from_text(user.get("id"))
        return None

    def ensure_user(
        self,
        *,
        email: str,
        full_name: str,
        role: str,
        auth_provider: str,
        email_verified: bool,
        avatar_url: str | None,
    ) -> tuple[uuid.UUID | None, str]:
        self._load_users()
        existing = self.find_user_id(email=email)
        if existing is not None:
            return existing, "existing_auth_user"

        temp_password = f"Averroes!{secrets.token_urlsafe(12)}"
        payload = {
            "email": email,
            "password": temp_password,
            "email_confirm": bool(email_verified),
            "user_metadata": {
                "full_name": full_name,
                "name": full_name,
                "role": role,
                "avatar_url": avatar_url,
            },
            "app_metadata": {
                "provider": auth_provider or "email",
                "role": role,
            },
        }
        response = requests.post(
            f"{self.base_url}/auth/v1/admin/users",
            headers=self._headers,
            json=payload,
            timeout=30,
        )
        if response.status_code >= 400:
            self._loaded = False
            fallback = self.find_user_id(email=email)
            if fallback is not None:
                return fallback, "existing_auth_user_after_retry"
            return None, f"auth_create_failed:{response.status_code}"

        user = response.json() or {}
        created_id = _uuid_from_text(user.get("id"))
        self._loaded = False
        self._load_users()
        return created_id, "created_auth_user"


@dataclass
class MigrationStats:
    counts: dict[str, int] = field(default_factory=dict)

    def add(self, key: str, amount: int = 1) -> None:
        self.counts[key] = self.counts.get(key, 0) + amount


class MigrationContext:
    def __init__(
        self,
        *,
        mongo_db,
        writer: UpsertWriter,
        dry_run: bool,
        supabase_admin: SupabaseAdminClient | None,
        create_auth_users: bool,
        namespace: uuid.UUID,
    ):
        self.mongo_db = mongo_db
        self.writer = writer
        self.dry_run = dry_run
        self.supabase_admin = supabase_admin
        self.create_auth_users = create_auth_users
        self.namespace = namespace
        self.stats = MigrationStats()
        self.profile_ids_by_legacy: dict[str, uuid.UUID] = {}
        self.profile_ids_by_supabase: dict[str, uuid.UUID] = {}
        self.profile_ids_by_email: dict[str, uuid.UUID] = {}
        self.class_ids: dict[str, uuid.UUID] = {}
        self.module_ids: dict[str, uuid.UUID] = {}
        self.material_ids: dict[str, uuid.UUID] = {}
        self.quiz_ids: dict[str, uuid.UUID] = {}
        self.certificate_template_ids: dict[str, uuid.UUID] = {}
        self.portfolio_ids: dict[str, uuid.UUID] = {}
        self.discussion_ids: dict[str, uuid.UUID] = {}
        self.book_category_ids: dict[str, uuid.UUID] = {}
        self.book_ids: dict[str, uuid.UUID] = {}
        self.consultation_category_ids: dict[str, uuid.UUID] = {}
        self.expert_ids: dict[str, uuid.UUID] = {}

    def stable_uuid(self, scope: str, legacy_id: str) -> uuid.UUID:
        return uuid.uuid5(self.namespace, f"{scope}:{legacy_id}")

    def resolve_profile_id(self, ref: Any) -> uuid.UUID | None:
        text = _text(ref)
        if not text:
            return None
        if text in self.profile_ids_by_legacy:
            return self.profile_ids_by_legacy[text]
        if text in self.profile_ids_by_supabase:
            return self.profile_ids_by_supabase[text]
        lowered = text.lower()
        if lowered in self.profile_ids_by_email:
            return self.profile_ids_by_email[lowered]
        return None

    def migrate(self) -> None:
        self.migrate_profiles()
        self.migrate_wallets()
        self.migrate_classes()
        self.migrate_learning_activity()
        self.migrate_portfolios()
        self.migrate_discussions()
        self.migrate_library()
        self.migrate_news_and_content()
        self.migrate_consultation()
        self.migrate_reels()

    def migrate_profiles(self) -> None:
        for document in self.mongo_db.users.find().sort("created_at", 1):
            legacy_id = str(document["_id"])
            email = _email(document.get("email"))
            role = (_text(document.get("role")) or "user").lower()
            full_name = _text(document.get("nama") or document.get("Nama")) or "Pengguna"
            auth_provider = _text(document.get("auth_provider")) or "local"
            email_verified = _bool(document.get("email_verified"))
            avatar_url = _text(document.get("foto_url"))
            linked_supabase_id = _uuid_from_text(document.get("supabase_user_id"))
            auth_user_id = linked_supabase_id
            auth_action = "linked_supabase_id" if linked_supabase_id else None

            if auth_user_id is None and email and self.supabase_admin is not None:
                auth_user_id = self.supabase_admin.find_user_id(email=email)
                if auth_user_id is not None:
                    auth_action = "matched_existing_auth_by_email"

            if (
                auth_user_id is None
                and email
                and role != "guest"
                and self.create_auth_users
                and self.supabase_admin is not None
            ):
                auth_user_id, auth_action = self.supabase_admin.ensure_user(
                    email=email,
                    full_name=full_name,
                    role=role,
                    auth_provider=auth_provider,
                    email_verified=email_verified,
                    avatar_url=avatar_url,
                )

            profile_id = auth_user_id or self.stable_uuid("users", legacy_id)
            metadata = _extra_data(
                document,
                {
                    "_id",
                    "nama",
                    "Nama",
                    "email",
                    "role",
                    "auth_provider",
                    "email_verified",
                    "foto_url",
                    "password_hash",
                    "supabase_user_id",
                    "privy_user_id",
                    "wallet_address",
                    "created_at",
                    "updated_at",
                    "last_login_at",
                },
            )
            row = {
                "id": profile_id,
                "auth_user_id": auth_user_id,
                "legacy_mongo_id": legacy_id,
                "email": email,
                "full_name": full_name,
                "role": role,
                "auth_provider": auth_provider,
                "email_verified": email_verified,
                "avatar_url": avatar_url,
                "privy_user_id": _text(document.get("privy_user_id")),
                "primary_wallet_address": _text(document.get("wallet_address")),
                "legacy_password_hash": _text(document.get("password_hash")),
                "requires_password_reset": bool(document.get("password_hash")) or auth_action == "created_auth_user",
                "metadata": _jsonb(metadata),
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at")) or datetime.now(UTC),
                "last_login_at": _utc(document.get("last_login_at")),
                "migrated_at": datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("profiles", row)

            self.profile_ids_by_legacy[legacy_id] = profile_id
            if email:
                self.profile_ids_by_email[email] = profile_id
            if auth_user_id is not None:
                self.profile_ids_by_supabase[str(auth_user_id)] = profile_id

            queue_status = "ready"
            queue_note = auth_action or "mapped_without_auth_user"
            requires_password_reset = row["requires_password_reset"]
            if auth_user_id is None and role != "guest":
                queue_status = "pending_auth_link"
                requires_password_reset = True
            elif auth_provider == "google":
                queue_status = "pending_provider_reauth"
            elif requires_password_reset:
                queue_status = "pending_password_reset"

            queue_row = {
                "profile_id": profile_id,
                "legacy_mongo_id": legacy_id,
                "email": email,
                "migration_status": queue_status,
                "requires_password_reset": requires_password_reset,
                "note": queue_note,
                "payload": _jsonb(
                    {
                        "role": role,
                        "auth_provider": auth_provider,
                        "email_verified": email_verified,
                    }
                ),
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
                "updated_at": datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert(
                    "auth_migration_queue",
                    queue_row,
                    conflict_columns=("legacy_mongo_id",),
                    update_exclude=("id", "created_at"),
                )

            self.stats.add("profiles")

    def migrate_wallets(self) -> None:
        for document in self.mongo_db.user_wallets.find():
            legacy_id = _legacy_id(document)
            user_id = self.resolve_profile_id(document.get("user_id"))
            if user_id is None:
                continue
            row = {
                "id": self.stable_uuid("user_wallets", legacy_id),
                "legacy_mongo_id": legacy_id,
                "user_id": user_id,
                "supabase_user_id": _uuid_from_text(document.get("supabase_user_id")),
                "privy_user_id": _text(document.get("privy_user_id")),
                "wallet_address": (_text(document.get("wallet_address")) or "").lower(),
                "wallet_type": _text(document.get("wallet_type")) or "embedded",
                "wallet_client": _text(document.get("wallet_client")) or "privy",
                "chain_type": _text(document.get("chain_type")) or "evm",
                "is_primary": _bool(document.get("is_primary")),
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at")) or datetime.now(UTC),
            }
            if not row["wallet_address"]:
                continue
            if not self.dry_run:
                self.writer.upsert("user_wallets", row)
            self.stats.add("user_wallets")

    def migrate_classes(self) -> None:
        for document in self.mongo_db.kelas.find():
            legacy_id = _legacy_id(document)
            class_id = self.stable_uuid("kelas", legacy_id)
            self.class_ids[legacy_id] = class_id
            row = {
                "id": class_id,
                "legacy_mongo_id": legacy_id,
                "title": _text(document.get("judul")) or "Kelas",
                "description": _text(document.get("deskripsi")),
                "level": _text(document.get("tingkat")),
                "image_url": _text(document.get("gambar_url")),
                "extra_data": _jsonb(
                    _extra_data(
                        document,
                        {
                            "_id",
                            "judul",
                            "deskripsi",
                            "tingkat",
                            "gambar_url",
                            "created_at",
                            "updated_at",
                        },
                    )
                ),
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("classes", row)
            self.stats.add("classes")

        for document in self.mongo_db.modul.find():
            legacy_id = _legacy_id(document)
            class_id = self.class_ids.get(_text(document.get("kelas_id")) or "")
            if class_id is None:
                continue
            module_id = self.stable_uuid("modul", legacy_id)
            self.module_ids[legacy_id] = module_id
            row = {
                "id": module_id,
                "legacy_mongo_id": legacy_id,
                "class_id": class_id,
                "title": _text(document.get("judul")) or "Modul",
                "description": _text(document.get("deskripsi")),
                "sort_order": _int(document.get("urutan")),
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("class_modules", row)
            self.stats.add("class_modules")

        for document in self.mongo_db.materi.find():
            legacy_id = _legacy_id(document)
            module_id = self.module_ids.get(_text(document.get("modul_id")) or "")
            if module_id is None:
                continue
            material_id = self.stable_uuid("materi", legacy_id)
            self.material_ids[legacy_id] = material_id
            row = {
                "id": material_id,
                "legacy_mongo_id": legacy_id,
                "module_id": module_id,
                "title": _text(document.get("judul")) or "Materi",
                "content": _text(document.get("konten")),
                "video_url": _text(document.get("url_video")),
                "sort_order": _int(document.get("urutan")),
                "extra_data": _jsonb(
                    _extra_data(
                        document,
                        {
                            "_id",
                            "modul_id",
                            "judul",
                            "konten",
                            "url_video",
                            "urutan",
                            "created_at",
                            "updated_at",
                        },
                    )
                ),
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("class_materials", row)
            self.stats.add("class_materials")

        for document in self.mongo_db.quiz.find():
            legacy_id = _legacy_id(document)
            class_id = self.class_ids.get(_text(document.get("kelas_id")) or "")
            if class_id is None:
                continue
            quiz_id = self.stable_uuid("quiz", legacy_id)
            self.quiz_ids[legacy_id] = quiz_id
            row = {
                "id": quiz_id,
                "legacy_mongo_id": legacy_id,
                "class_id": class_id,
                "question": _text(document.get("pertanyaan")) or "Quiz",
                "options": _jsonb(document.get("pilihan") or {}),
                "correct_answer": _text(document.get("jawaban_benar")),
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("quizzes", row)
            self.stats.add("quizzes")

        for document in self.mongo_db.sertifikat.find():
            legacy_id = _legacy_id(document)
            class_id = self.class_ids.get(_text(document.get("kelas_id")) or "")
            if class_id is None:
                continue
            template_id = self.stable_uuid("sertifikat", legacy_id)
            self.certificate_template_ids[legacy_id] = template_id
            row = {
                "id": template_id,
                "legacy_mongo_id": legacy_id,
                "class_id": class_id,
                "template_name": _text(document.get("nama_template")) or "Sertifikat",
                "description": _text(document.get("deskripsi")),
                "extra_data": _jsonb(
                    _extra_data(
                        document,
                        {
                            "_id",
                            "kelas_id",
                            "nama_template",
                            "deskripsi",
                            "created_at",
                            "updated_at",
                        },
                    )
                ),
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("certificate_templates", row)
            self.stats.add("certificate_templates")

    def migrate_learning_activity(self) -> None:
        for document in self.mongo_db.materi_progress.find():
            legacy_id = _legacy_id(
                document,
                fallback_key=f"progress:{document.get('user_id')}:{document.get('materi_id')}",
            )
            profile_id = self.resolve_profile_id(document.get("user_id"))
            material_id = self.material_ids.get(_text(document.get("materi_id")) or "")
            if profile_id is None or material_id is None:
                continue
            row = {
                "id": self.stable_uuid("materi_progress", legacy_id),
                "legacy_mongo_id": legacy_id,
                "user_id": profile_id,
                "material_id": material_id,
                "completed_at": _utc(document.get("completed_at")),
                "created_at": _utc(document.get("completed_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at") or document.get("completed_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("material_progress", row)
            self.stats.add("material_progress")

        for document in self.mongo_db.quiz_submissions.find():
            legacy_id = _legacy_id(
                document,
                fallback_key=f"quiz_submission:{document.get('user_id')}:{document.get('quiz_id')}:{document.get('created_at')}",
            )
            profile_id = self.resolve_profile_id(document.get("user_id"))
            quiz_id = self.quiz_ids.get(_text(document.get("quiz_id")) or "")
            if profile_id is None or quiz_id is None:
                continue
            row = {
                "id": self.stable_uuid("quiz_submissions", legacy_id),
                "legacy_mongo_id": legacy_id,
                "user_id": profile_id,
                "quiz_id": quiz_id,
                "answer": _text(document.get("jawaban")),
                "is_correct": _bool(document.get("benar")),
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at") or document.get("created_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("quiz_submissions", row)
            self.stats.add("quiz_submissions")

        class_id_by_template_legacy: dict[str, str] = {}
        for template in self.mongo_db.sertifikat.find():
            template_legacy_id = str(template["_id"])
            kelas_ref = _text(template.get("kelas_id"))
            if kelas_ref:
                class_id_by_template_legacy[kelas_ref] = template_legacy_id

        for document in self.mongo_db.sertifikat_user.find():
            legacy_id = _legacy_id(
                document,
                fallback_key=f"user_certificate:{document.get('user_id')}:{document.get('kelas_id')}",
            )
            profile_id = self.resolve_profile_id(document.get("user_id"))
            class_legacy_id = _text(document.get("kelas_id")) or ""
            class_id = self.class_ids.get(class_legacy_id)
            if profile_id is None or class_id is None:
                continue
            template_legacy_id = class_id_by_template_legacy.get(class_legacy_id)
            row = {
                "id": self.stable_uuid("sertifikat_user", legacy_id),
                "legacy_mongo_id": legacy_id,
                "user_id": profile_id,
                "class_id": class_id,
                "certificate_template_id": self.certificate_template_ids.get(template_legacy_id or ""),
                "certificate_name": _text(document.get("nama_sertifikat")),
                "certificate_number": _text(document.get("nomor")),
                "score_percent": _int(document.get("score_percent"), default=0),
                "download_url": _text(document.get("download_url")),
                "generated_at": _utc(document.get("generated_at")),
                "created_at": _utc(document.get("generated_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at") or document.get("generated_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("user_certificates", row)
            self.stats.add("user_certificates")

    def migrate_portfolios(self) -> None:
        for document in self.mongo_db.portofolio.find():
            legacy_id = _legacy_id(document)
            profile_id = self.resolve_profile_id(document.get("user_id"))
            if profile_id is None:
                continue
            portfolio_id = self.stable_uuid("portofolio", legacy_id)
            self.portfolio_ids[legacy_id] = portfolio_id
            row = {
                "id": portfolio_id,
                "legacy_mongo_id": legacy_id,
                "user_id": profile_id,
                "asset_name": _text(document.get("nama_aset")) or "Aset",
                "symbol": _text(document.get("simbol")) or "N/A",
                "quantity": _decimal(document.get("jumlah")),
                "purchase_price": _decimal(document.get("harga_beli")),
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("portfolio_items", row)
            self.stats.add("portfolio_items")

        for document in self.mongo_db.portofolio_riwayat.find():
            legacy_id = _legacy_id(
                document,
                fallback_key=f"portofolio_riwayat:{document.get('user_id')}:{document.get('portofolio_id')}:{document.get('created_at')}",
            )
            profile_id = self.resolve_profile_id(document.get("user_id"))
            if profile_id is None:
                continue
            raw_portfolio_ref = _text(document.get("portofolio_id"))
            row = {
                "id": self.stable_uuid("portofolio_riwayat", legacy_id),
                "legacy_mongo_id": legacy_id,
                "user_id": profile_id,
                "portfolio_item_id": self.portfolio_ids.get(raw_portfolio_ref or ""),
                "action": _text(document.get("aksi")) or "update",
                "asset_name": _text(document.get("nama_aset")),
                "symbol": _text(document.get("simbol")),
                "quantity": _decimal(document.get("jumlah")),
                "purchase_price": _decimal(document.get("harga_beli")),
                "total_value": _decimal(document.get("nilai")),
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("portfolio_history", row)
            self.stats.add("portfolio_history")

    def migrate_discussions(self) -> None:
        for document in self.mongo_db.diskusi.find():
            legacy_id = _legacy_id(document)
            self.discussion_ids[legacy_id] = self.stable_uuid("diskusi", legacy_id)

        for document in self.mongo_db.diskusi.find():
            legacy_id = _legacy_id(document)
            parent_ref = _text(document.get("parent_id"))
            row = {
                "id": self.discussion_ids[legacy_id],
                "legacy_mongo_id": legacy_id,
                "user_id": self.resolve_profile_id(document.get("user_id")),
                "parent_post_id": self.discussion_ids.get(parent_ref) if parent_ref else None,
                "title": _text(document.get("judul")),
                "body": _text(document.get("isi")) or "",
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("discussion_posts", row)
            self.stats.add("discussion_posts")

    def migrate_library(self) -> None:
        for document in self.mongo_db.kategori_buku.find():
            legacy_id = _legacy_id(document)
            category_id = self.stable_uuid("kategori_buku", legacy_id)
            self.book_category_ids[legacy_id] = category_id
            row = {
                "id": category_id,
                "legacy_mongo_id": legacy_id,
                "name": _text(document.get("nama")) or "Kategori",
                "slug": _text(document.get("slug")) or f"kategori-{legacy_id[:8]}",
                "sort_order": _int(document.get("urutan"), default=0),
                "is_active": _bool(document.get("is_active"), default=True),
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("book_categories", row)
            self.stats.add("book_categories")

        for document in self.mongo_db.buku.find():
            legacy_id = _legacy_id(document)
            book_id = self.stable_uuid("buku", legacy_id)
            self.book_ids[legacy_id] = book_id
            category_ref = _text(document.get("kategori_id"))
            row = {
                "id": book_id,
                "legacy_mongo_id": legacy_id,
                "category_id": self.book_category_ids.get(category_ref) if category_ref else None,
                "created_by_profile_id": self.resolve_profile_id(document.get("created_by")),
                "updated_by_profile_id": self.resolve_profile_id(document.get("updated_by")),
                "title": _text(document.get("judul")) or "Buku",
                "slug": _text(document.get("slug")) or f"buku-{legacy_id[:8]}",
                "author": _text(document.get("penulis")),
                "description": _text(document.get("deskripsi")),
                "access": _text(document.get("akses")) or "gratis",
                "status": _text(document.get("status")) or "draft",
                "language": _text(document.get("bahasa")) or "id",
                "is_featured": _bool(document.get("is_featured")),
                "format_file": _text(document.get("format_file")),
                "drive_file_id": _text(document.get("drive_file_id")),
                "cover_key": _text(document.get("cover_key")),
                "file_key": _text(document.get("file_key")),
                "file_pdf": _text(document.get("file_pdf")),
                "file_name": _text(document.get("file_nama")),
                "file_size_bytes": _int(document.get("ukuran_file_bytes"), default=0) or None,
                "storage_provider": _text(document.get("storage_provider")),
                "published_at": _utc(document.get("published_at")),
                "extra_data": _jsonb(
                    _extra_data(
                        document,
                        {
                            "_id",
                            "kategori_id",
                            "created_by",
                            "updated_by",
                            "judul",
                            "slug",
                            "penulis",
                            "deskripsi",
                            "akses",
                            "status",
                            "bahasa",
                            "is_featured",
                            "format_file",
                            "drive_file_id",
                            "cover_key",
                            "file_key",
                            "file_pdf",
                            "file_nama",
                            "ukuran_file_bytes",
                            "storage_provider",
                            "published_at",
                            "created_at",
                            "updated_at",
                        },
                    )
                ),
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("books", row)
            self.stats.add("books")

    def migrate_news_and_content(self) -> None:
        for document in self.mongo_db.berita.find():
            legacy_id = _legacy_id(document)
            row = {
                "id": self.stable_uuid("berita", legacy_id),
                "legacy_mongo_id": legacy_id,
                "title": _text(document.get("judul")) or "Berita",
                "slug": _text(document.get("slug")) or f"berita-{legacy_id[:8]}",
                "summary": _text(document.get("ringkasan")),
                "content": _text(document.get("konten")),
                "content_blocks": _jsonb(document.get("konten_blocks") or []),
                "source_url": _text(document.get("sumber_url")) or f"https://legacy.local/{legacy_id}",
                "source_name": _text(document.get("sumber_nama")),
                "image_url": _text(document.get("gambar_url")),
                "provider": _text(document.get("provider")),
                "published_at": _utc(document.get("published_at")),
                "created_at": _utc(document.get("created_at") or document.get("published_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("news_items", row)
            self.stats.add("news_items")

        for document in self.mongo_db.kajian.find():
            legacy_id = _legacy_id(document)
            row = {
                "id": self.stable_uuid("kajian", legacy_id),
                "legacy_mongo_id": legacy_id,
                "title": _text(document.get("judul")) or "Kajian",
                "description": _text(document.get("deskripsi")),
                "youtube_url": _text(document.get("youtube_url")),
                "channel_name": _text(document.get("channel")),
                "category": _text(document.get("kategori")),
                "duration_label": _text(document.get("durasi_label")),
                "sort_order": _int(document.get("urutan"), default=0),
                "is_active": _bool(document.get("is_active"), default=True),
                "extra_data": _jsonb(
                    _extra_data(
                        document,
                        {
                            "_id",
                            "judul",
                            "deskripsi",
                            "youtube_url",
                            "channel",
                            "kategori",
                            "durasi_label",
                            "urutan",
                            "is_active",
                            "created_at",
                            "updated_at",
                        },
                    )
                ),
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("kajian_items", row)
            self.stats.add("kajian_items")

        for document in self.mongo_db.screener.find():
            legacy_id = _legacy_id(document, fallback_key=f"screener:{document.get('simbol')}")
            row = {
                "id": self.stable_uuid("screener", legacy_id),
                "legacy_mongo_id": legacy_id,
                "coin_name": _text(document.get("nama_koin")) or "Koin",
                "symbol": (_text(document.get("simbol")) or "N/A").upper(),
                "status": _text(document.get("status")),
                "sharia_status": _text(document.get("status_syariah") or document.get("status")),
                "fiqh_explanation": _text(document.get("penjelasan_fiqh") or document.get("alasan")),
                "scholar_reference": _text(document.get("referensi_ulama")),
                "extra_data": _jsonb(
                    _extra_data(
                        document,
                        {
                            "_id",
                            "nama_koin",
                            "simbol",
                            "status",
                            "status_syariah",
                            "penjelasan_fiqh",
                            "alasan",
                            "referensi_ulama",
                            "created_at",
                            "updated_at",
                        },
                    )
                ),
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("screeners", row)
            self.stats.add("screeners")

    def migrate_consultation(self) -> None:
        for document in self.mongo_db.kategori_ahli.find():
            legacy_id = _legacy_id(document, fallback_key=f"kategori_ahli:{document.get('id')}")
            category_id = self.stable_uuid("kategori_ahli", legacy_id)
            self.consultation_category_ids[legacy_id] = category_id
            external_id = _text(document.get("id"))
            if external_id:
                self.consultation_category_ids[external_id] = category_id
            row = {
                "id": category_id,
                "legacy_mongo_id": legacy_id,
                "external_id": external_id,
                "name": _text(document.get("nama")) or "Kategori",
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("consultation_categories", row)
            self.stats.add("consultation_categories")

        for document in self.mongo_db.ahli_syariah.find():
            legacy_id = _legacy_id(document)
            expert_id = self.stable_uuid("ahli_syariah", legacy_id)
            self.expert_ids[legacy_id] = expert_id
            email = _email(document.get("email"))
            row = {
                "id": expert_id,
                "legacy_mongo_id": legacy_id,
                "profile_id": self.resolve_profile_id(email),
                "category_id": self.consultation_category_ids.get(_text(document.get("kategori_id")) or ""),
                "full_name": _text(document.get("nama")) or "Ahli Syariah",
                "email": email,
                "specialization": _text(document.get("spesialis")),
                "rating": _decimal(document.get("rating"), default="0"),
                "total_review": _int(document.get("total_review"), default=0),
                "years_experience": _int(document.get("pengalaman_tahun"), default=0),
                "session_price": _decimal(document.get("harga_per_sesi"), default="0"),
                "whatsapp_number": _text(document.get("no_whatsapp")),
                "is_online": _bool(document.get("is_online")),
                "is_verified": _bool(document.get("is_verified")),
                "photo_url": _text(document.get("foto_url")),
                "extra_data": _jsonb(
                    _extra_data(
                        document,
                        {
                            "_id",
                            "nama",
                            "email",
                            "spesialis",
                            "kategori_id",
                            "rating",
                            "total_review",
                            "pengalaman_tahun",
                            "harga_per_sesi",
                            "no_whatsapp",
                            "is_online",
                            "is_verified",
                            "foto_url",
                            "created_at",
                            "updated_at",
                        },
                    )
                ),
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("sharia_experts", row)
            self.stats.add("sharia_experts")

        for document in self.mongo_db.sessions.find():
            legacy_id = _legacy_id(
                document,
                fallback_key=f"session:{document.get('order_id') or document.get('user_id')}:{document.get('ahli_id')}",
            )
            row = {
                "id": self.stable_uuid("sessions", legacy_id),
                "legacy_mongo_id": legacy_id,
                "order_id": _text(document.get("order_id")),
                "user_id": self.resolve_profile_id(document.get("user_id")),
                "expert_id": self.expert_ids.get(_text(document.get("ahli_id")) or ""),
                "status": _text(document.get("status")) or "pending",
                "price": _decimal(document.get("harga"), default="0"),
                "extra_data": _jsonb(
                    _extra_data(
                        document,
                        {"_id", "order_id", "user_id", "ahli_id", "status", "harga", "created_at", "updated_at"},
                    )
                ),
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("consultation_sessions", row)
            self.stats.add("consultation_sessions")

    def migrate_reels(self) -> None:
        for document in self.mongo_db.reels.find():
            legacy_id = _legacy_id(document)
            row = {
                "id": self.stable_uuid("reels", legacy_id),
                "legacy_mongo_id": legacy_id,
                "sort_order": _int(document.get("urutan"), default=0),
                "title": _text(document.get("judul")) or "Reel",
                "category": _text(document.get("kategori")),
                "arabic_quote": _text(document.get("kutipan_arab")),
                "translation": _text(document.get("terjemah")),
                "source": _text(document.get("sumber")),
                "explanation": _text(document.get("penjelasan")),
                "audio_url": _text(document.get("audio_url")),
                "tags": _jsonb(document.get("tags") or []),
                "duration_seconds": _int(document.get("durasi_detik"), default=0),
                "is_active": _bool(document.get("aktif"), default=True),
                "extra_data": _jsonb(
                    _extra_data(
                        document,
                        {
                            "_id",
                            "urutan",
                            "judul",
                            "kategori",
                            "kutipan_arab",
                            "terjemah",
                            "sumber",
                            "penjelasan",
                            "audio_url",
                            "tags",
                            "durasi_detik",
                            "aktif",
                            "created_at",
                            "updated_at",
                        },
                    )
                ),
                "created_at": _utc(document.get("created_at")) or datetime.now(UTC),
                "updated_at": _utc(document.get("updated_at")) or datetime.now(UTC),
            }
            if not self.dry_run:
                self.writer.upsert("reels", row)
            self.stats.add("reels")


def _connect_postgres() -> Any:
    if psycopg is None:
        raise SystemExit("psycopg belum terpasang. Jalankan pip install -r requirements.txt")
    database_url = (
        os.getenv("POSTGRES_URL")
        or os.getenv("SUPABASE_DB_URL")
        or os.getenv("DATABASE_URL")
    )
    if not database_url:
        raise SystemExit("POSTGRES_URL atau SUPABASE_DB_URL belum diisi.")
    return psycopg.connect(database_url)


def _apply_schema(connection, schema_path: Path) -> None:
    sql_text = schema_path.read_text(encoding="utf-8")
    with connection.cursor() as cursor:
        cursor.execute(sql_text)
    connection.commit()


def _connect_mongo():
    uri = os.getenv("MONGODB_URI")
    db_name = os.getenv("DB_NAME")
    if not uri or not db_name:
        raise SystemExit("MONGODB_URI dan DB_NAME wajib diisi.")
    client = MongoClient(uri)
    return client, client[db_name]


def main() -> int:
    args = _parse_args()
    load_dotenv(ROOT_DIR / "apps" / "backend" / ".env")
    load_dotenv()

    create_auth_users = args.create_auth_users or _env_bool(
        "SUPABASE_MIGRATION_CREATE_AUTH_USERS",
        default=False,
    )

    mongo_client, mongo_db = _connect_mongo()
    pg_connection = None
    supabase_admin = None

    try:
        if not args.dry_run:
            pg_connection = _connect_postgres()
            if args.apply_schema:
                _apply_schema(pg_connection, Path(args.schema_path))

        if create_auth_users:
            supabase_url = (os.getenv("SUPABASE_URL") or "").strip()
            service_role_key = (os.getenv("SUPABASE_SERVICE_ROLE_KEY") or "").strip()
            if not supabase_url or not service_role_key:
                raise SystemExit(
                    "SUPABASE_URL dan SUPABASE_SERVICE_ROLE_KEY wajib diisi jika --create-auth-users dipakai."
                )
            supabase_admin = SupabaseAdminClient(supabase_url, service_role_key)

        context = MigrationContext(
            mongo_db=mongo_db,
            writer=UpsertWriter(pg_connection),
            dry_run=args.dry_run,
            supabase_admin=supabase_admin,
            create_auth_users=create_auth_users,
            namespace=DEFAULT_NAMESPACE,
        )
        context.migrate()

        if pg_connection is not None:
            pg_connection.commit()

        print("Migrasi selesai.")
        for key in sorted(context.stats.counts):
            print(f"- {key}: {context.stats.counts[key]}")
        if args.dry_run:
            print("Mode dry-run aktif: tidak ada perubahan yang ditulis ke PostgreSQL.")
        return 0
    except Exception as exc:
        if pg_connection is not None:
            pg_connection.rollback()
        print(f"Migrasi gagal: {exc}", file=sys.stderr)
        raise
    finally:
        if pg_connection is not None:
            pg_connection.close()
        mongo_client.close()


if __name__ == "__main__":
    raise SystemExit(main())
