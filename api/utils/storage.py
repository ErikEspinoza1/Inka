# api/utils/storage.py
import os
from supabase import create_client, Client

# Poned esto en vuestro .env idealmente
SUPABASE_URL = "https://unqfkfunxnlxyatjnyqd.supabase.co"
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVucWZrZnVueG5seHlhdGpueXFkIiwicm9sZSI6ImFub24iLCJpYXQiOjE3NjU3ODM5NTIsImV4cCI6MjA4MTM1OTk1Mn0.Mfe5ykSKG9gds8FNIjnaFuN63VsLZ_89-LZU0KGj8mI" # O Service Role Key si tienes problemas de permisos

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