from fastapi import FastAPI
from database import engine, Base
# Importamos TODOS los routers
from routers import auth, artists, bookings, users, content

Base.metadata.create_all(bind=engine)

app = FastAPI(title="Tattoo Art API with Supabase")

app.include_router(auth.router)
app.include_router(users.router)  
app.include_router(artists.router)
app.include_router(bookings.router)
app.include_router(content.router) 
@app.get("/")
def read_root():
    return {"status": "online", "db": "supabase"}