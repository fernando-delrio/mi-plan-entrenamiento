# Escalado y publicación — de plan personal a plataforma para entrenadores

> Este documento no cambia nada del código. Es la respuesta a tres preguntas:
> ¿dónde se guardan los datos hoy?, ¿es privado publicarlo en GitHub Pages?,
> y ¿qué haría falta para que otros entrenadores privados usaran esta app
> para crear planes a medida de sus propios clientes?

---

## 1. Dónde vive cada dato hoy

Todo vive en Supabase (Postgres + Auth + Storage). **No hay `localStorage` en
ningún punto de `index.html`** — lo confirmé buscando en todo el archivo antes
de escribir esto.

| Dato | Tabla / bucket | RLS |
|---|---|---|
| Turno de entreno, fecha de inicio del plan | `profile_settings` | `auth.uid() = user_id` |
| Peso, cintura, dolor pre/post por día | `body_metrics` | `auth.uid() = user_id` |
| Racha de días entrenados (lo que usa la pestaña **Historial** nueva) | `trained_days` | `auth.uid() = user_id` |
| Fotos de progreso (metadatos + archivo) | `photos` + bucket `progress-photos` (privado) | `auth.uid() = user_id` |
| Feedback detallado por sesión/ejercicio | `session_feedback` | `auth.uid() = user_id` — **tabla ya creada en la migración pero sin usar todavía desde la UI** |
| Sesión / login | Supabase Auth (`auth.users`) | — |

Fuente: `supabase/migrations/0001_init.sql`. Cada tabla tiene su política de
`select`/`insert`/`update`/`delete` filtrando por `auth.uid()`, así que un
usuario nunca puede leer ni escribir filas de otro usuario aunque conozca su
`user_id`.

**Dato interesante para ti:** `session_feedback` ya existe en la base de datos
(con `week_number`, `phase`, `difficulty_rating`, `overall_pain`, `notes` y un
`exercises jsonb` para feedback ejercicio por ejercicio) pero la app nunca la
usa. Es candidata natural para una versión más rica del Historial: no solo
"ese día dolió 3→5", sino "ese día, en el ejercicio Wall-sit, dolió 4".

---

## 2. ¿Es privado si lo publico en GitHub Pages?

Sí, y la razón importa para que lo puedas explicar en una entrevista 🆕:

**La privacidad no la da que el sitio sea público o privado — la da RLS.**
GitHub Pages sirve el `index.html` a cualquiera que tenga la URL, igual que
serviría cualquier archivo estático. Pero ese HTML no contiene ningún dato
tuyo: contiene la URL de tu proyecto Supabase y una clave "publishable"
(antes se llamaba `anon key`), que está **diseñada para ser pública**. Sin
sesión iniciada (sin JWT válido), esa clave no puede leer ni escribir ninguna
fila protegida por RLS. Por eso da igual que el repo sea público.

Lo que sí protege tus datos, en orden de importancia:
1. RLS activada en las 5 tablas (ya está).
2. Alta pública desactivada en Authentication → Settings (ya lo tienes anotado
   como requisito en la migración — **vale la pena que lo confirmes una vez en
   el dashboard de Supabase**, porque si alguien se registrase por su cuenta
   tendría una fila vacía pero válida en `auth.users`, sin acceso a tus datos
   pero sí "una cuenta").
3. El bucket `progress-photos` es privado (`public: false`) con política por
   carpeta `user_id` — nadie puede adivinar una URL de tu foto.

Si en algún momento quisieras que ni el HTML fuera visible sin login (algunos
navegadores muestran el código fuente igual, aunque los datos estén vacíos),
la única forma real es GitHub Pages con repo privado — pero **eso requiere
plan GitHub Pro/Team/Enterprise**, y el "friend group" que vea el sitio
tendría que ser colaborador del repo. Para tu caso (plan personal tuyo y de
Laura) no merece la pena: no hay nada sensible en el HTML en sí, solo lógica
de UI y el nombre de los ejercicios.

---

## 3. Ideas para la app personal (sin tocar nada todavía)

Cosas que encajan con la arquitectura actual (single-file + Supabase) sin
romper la premisa de GitHub Pages:

- **Exportar el historial para la consulta del 28 de diciembre** — un botón
  en Historial u Objetivos que genere un PDF/CSV con la evolución de dolor,
  peso y adherencia. Tu fisio/médico lo agradece más que enseñarle el móvil.
- **PWA instalable** — un `manifest.json` + service worker mínimo (cachear el
  propio `index.html` y los scripts CDN) para que puedas "instalar" la app en
  el móvil y se abra como si fuera nativa. Sigue siendo 100% estático.
- **Notificaciones locales** (Notification API del navegador) para los
  horarios de suplementos y del entreno — no requiere backend nuevo.
- **Usar `session_feedback`** (ya existe, ver sección 1) para un log por
  ejercicio, no solo por día — encajaría muy bien como una vista expandible
  dentro de cada fila del Historial.
- **Gráfica cruzada dolor vs. semana de fase** — para ver si el dolor sube
  justo cuando cambias de fase (dato objetivo para la consulta médica).
- **Reutilizar el patrón de la Edge Function `exercise-tutorial`** (proxy a
  Mistral con la clave en secreto de Supabase) para una segunda función que,
  con la racha de dolor alto reciente, sugiera "esta semana baja volumen en
  X" — mismo patrón de seguridad que ya tienes, solo un prompt distinto.

Ninguna de estas rompe la regla de "debe seguir funcionando como HTML
estático desde GitHub Pages".

---

## 4. Escalar a "entrenadores privados con planes por cliente" — esto es otro producto

