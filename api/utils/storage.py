# api/utils/storage.py
import os
from dotenv import load_dotenv
from supabase import create_client, Client

# Cargamos las variables del .env (por si este módulo se importa antes que main.py)
load_dotenv()

# Las claves ahora se leen del archivo .env, NUNCA hardcodeadas
SUPABASE_URL = os.getenv("SUPABASE_URL")
SUPABASE_KEY = os.getenv("SUPABASE_KEY")

if not SUPABASE_URL or not SUPABASE_KEY:
    raise RuntimeError(
        "🚨 Faltan SUPABASE_URL o SUPABASE_KEY en el archivo .env. "
        "Asegúrate de tener ambas variables definidas."
    )

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def upload_file_to_supabase(file_bytes, file_name, bucket="app-images", folder="certificados-higiene"):
    try:
        # Subir a la carpeta especificada dentro del bucket
        path = f"{folder}/{file_name}"
        
        # content-type es importante para que se vea en el navegador
        res = supabase.storage.from_(bucket).upload(
            path=path,
            file=file_bytes,
            file_options={"content-type": "image/jpeg"}
        )
        
        # Obtener la URL pública
        public_url = supabase.storage.from_(bucket).get_public_url(path)
        return public_url
    except Exception as e:
        print(f"Error subiendo a Supabase: {e}")
        return None

def delete_file_from_supabase(file_url: str, bucket: str = "portfolio-artistas"):
    """Extrae el path del archivo de la URL pública y lo borra del bucket de Supabase."""
    if not file_url:
        return False
    try:
        # La URL pública tiene formato: .../storage/v1/object/public/bucket/folder/filename
        # Extraemos todo lo que va después del nombre del bucket
        parts = file_url.split(f"/{bucket}/")
        if len(parts) < 2:
            print(f"⚠️ No se pudo extraer el path del archivo de la URL: {file_url}")
            return False
        
        file_path = parts[1]  # ej: "portfolio-artistas/archivo.jpg"
        
        response = supabase.storage.from_(bucket).remove([file_path])
        print(f"🗑️ Archivo borrado de Supabase: {file_path}")
        return True
    except Exception as e:
        print(f"⚠️ Error intentando borrar archivo de Supabase: {e}")
        return False