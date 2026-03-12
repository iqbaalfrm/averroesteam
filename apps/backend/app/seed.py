import re
import csv
from datetime import datetime
from pathlib import Path
from werkzeug.security import generate_password_hash
from app.extensions import mongo


def _topic_bank(title: str) -> list[str]:
    t = (title or "").lower()
    if "zakat" in t:
        return [
            "Nishab dan Haul",
            "Objek Zakat Aset Digital",
            "Perhitungan Nilai Aset",
            "Waktu Pembayaran Zakat",
            "Simulasi Portofolio Campuran",
            "Kesalahan Umum Perhitungan",
            "Strategi Pencatatan",
            "Studi Kasus Zakat Kripto",
            "Audit Perhitungan",
            "Rencana Zakat Tahunan",
        ]
    if "fiqh" in t or "muamalah" in t:
        return [
            "Prinsip Dasar Muamalah",
            "Gharar dalam Produk Digital",
            "Maisir dan Spekulasi",
            "Riba dalam Ekosistem Modern",
            "Akad dalam Aset Digital",
            "Kepemilikan dan Amanah",
            "Etika Transaksi",
            "Studi Kasus Kontemporer",
            "Filter Syariah Praktis",
            "Checklist Kepatuhan",
        ]
    if "analisis" in t or "pasar" in t:
        return [
            "Trend dan Struktur Market",
            "Support dan Resistance",
            "Volume dan Momentum",
            "Risk Management Dasar",
            "Entry dan Exit Plan",
            "Manajemen Emosi",
            "Jurnal Trading",
            "Evaluasi Strategi",
            "Studi Kasus Bull/Bear",
            "Rencana Pengembangan",
        ]
    if "investasi" in t or "portofolio" in t:
        return [
            "Tujuan dan Profil Risiko",
            "Alokasi Aset",
            "Diversifikasi Praktis",
            "Rebalancing Portofolio",
            "Manajemen Drawdown",
            "Evaluasi Kinerja",
            "Strategi DCA",
            "Perencanaan Jangka Panjang",
            "Kesalahan Umum Investor",
            "Checklist Investasi",
        ]
    return [
        "Dasar-Dasar Kripto",
        "Blockchain Fundamental",
        "Tokenomics",
        "Manajemen Risiko",
        "Keamanan Aset",
        "Diversifikasi",
        "Analisis Fundamental",
        "Analisis Teknikal",
        "Studi Kasus",
        "Rencana Belajar Lanjutan",
    ]


def _quiz_bank(title: str) -> list[dict]:
    t = (title or "").lower()
    if "zakat" in t:
        return [
            {"q": "Nishab zakat mal ditentukan oleh?", "a": {"A": "Harga emas/perak acuan", "B": "Jumlah transaksi", "C": "Durasi trading", "D": "Jumlah dompet"}, "k": "A"},
            {"q": "Haul berarti?", "a": {"A": "Biaya admin", "B": "Kepemilikan 1 tahun hijriah", "C": "Profit 10%", "D": "Aset non-likuid"}, "k": "B"},
            {"q": "Syarat wajib zakat mal?", "a": {"A": "Nishab dan haul terpenuhi", "B": "Punya 1 aset", "C": "Wajib trading", "D": "Aset selalu naik"}, "k": "A"},
        ]
    base = [
        {"q": "Tujuan utama manajemen risiko adalah?", "a": {"A": "Menghapus rugi total", "B": "Membatasi kerugian", "C": "Melipatgandakan leverage", "D": "Menebak puncak harga"}, "k": "B"},
        {"q": "Dalam fiqh muamalah, gharar berarti?", "a": {"A": "Akad jelas", "B": "Ketidakjelasan berlebihan", "C": "Sedekah wajib", "D": "Bagi hasil"}, "k": "B"},
        {"q": "Diversifikasi berfungsi untuk?", "a": {"A": "Hilangkan risiko", "B": "Kurangi dampak risiko tunggal", "C": "Naikkan fee", "D": "Percepat likuidasi"}, "k": "B"},
    ]
    if "analisis" in t or "pasar" in t:
        base.append({"q": "Support-resistance dipakai untuk?", "a": {"A": "Cek email", "B": "Identifikasi area harga penting", "C": "Hitung zakat", "D": "Audit server"}, "k": "B"})
    if "fiqh" in t or "muamalah" in t:
        base.append({"q": "Maisir identik dengan?", "a": {"A": "Produktivitas", "B": "Spekulasi/judi", "C": "Likuiditas", "D": "Hedging halal"}, "k": "B"})
    if "investasi" in t or "portofolio" in t:
        base.append({"q": "Rebalancing adalah?", "a": {"A": "Ganti password", "B": "Kembalikan komposisi aset ke target", "C": "Tutup akun", "D": "Naikkan leverage"}, "k": "B"})
    return base


