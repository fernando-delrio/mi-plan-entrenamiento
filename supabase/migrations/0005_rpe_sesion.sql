-- ─── RPE (esfuerzo percibido) de la sesión de hoy ───────────────────────────
-- Motivo (auditoría 2026-07-23): solo se registraba dolor de cadera, nunca el
-- esfuerzo general de la sesión. La regla de doble progresión ("sube peso
-- solo si tocas el techo del rango dos sesiones seguidas") dependía 100% de
-- la memoria. Un RPE 1-10 por sesión da una señal objetiva más para decidir
-- cuándo tocaría deload (2 semanas con RPE alto y sin progreso = fatiga
-- acumulada, no solo "no me acuerdo si fue duro").
-- Ejecutar una sola vez en Supabase → SQL Editor.

alter table public.body_metrics
  add column rpe smallint check (rpe between 1 and 10);
