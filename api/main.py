import os
import requests 
from fastapi import FastAPI, Depends, HTTPException, UploadFile, File
from fastapi.responses import Response
from fastapi.middleware.cors import CORSMiddleware  
from sqlalchemy.orm import Session
from sqlalchemy import text
from rembg import remove  # AI background removal
from database import engine, Base, get_db
from dotenv import load_dotenv
from PIL import Image
import io

# Load secret variables
load_dotenv()

# --- SSL PATCH ---
if "SSL_CERT_FILE" in os.environ:
    del os.environ["SSL_CERT_FILE"]

# Import all routers
from routers import auth, artists, bookings, users, content, messages, tattoo_ar

# Create tables in the database (Supabase)
Base.metadata.create_all(bind=engine)

app = FastAPI(title="Tattoo Art API with Supabase")

# --- CORS CONFIGURATION ---
# IMPORTANT: allow_credentials MUST be False if allow_origins is ["*"]
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  
    allow_credentials=False, 
    allow_methods=["*"],  
    allow_headers=["*"],  
)

# Include routers
app.include_router(auth.router)
app.include_router(users.router)
app.include_router(artists.router)
app.include_router(bookings.router)
app.include_router(content.router)
app.include_router(messages.router)
app.include_router(tattoo_ar.router)

# --- AI AUTOPILOT ENDPOINT ---
@app.get("/buscar-tatuajes-ia")
def search_tattoos_ai(idea: str, db: Session = Depends(get_db)):
    try:
        print(f"🧠 Searching for idea: {idea}")
        
        # 👇 MAGIC: Read the new key from .env without exposing it 👇
        api_key = os.getenv("GEMINI_API_KEY")
        
        if not api_key:
            raise Exception("🚨 GEMINI_API_KEY not found in the .env file")

        # 1. Ask Google which models are actually enabled
        url_models = f"https://generativelanguage.googleapis.com/v1beta/models?key={api_key}"
        res_models = requests.get(url_models)
        
        if res_models.status_code != 200:
            raise Exception(f"Failed to query Google: {res_models.text}")
        
        available_models = res_models.json().get("models", [])
        
        # Automatically find the first model that supports text-to-numbers (embeddings)
        embedding_model = None
        for m in available_models:
            if "embedContent" in m.get("supportedGenerationMethods", []):
                embedding_model = m["name"]
                break
                
        if not embedding_model:
            raise Exception("🚨 YOUR API KEY HAS NO SEARCH MODEL ENABLED.")
            
        print(f"✅ Hack successful! Google tells us to use hidden model: {embedding_model}")
        
        # 2. Fire the request with the exact model
        url_embed = f"https://generativelanguage.googleapis.com/v1beta/{embedding_model}:embedContent?key={api_key}"
        
        payload = {
            "model": embedding_model,
            "content": {
                "parts": [{"text": idea}]
            }
        }
        
        response = requests.post(url_embed, json=payload)
        
        if response.status_code != 200:
            raise Exception(f"Failed to generate vector: {response.text}")
            
        # Extract the list and EXACTLY trim it to 768 dimensions ✂️
        data = response.json()
        search_vector = data['embedding']['values'][:768]
        
        print("✅ Numbers generated! Searching for tattoos in Supabase...")
        
        # 3. Search in Supabase using CAST to prevent Python confusion
        query = text("SELECT * FROM buscar_tatuajes(CAST(:vector AS vector(768)), 3)")
        results = db.execute(query, {"vector": str(search_vector)}).mappings().all()
        
        return [dict(row) for row in results]
    except Exception as e:
        print(f"❌ AI Error: {e}")
        raise HTTPException(status_code=500, detail=str(e))

# --- ORIGINAL TEST ROUTE ---
@app.get("/")
def read_root():
    return {"status": "online", "db": "supabase", "version": "1.0.0"}


# --- NUEVO ENDPOINT PARA REALIDAD AUMENTADA (Transparencia Total) ---
@app.post("/api/remove-background")
async def remove_background(file: UploadFile = File(...)):
    try:
        input_image = await file.read()
        
        # 1. Abrimos la imagen y la convertimos a formato con Transparencia (RGBA)
        img = Image.open(io.BytesIO(input_image)).convert("RGBA")
        data = img.getdata()
        
        new_data = []
        
        # 2. Filtro de Umbral (Thresholding)
        # Si el píxel es mayormente blanco/claro (R>200, G>200, B>200), lo volvemos invisible.
        # Si es tinta negra/oscura, lo dejamos intacto.
        for item in data:
            if item[0] > 200 and item[1] > 200 and item[2] > 200:
                new_data.append((255, 255, 255, 0)) # Alpha = 0 (Transparente)
            else:
                new_data.append(item)
                
        img.putdata(new_data)
        
        # 3. Guardamos y enviamos a Flutter
        img_byte_arr = io.BytesIO()
        img.save(img_byte_arr, format='PNG')
        
        return Response(content=img_byte_arr.getvalue(), media_type="image/png")
    except Exception as e:
        return {"error": str(e)}