def _ensure_quiz_count(kelas_id, kelas_title: str, now: datetime, quiz_count: int = 15) -> None:
    quiz_rows = list(mongo.db.quiz.find({"kelas_id": kelas_id}).sort([("_id", 1)]))
    if len(quiz_rows) > quiz_count:
        extra = quiz_rows[quiz_count:]
        extra_ids = [q["_id"] for q in extra]
        mongo.db.quiz_submissions.delete_many({"quiz_id": {"$in": extra_ids}})
        mongo.db.quiz.delete_many({"_id": {"$in": extra_ids}})
        quiz_rows = quiz_rows[:quiz_count]

    bank = _quiz_bank(kelas_title)
    while len(quiz_rows) < quiz_count:
        i = len(quiz_rows) + 1
        tpl = bank[(i - 1) % len(bank)]
        qid = mongo.db.quiz.insert_one(
            {
                "kelas_id": kelas_id,
                "pertanyaan": f"Soal {i}. {tpl['q']}",
                "pilihan": tpl["a"],
                "jawaban_benar": tpl["k"],
                "created_at": now,
                "updated_at": now,
            }
        ).inserted_id
        quiz_rows.append({"_id": qid})


def _enforce_curriculum(
    kelas_id,
    kelas_title: str,
    now: datetime,
    module_count: int = 3,
    materi_per_module: int = 3,
) -> None:
    topics = _topic_bank(kelas_title)
    modul_rows = list(mongo.db.modul.find({"kelas_id": kelas_id}).sort("urutan", 1))

    # Trim modul berlebih agar tepat jumlah modul per kelas.
    if len(modul_rows) > module_count:
        extra_moduls = modul_rows[module_count:]
        extra_modul_ids = [m["_id"] for m in extra_moduls]
        extra_materi_ids = [
            m["_id"] for m in mongo.db.materi.find({"modul_id": {"$in": extra_modul_ids}})
        ]
        if extra_materi_ids:
            mongo.db.materi_progress.delete_many({"materi_id": {"$in": extra_materi_ids}})
            mongo.db.materi.delete_many({"_id": {"$in": extra_materi_ids}})
        mongo.db.modul.delete_many({"_id": {"$in": extra_modul_ids}})
        modul_rows = modul_rows[:module_count]

    # Tambah modul jika kurang dari target.
    while len(modul_rows) < module_count:
        idx = len(modul_rows) + 1
        topic = topics[(idx - 1) % len(topics)]
        modul_id = mongo.db.modul.insert_one(
            {
                "kelas_id": kelas_id,
                "judul": f"Modul {idx}: {topic}",
                "deskripsi": f"Pendalaman topik {topic.lower()} untuk {kelas_title.lower()}.",
                "urutan": idx,
                "created_at": now,
                "updated_at": now,
            }
        ).inserted_id
        modul_rows.append({"_id": modul_id, "urutan": idx})

    # Sinkronkan setiap modul: judul/deskripsi/urutan + materi tepat 3 item.
    for idx, modul in enumerate(modul_rows, start=1):
        topic = topics[(idx - 1) % len(topics)]
        mongo.db.modul.update_one(
            {"_id": modul["_id"]},
            {
                "$set": {
                    "judul": f"Modul {idx}: {topic}",
                    "deskripsi": f"Pendalaman topik {topic.lower()} untuk {kelas_title.lower()}.",
                    "urutan": idx,
                    "updated_at": now,
                }
            },
        )

        materi_rows = list(mongo.db.materi.find({"modul_id": modul["_id"]}).sort("urutan", 1))

        if len(materi_rows) > materi_per_module:
            extra_materi = materi_rows[materi_per_module:]
            extra_materi_ids = [m["_id"] for m in extra_materi]
            mongo.db.materi_progress.delete_many({"materi_id": {"$in": extra_materi_ids}})
            mongo.db.materi.delete_many({"_id": {"$in": extra_materi_ids}})
            materi_rows = materi_rows[:materi_per_module]

        while len(materi_rows) < materi_per_module:
            j = len(materi_rows) + 1
            mid = mongo.db.materi.insert_one(
                {
                    "modul_id": modul["_id"],
                    "judul": f"Materi {idx}.{j}: {topic}",
                    "konten": (
                        f"Pembahasan inti {topic.lower()} pada kelas {kelas_title}. "
                        f"Bagian {j} dari {materi_per_module}."
                    ),
                    "url_video": "",
                    "urutan": j,
                    "created_at": now,
                    "updated_at": now,
                }
            ).inserted_id
            materi_rows.append({"_id": mid, "urutan": j})

        for j, materi in enumerate(materi_rows, start=1):
            mongo.db.materi.update_one(
                {"_id": materi["_id"]},
                {
                    "$set": {
                        "judul": f"Materi {idx}.{j}: {topic}",
                        "urutan": j,
                        "updated_at": now,
                    }
                },
            )


