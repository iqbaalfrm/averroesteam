from flask import Blueprint, request

from app.models import Berita

from .common import response_success

berita_bp = Blueprint("berita_api", __name__, url_prefix="/api/berita")


@berita_bp.get("/terbaru")
def berita_terbaru():
    rows = Berita.query.order_by(Berita.published_at.desc()).limit(5).all()
    return response_success("Berhasil mengambil berita terbaru", [row.to_dict() for row in rows])


@berita_bp.get("")
def berita_semua():
    page = request.args.get("page", 1, type=int)
    per_page = request.args.get("per_page", 20, type=int)
    per_page = max(1, min(per_page, 50))
    pagination = Berita.query.order_by(Berita.published_at.desc()).paginate(
        page=page, per_page=per_page, error_out=False
    )

    data = {
        "items": [row.to_dict() for row in pagination.items],
        "page": page,
        "per_page": per_page,
        "total": pagination.total,
        "pages": pagination.pages,
    }
    return response_success("Berhasil mengambil semua berita", data)
