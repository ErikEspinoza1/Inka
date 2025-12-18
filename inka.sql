-- WARNING: This schema is for context only and is not meant to be run.
-- Table order and constraints may not be valid for execution.

CREATE TABLE public.ai_designs (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  prompt_text text,
  image_url text NOT NULL,
  style_tag text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT ai_designs_pkey PRIMARY KEY (id),
  CONSTRAINT ai_designs_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.artists (
  id uuid NOT NULL,
  shop_name text,
  bio text,
  styles ARRAY,
  address text,
  latitude double precision,
  longitude double precision,
  is_verified boolean DEFAULT false,
  CONSTRAINT artists_pkey PRIMARY KEY (id),
  CONSTRAINT artists_id_fkey FOREIGN KEY (id) REFERENCES public.profiles(id)
);
CREATE TABLE public.bookings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  client_id uuid NOT NULL,
  artist_id uuid NOT NULL,
  status USER-DEFINED DEFAULT 'pendiente'::booking_status,
  idea_description text NOT NULL,
  body_part text NOT NULL,
  size_cm text,
  reference_image_url text,
  price_quote numeric,
  booking_date timestamp with time zone,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT bookings_pkey PRIMARY KEY (id),
  CONSTRAINT bookings_client_id_fkey FOREIGN KEY (client_id) REFERENCES public.profiles(id),
  CONSTRAINT bookings_artist_id_fkey FOREIGN KEY (artist_id) REFERENCES public.artists(id)
);
CREATE TABLE public.messages (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  booking_id uuid,
  sender_id uuid,
  receiver_id uuid,
  content text NOT NULL,
  is_read boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT messages_pkey PRIMARY KEY (id),
  CONSTRAINT messages_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id),
  CONSTRAINT messages_sender_id_fkey FOREIGN KEY (sender_id) REFERENCES public.profiles(id),
  CONSTRAINT messages_receiver_id_fkey FOREIGN KEY (receiver_id) REFERENCES public.profiles(id)
);
CREATE TABLE public.posts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  artist_id uuid NOT NULL,
  image_url text NOT NULL,
  description text,
  style_tag text,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT posts_pkey PRIMARY KEY (id),
  CONSTRAINT posts_artist_id_fkey FOREIGN KEY (artist_id) REFERENCES public.artists(id)
);
CREATE TABLE public.profiles (
  id uuid NOT NULL,
  email text,
  full_name text,
  avatar_url text,
  role USER-DEFINED DEFAULT 'cliente'::user_role,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  password text NOT NULL DEFAULT '0'::text CHECK (length(password) <= 80),
  CONSTRAINT profiles_pkey PRIMARY KEY (id)
);
CREATE TABLE public.reviews (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  booking_id uuid,
  reviewer_id uuid,
  artist_id uuid,
  rating integer CHECK (rating >= 1 AND rating <= 5),
  comment text,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT reviews_pkey PRIMARY KEY (id),
  CONSTRAINT reviews_booking_id_fkey FOREIGN KEY (booking_id) REFERENCES public.bookings(id),
  CONSTRAINT reviews_reviewer_id_fkey FOREIGN KEY (reviewer_id) REFERENCES public.profiles(id),
  CONSTRAINT reviews_artist_id_fkey FOREIGN KEY (artist_id) REFERENCES public.artists(id)
);
CREATE TABLE public.saved_posts (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid NOT NULL,
  post_id uuid NOT NULL,
  created_at timestamp with time zone DEFAULT timezone('utc'::text, now()),
  CONSTRAINT saved_posts_pkey PRIMARY KEY (id),
  CONSTRAINT saved_posts_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT saved_posts_post_id_fkey FOREIGN KEY (post_id) REFERENCES public.posts(id)
);
CREATE TABLE public.simulations (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  user_id uuid,
  design_id uuid,
  body_photo_url text NOT NULL,
  result_image_url text NOT NULL,
  created_at timestamp with time zone DEFAULT now(),
  CONSTRAINT simulations_pkey PRIMARY KEY (id),
  CONSTRAINT simulations_user_id_fkey FOREIGN KEY (user_id) REFERENCES public.profiles(id),
  CONSTRAINT simulations_design_id_fkey FOREIGN KEY (design_id) REFERENCES public.ai_designs(id)
);