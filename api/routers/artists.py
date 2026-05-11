from fastapi import APIRouter, Depends, HTTPException, Query, File, Form, UploadFile
from sqlalchemy.orm import Session
from typing import List, Optional
import database, models, schemas, auth
import shutil
from datetime import datetime
from utils.storage import upload_file_to_supabase, delete_file_from_supabase
import google.generativeai as genai
from PIL import Image
import io
import os
from dotenv import load_dotenv
import base64
import requests
import json as json_lib
from utils.ar_processor import generar_stencil_ar
import hashlib

# CONFIGURACIÓN DE GEMINI
api_key = os.getenv("GEMINI_API_KEY")
if api_key:
    genai.configure(api_key=api_key)

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

    # 2. Generar nombre descriptivo pero único por ID (sin timestamp para permitir sobrescritura)
    clean_shop_name = artist.shop_name.replace(" ", "_") 
    filename = f"{clean_shop_name}_{artist.id}.jpg"
    
    # 3. Leer el archivo en memoria y calcular HASH para evitar duplicados
    file_bytes = await file.read()
    cert_hash = hashlib.sha256(file_bytes).hexdigest()

    # Comprobar si otro artista ya tiene este certificado registrado
    duplicate_artist = db.query(models.Artist).filter(
        models.Artist.certificate_hash == cert_hash,
        models.Artist.id != current_user.id
    ).first()

    if duplicate_artist:
        raise HTTPException(
            status_code=400, 
            detail="Error: Este certificado ya está registrado por otro artista. El uso de documentos ajenos está prohibido."
        )

    # ====================================================
    # 🤖 EL BOT: VERIFICACIÓN CON IA (GEMINI 1.5 FLASH)
    # ====================================================
    print("🤖 IA Analizando documento...")
    is_ai_verified = False
    verification_status = "Pendiente Revisión"
    
    try:
        img = Image.open(io.BytesIO(file_bytes))
        model = genai.GenerativeModel('gemini-flash-latest')
        
        prompt_cert = (
            "Analiza esta imagen y determina si es un certificado oficial de Higiénico Sanitario "
            "válido para profesionales del tatuaje, piercing o micropigmentación. "
            "Responde ÚNICAMENTE con un JSON válido (sin formato Markdown, solo texto plano). "
            "El JSON debe tener esta estructura:\n"
            '{"es_valido": boolean, "explicacion": "string"}\n\n'
            "REGLAS:\n"
            "- 'es_valido' es true solo si el documento es claramente un certificado de higiene sanitaria.\n"
            "- En 'explicacion' justifica MUY brevemente (máximo 5-7 palabras). Ejemplo: 'Es una foto de un coche' o 'Certificado sanitario válido'."
        )
        
        response = model.generate_content([prompt_cert, img])
        texto_ia = response.text.strip()
        
        # Limpiar markdown si Gemini lo añade
        if texto_ia.startswith("```"):
            texto_ia = texto_ia.split("\n", 1)[-1].rsplit("\n", 1)[0].strip()
        if texto_ia.startswith("json"):
            texto_ia = texto_ia[4:].strip()
            
        analisis = json_lib.loads(texto_ia)
        is_ai_verified = analisis.get("es_valido", False)
        explicacion = analisis.get("explicacion", "")
        
        print(f"🕵️ Resultado Gemini: {is_ai_verified} - {explicacion}")
        verification_status = "Verificado (IA)" if is_ai_verified else f"Rechazado (IA): {explicacion}"
        
    except Exception as e:
        print(f"Error Gemini: {e}")
        verification_status = "Error IA - Pendiente"

    # ====================================================
    # 4. LIMPIEZA Y SUBIDA A SUPABASE
    # ====================================================
    # Borrar el certificado antiguo si el nombre ha cambiado o para asegurar limpieza
    if artist.business_document_url:
        # Si el nombre del archivo actual es distinto al nuevo, lo borramos.
        # Si es el mismo, el 'upsert' de la función de subida se encargará de sobrescribirlo.
        if filename not in artist.business_document_url:
            print(f"🗑️ El nombre ha cambiado o es necesario limpiar. Borrando anterior...")
            delete_file_from_supabase(artist.business_document_url)

    public_url = upload_file_to_supabase(file_bytes, filename)

    if not public_url:
        raise HTTPException(status_code=500, detail="Fallo al subir imagen a Supabase")

    # 5. ACTUALIZAR BASE DE DATOS
    artist.business_document_url = public_url
    artist.certificate_hash = cert_hash # Guardamos el hash para futuras comprobaciones
    
    # Actualizamos el estado de verificación: si la IA dice que no vale,
    # el artista deja de estar verificado.
    artist.is_verified = is_ai_verified
    
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
    description: str = Form(""),
    style_tag: str = Form(""),
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
    
    # Texto del artista (puede venir vacío)
    texto_artista = f"{style_tag} {description}".strip()
    
    # =======================================================
    # 🕵️ PASO 1: GEMINI MULTIMODAL — Validación de imagen
    #   + Moderación del texto del artista
    #   + Generación de keywords para embedding
    # =======================================================
    texto_ia_embedding = ""  # Se llenará si Gemini aprueba la imagen
    
    if api_key:
        print("🔍 Pasando filtro Anti-Basura + Análisis Multimodal de Gemini...")
        try:
            img = Image.open(io.BytesIO(file_bytes))
            model = genai.GenerativeModel('gemini-flash-latest')
            
            # Prompt multimodal: validación imagen + moderación texto + metadatos
            # Si el artista ha escrito texto, se lo pasamos a Gemini para moderarlo
            bloque_texto = ""
            if texto_artista:
                bloque_texto = (
                    f'\n\nAdemás, el artista ha escrito este texto para acompañar la imagen:\n'
                    f'"""{texto_artista}"""\n'
                    'Si este texto contiene insultos, contenido sexual explícito, spam, '
                    'URLs sospechosas, contenido de odio o cualquier texto que no sea '
                    'apropiado para una plataforma profesional de tatuajes, marca '
                    '"texto_inapropiado" como true. Si es un texto normal y profesional '
                    '(nombre de estilo, descripción del trabajo, etc.), marca "texto_inapropiado" como false.'
                )
            
            prompt_multimodal = (
                "Eres un experto en tatuajes profesional y moderador de contenido. "
                "Analiza esta imagen y responde ÚNICAMENTE con un JSON válido "
                "(sin formato Markdown, sin ```json, solo texto plano parseable). "
                "El JSON debe tener exactamente esta estructura:\n"
                '{"es_tatuaje": boolean, "texto_inapropiado": boolean, "descripcion_tecnica": "string"}\n\n'
                "REGLAS PARA LA IMAGEN:\n"
                "- Si la imagen NO es un tatuaje real, ni un diseño de tatuaje, ni un boceto artístico "
                '(es decir, es un perro, un paisaje, un meme, comida, una selfie, etc.), responde: '
                '{"es_tatuaje": false, "texto_inapropiado": false, "descripcion_tecnica": ""}\n'
                "- Si la imagen SÍ es un tatuaje real, un diseño de tatuaje o un boceto artístico válido, "
                '"es_tatuaje" debe ser true. En "descripcion_tecnica" escribe una lista de '
                "aproximadamente 20 palabras clave en español separadas por comas. "
                "Incluye: estilo artístico (ej: neotradicional, realismo, old school, japonés, blackwork), "
                "sujeto principal (ej: león, rosa, calavera, dragón), "
                "técnica (ej: puntillismo, línea fina, acuarela, dotwork), "
                "posibles zonas del cuerpo (ej: brazo, antebrazo, espalda, pierna), "
                "y elementos secundarios visibles (ej: flores, geometría, mandala, lettering, sombras)."
                f"{bloque_texto}"
            )
            
            response = model.generate_content([prompt_multimodal, img])
            texto_ia = response.text.strip()
            
            # Limpiar markdown si Gemini lo añade
            if texto_ia.startswith("```"):
                texto_ia = texto_ia.split("\n", 1)[-1].rsplit("\n", 1)[0].strip()
            if texto_ia.startswith("json"):
                texto_ia = texto_ia[4:].strip()
                
            analisis = json_lib.loads(texto_ia)
            es_tatuaje = analisis.get("es_tatuaje", False)
            texto_inapropiado = analisis.get("texto_inapropiado", False)
            descripcion_tecnica = analisis.get("descripcion_tecnica", "")
            
            print(f"🕵️ ¿Es tatuaje? {es_tatuaje}")
            print(f"🚫 ¿Texto inapropiado? {texto_inapropiado}")
            print(f"📝 Descripción técnica: {descripcion_tecnica}")
            
            # VALIDACIÓN 1: Imagen no es tatuaje
            if not es_tatuaje:
                raise HTTPException(
                    status_code=400, 
                    detail="Imagen rechazada: Nuestra IA ha detectado que no es un tatuaje."
                )
            
            # VALIDACIÓN 2: Texto del artista es inapropiado
            if texto_inapropiado:
                raise HTTPException(
                    status_code=400,
                    detail="Texto rechazado: El título o descripción contiene contenido inapropiado. Modifícalo e inténtalo de nuevo."
                )
            
            # ✅ Todo aprobado: guardar la descripción técnica para el embedding
            texto_ia_embedding = descripcion_tecnica
                
        except HTTPException:
            raise
        except Exception as e:
            print(f"⚠️ Error en el filtro Gemini: {e}")
            raise HTTPException(status_code=500, detail="Error validando la imagen.")
    
    # =======================================================
    # 2. Subir a Supabase la original
    # =======================================================
    public_url = upload_file_to_supabase(file_bytes, filename, folder="portfolio-artistas")
    if not public_url:
        raise HTTPException(status_code=500, detail="Failed to upload image")
        
    # =======================================================
    # 🌟 GENERAR Y SUBIR STENCIL PARA AR
    # =======================================================
    ar_public_url = None
    try:
        print("🪄 Iniciando extracción de tatuaje para AR en segundo plano...")
        ar_bytes = generar_stencil_ar(file_bytes)
        
        if ar_bytes:
            ar_filename = f"ar_stencil_{current_user.id}_{timestamp}.png"
            # Subimos el PNG transparente a una carpeta especial en Supabase
            ar_public_url = upload_file_to_supabase(ar_bytes, ar_filename, folder="ar-stencils")
            print(f"✅ Stencil AR subido: {ar_public_url}")
    except Exception as e:
        print(f"⚠️ Aviso: Falló la generación del Stencil AR. Error: {e}")
        # No lanzamos HTTPException porque no queremos bloquear la subida del post normal
        # simplemente se quedará sin versión AR.
    
    # =======================================================
    # 3. CALCULAR EL EMBEDDING — Combinando IA + texto del artista
    # La IA analizó la imagen real → keywords técnicas precisas
    # El artista aporta contexto humano → título y descripción
    # Juntos = embedding rico y completo para búsquedas
    # =======================================================
    vector_ia = None
    
    # Combinar: keywords de la IA + texto del artista (si existe)
    texto_para_embedding = texto_ia_embedding
    if texto_artista:
        texto_para_embedding = f"{texto_ia_embedding}, {texto_artista}"
    
    if texto_para_embedding.strip():
        try:
            print(f"🤖 Calculando embedding: {texto_para_embedding[:100]}...")
            response = genai.embed_content(
                model="models/gemini-embedding-001",
                content=texto_para_embedding,
                task_type="retrieval_document"
            )
            vector_ia = response['embedding'][:768]
            print("✅ Embedding calculado (IA visual + texto artista).")
        except Exception as e:
            print(f"⚠️ Aviso: Falló el embedding. Error: {e}")

    # =======================================================
    # 4. Crear post en Base de Datos
    # description y style_tag del artista se guardan para la UI,
    # el vector combina análisis visual de la IA + texto humano.
    # =======================================================
    new_post = models.Post(
        artist_id=current_user.id,
        image_url=public_url,
        ar_image_url=ar_public_url,
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
    
    # 🧹 1. Borrar la foto original del Storage de Supabase
    delete_file_from_supabase(post.image_url, bucket="portfolio-artistas")
    
    # 🧹 2. Borrar la foto AR (stencil) si existe
    if hasattr(post, 'ar_image_url') and post.ar_image_url:
        delete_file_from_supabase(post.ar_image_url, bucket="ar-stencils")
    
    # 🧹 3. Borrar la fila de la base de datos
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