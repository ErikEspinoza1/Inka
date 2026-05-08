from fastapi import APIRouter, Depends, HTTPException, Query, File, UploadFile
from sqlalchemy.orm import Session
from typing import List, Optional
import database, models, schemas, auth
import easyocr
import shutil
from datetime import datetime
from utils.storage import upload_file_to_supabase
import google.generativeai as genai
from PIL import Image
import io
import os
from dotenv import load_dotenv
import base64
import requests
import json as json_lib

reader = easyocr.Reader(['es'], gpu=False)

router = APIRouter(prefix="/artists", tags=["Artists"])

# 1. Obtener artistas (Solo VERIFICADOS)
# Añadimos filtros opcionales por si quieres buscar por ciudad o estilo
@router.get("/", response_model=List[schemas.ArtistResponse])
def get_all_artists(
    style: Optional[str] = None,
    db: Session = Depends(database.get_db)
):
    # Base query: Solo artistas verificados
    query = db.query(models.Artist).filter(models.Artist.is_verified == True)
    
    if style:
        # Filtro básico de array (Postgres specific syntax might differ, this is simple python filter equivalent logic for ORM)
        # Para arrays en PG se suele usar: models.Artist.styles.any(style)
        query = query.filter(models.Artist.styles.any(style))
        
    return query.all()

