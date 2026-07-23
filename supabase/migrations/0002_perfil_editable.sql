-- ─── Perfil editable: peso inicial, altura, edad, cadera, consulta médica ───
-- Motivo: estos datos vivían hardcodeados como constantes en index.html
-- (PROFILE.pesoInicialKg, etc.). El peso inicial real de Fernando es 88kg y
-- estaba mal puesto a 86 en el código — corregirlo exigía tocar el fuente.
-- A partir de esta migración se editan desde la pestaña Objetivos ("Mis
-- datos") y quedan en profile_settings; el código solo se usa como valor por
-- defecto mientras la fila en Supabase no tenga el dato (columnas NULL-ables).
-- Ejecutar una sola vez en Supabase → SQL Editor.

alter table public.profile_settings
  add column peso_inicial_kg numeric(5,2),
  add column altura_cm       smallint,
  add column edad            smallint,
  add column cadera_lado     text check (cadera_lado in ('derecha','izquierda','bilateral')),
  add column consulta_medica date;

-- Rollback manual si hiciera falta:
-- alter table public.profile_settings
--   drop column peso_inicial_kg, drop column altura_cm, drop column edad,
--   drop column cadera_lado, drop column consulta_medica;
