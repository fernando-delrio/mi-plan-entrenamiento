-- ─── Feedback por ejercicio: un registro por día, editable ──────────────────
-- session_feedback ya existía (con columna exercises jsonb pensada para esto)
-- pero nunca se conectó a la UI. Le faltaban dos cosas para poder hacer
-- upsert por día como ya se hace en body_metrics:
--   1) una restricción única (user_id, session_date) para poder usar
--      `.upsert(..., { onConflict: "user_id,session_date" })`.
--   2) una política de UPDATE — solo tenía select/insert/delete, así que el
--      camino de "conflicto → actualizar" de un upsert habría fallado bajo RLS.
-- Ejecutar una sola vez en Supabase → SQL Editor.

alter table public.session_feedback
  add constraint session_feedback_user_date_unique unique (user_id, session_date);

create policy "session_feedback_update_own" on public.session_feedback
  for update using (auth.uid() = user_id) with check (auth.uid() = user_id);
