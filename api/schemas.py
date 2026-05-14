from pydantic import BaseModel, EmailStr, ConfigDict
from typing import Optional, List
from uuid import UUID
from datetime import datetime
from models import UserRole, BookingStatus, StudioType

# --- USUARIOS ---
class UserCreate(BaseModel):
    email: EmailStr
    password: str
    full_name: str

class UserLogin(BaseModel):
    email: EmailStr
    password: str

class Token(BaseModel):
    access_token: str
    token_type: str

class UserResponse(BaseModel):
    id: UUID
    email: EmailStr
    full_name: str
    role: UserRole
    
    model_config = ConfigDict(from_attributes=True)

# --- ARTISTAS ---
class ArtistCreate(BaseModel):
    shop_name: str
    bio: str
    styles: List[str]
    address: str
    latitude: float
    longitude: float
    workspace_type: StudioType
    show_exact_location: bool
    instagram_handle: str
    whatsapp_number: Optional[str] = None
    website_url: Optional[str] = None
    business_license_id: str
    business_document_url: Optional[str] = None

class ArtistUpdate(BaseModel):
    shop_name: Optional[str] = None
    bio: Optional[str] = None
    styles: Optional[List[str]] = None
    instagram_handle: Optional[str] = None
    address: Optional[str] = None
    latitude: Optional[float] = None
    longitude: Optional[float] = None
    workspace_type: Optional[StudioType] = None
    business_document_url: Optional[str] = None

class ArtistResponse(BaseModel):
    id: UUID
    shop_name: str
    bio: Optional[str] = None
    styles: List[str] = []
    latitude: float  # Crucial para el pin del mapa
    longitude: float # Crucial para el pin del mapa
    address: Optional[str] = None
    workspace_type: Optional[StudioType] = None 
    instagram_handle: Optional[str] = None
    whatsapp_number: Optional[str] = None
    website_url: Optional[str] = None
    avatar_url: Optional[str] = None 
    is_verified: bool
    
    model_config = ConfigDict(from_attributes=True)

# --- RESERVAS (Bookings) ---
class BookingCreate(BaseModel):
    artist_id: UUID
    idea_description: str
    body_part: str
    size_cm: Optional[str] = None
    booking_date: Optional[datetime] = None

class BookingUpdate(BaseModel):
    status: Optional[BookingStatus] = None
    price_quote: Optional[float] = None
    booking_date: Optional[datetime] = None
    idea_description: Optional[str] = None
    body_part: Optional[str] = None
    size_cm: Optional[str] = None
    client_accepted: Optional[bool] = None
    artist_accepted: Optional[bool] = None

class BookingResponse(BaseModel):
    id: UUID
    client_id: UUID
    artist_id: UUID
    status: BookingStatus
    idea_description: str
    body_part: str
    size_cm: Optional[str] = None
    booking_date: Optional[datetime] = None
    price_quote: Optional[float] = None
    client_accepted: bool
    artist_accepted: bool
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

# --- POSTS, REVIEWS, AI & MENSAJES ---
class PostCreate(BaseModel):
    image_url: str
    description: Optional[str] = None
    style_tag: Optional[str] = None

class PostResponse(BaseModel):
    id: UUID
    artist_id: UUID
    image_url: str
    description: Optional[str]
    style_tag: Optional[str] = None
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

class ReviewCreate(BaseModel):
    booking_id: UUID
    rating: int
    comment: Optional[str] = None

class ReviewResponse(BaseModel):
    id: UUID
    reviewer_id: UUID
    artist_id: UUID
    rating: int
    comment: Optional[str] = None
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

class MessageCreate(BaseModel):
    receiver_id: UUID
    content: str
    booking_id: Optional[UUID] = None

class MessageResponse(BaseModel):
    id: UUID
    booking_id: Optional[UUID] = None
    sender_id: UUID
    receiver_id: UUID
    content: str
    is_read: bool
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)

# --- DISEÑOS DE IA (Añadir esto a api/schemas.py) ---

class AIDesignCreate(BaseModel):
    prompt_text: str
    image_url: str
    style_tag: Optional[str] = None

class AIDesignResponse(BaseModel):
    id: UUID
    prompt_text: str
    image_url: str
    created_at: datetime
    
    model_config = ConfigDict(from_attributes=True)