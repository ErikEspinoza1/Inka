import requests
from supabase import create_client, Client
import os

# --- PARCHE PARA EL ERROR DE SSL EN TU WINDOWS ---
if "SSL_CERT_FILE" in os.environ:
    del os.environ["SSL_CERT_FILE"]

# --- 1. CONFIGURACIÓN (Pon tus claves reales aquí) ---
GEMINI_API_KEY = "AIzaSyD4tg-S1T2YO9Yp8adctrMJp1yPDY5MOXY"
SUPABASE_URL = "https://unqfkfunxnlxyatjnyqd.supabase.co" 
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InVucWZrZnVueG5seHlhdGpueXFkIiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc2NTc4Mzk1MiwiZXhwIjoyMDgxMzU5OTUyfQ.d7ouFX4EPGeaoOVQ-gljxnoc_ZPUxq3o0asLqL7HPrA" 

# Conectamos con Supabase
supabase: Client = create_client(SUPABASE_URL, SUPABASE_KEY)

# --- 2. EL CATÁLOGO DE TATUAJES ---
# Aquí ponéis los tatuajes reales que queréis que aparezcan.
# Podéis sacar las URLs de imágenes de Google para probar.
nuevos_tatuajes = [
    # --- LOS ORIGINALES ---
    {
        "titulo": "Lobo del Bosque",
        "descripcion": "Tatuaje realista en blanco y negro de la cara de un lobo salvaje, con pinos de un bosque. Simboliza la naturaleza, la fuerza y la soledad.",
        "imagen_url": "https://unqfkfunxnlxyatjnyqd.supabase.co/storage/v1/object/public/app-images/portfolio-artistas/Lobo%20del%20Bosque%20(1).jpg",
        "estilo": "Realismo"
    },
    {
        "titulo": "Dragón Japonés",
        "descripcion": "Un gran tatuaje estilo Irezumi tradicional japonés de un dragón escamado serpenteando entre nubes y viento.",
        "imagen_url": "https://unqfkfunxnlxyatjnyqd.supabase.co/storage/v1/object/public/app-images/portfolio-artistas/dragon%20japones.jpg",
        "estilo": "Irezumi / Japonés"
    },
    {
        "titulo": "Calavera Pirata y Rosas",
        "descripcion": "Tatuaje estilo Old School (Tradicional Americano). Calavera clásica rodeada de rosas rojas vibrantes.",
        "imagen_url": "https://unqfkfunxnlxyatjnyqd.supabase.co/storage/v1/object/public/app-images/portfolio-artistas/calavares%20pirata%20y%20rosas.jpg",
        "estilo": "Old School"
    },
    {
        "titulo": "Mandala Ornamental",
        "descripcion": "Diseño de mandala geométrico simétrico, hecho con la técnica de dotwork (puntillismo) en tinta negra.",
        "imagen_url": "https://unqfkfunxnlxyatjnyqd.supabase.co/storage/v1/object/public/app-images/portfolio-artistas/Mandala%20Ornamental.jpg",
        "estilo": "Dotwork / Ornamental"
    },
    {
        "titulo": "Mariposa Acuarela",
        "descripcion": "Una mariposa volando con fondo de manchas de color estilo acuarela (watercolor) en tonos morado y azul.",
        "imagen_url": "https://unqfkfunxnlxyatjnyqd.supabase.co/storage/v1/object/public/app-images/portfolio-artistas/Mariposa.jpg",
        "estilo": "Acuarela"
    },
    
    # --- LOS NUEVOS: ARMAS Y FLORES ---
    {
        "titulo": "Espada y Serpiente",
        "descripcion": "Tatuaje de una espada afilada o katana atravesando a una serpiente enrollada. Simboliza la lucha y el peligro.",
        "imagen_url": "https://unqfkfunxnlxyatjnyqd.supabase.co/storage/v1/object/public/app-images/portfolio-artistas/espada%20serpiente.jpg",
        "estilo": "Neo Tradicional"
    },
    {
        "titulo": "Rosa Clásica",
        "descripcion": "Tatuaje de una rosa sola, muy detallada con sus pétalos y hojas. Un clásico del romanticismo y la pasión.",
        "imagen_url": "https://unqfkfunxnlxyatjnyqd.supabase.co/storage/v1/object/public/app-images/portfolio-artistas/rosa.jpg",
        "estilo": "Realismo"
    },
    {
        "titulo": "Pistola y Flor",
        "descripcion": "Tatuaje de un arma de fuego (pistola) combinada con una flor, representando el contraste entre la vida y la muerte, la belleza y el peligro.",
        "imagen_url": "https://unqfkfunxnlxyatjnyqd.supabase.co/storage/v1/object/public/app-images/portfolio-artistas/pistola%20y%20flor.jpg",
        "estilo": "Blackwork"
    },
    {
        "titulo": "Calavera Oscura",
        "descripcion": "Tatuaje de una calavera humana, oscuro y lúgubre, representando la mortalidad y el paso del tiempo.",
        "imagen_url": "https://unqfkfunxnlxyatjnyqd.supabase.co/storage/v1/object/public/app-images/portfolio-artistas/calavera.jpg",
        "estilo": "Dark Trash Realism"
    },

    # --- LOS NUEVOS: ANIME Y MANGA ---
    {
        "titulo": "Tanjiro (Demon Slayer)",
        "descripcion": "Tatuaje otaku de anime manga de Tanjiro Kamado (Kimetsu no Yaiba), con efecto de la respiración de agua.",
        "imagen_url": "https://unqfkfunxnlxyatjnyqd.supabase.co/storage/v1/object/public/app-images/portfolio-artistas/tanjiro%20anime.jpg",
        "estilo": "Anime / Manga"
    },
    {
        "titulo": "Naruto Uzumaki",
        "descripcion": "Tatuaje otaku de anime de Naruto, el famoso ninja de Konoha, mostrando su determinación y chakra.",
        "imagen_url": "https://unqfkfunxnlxyatjnyqd.supabase.co/storage/v1/object/public/app-images/portfolio-artistas/naruto%20anime.jpg",
        "estilo": "Anime / Manga"
    },
    {
        "titulo": "Jogo (Jujutsu Kaisen)",
        "descripcion": "Tatuaje otaku de anime manga del personaje Jogo, la maldición de fuego y volcanes de Jujutsu Kaisen.",
        "imagen_url": "https://unqfkfunxnlxyatjnyqd.supabase.co/storage/v1/object/public/app-images/portfolio-artistas/jogo%20anime.jpg",
        "estilo": "Anime / Manga"
    },
    {
        "titulo": "Calavera One Piece",
        "descripcion": "Tatuaje otaku de anime del Jolly Roger, la famosa calavera pirata con sombrero de paja de la tripulación de Luffy en One Piece.",
        "imagen_url": "https://unqfkfunxnlxyatjnyqd.supabase.co/storage/v1/object/public/app-images/portfolio-artistas/calavera%20onepiece.jpg",
        "estilo": "Anime / Manga"
    },

    # --- LOS NUEVOS: SUPERHÉROES Y CÓMICS ---
    {
        "titulo": "Spiderman Acción",
        "descripcion": "Tatuaje de cómic de superhéroes de Marvel mostrando a Spiderman (Hombre Araña) en plena acción usando sus telarañas.",
        "imagen_url": "https://unqfkfunxnlxyatjnyqd.supabase.co/storage/v1/object/public/app-images/portfolio-artistas/spidermancontraje.jpg",
        "estilo": "Cómic / Color"
    },
    {
        "titulo": "Spiderman Clásico",
        "descripcion": "Tatuaje de Spiderman, el famoso trepamuros de los cómics de Marvel, un diseño ideal para fans de los superhéroes.",
        "imagen_url": "https://unqfkfunxnlxyatjnyqd.supabase.co/storage/v1/object/public/app-images/portfolio-artistas/spiderman.jpg",
        "estilo": "Cómic"
    },
    {
        "titulo": "Máscara Spiderman",
        "descripcion": "Tatuaje minimalista de superhéroes centrado únicamente en la máscara con los grandes ojos blancos de Spiderman.",
        "imagen_url": "https://unqfkfunxnlxyatjnyqd.supabase.co/storage/v1/object/public/app-images/portfolio-artistas/mascaraspider.jpg",
        "estilo": "Minimalista / Cómic"
    }
]

