import os
import firebase_admin
from firebase_admin import credentials, messaging
from sqlalchemy.orm import Session
import models

# Inicializar Firebase Admin
# El archivo JSON debe estar en la carpeta 'api'
cred_path = os.path.join(os.path.dirname(__file__), "..", "firebase-adminsdk.json")

if os.path.exists(cred_path):
    cred = credentials.Certificate(cred_path)
    firebase_admin.initialize_app(cred)
    print("✅ Firebase Admin inicializado correctamente")
else:
    print("⚠️ No se encontró firebase-adminsdk.json. Las notificaciones push no funcionarán.")

def send_push_notification(receiver_id: str, title: str, body: str, db: Session):
    """
    Envía una notificación push a un usuario específico usando su fcm_token.
    """
    user = db.query(models.Profile).filter(models.Profile.id == receiver_id).first()
    
    if not user or not user.fcm_token:
        print(f"🚫 No se puede enviar notificación: Usuario {receiver_id} no tiene fcm_token")
        return

    message = messaging.Message(
        notification=messaging.Notification(
            title=title,
            body=body,
        ),
        token=user.fcm_token,
        # Opcional: añadir datos para que la app sepa qué abrir
        data={
            "click_action": "FLUTTER_NOTIFICATION_CLICK",
            "type": "chat_message",
        }
    )

    try:
        response = messaging.send(message)
        print(f"🚀 Notificación enviada con éxito: {response}")
    except Exception as e:
        print(f"❌ Error al enviar notificación: {e}")