Aquí la respuesta honesta es: **esto ya no es una extensión de tu plan
personal, es un producto distinto que conviene empezar como proyecto nuevo.**
Te explico por qué y qué cambiaría.

### Qué es hoy realmente

Ahora mismo `index.html` ya tiene una forma primitiva de "multi-perfil": el
objeto `PROFILES` (`fernando` / `laura`) y un mapa `PROFILE_KEY_BY_EMAIL` que
asocia un email de Supabase Auth a un perfil hardcodeado en el propio archivo
JS. Es exactamente la semilla de lo que pides, pero con una limitación grande:

**El plan (fases, días, ejercicios, progresión) está escrito en código
JavaScript, no en la base de datos.** Añadir una persona nueva hoy significa
que tú (o yo) editamos `index.html` y hacemos deploy. Un entrenador que
quisiera dar de alta a un cliente nuevo desde el móvil, sin tocar código, no
puede hacerlo con esta arquitectura.

### Qué haría falta para que un entrenador cree planes para sus clientes

| Pieza | Hoy | Lo que hace falta |
|---|---|---|
| Quién es quién | 2 emails hardcodeados en `PROFILE_KEY_BY_EMAIL` | Tabla `profiles` con `role` (`trainer`/`client`) y `trainer_id` en cada cliente |
| Contenido del plan | Constantes JS (`phases`, `dd`, `nutricionTips`...) | Tablas `plans`, `plan_phases`, `plan_days`, `plan_exercises` — el plan es *dato*, no código |
| Quién edita el plan | Nadie desde la UI — solo editando el archivo | Un **editor de planes** para el entrenador: formularios para crear fases/días/ejercicios sin tocar código |
| Aislamiento entre entrenadores | No existe (es tu app personal) | RLS: un entrenador solo ve/edita sus propios clientes y planes; un cliente solo ve su plan asignado y solo escribe su propio tracking |
| Alta de usuarios | Alta pública desactivada, solo tú y Laura ya existís como usuarios | Alta pública también desactivada, pero con **invitación**: el entrenador crea la cuenta del cliente (Supabase Admin API desde una Edge Function), el cliente nunca se registra solo |
| Feedback con IA | Un Edge Function fijo por perfil (`PHYSIO_CONTEXT` hardcodeado) | El contexto físico del cliente pasa a ser una columna en `profiles`, no una constante en el código de la función |

### Por qué no seguir creciendo el archivo único

`index.html` ya tiene más de 2000 líneas. Es manejable para un plan de 2
personas fijas porque tú conoces cada sección. Pero un editor de planes +
roles + aislamiento multi-entrenador es una complejidad de otro orden: no es
"una pestaña más", es un área nueva de la aplicación (la del entrenador) con
su propia lógica de permisos. Seguir metiéndolo en el mismo archivo violaría
justo los principios que ya sigues en este proyecto (SRP, "un módulo, una
responsabilidad") — el archivo pasaría a tener dos responsabilidades muy
distintas: "mi plan personal" y "plataforma multi-tenant".

**Recomendación:** trátalo como un proyecto nuevo, reutilizando lo que ya
sabe funcionar:
- El mismo Supabase (o un proyecto Supabase nuevo, más limpio, sin las tablas
  personales de Fernando/Laura mezcladas con las de clientes de terceros).
- El mismo patrón de RLS por `auth.uid()` que ya dominas.
- El contenido de ejercicios/fases de este plan como **datos semilla**
  (seed) del nuevo esquema, no como código a copiar y pegar.
- Para la construcción en sí, el stack por defecto que ya tienes documentado
  en tu `CLAUDE.md` general (React + Vite + Tailwind + FastAPI o Supabase +
  Alembic/migraciones SQL versionadas) en vez de seguir en un único HTML sin
  build — un editor de planes con formularios, validación y varias pantallas
  se beneficia mucho de tener componentes y rutas de verdad.

### Publicación para la versión escalada

- Vercel o Netlify (build real con Vite) en vez de GitHub Pages — mismo
  razonamiento de privacidad de la sección 2: la privacidad la sigue dando
  RLS, no dónde se hostea. La ventaja de Vercel/Netlify aquí es el build
  step (code-splitting, variables de entorno por ambiente), no la privacidad.
- Sin alta pública — el flujo de alta lo dispara el entrenador (invitación),
  nunca un formulario abierto de registro.
- Si en algún momento hay entrenadores gestionando datos de salud de terceros
  en la UE, conviene tener una política de privacidad real y un aviso de
  tratamiento de datos — no hace falta ahora mismo con solo Fernando y Laura,
  pero sí en cuanto haya un tercero ajeno a la familia.

---

## 5. Roadmap sugerido, en fases

1. **Fase 0 (hecho):** plan personal Fernando + Laura, Supabase, pestaña
   Historial nueva.
2. **Fase 1 — pulir lo personal:** exportar historial, PWA, usar
   `session_feedback` para el log por ejercicio.
3. **Fase 2 — prototipo de datos:** diseñar `plans`/`plan_phases`/
   `plan_days`/`plan_exercises` y las políticas RLS multi-entrenador en un
   proyecto Supabase aparte, sin tocar el de Fernando/Laura.
4. **Fase 3 — editor de planes:** construir la plataforma nueva (proyecto
   con build real) con el editor de planes para entrenadores.
5. **Fase 4 — publicar:** onboarding por invitación, dominio propio, y si
   procede, cobro por suscripción (Stripe) a los entrenadores.

Ninguna fase obliga a tocar el `index.html` de tu plan personal — puede
seguir viviendo tal cual, como el "cliente cero" que demuestra que el
concepto funciona.
