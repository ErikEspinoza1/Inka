from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware

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