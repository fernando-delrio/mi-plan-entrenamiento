-- ─── Check-in nutricional diario: proteína, agua, alcohol ───────────────────
-- Motivo (auditoría 2026-07-23): había consejos de proteína/hidratación pero
-- ningún dato que confirmara si de verdad se cumplían un día concreto — sin
-- esto no se puede distinguir "mala semana metabólica" de "no llegué a la
-- proteína". Se añade a body_metrics (misma fila diaria que peso/cintura/dolor)
-- en vez de crear una tabla nueva, porque es el mismo patrón de un registro
-- por usuario y día que ya existe.
-- Ejecutar una sola vez en Supabase → SQL Editor.

alter table public.body_metrics
  add column protein_status text check (protein_status in ('si','a_medias','no')),
  add column water_liters   numeric(3,1),
  add column alcohol        boolean;