def _ensure_user(email: str, nama: str, role: str, password: str, now: datetime) -> None:
    if mongo.db.users.find_one({"email": email}):
        return
    mongo.db.users.insert_one(
        {
            "nama": nama,
            "email": email,
            "password_hash": generate_password_hash(password),
            "role": role,
            "created_at": now,
            "updated_at": now,
        }
    )


def _slugify(text: str) -> str:
    slug = re.sub(r"[^a-z0-9]+", "-", (text or "").strip().lower()).strip("-")
    return slug or "buku"


def _ensure_unique_buku_slug(base_text: str) -> str:
    base = _slugify(base_text)
    slug = base
    i = 2
    while mongo.db.buku.find_one({"slug": slug}):
        slug = f"{base}-{i}"
        i += 1
    return slug


def _extract_drive_file_id(url: str) -> str:
    match = re.search(r"/d/([a-zA-Z0-9_-]+)", url or "")
    return match.group(1) if match else ""


def _seed_pustaka_books(now: datetime) -> None:
    books = [
        {
            "judul": "Al-Ahkam Al-Fiqhiyyah Al-Muta'alliqah bil-'Umalat al-Iliktruniyyah",
            "penulis": "Tim Riset Averroes",
            "deskripsi": "Kajian hukum fiqih terkait transaksi dan muamalah elektronik.",
            "drive_url": "https://drive.google.com/file/d/1hc1yBau9ub_DSvQR6mvIUjIwLhHcRC9S/view?usp=sharing",
        },
        {
            "judul": "Hukum Fiqih terhadap Uang Kertas (Fiat)",
            "penulis": "Tim Riset Averroes",
            "deskripsi": "Pembahasan fiqih mengenai uang kertas (fiat) dalam perspektif muamalah.",
            "drive_url": "https://drive.google.com/file/d/1KY-iwtK_ydpXECCqjmNTe3w9NgGpJa3s/view?usp=sharing",
        },
        {
            "judul": "ISCHAIN - Soal Jawab Cryptocurrency",
            "penulis": "ISCHAIN",
            "deskripsi": "Kumpulan tanya jawab praktis seputar cryptocurrency dari perspektif syariah.",
            "drive_url": "https://drive.google.com/file/d/1UpeSMuSjgEb-aqHuHE5xry1HAp5HSwK8/view?usp=sharing",
        },
        {
            "judul": "ISCHAIN - Panduan Memilih Aset Kripto yang Halal",
            "penulis": "ISCHAIN",
            "deskripsi": "Panduan ringkas untuk menyaring aset kripto yang sesuai prinsip halal.",
            "drive_url": "https://drive.google.com/file/d/159GtpjQKavAc-CH2owF3EjA9yXHIzP1M/view?usp=drive_link",
        },
    ]

    for item in books:
        drive_id = _extract_drive_file_id(item["drive_url"])
        if not drive_id:
            continue

        existing = mongo.db.buku.find_one({"judul": item["judul"]})
        if existing:
            mongo.db.buku.update_one(
                {"_id": existing["_id"]},
                {
                    "$set": {
                        "penulis": item["penulis"],
                        "deskripsi": item["deskripsi"],
                        "drive_file_id": drive_id,
                        "format_file": "pdf",
                        "status": "published",
                        "akses": existing.get("akses") or "gratis",
                        "bahasa": existing.get("bahasa") or "id",
                        "published_at": existing.get("published_at") or now,
                        "updated_at": now,
                    }
                },
            )
            continue

        mongo.db.buku.insert_one(
            {
                "judul": item["judul"],
                "penulis": item["penulis"],
                "deskripsi": item["deskripsi"],
                "slug": _ensure_unique_buku_slug(item["judul"]),
                "kategori_id": None,
                "status": "published",
                "akses": "gratis",
                "bahasa": "id",
                "is_featured": False,
                "format_file": "pdf",
                "drive_file_id": drive_id,
                "published_at": now,
                "created_at": now,
                "updated_at": now,
                "created_by": None,
                "updated_by": None,
            }
        )


