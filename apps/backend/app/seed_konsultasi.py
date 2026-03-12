from datetime import datetime
from app.extensions import mongo
from werkzeug.security import generate_password_hash

def _ensure_kategori_konsultasi(now: datetime) -> None:
    kategori = [
        {"id": "fiqh_muamalah", "nama": "Fiqh Muamalah"},
        {"id": "investasi_syariah", "nama": "Investasi Syariah"},
        {"id": "zakat_wakaf", "nama": "Zakat & Wakaf"},
    ]
    for kat in kategori:
        mongo.db.kategori_ahli.update_one(
            {"id": kat["id"]},
            {"$set": {
                "nama": kat["nama"],
                "updated_at": now
            }},
            upsert=True
        )

def _seed_ahli_syariah(now: datetime) -> None:
    ahli_list = [
        {
            "nama": "Ustadz Fida Munadzir",
            "email": "fida@averroes.com",
            "spesialis": "Ahli Fiqh Muamalah",
            "kategori_id": "fiqh_muamalah",
            "rating": 4.9,
            "total_review": 120,
            "pengalaman_tahun": 12,
            "harga_per_sesi": 50000,
            "no_whatsapp": "628123456789",
            "is_online": True,
            "is_verified": True,
            "foto_url": "https://lh3.googleusercontent.com/aida-public/AB6AXuA6wdv3CSHlAgUXUTKatvNd7pFq5_DtsGM5RXtCNGOOg_FU7kQl_zsy6d-mZRxZR6VS5VhgGppyQaAUOvufZt1VGPFG7ekWi3ARygped7vn-a8uwu-hQVzKQiShYe6XGZG7iWpIZT3rPVboSeCheveyEiBF4CPevnwm-W8OLlEKqn66-niZwCGPBw31vXAoC7jxRSF3Y5cgW2qQpNgkDIOGEyNyx7Nbc0a1dthidyyrHhFlAWfBxDVVwIWWhFvViKkuK7chHa2C4dA",
        },
        {
            "nama": "Ustadz Devin Halim Wijaya",
            "email": "devin@averroes.com",
            "spesialis": "Spesialis Investasi Syariah",
            "kategori_id": "investasi_syariah",
            "rating": 4.8,
            "total_review": 85,
            "pengalaman_tahun": 8,
            "harga_per_sesi": 50000,
            "no_whatsapp": "628223456789",
            "is_online": True,
            "is_verified": True,
            "foto_url": "https://lh3.googleusercontent.com/aida-public/AB6AXuDCr7P7hom-AXpyjbrbfu4HfnbzDYI8Gv0h0BPZOHZ21IcsjuqkMf6209xp4v5wDA1JpaI9bVWwtHQyft5fgfsg1P_Q5nNjppIXiVt70xmOp6mmvegcUDLWzFRu2TUe9OPWaF9cWM5JJhIfhaAaOikdZlqN_V6Rfv1Y6aM2Gtnhmwb-Xdy8lKwhyEUJGarJF2zMuucnRRk8ovkwaJcLvJpzJfE6TJvdTBzUV_nRk__VJNPePhpMWdOgc54o_ptnzVPmt90FuVbEnW8",
        },
        {
            "nama": "Ustadz Ade Setiawan",
            "email": "ade@averroes.com",
            "spesialis": "Kajian Zakat & Wakaf Digital",
            "kategori_id": "zakat_wakaf",
            "rating": 5.0,
            "total_review": 210,
            "pengalaman_tahun": 15,
            "harga_per_sesi": 50000,
            "no_whatsapp": "628323456789",
            "is_online": False,
            "is_verified": True,
            "foto_url": "https://lh3.googleusercontent.com/aida-public/AB6AXuBcrW3ePyd8Fk9_N4w5WUyl--cOXRfh0habRU9qOqlpJZfAz53Bb1U3WdHxaSVJhDMkAZT8KsElfABog3-_2WNB39kD6KIg_aYLjFK6NNgmnYi_UltjDLzbaaer1-1lsR5ue178r_xXlf9RNwnJG0WFrZcaVmtDej_QuZWUMlhqE4VeIjL9U6cV0kDnkkmjdyA5nD07VMtHSHJCmT9eRi1ZylMAxtha5Iny-zb_vlOJyvf7cwXvlazs_GEJo9M0iZE_svtysIxc5tk",
        },
    ]
    
    for item in ahli_list:
        # 1. Pastikan User Akun (Role Ustadz) ada
        if not mongo.db.users.find_one({"email": item["email"]}):
            mongo.db.users.insert_one({
                "nama": item["nama"],
                "email": item["email"],
                "password_hash": generate_password_hash("ustadz123"),
                "role": "ustadz",
                "created_at": now,
                "updated_at": now
            })
        
        # 2. Update/Insert Data Ahli
        mongo.db.ahli_syariah.update_one(
            {"email": item["email"]},
            {"$set": {
                "nama": item["nama"],
                "spesialis": item["spesialis"],
                "kategori_id": item["kategori_id"],
                "rating": item["rating"],
                "total_review": item["total_review"],
                "pengalaman_tahun": item["pengalaman_tahun"],
                "harga_per_sesi": item["harga_per_sesi"],
                "no_whatsapp": item["no_whatsapp"],
                "is_online": item["is_online"],
                "is_verified": item["is_verified"],
                "foto_url": item["foto_url"],
                "updated_at": now
            }},
            upsert=True
        )

def seed_konsultasi_data():
    now = datetime.utcnow()
    _ensure_kategori_konsultasi(now)
    _seed_ahli_syariah(now)
    print("Seeding data Konsultasi & Ustadz berhasil.")
