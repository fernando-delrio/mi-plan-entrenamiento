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

---

## 6. Profundización: SaaS de "plantilla editable por entrenador" — app móvil + PC, coste mínimo

> Todo lo que sigue es solo documentación — no toca `index.html` ni crea
> ningún proyecto nuevo. Es la respuesta a "cómo sería esto en concreto,
> como app de móvil y de PC, lo más barata posible".

### 6.1 Qué es exactamente "una plantilla como la nuestra, editable"

Hoy tu plan (fases, días, ejercicios, progresión) es código: los objetos
`phases` y `dd` dentro de `index.html`. La versión SaaS necesita que ese
mismo contenido sea **dato que un entrenador edita desde un formulario**, sin
tocar una línea de código. Dos formas de modelarlo en Supabase:

| Opción | Cómo es | Coste de construirlo |
|---|---|---|
| **Normalizado** (tablas `plan_templates` → `plan_phases` → `plan_days` → `plan_exercises`, con filas y claves foráneas) | Cada ejercicio es una fila con relaciones | Alto: cada pantalla del editor necesita CRUD anidado en 4 niveles, más migraciones por cada cambio de forma |
| **JSONB por plantilla** (una fila en `plan_templates` con una columna `content jsonb` que contiene fases→días→ejercicios, igual de forma que hoy `phases`/`dd` en JS) | Un solo documento estructurado por plantilla | Bajo: el editor es un formulario que lee/escribe ese JSON; añadir un campo nuevo a un ejercicio no requiere migración |

