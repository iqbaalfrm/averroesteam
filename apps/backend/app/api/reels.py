import re
from flask import Blueprint, request
from app.extensions import mongo
from .common import response_success, response_error, format_doc

reels_bp = Blueprint("reels_api", __name__, url_prefix="/api/reels")

# ─── Dummy data Fiqh Muamalah / Ekonomi Syariah ─────────────────────
# Audio TTS gratis dari Alquran Cloud untuk ayat-ayat terkait muamalah.
# Di production, ganti dengan audio khusus ustadz/narasumber.

_DUMMY_REELS = [
    # ─── Fiqh Muamalah & Ekonomi Syariah ─────────────────────────────
    {
        "judul": "Al-Baqarah : 275",
        "kategori": "Fiqh Muamalah",
        "kutipan_arab": "وَأَحَلَّ اللَّهُ الْبَيْعَ وَحَرَّمَ الرِّبَا",
        "terjemah": "Dan Allah telah menghalalkan jual beli dan mengharamkan riba.",
        "sumber": "QS. Al-Baqarah : 275",
        "audio_url": "https://cdn.islamic.network/quran/audio/128/ar.alafasy/282.mp3",
    },
    {
        "judul": "Ali Imran : 130",
        "kategori": "Fiqh Muamalah",
        "kutipan_arab": "يَا أَيُّهَا الَّذِينَ آمَنُوا لَا تَأْكُلُوا الرِّبَا أَضْعَافًا مُّضَاعَفَةً ۖ وَاتَّقُوا اللَّهَ لَعَلَّكُمْ تُفْلِحُونَ",
        "terjemah": "Wahai orang-orang yang beriman, janganlah kamu memakan riba dengan berlipat ganda dan bertakwalah kepada Allah agar kamu beruntung.",
        "sumber": "QS. Ali Imran : 130",
        "audio_url": "https://cdn.islamic.network/quran/audio/128/ar.alafasy/423.mp3",
    },
    {
        "judul": "Al-Baqarah : 282",
        "kategori": "Fiqh Muamalah",
        "kutipan_arab": "يَا أَيُّهَا الَّذِينَ آمَنُوا إِذَا تَدَايَنتُم بِدَيْنٍ إِلَىٰ أَجَلٍ مُّسَمًّى فَاكْتُبُوهُ",
        "terjemah": "Wahai orang-orang beriman, apabila kamu bermuamalah tidak tunai untuk waktu yang ditentukan, hendaklah kamu menuliskannya.",
        "sumber": "QS. Al-Baqarah : 282",
        "audio_url": "https://cdn.islamic.network/quran/audio/128/ar.alafasy/289.mp3",
    },
    {
        "judul": "Al-Maidah : 90",
        "kategori": "Fiqh Muamalah",
        "kutipan_arab": "يَا أَيُّهَا الَّذِينَ آمَنُوا إِنَّمَا الْخَمْرُ وَالْمَيْسِرُ وَالْأَنصَابُ وَالْأَزْلَامُ رِجْسٌ مِّنْ عَمَلِ الشَّيْطَانِ فَاجْتَنِبُوهُ",
        "terjemah": "Wahai orang-orang beriman, sesungguhnya khamr, judi, berhala, dan mengundi nasib adalah perbuatan keji dari setan. Maka jauhilah.",
        "sumber": "QS. Al-Maidah : 90",
        "audio_url": "https://cdn.islamic.network/quran/audio/128/ar.alafasy/759.mp3",
    },
    # ─── Sabar ───────────────────────────────────────────────────────
    {
        "judul": "Al-Baqarah : 153",
        "kategori": "Sabar",
        "kutipan_arab": "يَا أَيُّهَا الَّذِينَ آمَنُوا اسْتَعِينُوا بِالصَّبْرِ وَالصَّلَاةِ ۚ إِنَّ اللَّهَ مَعَ الصَّابِرِينَ",
        "terjemah": "Wahai orang-orang beriman, mohonlah pertolongan dengan sabar dan shalat. Sungguh, Allah bersama orang-orang yang sabar.",
        "sumber": "QS. Al-Baqarah : 153",
        "audio_url": "https://cdn.islamic.network/quran/audio/128/ar.alafasy/160.mp3",
    },
    {
        "judul": "Az-Zumar : 10",
        "kategori": "Sabar",
        "kutipan_arab": "إِنَّمَا يُوَفَّى الصَّابِرُونَ أَجْرَهُم بِغَيْرِ حِسَابٍ",
        "terjemah": "Sesungguhnya hanya orang-orang yang bersabarlah yang disempurnakan pahalanya tanpa batas.",
        "sumber": "QS. Az-Zumar : 10",
        "audio_url": "https://cdn.islamic.network/quran/audio/128/ar.alafasy/4068.mp3",
    },
    {
        "judul": "Al-Anfal : 46",
        "kategori": "Sabar",
        "kutipan_arab": "وَاصْبِرُوا ۚ إِنَّ اللَّهَ مَعَ الصَّابِرِينَ",
        "terjemah": "Dan bersabarlah, sesungguhnya Allah bersama orang-orang yang sabar.",
        "sumber": "QS. Al-Anfal : 46",
        "audio_url": "https://cdn.islamic.network/quran/audio/128/ar.alafasy/1206.mp3",
    },
    # ─── Tawakal ─────────────────────────────────────────────────────
    {
        "judul": "At-Talaq : 3",
        "kategori": "Tawakal",
        "kutipan_arab": "وَمَن يَتَوَكَّلْ عَلَى اللَّهِ فَهُوَ حَسْبُهُ",
        "terjemah": "Dan barangsiapa bertawakal kepada Allah, niscaya Allah akan mencukupkan keperluannya.",
        "sumber": "QS. At-Talaq : 3",
        "audio_url": "https://cdn.islamic.network/quran/audio/128/ar.alafasy/5220.mp3",
    },
    {
        "judul": "Ali Imran : 159",
        "kategori": "Tawakal",
        "kutipan_arab": "فَإِذَا عَزَمْتَ فَتَوَكَّلْ عَلَى اللَّهِ ۚ إِنَّ اللَّهَ يُحِبُّ الْمُتَوَكِّلِينَ",
        "terjemah": "Apabila engkau telah membulatkan tekad, maka bertawakallah kepada Allah. Sungguh, Allah mencintai orang yang bertawakal.",
        "sumber": "QS. Ali Imran : 159",
        "audio_url": "https://cdn.islamic.network/quran/audio/128/ar.alafasy/452.mp3",
    },
    # ─── Tidak Tamak / Qana'ah ───────────────────────────────────────
    {
        "judul": "An-Nisa : 32",
        "kategori": "Qana'ah",
        "kutipan_arab": "وَلَا تَتَمَنَّوْا مَا فَضَّلَ اللَّهُ بِهِ بَعْضَكُمْ عَلَىٰ بَعْضٍ",
        "terjemah": "Dan janganlah kamu iri hati terhadap karunia yang telah dilebihkan Allah kepada sebagian kamu atas sebagian yang lain.",
        "sumber": "QS. An-Nisa : 32",
        "audio_url": "https://cdn.islamic.network/quran/audio/128/ar.alafasy/525.mp3",
    },
    {
        "judul": "Ibrahim : 7",
        "kategori": "Syukur",
        "kutipan_arab": "لَئِن شَكَرْتُمْ لَأَزِيدَنَّكُمْ ۖ وَلَئِن كَفَرْتُمْ إِنَّ عَذَابِي لَشَدِيدٌ",
        "terjemah": "Jika kamu bersyukur, niscaya Aku akan menambah nikmat kepadamu, tetapi jika kamu mengingkari, maka sesungguhnya azab-Ku sangat berat.",
        "sumber": "QS. Ibrahim : 7",
        "audio_url": "https://cdn.islamic.network/quran/audio/128/ar.alafasy/1757.mp3",
    },
    {
        "judul": "Al-Hadid : 23",
        "kategori": "Qana'ah",
        "kutipan_arab": "لِّكَيْلَا تَأْسَوْا عَلَىٰ مَا فَاتَكُمْ وَلَا تَفْرَحُوا بِمَا آتَاكُمْ",
        "terjemah": "Agar kamu tidak bersedih atas apa yang luput darimu dan tidak pula terlalu gembira atas apa yang diberikan-Nya kepadamu.",
        "sumber": "QS. Al-Hadid : 23",
        "audio_url": "https://cdn.islamic.network/quran/audio/128/ar.alafasy/5098.mp3",
    },
    # ─── Tawadhu & Ihsan ─────────────────────────────────────────────
    {
        "judul": "Luqman : 18",
        "kategori": "Tawadhu",
        "kutipan_arab": "وَلَا تُصَعِّرْ خَدَّكَ لِلنَّاسِ وَلَا تَمْشِ فِي الْأَرْضِ مَرَحًا ۖ إِنَّ اللَّهَ لَا يُحِبُّ كُلَّ مُخْتَالٍ فَخُورٍ",
        "terjemah": "Dan janganlah kamu memalingkan wajahmu dari manusia dan janganlah berjalan di bumi dengan angkuh. Sungguh, Allah tidak menyukai orang yang sombong dan membanggakan diri.",
        "sumber": "QS. Luqman : 18",
        "audio_url": "https://cdn.islamic.network/quran/audio/128/ar.alafasy/3487.mp3",
    },
    {
        "judul": "Al-Baqarah : 195",
        "kategori": "Ihsan",
        "kutipan_arab": "وَأَحْسِنُوا ۛ إِنَّ اللَّهَ يُحِبُّ الْمُحْسِنِينَ",
        "terjemah": "Dan berbuat baiklah. Sungguh, Allah menyukai orang-orang yang berbuat baik.",
        "sumber": "QS. Al-Baqarah : 195",
        "audio_url": "https://cdn.islamic.network/quran/audio/128/ar.alafasy/202.mp3",
    },
    {
        "judul": "At-Taubah : 103",
        "kategori": "Zakat",
        "kutipan_arab": "خُذْ مِنْ أَمْوَالِهِمْ صَدَقَةً تُطَهِّرُهُمْ وَتُزَكِّيهِم بِهَا",
        "terjemah": "Ambillah zakat dari harta mereka, guna membersihkan dan menyucikan mereka.",
        "sumber": "QS. At-Taubah : 103",
        "audio_url": "https://cdn.islamic.network/quran/audio/128/ar.alafasy/1338.mp3",
    },
]