def _normalize_screener_status(raw_value: str) -> str:
    value = (raw_value or "").strip().lower()
    if value.startswith("yes"):
        return "halal"
    if value.startswith("no"):
        return "haram"
    return "proses"


def _extract_screener_symbol(asset_name: str) -> str:
    text = (asset_name or "").strip()
    match = re.search(r"\(([^)]+)\)", text)
    if match:
        symbol = re.sub(r"[^A-Za-z0-9]", "", match.group(1)).upper()
        if symbol:
            return symbol

    candidates = re.findall(r"[A-Za-z0-9]{2,10}", text)
    if candidates:
        return candidates[-1].upper()
    return "NA"


def _clean_screener_name(asset_name: str) -> str:
    text = (asset_name or "").strip()
    text = re.sub(r"\([^)]*\)", "", text).strip()
    return text or "Tanpa Nama"


def _build_screener_explanation(row: dict[str, str]) -> str:
    underlying = (row.get("Underlying") or "").strip()
    nilai_jelas = (row.get("Nilai yang Jelas") or "").strip()
    serah_terima = (row.get("Bisakah Diserah-terimakan") or "").strip()
    sharia_raw = (row.get("Yes/No Sharia") or "").strip()

    sections = []
    if underlying:
        sections.append(f"Underlying: {underlying}")
    if nilai_jelas:
        sections.append(f"Nilai: {nilai_jelas}")
    if serah_terima:
        sections.append(f"Serah-terima: {serah_terima}")
    if sharia_raw:
        sections.append(f"Sharia CSV: {sharia_raw}")
    return " | ".join(sections) or "Tidak ada keterangan."


