from pymongo import ASCENDING, DESCENDING
from pymongo.database import Database

def setup_indexes(db: Database):
    db.users.create_index([("email", ASCENDING)], unique=True, sparse=True)
    db.password_reset_otp.create_index([("email", ASCENDING)])
    berita_indexes = db.berita.index_information()
    slug_idx = berita_indexes.get("slug_1")
    if slug_idx:
        current_sparse = bool(slug_idx.get("sparse", False))
        current_unique = bool(slug_idx.get("unique", False))
        if (not current_sparse) or (not current_unique):
            db.berita.drop_index("slug_1")
    db.berita.create_index([("slug", ASCENDING)], unique=True, sparse=True)
    db.lms_progress.create_index([("user_id", ASCENDING), ("materi_id", ASCENDING)], unique=True)
    db.quiz_submissions.create_index([("user_id", ASCENDING), ("quiz_id", ASCENDING)])
    db.portofolio.create_index([("user_id", ASCENDING)])
    db.portofolio_transaksi.create_index([("portofolio_id", ASCENDING)])
    db.diskusi.create_index([("created_at", DESCENDING)])
    db.screener.create_index([("simbol", ASCENDING)], unique=True)
    db.buku.create_index([("slug", ASCENDING)], unique=True)