def _seed_dummy_reels():
    """Seeder: Masukkan dummy reels ke MongoDB.
    Drop dan re-seed jika versi data berubah (misal audio URL diperbaiki).
    """
    _SEED_VERSION = "v4-fixed-ayah"  # Naikkan versi jika data berubah
    marker = mongo.db.reels_meta.find_one({"_id": "seed_version"})
    current_version = (marker or {}).get("version") if marker else None

    if current_version == _SEED_VERSION:
        return  # Data sudah benar

    # Drop data lama dan seed ulang
    mongo.db.reels.drop()

    from datetime import datetime
    now = datetime.utcnow()
    for idx, reel in enumerate(_DUMMY_REELS):
        reel_doc = {
            "urutan": idx + 1,
            "judul": reel["judul"],
            "kategori": reel["kategori"],
            "kutipan_arab": reel["kutipan_arab"],
            "terjemah": reel["terjemah"],
            "sumber": reel["sumber"],
            "penjelasan": reel.get("penjelasan", ""),
            "audio_url": reel.get("audio_url", ""),
            "tags": reel.get("tags", []),
            "durasi_detik": reel.get("durasi_detik", 0),
            "aktif": True,
            "created_at": now,
            "updated_at": now,
        }
        mongo.db.reels.insert_one(reel_doc)

    # Update version marker
    mongo.db.reels_meta.update_one(
        {"_id": "seed_version"},
        {"$set": {"version": _SEED_VERSION}},
        upsert=True,
    )