def _seed_screener_from_csv(now: datetime) -> None:
    repo_root = Path(__file__).resolve().parents[3]
    csv_path = repo_root / "screener.csv"
    if not csv_path.exists():
        print(f"Seed screener dilewati: file tidak ditemukan ({csv_path}).")
        return

    rows: list[dict[str, str]] = []
    with csv_path.open("r", encoding="utf-8-sig", newline="") as f:
        reader = csv.DictReader(f, delimiter=";")
        for row in reader:
            if not row:
                continue
            item = {k: (v or "").strip() for k, v in row.items()}
            if any(item.values()):
                rows.append(item)

    prepared = []
    used_symbols: set[str] = set()
    for row in rows:
        asset_name = (row.get("Aset Kripto") or "").strip()
        if not asset_name:
            continue

        base_symbol = _extract_screener_symbol(asset_name)
        symbol = base_symbol
        suffix = 2
        while symbol in used_symbols:
            symbol = f"{base_symbol}{suffix}"
            suffix += 1
        used_symbols.add(symbol)

        status = _normalize_screener_status(row.get("Yes/No Sharia", ""))
        prepared.append(
            {
                "nama_koin": _clean_screener_name(asset_name),
                "simbol": symbol,
                "status": status,
                "status_syariah": status,
                "penjelasan_fiqh": _build_screener_explanation(row),
                "referensi_ulama": "Sumber: CSV Screener Averroes (kajian internal, bukan fatwa resmi).",
                "created_at": now,
                "updated_at": now,
            }
        )

    mongo.db.screener.delete_many({})
    if prepared:
        mongo.db.screener.insert_many(prepared)
    print(f"Seed screener dari CSV: {len(prepared)} data masuk.")


def _seed_kelas_bundle(bundle: dict, now: datetime) -> None:
    existing = mongo.db.kelas.find_one({"judul": bundle["judul"]})
    if existing:
        kelas_id = existing["_id"]
        mongo.db.kelas.update_one(
            {"_id": kelas_id},
            {
                "$set": {
                    "deskripsi": bundle["deskripsi"],
                    "tingkat": bundle.get("tingkat", "Pemula"),
                    "gambar_url": bundle.get("gambar_url"),
                    "updated_at": now,
                }
            },
        )
    else:
        kelas_doc = {
            "judul": bundle["judul"],
            "deskripsi": bundle["deskripsi"],
            "tingkat": bundle.get("tingkat", "Pemula"),
            "gambar_url": bundle.get("gambar_url"),
            "created_at": now,
            "updated_at": now,
        }
        kelas_id = mongo.db.kelas.insert_one(kelas_doc).inserted_id

    for modul in bundle.get("modul", []):
        modul_existing = mongo.db.modul.find_one(
            {"kelas_id": kelas_id, "judul": modul["judul"]}
        )
        if modul_existing:
            modul_id = modul_existing["_id"]
            mongo.db.modul.update_one(
                {"_id": modul_id},
                {
                    "$set": {
                        "deskripsi": modul["deskripsi"],
                        "urutan": modul["urutan"],
                        "updated_at": now,
                    }
                },
            )
        else:
            modul_doc = {
                "kelas_id": kelas_id,
                "judul": modul["judul"],
                "deskripsi": modul["deskripsi"],
                "urutan": modul["urutan"],
                "created_at": now,
                "updated_at": now,
            }
            modul_id = mongo.db.modul.insert_one(modul_doc).inserted_id

        for materi in modul.get("materi", []):
            materi_existing = mongo.db.materi.find_one(
                {"modul_id": modul_id, "judul": materi["judul"]}
            )
            if materi_existing:
                mongo.db.materi.update_one(
                    {"_id": materi_existing["_id"]},
                    {
                        "$set": {
                            "konten": materi["konten"],
                            "url_video": materi.get("url_video", ""),
                            "urutan": materi["urutan"],
                            "updated_at": now,
                        }
                    },
                )
            else:
                mongo.db.materi.insert_one(
                    {
                        "modul_id": modul_id,
                        "judul": materi["judul"],
                        "konten": materi["konten"],
                        "url_video": materi.get("url_video", ""),
                        "urutan": materi["urutan"],
                        "created_at": now,
                        "updated_at": now,
                    }
                )

    for quiz in bundle.get("quiz", []):
        quiz_existing = mongo.db.quiz.find_one(
            {"kelas_id": kelas_id, "pertanyaan": quiz["pertanyaan"]}
        )
        if quiz_existing:
            mongo.db.quiz.update_one(
                {"_id": quiz_existing["_id"]},
                {
                    "$set": {
                        "pilihan": quiz["pilihan"],
                        "jawaban_benar": quiz["jawaban_benar"],
                        "updated_at": now,
                    }
                },
            )
        else:
            mongo.db.quiz.insert_one(
                {
                    "kelas_id": kelas_id,
                    "pertanyaan": quiz["pertanyaan"],
                    "pilihan": quiz["pilihan"],
                    "jawaban_benar": quiz["jawaban_benar"],
                    "created_at": now,
                    "updated_at": now,
                }
            )

    if not mongo.db.sertifikat.find_one({"kelas_id": kelas_id}):
        mongo.db.sertifikat.insert_one(
            {
                "kelas_id": kelas_id,
                "nama_template": f"Sertifikat {bundle['judul']}",
                "created_at": now,
                "updated_at": now,
            }
        )


