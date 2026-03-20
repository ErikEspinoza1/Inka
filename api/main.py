from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from database import engine, Base
from routers import auth, artists, bookings, users, content, tattoo_ar

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Tattoo Art API with Supabase")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(auth.router)
app.include_router(users.router)
app.include_router(artists.router)
app.include_router(bookings.router)
app.include_router(content.router)
app.include_router(tattoo_ar.router)

@app.get("/")
def read_root():
    return {"status": "online", "db": "supabase"}

    # .\venv\Scripts\activate
    # uvicorn main:app --host 0.0.0.0 --reload