# ─── API Endpoints ──────────────────────────────────────────────────

@reels_bp.get("")
def list_reels():
    """
    GET /api/reels
    Query params:
      - kategori  : filter by kategori (Fiqh Muamalah / Ekonomi Syariah)
      - tag       : filter by tag
      - limit     : jumlah hasil (default 20, max 50)
    """
    filters = {"aktif": True}

    kategori = (request.args.get("kategori") or "").strip()
    if kategori:
        filters["kategori"] = re.compile(re.escape(kategori), re.IGNORECASE)

    tag = (request.args.get("tag") or "").strip().lower()
    if tag:
        filters["tags"] = tag

    limit = 20
    try:
        limit = min(int(request.args.get("limit") or 20), 50)
    except (ValueError, TypeError):
        pass

    rows = list(
        mongo.db.reels
        .find(filters)
        .sort("urutan", 1)
        .limit(limit)
    )

    if not rows:
        # Seed otomatis kalau kosong
        _seed_dummy_reels()
        rows = list(
            mongo.db.reels
            .find(filters)
            .sort("urutan", 1)
            .limit(limit)
        )

    data = [format_doc(row) for row in rows]
    return response_success(
        f"Berhasil mengambil {len(data)} reels Fiqh Muamalah",
        data,
    )


@reels_bp.get("/<string:reel_id>")
def detail_reel(reel_id):
    """GET /api/reels/<id> — Detail satu reel."""
    from bson import ObjectId
    try:
        row = mongo.db.reels.find_one({"_id": ObjectId(reel_id)})
    except Exception:
        return response_error("ID tidak valid", 400)

    if not row:
        return response_error("Reel tidak ditemukan", 404)

    return response_success("Berhasil mengambil detail reel", format_doc(row))


@reels_bp.get("/kategori")
def list_kategori():
    """GET /api/reels/kategori — Daftar kategori unik."""
    pipeline = [
        {"$match": {"aktif": True}},
        {"$group": {"_id": "$kategori", "jumlah": {"$sum": 1}}},
        {"$sort": {"_id": 1}},
    ]
    results = list(mongo.db.reels.aggregate(pipeline))
    data = [{"kategori": r["_id"], "jumlah": r["jumlah"]} for r in results]
    return response_success("Berhasil mengambil kategori reels", data)
