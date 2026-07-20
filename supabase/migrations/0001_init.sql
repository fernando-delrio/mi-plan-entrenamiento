-- ─── Plan Entrenamiento Fernando — esquema inicial ──────────────────────────
-- Ejecutar completo en Supabase → SQL Editor, una sola vez, tras crear el proyecto.
-- App de un solo usuario real (Fernando). El alta pública debe quedar
-- desactivada en Authentication → Settings antes o justo después de esto.

-- ── profile_settings: una fila por usuario (turno de entreno + fecha de inicio) ──
create table public.profile_settings (
  user_id       uuid primary key default auth.uid() references auth.users(id) on delete cascade,
  turno_entreno text not null default 'manana' check (turno_entreno in ('manana','tarde')),
  plan_start_date date,
  updated_at    timestamptz not null default now()
);

-- ── body_metrics: peso + cintura + dolor, una fila por usuario y día ──
create table public.body_metrics (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  metric_date  date not null default current_date,
  weight_kg    numeric(5,2),
  waist_cm     numeric(5,2),
  pain_pre     smallint check (pain_pre  between 0 and 10),
  pain_post    smallint check (pain_post between 0 and 10),
  created_at   timestamptz not null default now(),
  updated_at   timestamptz not null default now(),
  unique (user_id, metric_date)
);
create index body_metrics_user_date_idx on public.body_metrics (user_id, metric_date desc);

-- ── trained_days: racha de días entrenados ──
create table public.trained_days (
  id             uuid primary key default gen_random_uuid(),
  user_id        uuid not null default auth.uid() references auth.users(id) on delete cascade,
  training_date  date not null default current_date,
  created_at     timestamptz not null default now(),
  unique (user_id, training_date)
);

-- ── photos: metadatos; el archivo real vive en Storage (bucket progress-photos) ──
create table public.photos (
  id           uuid primary key default gen_random_uuid(),
  user_id      uuid not null default auth.uid() references auth.users(id) on delete cascade,
  photo_date   date not null default current_date,
  storage_path text not null,
  created_at   timestamptz not null default now()
);
create index photos_user_date_idx on public.photos (user_id, photo_date desc);

-- ── session_feedback: feedback por sesión de entreno (base para adaptar el plan) ──
-- exercises: [{ "name": "Wall-sit", "pain": 2, "note": "leve tirón cadera" }, ...]
create table public.session_feedback (
  id                uuid primary key default gen_random_uuid(),
  user_id           uuid not null default auth.uid() references auth.users(id) on delete cascade,
  session_date      date not null default current_date,
  week_number       int,
  phase             text,
  difficulty_rating smallint check (difficulty_rating between 1 and 5),
  overall_pain      smallint check (overall_pain between 0 and 10),
  notes             text,
  exercises         jsonb not null default '[]'::jsonb,
  created_at        timestamptz not null default now()
);
create index session_feedback_user_date_idx on public.session_feedback (user_id, session_date desc);

-- ─── Row Level Security: cada usuario solo ve y toca sus propias filas ──────
alter table public.profile_settings  enable row level security;
alter table public.body_metrics      enable row level security;
alter table public.trained_days      enable row level security;
alter table public.photos            enable row level security;
alter table public.session_feedback  enable row level security;

create policy "profile_settings_select_own" on public.profile_settings for select using (auth.uid() = user_id);
create policy "profile_settings_insert_own" on public.profile_settings for insert with check (auth.uid() = user_id);
create policy "profile_settings_update_own" on public.profile_settings for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "profile_settings_delete_own" on public.profile_settings for delete using (auth.uid() = user_id);

create policy "body_metrics_select_own" on public.body_metrics for select using (auth.uid() = user_id);
create policy "body_metrics_insert_own" on public.body_metrics for insert with check (auth.uid() = user_id);
create policy "body_metrics_update_own" on public.body_metrics for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "body_metrics_delete_own" on public.body_metrics for delete using (auth.uid() = user_id);

create policy "trained_days_select_own" on public.trained_days for select using (auth.uid() = user_id);
create policy "trained_days_insert_own" on public.trained_days for insert with check (auth.uid() = user_id);
create policy "trained_days_delete_own" on public.trained_days for delete using (auth.uid() = user_id);

create policy "photos_select_own" on public.photos for select using (auth.uid() = user_id);
create policy "photos_insert_own" on public.photos for insert with check (auth.uid() = user_id);
create policy "photos_delete_own" on public.photos for delete using (auth.uid() = user_id);

create policy "session_feedback_select_own" on public.session_feedback for select using (auth.uid() = user_id);
create policy "session_feedback_insert_own" on public.session_feedback for insert with check (auth.uid() = user_id);
create policy "session_feedback_delete_own" on public.session_feedback for delete using (auth.uid() = user_id);

-- ─── Storage: bucket privado para fotos de progreso ─────────────────────────
insert into storage.buckets (id, name, public)
values ('progress-photos', 'progress-photos', false)
on conflict (id) do nothing;

create policy "progress_photos_select_own"
  on storage.objects for select
  using (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "progress_photos_insert_own"
  on storage.objects for insert
  with check (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = auth.uid()::text);

create policy "progress_photos_delete_own"
  on storage.objects for delete
  using (bucket_id = 'progress-photos' and (storage.foldername(name))[1] = auth.uid()::text);
