-- ─── strength_tests: PRs / marcas de fuerza a lo largo del tiempo ───────────
-- Motivo (auditoría 2026-07-23): el peso y la cintura se registran y grafican
-- (MiniChart), pero la fuerza (dominadas máximas, minutos en Zona 4...) solo
-- vive como texto de objetivo por semana en `tests2`, sin ningún dato con
-- fecha ni gráfica. El objetivo es recomposición (perder grasa Y ganar
-- músculo) — medir solo el peso sesga la lectura del progreso hacia la mitad
-- equivocada. A diferencia de body_metrics (una fila por día), aquí puede
-- haber varios tests distintos el mismo día, así que NO es upsert por fecha:
-- cada marca es una fila nueva.

create table public.strength_tests (
  id         uuid primary key default gen_random_uuid(),
  user_id    uuid not null default auth.uid() references auth.users(id) on delete cascade,
  test_date  date not null default current_date,
  test_name  text not null,
  value      numeric(7,2) not null,
  unit       text not null default 'reps',
  created_at timestamptz not null default now()
);
create index strength_tests_user_test_idx on public.strength_tests (user_id, test_name, test_date desc);

alter table public.strength_tests enable row level security;

create policy "strength_tests_select_own" on public.strength_tests for select using (auth.uid() = user_id);
create policy "strength_tests_insert_own" on public.strength_tests for insert with check (auth.uid() = user_id);
create policy "strength_tests_update_own" on public.strength_tests for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
create policy "strength_tests_delete_own" on public.strength_tests for delete using (auth.uid() = user_id);
