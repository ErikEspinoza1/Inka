from fastapi import FastAPI, UploadFile, File
from fastapi.responses import Response
from fastapi.middleware.cors import CORSMiddleware
from rembg import remove # Importación de la IA para borrar fondos

# Importamos la base de datos y modelos
from database import engine, Base
# Importamos los routers
from routers import auth, artists, bookings, users, content, tattoo_ar

# Crear las tablas en la base de datos (Supabase)
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Tattoo Art API with Supabase")

# CONFIGURACIÓN DE CORS (Solución al error "Failed to fetch")
# Importante: Si usas allow_origins=["*"], allow_credentials DEBE ser False
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"], 
    allow_credentials=False, 
    allow_methods=["*"],
    allow_headers=["*"],
)

# Inclusión de rutas
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(artists.router)
app.include_router(bookings.router)
app.include_router(content.router)
app.include_router(tattoo_ar.router)

@app.get("/")
def read_root():
    return {"status": "online", "db": "supabase", "version": "1.0.0"}


# --- NUEVO ENDPOINT PARA REALIDAD AUMENTADA (Quitar Fondo) ---
@app.post("/api/remove-background")
async def remove_background(file: UploadFile = File(...)):
    try:
        # Leemos los bytes de la imagen enviada desde Flutter
        input_image = await file.read()
        
        # Usamos IA (U2Net a través de rembg) para eliminar el fondo
        output_image = remove(input_image)
        
        # Devolvemos la imagen limpia en formato PNG (transparente)
        return Response(content=output_image, media_type="image/png")
    except Exception as e:
        return {"error": str(e)}