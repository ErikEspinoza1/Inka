# api/utils/storage.py
import os
from supabase import create_client, Client

# Poned esto en vuestro .env idealmente
SUPABASE_URL = "https://unqfkfunxnlxyatjnyqd.storage.supabase.co/storage/v1/s3"
SUPABASE_KEY = "1db4fc8c68ecfcd8e4b183a6f2a6e75b61051dc5deb34802a915439aa3b400e6" # O Service Role Key si tienes problemas de permisos

#ACCES KEI ID: b1088ff48be9224ef7374f8cb1a06c47
#SECRET ACCESS KEY: 1db4fc8c68ecfcd8e4b183a6f2a6e75b61051dc5deb34802a915439aa3b400e6

supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

def upload_file_to_supabase(file_bytes, file_name, bucket="app-images"):
    try:
        # Subir a la carpeta 'certificados-higiene' dentro del bucket
        path = f"certificados-higiene/{file_name}"
        
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