def seed_data():
    now = datetime.utcnow()

    _ensure_user("admin@averroes.com", "Admin Averroes", "admin", "admin123", now)
    _ensure_user("user@averroes.com", "Coba User", "user", "user123", now)

    kelas_bundles = [
        {
            "judul": "Fundamental Kripto & Fiqh Muamalah",
            "deskripsi": "Belajar dasar-dasar aset kripto sesuai prinsip syariah.",
            "tingkat": "Pemula",
            "gambar_url": "https://images.unsplash.com/photo-1621761191319-c6fb62004040?auto=format&fit=crop&w=1200&q=80",
            "modul": [
                {
                    "judul": "Modul 1: Pengenalan Blockchain",
                    "deskripsi": "Konsep dasar blockchain.",
                    "urutan": 1,
                    "materi": [
                        {
                            "judul": "Materi 1.1: Apa itu Blockchain?",
                            "konten": "Blockchain adalah buku besar digital terdistribusi untuk mencatat transaksi secara transparan.",
                            "url_video": "https://youtube.com/watch?v=sc2P0I8W0-0",
                            "urutan": 1,
                        },
                        {
                            "judul": "Materi 1.2: Nilai Syariah di Ekosistem Kripto",
                            "konten": "Mengenal prinsip halal-haram, gharar, dan maisir dalam aktivitas aset digital.",
                            "urutan": 2,
                        },
                    ],
                },
                {
                    "judul": "Modul 2: Prinsip Halal-Haram Aset Digital",
                    "deskripsi": "Kerangka fiqh muamalah untuk menilai aset kripto.",
                    "urutan": 2,
                    "materi": [
                        {
                            "judul": "Materi 2.1: Objek Transaksi yang Halal",
                            "konten": "Memahami syarat objek muamalah yang jelas, bernilai, dan tidak bertentangan syariah.",
                            "urutan": 1,
                        }
                    ],
                },
                {
                    "judul": "Modul 3: Risiko Gharar dan Maisir",
                    "deskripsi": "Identifikasi ketidakjelasan dan spekulasi berlebihan.",
                    "urutan": 3,
                    "materi": [
                        {
                            "judul": "Materi 3.1: Studi Kasus Gharar di Produk Kripto",
                            "konten": "Menilai praktik high-risk trading, leverage, dan produk yang minim transparansi.",
                            "urutan": 1,
                        }
                    ],
                },
                {
                    "judul": "Modul 4: Wallet, Custody, dan Keamanan",
                    "deskripsi": "Manajemen aset dengan aman dan bertanggung jawab.",
                    "urutan": 4,
                    "materi": [
                        {
                            "judul": "Materi 4.1: Self-custody vs Exchange Wallet",
                            "konten": "Perbedaan kontrol aset, risiko pihak ketiga, serta praktik keamanan seed phrase.",
                            "urutan": 1,
                        }
                    ],
                },
                {
                    "judul": "Modul 5: Fundamental Token dan Use Case",
                    "deskripsi": "Menilai utilitas proyek agar tidak hanya ikut hype.",
                    "urutan": 5,
                    "materi": [
                        {
                            "judul": "Materi 5.1: Cara Membaca Whitepaper",
                            "konten": "Parameter dasar untuk mengevaluasi model bisnis, tokenomics, dan roadmap.",
                            "urutan": 1,
                        }
                    ],
                },
                {
                    "judul": "Modul 6: Manajemen Risiko Investasi",
                    "deskripsi": "Aturan dasar agar keputusan investasi lebih disiplin.",
                    "urutan": 6,
                    "materi": [
                        {
                            "judul": "Materi 6.1: Position Sizing dan Batas Kerugian",
                            "konten": "Menentukan porsi modal, stop-loss, dan target berbasis profil risiko.",
                            "urutan": 1,
                        }
                    ],
                },
                {
                    "judul": "Modul 7: Portofolio Syariah Dasar",
                    "deskripsi": "Membangun komposisi aset digital yang lebih seimbang.",
                    "urutan": 7,
                    "materi": [
                        {
                            "judul": "Materi 7.1: Diversifikasi dan Rebalancing",
                            "konten": "Strategi membagi aset inti-satelit dan evaluasi berkala.",
                            "urutan": 1,
                        }
                    ],
                },
                {
                    "judul": "Modul 8: Etika dan Kepatuhan Investasi",
                    "deskripsi": "Menjaga adab investasi dan menghindari praktik terlarang.",
                    "urutan": 8,
                    "materi": [
                        {
                            "judul": "Materi 8.1: Checklist Investasi Bertanggung Jawab",
                            "konten": "Daftar cek sebelum membeli aset: niat, data, risiko, dan kepatuhan syariah.",
                            "urutan": 1,
                        }
                    ],
                },
            ],
            "quiz": [
                {
                    "pertanyaan": "Apa fungsi utama blockchain?",
                    "pilihan": {
                        "A": "Mencatat transaksi secara terdesentralisasi",
                        "B": "Menghapus semua risiko investasi",
                        "C": "Menjamin harga naik",
                        "D": "Menggantikan bank sentral",
                    },
                    "jawaban_benar": "A",
                }
            ],
        },
        {
            "judul": "Analisis Pasar Kripto untuk Pemula",
            "deskripsi": "Belajar membaca tren, support-resistance, dan manajemen risiko dasar.",
            "tingkat": "Pemula",
            "gambar_url": "https://images.unsplash.com/photo-1642052502317-9f1bde08d54d?auto=format&fit=crop&w=1200&q=80",
            "modul": [
                {
                    "judul": "Modul 1: Dasar Analisis",
                    "deskripsi": "Pengenalan price action dan volume.",
                    "urutan": 1,
                    "materi": [
                        {
                            "judul": "Materi 1.1: Membaca Candle",
                            "konten": "Memahami pola candlestick untuk membantu keputusan entry/exit.",
                            "urutan": 1,
                        },
                        {
                            "judul": "Materi 1.2: Risk Management",
                            "konten": "Atur ukuran posisi dan stop-loss agar risiko tetap terkendali.",
                            "urutan": 2,
                        },
                    ],
                }
            ],
            "quiz": [
                {
                    "pertanyaan": "Tujuan stop-loss adalah?",
                    "pilihan": {
                        "A": "Menambah profit",
                        "B": "Membatasi kerugian",
                        "C": "Menjamin menang",
                        "D": "Menghindari pajak",
                    },
                    "jawaban_benar": "B",
                }
            ],
        },
        {
            "judul": "Investasi Syariah: Portofolio Aset Digital",
            "deskripsi": "Strategi diversifikasi portofolio kripto sesuai kaidah syariah.",
            "tingkat": "Menengah",
            "gambar_url": "https://images.unsplash.com/photo-1554224155-8d04cb21cd6c?auto=format&fit=crop&w=1200&q=80",
            "modul": [
                {
                    "judul": "Modul 1: Diversifikasi",
                    "deskripsi": "Menyusun portofolio berimbang.",
                    "urutan": 1,
                    "materi": [
                        {
                            "judul": "Materi 1.1: Alokasi Aset",
                            "konten": "Pisahkan aset inti dan aset spekulatif berdasarkan profil risiko.",
                            "urutan": 1,
                        }
                    ],
                }
            ],
            "quiz": [
                {
                    "pertanyaan": "Manfaat utama diversifikasi adalah?",
                    "pilihan": {
                        "A": "Menghilangkan risiko",
                        "B": "Menaikkan leverage",
                        "C": "Mengurangi dampak risiko tunggal",
                        "D": "Menambah biaya transaksi",
                    },
                    "jawaban_benar": "C",
                }
            ],
        },
        {
            "judul": "Fiqh Muamalah Lanjutan untuk Aset Digital",
            "deskripsi": "Pendalaman kaidah fiqh muamalah pada transaksi dan produk kripto modern.",
            "tingkat": "Lanjutan",
            "gambar_url": "https://images.unsplash.com/photo-1587614382346-4ec70e388b28?auto=format&fit=crop&w=1200&q=80",
            "modul": [
                {
                    "judul": "Modul 1: Gharar dan Maisir",
                    "deskripsi": "Menilai akad dan instrumen yang rawan spekulasi berlebihan.",
                    "urutan": 1,
                    "materi": [
                        {
                            "judul": "Materi 1.1: Studi Kasus Produk Derivatif",
                            "konten": "Analisis praktik derivatif dan tingkat ketidakpastian dalam perspektif syariah.",
                            "urutan": 1,
                        }
                    ],
                }
            ],
            "quiz": [
                {
                    "pertanyaan": "Dalam fiqh muamalah, gharar berarti?",
                    "pilihan": {
                        "A": "Transaksi jelas dan transparan",
                        "B": "Ketidakjelasan berlebihan dalam akad",
                        "C": "Keuntungan pasti",
                        "D": "Sedekah wajib",
                    },
                    "jawaban_benar": "B",
                }
            ],
        },
        {
            "judul": "Zakat Aset Kripto Praktis",
            "deskripsi": "Cara menghitung nishab, haul, dan simulasi zakat aset kripto.",
            "tingkat": "Pemula",
            "gambar_url": "https://images.unsplash.com/photo-1565514020179-026b92b84bb6?auto=format&fit=crop&w=1200&q=80",
            "modul": [
                {
                    "judul": "Modul 1: Dasar Zakat Kripto",
                    "deskripsi": "Nishab, haul, dan skenario perhitungan.",
                    "urutan": 1,
                    "materi": [
                        {
                            "judul": "Materi 1.1: Simulasi Perhitungan",
                            "konten": "Simulasi perhitungan zakat ketika nilai portofolio menyentuh nishab.",
                            "urutan": 1,
                        }
                    ],
                }
            ],
            "quiz": [
                {
                    "pertanyaan": "Syarat wajib zakat mal adalah?",
                    "pilihan": {
                        "A": "Melebihi nishab dan mencapai haul",
                        "B": "Memiliki 1 aset saja",
                        "C": "Trading harian",
                        "D": "Nilai aset stabil",
                    },
                    "jawaban_benar": "A",
                }
            ],
        },
    ]

    for bundle in kelas_bundles:
        _seed_kelas_bundle(bundle, now)
        kelas = mongo.db.kelas.find_one({"judul": bundle["judul"]})
        if kelas:
            _enforce_curriculum(
                kelas["_id"],
                bundle["judul"],
                now,
                module_count=3,
                materi_per_module=3,
            )
            _ensure_quiz_count(kelas["_id"], bundle["judul"], now, quiz_count=15)

    _seed_screener_from_csv(now)
    _seed_pustaka_books(now)

    print("Seeding MongoDB berhasil.")

if __name__ == "__main__":
    seed_data()