**Recomendación para un MVP barato: JSONB.** Pierdes la capacidad de hacer
consultas SQL finas ("todos los ejercicios llamados Sentadilla en cualquier
plantilla de cualquier entrenador"), pero eso no lo necesitas al principio, y
te ahorras muchísimo tiempo de desarrollo — que es la parte más cara de
verdad, más que cualquier factura de hosting. Puedes migrar a tablas
normalizadas más adelante si el producto crece y esa consulta cruzada se
vuelve necesaria.

### 6.2 Cómo un entrenador "se la pasa" a un cliente, dentro de la app

1. El entrenador pulsa "Nuevo cliente" e introduce su email.
2. Una **Edge Function** (con la `service_role key`, que nunca toca el
   navegador) llama a `supabase.auth.admin.inviteUserByEmail(email)`.
   Supabase manda el email de invitación automáticamente — no hace falta
   montar un servicio de correo aparte para esto.
3. El cliente abre el enlace, pone su contraseña, y entra directo a la app.
4. En vez de que la plantilla completa se comparta por referencia, se hace
   una **copia** de ella en una tabla `client_plans` (con un `template_id`
   apuntando a la plantilla de origen, por si el entrenador quiere saber de
   dónde viene). Copiar en vez de referenciar permite que el entrenador
   ajuste la plantilla maestra sin romper los planes ya asignados a clientes
   activos — el mismo principio que ya usas tú: cuando a Fernando se le
   sustituye un ejercicio de cadera, es una decisión específica para él, no
   un cambio silencioso en un documento compartido.
5. RLS clave: una tabla `clients` con `(user_id, trainer_id)`. El cliente
   solo ve su propia fila (`user_id = auth.uid()`, igual que ya tienes hoy).
   El entrenador necesita, además, una política de **solo lectura** sobre el
   `body_metrics`/`trained_days` de sus propios clientes (para hacer
   seguimiento), pero nunca de escritura — el dato lo registra el cliente,
   no el entrenador.

### 6.3 App de móvil y PC — cuál es la más barata (con cifras reales)

Miré esto expresamente porque "barato" tiene una trampa: lo más barato en
hosting no siempre es lo más barato en horas de desarrollo, y al revés.

| Enfoque | Qué es | Coste de tienda | Coste de desarrollo | Cuándo tiene sentido |
|---|---|---|---|---|
| **PWA** (la misma web, instalable con "Añadir a pantalla de inicio") | Un único código React responsive, funciona en móvil y PC por igual | 0€ — no pasa por App Store ni Google Play | El más bajo: un ejemplo real de PWA con caché offline y notificaciones se construyó por **menos de 18.000$**, frente a un presupuesto de 75.000$ para la versión nativa equivalente | Para validar el producto con los primeros entrenadores, sin gastar en tiendas de apps |
| **Capacitor** (envuelve la misma web en un shell nativo instalable desde las tiendas) | Reutiliza 80–90% del código web ya escrito | Apple Developer Program: **99$/año**. Google Play Console: **25$ pago único** | Bajo-medio: mismo código React, se añade una capa fina nativa | Cuando ya tienes entrenadores reales y quieres presencia/descubribilidad en las tiendas |
| **React Native / Flutter** (código nativo aparte, no reutiliza tu web) | Un codebase distinto del panel web del entrenador | Mismos 99$/año + 25$ | Alto: for budgets under 50.000$ Capacitor es lo recomendado; React Native/Flutter solo compensa con más de 100.000$ de presupuesto o cuando el rendimiento nativo es crítico | No es tu caso — una app de planes de entrenamiento no necesita gráficos 3D ni sensores nativos avanzados |

**Recomendación concreta:** empieza con **PWA** (mismo código para móvil y
PC, cero coste de tienda) y, solo si el producto valida con entrenadores
reales pagando, añade **Capacitor** encima del mismo código para publicarlo
en App Store/Google Play — no antes, porque los 99$/año de Apple son un
coste recurrente que no compensa pagar mientras estás validando la idea.

### 6.4 Coste total estimado, mes a mes

| Partida | Fase MVP (validar con pocos entrenadores) | Fase con apps en tienda |
|---|---|---|
| Hosting frontend | **0€** — Cloudflare Pages free tier: ancho de banda ilimitado, 500 builds/mes | igual, 0€ |
| Backend (Supabase) | **0€** — free tier: 500MB BD, 50.000 usuarios activos/mes, 1GB storage, 5GB de tráfico | 25$/mes (plan Pro) en cuanto superes esos límites — con pocos entrenadores no hace falta todavía |
| Dominio propio | ~10€/año (opcional, puedes usar el subdominio gratis de Cloudflare Pages al principio) | igual |
| Apple Developer Program | — | 99$/año |
| Google Play Console | — | 25$ pago único |
| Emails de invitación | 0€ — incluidos en Supabase Auth | igual |
| Cobro a entrenadores (Stripe) | 0€ fijo, solo comisión por transacción cuando factures | igual |

**Total fase MVP: prácticamente 0€/mes.** Puedes tener el producto entero
funcionando (web + móvil vía PWA) sin pagar nada hasta que crezca lo
suficiente para superar el free tier de Supabase o quieras estar en las
tiendas de apps.

### 6.5 Qué NO hacer todavía, para que siga siendo barato

- No pagues Apple/Google hasta que al menos un par de entrenadores reales
  estén usando la PWA y quieran de verdad estar en la tienda.
- No normalices la base de datos de planes en tablas separadas desde el
  primer día — el JSONB por plantilla (sección 6.1) es más barato de
  construir y suficiente para un MVP.
- No montes un servicio de email de marketing aparte — los correos
  transaccionales de invitación de Supabase Auth ya cubren ese caso.
- No implementes cobro con Stripe hasta tener el primer entrenador dispuesto
  a pagar — mientras tanto, no cuesta nada tenerlo en modo gratuito.

### 6.6 Stack técnico completo (decidido 2026-07-21)

React + Supabase ya estaban decididos. Para CSS, entre Bootstrap (componentes
ya hechos, más rápido para el editor de plantillas) y Tailwind (consistente
con el resto de tus proyectos, según tu `CLAUDE.md` general), **se eligió
Tailwind** — prioriza reutilizar lo que ya sabes sobre ganar velocidad en
esta parte concreta.

| Pieza | Para qué | Coste |
|---|---|---|
| **React + Vite** | UI + build tool (dev server, build optimizado, code-splitting) | 0€ |
| **Tailwind CSS** | Estilos, consistente con tus otros proyectos | 0€ |
| **Supabase** | Auth + Postgres + Storage + Edge Functions — todo el backend | 0€ en fase MVP (ver 6.4) |
| **React Router** | Navegación: login, panel del entrenador, editor de plantilla, vista del cliente, aceptar invitación | 0€ |
| **Boxicons** | Iconos, ya está en `~/.claude/RECURSOS.md` | 0€ |
| **Cloudflare Pages** | Hosting con deploy automático al hacer `git push` | 0€ |
| **PWA** (manifest + service worker) | Instalable en móvil y PC desde el día 1, sin tienda | 0€ |
| **Vitest + React Testing Library** | Testing, ya es la convención del `CLAUDE.md` general | 0€ |
| **Capacitor** | Solo si se valida el producto y se quiere estar en App Store/Google Play (ver 6.3) | 99$/año (Apple) + 25$ una vez (Google) |
| **Stripe** | Solo cuando haya un entrenador dispuesto a pagar (Fase 4 del roadmap) | 0€ fijo, comisión por cobro |

**TypeScript — a valorar, no decidido:** este proyecto maneja roles, RLS y
una plantilla en JSON con una forma concreta (fases→días→ejercicios), donde
un error de tecleo en un campo es un bug silencioso que TypeScript detectaría
al escribir el código. No es obligatorio, y añade una curva de aprendizaje
extra mientras Fernando sigue aprendiendo JS/React a fondo — queda como
mejora a considerar más adelante, no del día 1.

Sources:
- [Supabase Pricing in 2026: Plans, Free Tier Limits & Full Breakdown](https://uibakery.io/blog/supabase-pricing)
- [Apple Developer Program Cost: The $99/Year Fee Explained (2026)](https://appbuilder24.com/blog/apple-developer-account-needed)
- [Google Play Developer Fee 2026: $25 + 12-Tester Rule](https://www.iconikai.com/blog/google-play-developer-account-fee-2026)
- [PWA vs Capacitor vs Native: Choosing an App Architecture in 2026](https://ourcodeworld.com/articles/read/3646/pwa-vs-capacitor-vs-native-2026)
- [Cloudflare Pages vs Netlify vs Vercel: Static Site Hosting Compared (2026)](https://danubedata.ro/blog/cloudflare-pages-vs-netlify-vs-vercel-static-hosting-2026)

---

## 7. ¿Esto es un SaaS? Y cuál es la mejor manera de hacerlo funcional de verdad

### 7.1 Sí, es un SaaS — y en concreto un "SaaS vertical"

SaaS (Software as a Service) se define por cuatro rasgos, y este proyecto los
cumple todos:

| Rasgo del SaaS | ¿Lo cumple este proyecto? |
|---|---|
| **Multi-tenant** — una sola instancia de la app sirve a muchos clientes distintos, con los datos separados | Sí — muchos entrenadores comparten la misma app y base de datos, aislados por RLS (sección 6.2) |
| **Suscripción** — se paga de forma recurrente por usar el software, no se compra una copia | Se añade en la Fase 4 (Stripe) — el modelo ya está pensado para esto desde el principio |
| **Alojado en la nube, accesible por navegador** | Sí — Supabase + Cloudflare Pages, accesible como web y como PWA instalable |
| **Mantenimiento centralizado** — el proveedor mantiene la app, el cliente no instala ni actualiza nada | Sí — tú mantienes un único código para todos los entrenadores, ninguno gestiona su propio servidor |

Además, es un **SaaS vertical**: no es una herramienta genérica de gestión
para cualquier negocio, sino una hecha específicamente para un nicho
(entrenadores personales y sus planes de entrenamiento) — el mismo tipo de
producto que Calendly es para reservas o Shopify para tiendas, pero aplicado
a este sector. Merece la pena que conozcas el término porque es exactamente
cómo se llamaría esto si lo describieras en una entrevista o a un inversor.

### 7.2 El patrón de aislamiento de datos correcto (confirma la sección 6.2)

Investigué las tres formas estándar de aislar datos entre clientes en un
SaaS multi-tenant:

| Patrón | Cómo es | Cuándo se usa |
|---|---|---|
| **RLS con esquema compartido** (lo que ya recomendamos en la sección 6.2) | Todas las filas en las mismas tablas, con un `trainer_id`/`user_id` y políticas RLS que filtran el acceso | El punto de partida estándar de la mayoría de SaaS — coste de infraestructura más bajo, una sola base de datos que mantener |
| **Esquema por cliente** | Mismo servidor de base de datos, pero cada entrenador tiene su propio esquema | Cuando un cliente grande necesita más aislamiento del que da RLS |
| **Base de datos por cliente** | Cada entrenador tiene su propia base de datos completa | Solo para clientes enterprise con requisitos regulatorios — máximo aislamiento, máximo coste |

**Confirmado:** la recomendación de "RLS con esquema compartido" que ya
propuse en la sección 6.2 es exactamente el patrón estándar con el que
arrancan la mayoría de SaaS reales, y solo se pasa a los otros dos si en el
futuro aparece un cliente grande que lo exija — no es algo que haya que
resolver ahora.

### 7.3 Cómo hacerlo "funcional de verdad" (no solo bien diseñado)

Esto es lo que de verdad respondía a tu pregunta — la diferencia entre un
proyecto con buena arquitectura y uno que **funciona** para un usuario real
desde el primer día:

1. **Construye un solo recorrido completo de principio a fin antes que nada
   ("vertical slice"):** un entrenador crea una plantilla → invita a un
   cliente → el cliente entra y ve su plan → el cliente marca un
   entrenamiento como hecho. Ese recorrido entero, funcionando de verdad, es
   más valioso al principio que tener 10 pantallas a medias. Encaja
   directamente con tu roadmap de la sección 5: la Fase 2/3 debería producir
   ese recorrido completo, no todas las piezas del producto a la vez.

2. **"Simple" no significa "roto":** aunque el MVP tenga pocas funciones, sí
   tiene que manejar errores obvios, guardar los datos de forma fiable,
   proteger las cuentas (RLS + sin alta pública, que ya tenemos resuelto) y
   explicar al usuario qué está pasando en cada pantalla. La seguridad básica
   no es algo que se deja para "después del MVP" — ya la tenemos desde el
   diseño.

3. **Un "efecto wow", no diez funciones mediocres:** tienes ya algo que
   ningún genérico de fitness tiene — la lógica de sustitución de ejercicios
   por condición física (cadera, diástasis) que ya construiste para ti y
   Laura. Si el editor de plantillas del entrenador incluye "marca este
   ejercicio como de riesgo para tal condición y sugiere su alternativa", eso
   es un diferenciador real frente a una app de plantillas genérica — no lo
   pierdas al generalizar el producto.

4. **No construyas todo antes de enseñárselo a alguien:** la validación
   (hablar con 1-3 entrenadores reales, ver si de verdad lo usarían) importa
   tanto como el código — no tiene sentido pulir el editor de plantillas
   durante semanas sin que ningún entrenador real lo haya tocado todavía.

5. **La métrica que de verdad importa al principio no es "cuántas funciones
   tiene", es la tasa de activación:** de los entrenadores que prueban la
   app, ¿qué porcentaje llega a completar el recorrido central (crear una
   plantilla + invitar a su primer cliente) en las primeras 24h? Si eso pasa
   con pocos usuarios, es una señal mucho más fiable que cualquier opinión
   sobre si "está bien hecho".

### 7.4 Qué significa esto para tu roadmap (sección 5)

La Fase 2 ("prototipo de datos") y la Fase 3 ("editor de planes") de la
sección 5 deberían fusionarse en la práctica en un único objetivo: **el
recorrido completo funcionando con datos reales, aunque sea feo**, antes de
pulir nada. El diseño bonito del editor puede esperar; que un entrenador real
pueda de verdad invitar a un cliente y que ese cliente vea su plan, no.

Sources:
- [How to Build a SaaS MVP: Step-by-Step Guide 2026](https://acropolium.com/blog/build-saas-mvp/)
- [SaaS MVP Development: Complete Startup Guide for 2026](https://codevelo.io/blog/saas-mvp-development)
- [How to Design a Multi-Tenant SaaS Architecture](https://clerk.com/blog/how-to-design-multitenant-saas-architecture)
- [Multi-tenant SaaS: RLS vs schema-per-tenant vs database-per-tenant](https://aliasghar.me/blog/multi-tenant-saas-data-isolation)
- [What Is Software as a Service (SaaS)? | IBM](https://www.ibm.com/think/topics/saas)
- [SaaS Multitenancy: Components, Pros and Cons and 5 Best Practices | Frontegg](https://frontegg.com/blog/saas-multitenancy)

---

## 8. Nombre elegido: Kinovia (kinovia.io) — posicionamiento y cómo validar antes de programar

### 8.1 El nombre

**Kinovia**, dominio **kinovia.io**. Comprobado antes de decidir:
- **Sin conflicto de nicho** (a diferencia de "Kinesia", que sí lo tenía):
  quien ya usa "Kinovia" es una productora audiovisual en Indonesia, un
  salón de belleza en Bélgica y una plataforma "próximamente" en Camerún —
  ninguno en fitness/salud, cero riesgo de confusión de marca en tu sector.
- `kinovia.com`, `kinovia.net` y `kinovia.org` ya están registrados por esas
  empresas — por eso el dominio real es `.io`. Esta comprobación viene de
  búsqueda web, no de un registrador — **antes de comprarlo, confírmalo en
  un registrador real (Namecheap, OVH, etc.)**.

### 8.2 Posicionamiento — framework de April Dunford ("Obviously Awesome")

Es el framework de referencia en positioning B2B/SaaS (usado con Google, IBM,
Postman, Epic Games). Se construye de abajo arriba: no partes de "en qué
categoría de mercado estoy", partes de tus mejores clientes potenciales y qué
uso le darían. Aplicado a Kinovia:

| Componente | Para Kinovia |
|---|---|
| **Alternativas competitivas** (qué usaría el entrenador si Kinovia no existiera) | Trainerize, TrueCoach, una plantilla de Excel/Google Sheets, o PDFs por WhatsApp |
| **Atributos únicos** | El motor de sustitución de ejercicios **por condición física** (cadera, diástasis, rodilla...) integrado en el propio dato del plan — ninguna de las alternativas lo tiene como núcleo, es una nota manual en el mejor de los casos |
| **Valor que eso habilita** | El entrenador puede aceptar clientes con lesiones/limitaciones reales sin necesitar ser fisioterapeuta y sin miedo a empeorarlos — hoy muchos entrenadores rechazan o improvisan con este perfil de cliente |
| **Cliente ideal** | Entrenadores personales que ya trabajan (o quieren trabajar) con clientes con alguna limitación física real: postparto, artrosis, rehabilitación, clientes mayores — no coaches de solo rendimiento/culturismo |
| **Categoría de mercado** | No "software genérico de gestión de entrenador" (categoría saturada, dominada por Trainerize) sino **"software de planificación segura para entrenadores con clientes con condición física"** — una categoría más pequeña, pero donde no compites de tú a tú contra jugadores con presupuestos de marketing enormes |

### 8.3 Cómo validar esto ANTES de escribir código

La investigación es clara en un punto: **el 85% de los SaaS fracasan por
falta de validación, no por mala ingeniería** — la parte de "hablar con
gente real" no es un trámite, es más importante que el código en esta fase.

**El método (Mom Test, de Rob Fitzpatrick):** no preguntes "¿usarías una app
que...?" (la gente siempre dice que sí por educación). Pregunta por su
comportamiento pasado real: qué usan ahora, qué les frustra de verdad, si
alguna vez han rechazado o complicado un cliente por su lesión, y qué
pagarían por resolverlo — sin mencionar Kinovia todavía.

**Objetivo concreto antes de tocar el editor de plantillas:**
- Habla con **unos 15-20 entrenadores** que encajen con el perfil ideal
  (sección 8.2) — aquí es donde tu ventaja de **"localmente me sería fácil
  insertarla"** vale oro: el "founder-led outreach" (tú mismo hablando con
  ellos, no un anuncio) es más efectivo al principio que cualquier campaña,
  precisamente porque puedes ajustar el mensaje en la conversación.
- Señal de validación real: si **10-15 de esos 20** confirman el problema y
  pueden decir qué pagarían por resolverlo, hay demanda de verdad. Si son
  menos de la mitad, el problema o la solución hay que replantearla antes de
  construir nada.
- Un empujón extra si consigues **3-5 que se comprometan a probarlo en
  cuanto exista** (aunque sea gratis al principio) — eso es lo que confirma
  que no es solo cortesía en la conversación.

Este proceso lleva 2-3 semanas y no cuesta nada más que tu tiempo — encaja
justo antes de la Fase 2 del roadmap (sección 5), no después.

Sources:
- [How to Validate Your B2B SaaS Idea for VC investment](https://www.forumvc.com/thought-pieces/how-to-validate-your-b2b-saas-idea-for-vc-investment-a-comprehensive-guide-for-founders)
- [Customer Discovery: A SaaS Founder Playbook for 2026](https://saasfractionalcpo.com/blog/customer-discovery-guide/)
- [How to get your first customer in B2B SaaS?](https://the7eagles.com/b2b-saas-how-to-get-first-customers/)
- [5 Components of SaaS Positioning That Most Founders Skip (April Dunford)](https://saasclub.io/podcast/5-steps-saas-product-positioning-with-april-dunford-252/)
- [April Dunford's Positioning Framework / Canvas / Worksheet](https://www.kathirvel.com/guide-april-dunford-positioning-framework/)
