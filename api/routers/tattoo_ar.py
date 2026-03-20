# api/routers/tattoo_ar.py
from fastapi import APIRouter, File, UploadFile, HTTPException
from fastapi.responses import Response
from rembg import remove

router = APIRouter(prefix="/tattoo", tags=["Tattoo AR"])


@router.get("/health")
def health():
    return {"status": "ok", "service": "tattoo_ar"}


@router.post("/remove_bg")
async def remove_bg(file: UploadFile = File(...)):
    """
    Recibe imagen PNG o JPG, devuelve PNG con fondo transparente.
    """
    if file.content_type not in ("image/png", "image/jpeg", "image/jpg", "image/webp"):
        raise HTTPException(
            status_code=400,
            detail=f"Formato no soportado: {file.content_type}. Usa PNG o JPG."
        )
    try:
        data = await file.read()
        if len(data) == 0:
            raise HTTPException(status_code=400, detail="Archivo vacío")
        result = remove(data)
        return Response(content=result, media_type="image/png")
    except HTTPException:
        raise
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Error al procesar imagen: {str(e)}")