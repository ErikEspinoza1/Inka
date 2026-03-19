import requests
from supabase import create_client, Client
import os

# --- PARCHE PARA EL ERROR DE SSL EN TU WINDOWS ---
if "SSL_CERT_FILE" in os.environ:
    del os.environ["SSL_CERT_FILE"]

# --- 1. CONFIGURACIÓN (Pon tus claves reales y el artist_id) ---
GEMINI_API_KEY = "AIzaSyD4tg-S1T2YO9Yp8adctrMJp1yPDY5MOXY"
SUPABASE_URL = "https://unqfkfunxnlxyatjnyqd.supabase.co" 
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVucWZrZnVueG5seHlhdGpueXFkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NTc4Mzk1MiwiZXhwIjoyMDgxMzU5OTUyfQ.d7ouFX4EPGeaoOVQ-gljxnoc_ZPUxq3o0asLqL7HPrA"
ARTIST_ID = "082e2bbb-6ceb-4a96-9f91-da87b0305820" # <-- ¡Ojo con el ID! Debe ser el mismo que usaste para subir los posts originales.

# Conectamos con Supabase
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# --- 2. EL CATÁLOGO CORREGIDO (Solo descripciones limpias y precisas) ---
descripciones_corregidas = [
    {
        "url_partial": "Lobo%20del%20Bosque%20(1).jpg",
        "description": "Lobo del Bosque - Tatuaje realista en blanco y negro de la cara de un lobo salvaje. No contiene ninguna flor ni rosa."
    },
    {
        "url_partial": "spiderman.jpg",
        "description": "Spiderman Clásico - Tatuaje del famoso trepamuros de Marvel, el Hombre Araña. Diseño puramente de cómic sin flores ni elementos orgánicos."
    },
    {
        "url_partial": "rosa.jpg",
        "description": "Rosa Clásica - Tatuaje de una rosa sola, muy detallada con sus pétalos y hojas. Es un diseño puramente floral de una rosa real."
    }
    # Añade más aquí si crees que sus descripciones eran confusas
]

# --- 3. LA FUNCIÓN MÁGICA PARA EMBEDDING ---
def obtener_embedding(texto):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key={GEMINI_API_KEY}"
    payload = {
        "model": "models/gemini-embedding-001",
        "content": {"parts": [{"text": texto}]}
    }
    respuesta = requests.post(url, json=payload)
    if respuesta.status_code == 200:
        return respuesta.json()['embedding']['values'][:768]
    else:
        print(f"Error con Google: {respuesta.text}")
        return None

# --- 4. A TRABAJAR ---
print("🚀 Iniciando corrección de descripciones...")

for correccion in descripciones_corregidas:
    print(f"\nBuscando post con URL parcial: {correccion['url_partial']}...")
    
    # 1. Buscamos el post por su URL (parcial para facilitar)
    # Suponemos que la url completa contiene artist_id y timestamp, 
    # buscamos posts que tengan artist_id y cuya image_url contenga la url_partial
    query = supabase.table("posts").select("*").eq("artist_id", ARTIST_ID).ilike("image_url", f"%{correccion['url_partial']}%")
    resultados = query.execute()
    
    if resultados.data:
        post = resultados.data[0]
        post_id = post['id']
        print(f"✅ Encontrado Post con ID: {post_id}. Actualizando descripción...")
        
        # 2. Recalculamos el Embedding con la descripción limpia
        nuevo_vector = obtener_embedding(correccion['description'])
        
        if nuevo_vector:
            # 3. Actualizamos la fila en Supabase
            datos_actualizar = {
                "description": correccion['description'],
                "embedding": nuevo_vector
            }
            try:
                supabase.table("posts").update(datos_actualizar).eq("id", post_id).execute()
                print(f"🎉 Post {post_id} actualizado con éxito con la nueva descripción y vector.")
            except Exception as e:
                print(f"❌ Error al actualizar en Supabase: {e}")
    else:
        print(f"⚠️ No se encontró ningún post para '{correccion['url_partial']}' de este artista.")

print("\n🎉 Proceso de corrección terminado. Los embeddings ya no están contaminados.")