# 2. Endpoint para Admin (Ver todos, incluidos pendientes de revisión)
@router.get("/admin/pending", response_model=List[schemas.ArtistResponse])
def get_pending_artists(
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    if current_user.role != models.UserRole.ADMIN: # Asegúrate de tener ADMIN en tu Enum UserRole
        raise HTTPException(status_code=403, detail="Admin privileges required")
        
    return db.query(models.Artist).filter(models.Artist.is_verified == False).all()

# 3. Convertirse en Artista (Registro)
@router.post("/become-artist", response_model=schemas.ArtistResponse)
def create_artist_profile(
    artist_data: schemas.ArtistCreate, 
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    if current_user.artist_profile:
        raise HTTPException(status_code=400, detail="User is already an artist")
    
    # Crear el objeto artista
    # Por defecto is_verified es FALSE en el modelo, así que no hace falta ponerlo aquí
    new_artist = models.Artist(
        id=current_user.id, 
        **artist_data.dict()
    )
    
    # Actualizar rol del usuario base a ARTISTA
    current_user.role = models.UserRole.artista
    
    db.add(new_artist)
    db.commit()
    db.refresh(new_artist)
    
    return new_artist

# --- ENDPOINT ACTUALIZAR PERFIL ---
@router.patch("/me", response_model=schemas.ArtistResponse)
def update_artist_profile(
    update_data: schemas.ArtistUpdate,
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    # Validar que sea artista
    if current_user.role != models.UserRole.artista:
        raise HTTPException(status_code=403, detail="Not authorized")
        
    artist = db.query(models.Artist).filter(models.Artist.id == current_user.id).first()
    if not artist:
        raise HTTPException(status_code=404, detail="Artist profile not found")
        
    # Actualizar campos dinámicamente
    update_dict = update_data.dict(exclude_unset=True)
    for key, value in update_dict.items():
        setattr(artist, key, value)
        
    db.commit()
    db.refresh(artist)
    return artist

@router.get("/me", response_model=schemas.ArtistResponse)
def get_my_artist_profile(
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    # Verificamos si tiene perfil de artista
    if not current_user.artist_profile:
        raise HTTPException(status_code=404, detail="No artist profile found")
    
    return current_user.artist_profile


@router.post("/upload-certificate")
async def upload_certificate(
    file: UploadFile = File(...),
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    # 1. Validar que sea artista
    if current_user.role != models.UserRole.artista:
        raise HTTPException(status_code=403, detail="Solo artistas pueden subir certificados")

    artist = db.query(models.Artist).filter(models.Artist.id == current_user.id).first()
    if not artist:
        raise HTTPException(status_code=404, detail="Perfil de artista no encontrado")

    # 2. Generar nombre único: ShopName_ID_Timestamp.jpg
    # Limpiamos el nombre de espacios para evitar problemas en URL
    clean_shop_name = artist.shop_name.replace(" ", "_") 
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"{clean_shop_name}_{artist.id}_{timestamp}.jpg"
    
    # 3. Leer el archivo en memoria
    file_bytes = await file.read()

    # ====================================================
    # 🤖 EL BOT: VERIFICACIÓN CON IA (EasyOCR)
    # ====================================================
    print("🤖 IA Analizando documento...")
    try:
        # EasyOCR lee directamente los bytes
        result = reader.readtext(file_bytes, detail=0) # detail=0 devuelve solo el texto
        full_text = " ".join(result).upper() # Convertimos todo a mayúsculas
        print(f"Texto detectado: {full_text[:100]}...") # Log para ver qué lee

        # PALABRAS CLAVE PARA APROBAR
        keywords = ["CERTIFICADO", "HIGIENICO", "SANITARIO", "APTO", "CURSO", "TITULO"]
        
        # Lógica: Si encuentra al menos 2 palabras clave, lo damos por válido
        matches = sum(1 for word in keywords if word in full_text)
        is_ai_verified = matches >= 1 
        
        verification_status = "Verificado (IA)" if is_ai_verified else "Pendiente Revisión"
        
    except Exception as e:
        print(f"Error IA: {e}")
        is_ai_verified = False # Si falla la IA, no bloqueamos, solo lo dejamos pendiente
        verification_status = "Error IA - Pendiente"

    # ====================================================
    # 4. SUBIR A SUPABASE
    # ====================================================
    # (Aquí deberías llamar a la función del PASO 2. Te pongo el código inline por si acaso)
    # Asumiendo que has instanciado 'supabase' client aquí arriba como te expliqué antes:
    from utils.storage import upload_file_to_supabase # Asegúrate de importar esto
    public_url = upload_file_to_supabase(file_bytes, filename)

    if not public_url:
        raise HTTPException(status_code=500, detail="Fallo al subir imagen a Supabase")

    # 5. ACTUALIZAR BASE DE DATOS
    artist.business_document_url = public_url
    
    # OPCIONAL: ¿Quieres que se verifique automáticamente en la app?
    # Si la IA dice que sí, ponemos is_verified = True.
    # Si prefieres ser cauto, déjalo en False y que un admin lo revise, 
    # pero dijiste que no querías hacer esperar a las empresas:
    if is_ai_verified:
        artist.is_verified = True
    
    db.commit()
    
    return {
        "status": "success", 
        "ai_analysis": verification_status,
        "is_verified": artist.is_verified,
        "url": public_url
    }

# --- PORTFOLIO ENDPOINTS ---

@router.get("/me/posts", response_model=List[schemas.PostResponse])
def get_my_posts(
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    if current_user.role != models.UserRole.artista:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    artist = db.query(models.Artist).filter(models.Artist.id == current_user.id).first()
    if not artist:
        raise HTTPException(status_code=404, detail="Artist profile not found")
    
    return db.query(models.Post).filter(models.Post.artist_id == current_user.id).all()

@router.post("/me/posts", response_model=schemas.PostResponse)
async def create_post(
    description: str = "",
    style_tag: str = "",
    file: UploadFile = File(...),
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    if current_user.role != models.UserRole.artista:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    artist = db.query(models.Artist).filter(models.Artist.id == current_user.id).first()
    if not artist:
        raise HTTPException(status_code=404, detail="Artist profile not found")
    
    # 1. Generar nombre único y leer archivo de la memoria (aún no se sube)
    clean_shop_name = artist.shop_name.replace(" ", "_")
    timestamp = datetime.now().strftime("%Y%m%d_%H%M%S")
    filename = f"portfolio_{clean_shop_name}_{current_user.id}_{timestamp}.jpg"
    file_bytes = await file.read()
    
    # =======================================================
    # 🕵️ PASO 1: GEMINI MULTIMODAL — Validación + Metadatos
    # Un solo prompt que mata dos pájaros de un tiro:
    #   - Filtra basura (perros, memes, paisajes)
    #   - Genera keywords técnicas para el embedding
    # =======================================================
    api_key = os.getenv("GEMINI_API_KEY")
    texto_ia_embedding = ""  # Se llenará si Gemini aprueba la imagen
    
    if api_key:
        print("🔍 Pasando filtro Anti-Basura + Análisis Multimodal de Gemini...")
        try:
            # 1. Convertimos la imagen a Base64
            base64_image = base64.b64encode(file_bytes).decode('utf-8')
            # Flutter a veces envía 'application/octet-stream' — Gemini lo rechaza
            mime_type = file.content_type if file.content_type and file.content_type.startswith("image/") else "image/jpeg"
            
            # 2. URL con el modelo Gemini 2.5 Flash
            url_vision = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}"
            
            # 3. Prompt multimodal: validación + generación de metadatos en un solo disparo
            prompt_multimodal = (
                "Eres un experto en tatuajes profesional. Analiza esta imagen y responde "
                "ÚNICAMENTE con un JSON válido (sin formato Markdown, sin ```json, solo texto plano parseable). "
                "El JSON debe tener exactamente esta estructura:\n"
                '{"es_tatuaje": boolean, "descripcion_tecnica": "string"}\n\n'
                "REGLAS:\n"
                "- Si la imagen NO es un tatuaje real, ni un diseño de tatuaje, ni un boceto artístico "
                '(es decir, es un perro, un paisaje, un meme, comida, una selfie, etc.), responde: '
                '{"es_tatuaje": false, "descripcion_tecnica": ""}\n'
                "- Si la imagen SÍ es un tatuaje real, un diseño de tatuaje o un boceto artístico válido, "
                'responde con "es_tatuaje": true y en "descripcion_tecnica" escribe una lista de '
                "aproximadamente 20 palabras clave en español separadas por comas. "
                "Incluye: estilo artístico (ej: neotradicional, realismo, old school, japonés, blackwork), "
                "sujeto principal (ej: león, rosa, calavera, dragón), "
                "técnica (ej: puntillismo, línea fina, acuarela, dotwork), "
                "posibles zonas del cuerpo (ej: brazo, antebrazo, espalda, pierna), "
                "y elementos secundarios visibles (ej: flores, geometría, mandala, lettering, sombras)."
            )
            
            payload = {
                "contents": [{
                    "parts": [
                        {"text": prompt_multimodal},
                        {
                            "inline_data": {
                                "mime_type": mime_type,
                                "data": base64_image
                            }
                        }
                    ]
                }]
            }
            
            # 4. Disparamos la petición
            respuesta = requests.post(url_vision, json=payload)
            
            if respuesta.status_code == 200:
                datos = respuesta.json()
                texto_crudo = datos['candidates'][0]['content']['parts'][0]['text'].strip()
                print(f"🧠 Respuesta cruda de Gemini: {texto_crudo}")
                
                # Limpiar posible formato markdown que Gemini añade a veces
                texto_limpio = texto_crudo
                if texto_limpio.startswith("```"):
                    texto_limpio = texto_limpio.split("\n", 1)[-1]  # Quita la primera línea ```json
                if texto_limpio.endswith("```"):
                    texto_limpio = texto_limpio[:-3]  # Quita el ``` final
                texto_limpio = texto_limpio.strip()
                
                # Parsear el JSON
                analisis = json_lib.loads(texto_limpio)
                
                es_tatuaje = analisis.get("es_tatuaje", False)
                descripcion_tecnica = analisis.get("descripcion_tecnica", "")
                
                print(f"🕵️ ¿Es tatuaje? {es_tatuaje}")
                print(f"📝 Descripción técnica: {descripcion_tecnica}")
                
                if not es_tatuaje:
                    raise HTTPException(
                        status_code=400, 
                        detail="Imagen rechazada: Nuestra IA ha detectado que no es un tatuaje."
                    )
                
                # ✅ Aprobada: guardar la descripción técnica para el embedding
                texto_ia_embedding = descripcion_tecnica
                
            else:
                # Si Google falla, bloqueamos por seguridad
                print(f"⚠️ Error en la API de Gemini: {respuesta.text}")
                raise HTTPException(
                    status_code=500, 
                    detail="Error temporal en el sistema de validación. Inténtalo de nuevo."
                )
                
        except HTTPException:
            raise  # Lanza el error exacto al móvil (400 o 500)
        except json_lib.JSONDecodeError as e:
            print(f"⚠️ Gemini devolvió un JSON inválido: {e}")
            raise HTTPException(status_code=500, detail="Error procesando la validación. Inténtalo de nuevo.")
        except Exception as e:
            print(f"⚠️ Error general en el filtro: {e}")
            raise HTTPException(status_code=500, detail="Error validando la imagen.")
    
    # =======================================================
    # 2. Subir a Supabase (SÓLO LLEGA AQUÍ SI ES UN TATUAJE REAL)
    # =======================================================
    public_url = upload_file_to_supabase(file_bytes, filename, folder="portfolio-artistas")
    if not public_url:
        raise HTTPException(status_code=500, detail="Failed to upload image")
    
    # =======================================================
    # 3. CALCULAR EL EMBEDDING — Usando la descripción de la IA
    # La IA analizó la imagen real, así que sus keywords son
    # mucho más precisas que lo que escribiría el usuario.
    # =======================================================
    vector_ia = None
    
    if texto_ia_embedding.strip():
        try:
            print(f"🤖 Calculando embedding con texto de la IA: {texto_ia_embedding[:80]}...")
            if not api_key:
                raise Exception("🚨 No se encontró la GEMINI_API_KEY en el .env")

            url_embed = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key={api_key}"
            
            payload = {
                "model": "models/gemini-embedding-001",
                "content": {"parts": [{"text": texto_ia_embedding}]}
            }
            respuesta = requests.post(url_embed, json=payload)
            
            if respuesta.status_code == 200:
                vector_ia = respuesta.json()['embedding']['values'][:768]
                print("✅ Embedding calculado con éxito a partir del análisis visual de la IA.")
            else:
                 print(f"⚠️ Error de Gemini Embedding: {respuesta.text}")
        except Exception as e:
            print(f"⚠️ Aviso: Falló el embedding. Error: {e}")

    # =======================================================
    # 4. Crear post en Base de Datos
    # description y style_tag del usuario se guardan para la UI,
    # pero el vector viene del análisis visual de la IA.
    # =======================================================
    new_post = models.Post(
        artist_id=current_user.id,
        image_url=public_url,
        description=description,
        style_tag=style_tag,
        embedding=vector_ia 
    )
    
    db.add(new_post)
    db.commit()
    db.refresh(new_post)
    
    return new_post
@router.delete("/me/posts/{post_id}")
def delete_post(
    post_id: str,
    current_user: models.Profile = Depends(auth.get_current_user),
    db: Session = Depends(database.get_db)
):
    if current_user.role != models.UserRole.artista:
        raise HTTPException(status_code=403, detail="Not authorized")
    
    post = db.query(models.Post).filter(
        models.Post.id == post_id,
        models.Post.artist_id == current_user.id
    ).first()
    
    if not post:
        raise HTTPException(status_code=404, detail="Post not found")
    
    db.delete(post)
    db.commit()
    
    return {"status": "deleted"}

# --- CLIENT ENDPOINTS ---

@router.get("/{artist_id}", response_model=schemas.ArtistResponse)
def get_artist_by_id(artist_id: str, db: Session = Depends(database.get_db)):
    artist = db.query(models.Artist).filter(models.Artist.id == artist_id).first()
    if not artist:
        raise HTTPException(status_code=404, detail="Artist not found")
    return artist

@router.get("/{artist_id}/posts", response_model=List[schemas.PostResponse])
def get_artist_posts(artist_id: str, db: Session = Depends(database.get_db)):
    # Verificar que el artista existe
    artist = db.query(models.Artist).filter(models.Artist.id == artist_id).first()
    if not artist:
        raise HTTPException(status_code=404, detail="Artist not found")
    
    return db.query(models.Post).filter(models.Post.artist_id == artist_id).all()