# --- 3. LA FUNCIÓN MÁGICA ---
def obtener_embedding(texto):
    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-001:embedContent?key={GEMINI_API_KEY}"
    payload = {
        "model": "models/gemini-embedding-001",
        "content": {"parts": [{"text": texto}]}
    }
    respuesta = requests.post(url, json=payload)
    if respuesta.status_code == 200:
        # Recortamos a 768 para que encaje en la caja fuerte de Supabase
        return respuesta.json()['embedding']['values'][:768]
    else:
        print(f"Error con Google: {respuesta.text}")
        return None

# --- 4. A TRABAJAR ---
print("🚀 Iniciando inyección de tatuajes en la Base de Datos...")

for tatuaje in nuevos_tatuajes:
    print(f"\nProcesando: {tatuaje['titulo']}...")
    vector = obtener_embedding(tatuaje['descripcion'])
    
    if vector:
        # ARREGLAMOS LOS ESPACIOS EN LAS URLs POR SI ACASO:
        url_segura = tatuaje['imagen_url'].replace(" ", "%20")
        
        datos_insertar = {
            "description": f"{tatuaje['titulo']} - {tatuaje['descripcion']}",
            "image_url": url_segura,
            "style_tag": tatuaje['estilo'],
            "embedding": vector,             
            "artist_id": "082e2bbb-6ceb-4a96-9f91-da87b0305820" # <-- ¡Ojo con el ID!
        }
        
        try:
            supabase.table("posts").insert(datos_insertar).execute()
            print("✅ Guardado con éxito en Supabase.")
        except Exception as e:
            print(f"❌ Error al guardar en BD: {e}")

print("\n🎉 ¡PROCESO TERMINADO! El catálogo está lleno y listo para la acción.")