"""FastAPI backend cho Gold Rush — cùng khuôn với `api/main.py` của notebook AI Web Apps.

Chạy:  uvicorn api.main:app --reload --port 8000      (tài liệu tương tác: /docs)

| Method | Endpoint               | Việc                                                       |
|--------|------------------------|------------------------------------------------------------|
| GET    | /api/health            | trạng thái, thành phần nào đã nạp                           |
| POST   | /api/nhat-ky           | app gửi nhật ký một ván (telemetry)                        |
| GET    | /api/bang-xep-hang     | top điểm cao                                               |
| GET    | /api/thong-ke          | số liệu tổng quan, tách theo bật/tắt độ khó thích ứng       |
| GET    | /api/su-kien           | sự kiện (vd. trúng đòn) kèm toạ độ — vẽ bản đồ nhiệt       |
| POST   | /api/do-kho/du-doan    | dự đoán xác suất thua từ 5 đặc trưng (kiểm tra chéo với app)|
| GET    | /api/mo-hinh/do-kho    | tải tệp mô hình hiện hành (app cập nhật mô hình không cần phát hành lại) |
| GET    | /api/ban-do/sinh       | sinh bản đồ .tmx mới theo seed                             |
| POST   | /api/tro-ly            | trợ lý gợi ý cách chơi (RAG rút gọn)                        |
"""
import json
import logging
import sys
import time
from contextlib import asynccontextmanager
from pathlib import Path

sys.path.insert(0, str(Path(__file__).resolve().parents[1]))   # import được config, core khi chạy uvicorn

from fastapi import FastAPI, HTTPException, Query, Request
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import FileResponse, Response
from pydantic import BaseModel, Field

from config import CORS_ORIGINS, ENABLED, KB_DIR, MAX_NHAT_KY_KB, MO_HINH_DO_KHO, NHAT_KY_DIR
from core import do_kho, nhat_ky, sinh_ban_do
from core.tro_ly import TroLy

logging.basicConfig(level=logging.INFO, format="%(asctime)s %(levelname)s %(name)s: %(message)s")
log = logging.getLogger("api")
STATE: dict = {}


@asynccontextmanager
async def lifespan(app: FastAPI):
    # Nạp MỘT LẦN lúc khởi động; một thành phần lỗi không làm sập cả server
    if "do_kho" in ENABLED:
        try:
            STATE["do_kho"] = json.loads(MO_HINH_DO_KHO.read_text(encoding="utf-8"))
        except (OSError, ValueError) as e:
            log.error("không nạp được mô hình độ khó %s: %s", MO_HINH_DO_KHO, e)
    if "tro_ly" in ENABLED:
        try:
            STATE["tro_ly"] = TroLy(KB_DIR)
        except (OSError, ValueError) as e:
            log.error("không nạp được kho tri thức %s: %s", KB_DIR, e)
    yield
    STATE.clear()


app = FastAPI(title="Gold Rush AI API", version="1.0.0", lifespan=lifespan)
app.add_middleware(CORSMiddleware, allow_origins=CORS_ORIGINS, allow_methods=["*"], allow_headers=["*"])


@app.middleware("http")
async def do_thoi_gian(request: Request, call_next):
    t0 = time.perf_counter()
    response = await call_next(request)
    response.headers["X-Process-Time-ms"] = f"{(time.perf_counter() - t0) * 1000:.1f}"
    return response


def _can(ten: str):
    if ten not in ENABLED:
        raise HTTPException(404, f"Thành phần '{ten}' đang tắt (biến ENABLED)")
    if ten in ("do_kho", "tro_ly") and ten not in STATE:
        raise HTTPException(503, f"'{ten}' chưa nạp được — xem log và /api/health")


@app.get("/api/health")
def health():
    return {"status": "ok", "bat": sorted(ENABLED),
            "da_nap": {"do_kho": "do_kho" in STATE, "tro_ly": "tro_ly" in STATE},
            "phien_ban_mo_hinh": STATE.get("do_kho", {}).get("phien_ban")}


# ---------- Nhật ký & bảng xếp hạng ----------
@app.post("/api/nhat-ky", status_code=201)
async def nhan_nhat_ky(request: Request):
    _can("nhat_ky")
    than = await request.body()
    if len(than) > MAX_NHAT_KY_KB * 1024:
        raise HTTPException(413, f"Nhật ký vượt quá {MAX_NHAT_KY_KB} KB")
    try:
        nk = nhat_ky.NhatKyVan.model_validate_json(than)
    except ValueError as e:
        raise HTTPException(422, f"Nhật ký không hợp lệ: {e}")
    nhat_ky.luu(nk, NHAT_KY_DIR)
    return {"da_luu": True, "ma_van": nk.ma_van}


@app.get("/api/bang-xep-hang")
def xep_hang(top: int = Query(10, ge=1, le=100)):
    _can("nhat_ky")
    return {"bang": nhat_ky.bang_xep_hang(nhat_ky.doc_tat_ca(NHAT_KY_DIR), top)}


@app.get("/api/thong-ke")
def thong_ke():
    _can("nhat_ky")
    return nhat_ky.thong_ke(nhat_ky.doc_tat_ca(NHAT_KY_DIR))


@app.get("/api/su-kien")
def su_kien(loai: str = Query("trung_don", pattern="^(nhat_xu|trung_don|ket_thuc)$"),
            ban_do: str = Query("gold_rush.tmx", max_length=60)):
    _can("nhat_ky")
    return {"su_kien": nhat_ky.loc_su_kien(nhat_ky.doc_tat_ca(NHAT_KY_DIR), loai, ban_do)}


# ---------- Mô hình độ khó ----------
class YeuCauDoKho(BaseModel):
    dac_trung: list[float] = Field(min_length=len(do_kho.DAC_TRUNG), max_length=len(do_kho.DAC_TRUNG))


@app.post("/api/do-kho/du-doan")
def du_doan_do_kho(yc: YeuCauDoKho):
    _can("do_kho")
    mh = STATE["do_kho"]
    p = do_kho.du_doan(mh, yc.dac_trung)
    return {"p_thua": round(p, 6), "he_so_toc_do": round(do_kho.he_so_toc_do(p), 4),
            "phien_ban": mh["phien_ban"], "dac_trung": mh["dac_trung"]}


@app.get("/api/mo-hinh/do-kho")
def tai_mo_hinh():
    _can("do_kho")
    return FileResponse(MO_HINH_DO_KHO, media_type="application/json", filename=MO_HINH_DO_KHO.name)


# ---------- Sinh bản đồ ----------
@app.get("/api/ban-do/sinh")
def sinh_ban_do_moi(seed: int = Query(0, ge=0, le=10**9), mat_do: float = Query(0.42, ge=0.30, le=0.48)):
    _can("ban_do")
    try:
        kq = sinh_ban_do.sinh(seed=seed, mat_do=mat_do)
    except ValueError as e:                      # bản đồ quá chật để đặt kẻ địch
        raise HTTPException(422, str(e))
    return Response(sinh_ban_do.thanh_tmx(kq), media_type="application/xml",
                    headers={"X-Chi-So": json.dumps(kq["chi_so"]),
                             "Content-Disposition": f'attachment; filename="gold_rush_{seed}.tmx"'})


# ---------- Trợ lý ----------
class CauHoi(BaseModel):
    cau_hoi: str = Field(min_length=1, max_length=300)


@app.post("/api/tro-ly")
def tro_ly(yc: CauHoi):
    _can("tro_ly")
    return STATE["tro_ly"].hoi(yc.cau_hoi)
