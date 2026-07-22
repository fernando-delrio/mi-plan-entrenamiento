# CLAUDE.md — Guía de arquitectura y estilo · Kinovia

> Borrador preparado el 2026-07-21, **antes de crear el proyecto**. Cuando
> exista el repositorio real de Kinovia, este archivo se mueve a su raíz.
> Está basado en el `CLAUDE.md` general de Fernando y en el de su plan de
> entrenamiento personal, adaptado al stack y las reglas propias de este
> proyecto. Antes de escribir cualquier línea de código de Kinovia, lee y
> aplica estas convenciones sin excepción.

---

## 0.0 Dominio del proyecto

**Kinovia** (dominio previsto: `kinovia.io`) es un SaaS vertical para
entrenadores personales: cada entrenador tiene su propio panel para crear
**plantillas de plan de entrenamiento editables** y asignárselas a sus
clientes, que las ven y registran su seguimiento (entrenos hechos, dolor,
peso...) desde su propia cuenta.

**No es un plan de una sola persona** (eso es el otro proyecto, `plan
entrenamientoi mio`) — es multi-tenant: muchos entrenadores, cada uno con sus
propios clientes, todos en la misma base de datos, aislados por RLS.

**El diferenciador de producto no es opcional, es el corazón del negocio:**
un motor de sustitución de ejercicios por condición física (cadera, rodilla,
diástasis, etc.), integrado en el propio dato de la plantilla — no una nota
manual aparte. Es lo que separa a Kinovia de un Trainerize/TrueCoach
genérico. Cualquier decisión de producto que lo diluya o lo convierta en una
casilla opcional escondida está yendo en contra de la razón de ser del
proyecto. Ver `doc/escalado-y-entrenadores.md` (del proyecto personal),
secciones 6-8, para todo el razonamiento detrás de esta decisión.

**Premisas no negociables:**
- La privacidad entre entrenadores/clientes la da **RLS**, no dónde se
  aloja el frontend — mismo principio que en el proyecto personal.
- **Alta siempre por invitación**, nunca pública — ni para entrenadores ni
  para clientes.
- **JSONB primero, no tablas normalizadas** para el contenido de la
  plantilla (fases→días→ejercicios) — más barato y rápido de construir para
  un MVP; se normaliza más adelante solo si de verdad hace falta consultar
  ejercicios a través de plantillas.
- **No se pule el editor de plantillas sin validar demanda primero** —
  mínimo 15-20 conversaciones reales con entrenadores (Mom Test, no
  preguntas hipotéticas) antes de invertir tiempo en esa pantalla a fondo.
- **Empezar por PWA**, no por apps nativas de tienda — Capacitor solo si el
  producto se valida con entrenadores reales dispuestos a pagar.

---

## 0.1 Prólogo de Coplien — Profesionalismo y legado

> "Escribir código sucio es fácil. Cualquiera lo hace bajo presión.
> El profesional sabe que la presión es precisamente cuándo NO se puede permitir suciedad.
> Porque el código sucio tiene un costo: no solo en el presente, sino en el futuro
> de quien lo lee, lo mantiene, lo extiende. Ese futuro es responsabilidad tuya."
> — James O. Coplien, "Código Limpio"

**Las 5 promesas de Coplien:**

| Principio | Cómo lo aplicamos |
|---|---|
| **El código debe ser legible** | Guard Clauses, Extract Function, nombres descriptivos |
| **La responsabilidad es personal** | Cada commit es tuyo — mensaje claro + archivos tocados |
| **Aprender requiere esfuerzo** | MODO DE APRENDIZAJE — pregunta de comprensión tras cada bloque |
| **La disciplina evita deuda técnica** | REGLA DE INCREMENTOS — cambios pequeños, frecuentes, funcionales |
| **El legado afecta a otros** | `ERRORES_APRENDIDOS.md` — registra lo aprendido para no repetirlo |

---

## 0.2 Filosofía general — Ousterhout + Shvets + SOLID

### 1. John Ousterhout — "A Philosophy of Software Design"
- **Deep modules, thin interfaces**: interfaz simple, cuerpo profundo.
- **Naming matters**: un nombre bueno es documentación; uno malo es deuda técnica.
- **Un módulo, una responsabilidad**: si necesitas comentario para explicar qué hace, tiene dos responsabilidades.
- **Evita cambios generales para casos especiales**: si añadir una feature requiere tocar 10 archivos, la arquitectura está mal.

### 2. Alexander Shvets — "Dive Into Design Patterns" + "Dive Into Refactoring"
- **Strategy Pattern**: variación encapsulada en un objeto de configuración — el propio motor de sustitución de ejercicios por condición es un Strategy.
- **Guard Clauses**: condiciones que saltan rápido, no if/else anidados.
- **Extract Function**: si necesitas comentario, extrae a función nombrada.

### 3. SOLID (Robert Martin)
- **S**ingle Responsibility, **O**pen/Closed, **L**iskov Substitution, **I**nterface Segregation, **D**ependency Inversion — aplicados de forma pragmática, no dogmática.

---

## 0.3 Los 5 principios — DRY · KISS · YAGNI · SOC · LOD

Igual que en el resto de proyectos de Fernando — DRY (una sola fuente de verdad, sobre todo para la lógica de sustitución de ejercicios), KISS, YAGNI (nada de features "por si acaso" antes de validar demanda), SOC (schemas/service/router separados) y LOD (máximo 1-2 puntos de acceso por expresión).

---

## 🎓 MODO DE APRENDIZAJE — Reglas pedagógicas obligatorias

> Fernando viene de 10 años como soldador y está en transición a
> desarrollador. Kinovia es un proyecto más ambicioso que su plan personal —
> multi-tenant, roles, RLS de verdad — así que el modo de aprendizaje importa
> todavía más aquí: el objetivo es que entienda cada decisión para poder
> explicarla en una entrevista, no solo que el producto funcione.

### Reglas obligatorias para Claude

1. **Antes de escribir código**, explicar en 2-3 líneas: qué vamos a hacer,
   por qué este approach y no otro, y qué concepto clave entra en juego.
2. **Comentarios en el código**: todo bloque de más de 15 líneas debe tener
   comentarios que expliquen el "por qué", no solo el "qué".
3. **Pregunta de comprensión** después de cada bloque importante.
4. **Nunca dar código sin contexto** — si Fernando pide "hazme el editor de
   plantillas", preguntar primero qué entiende él por eso.
5. **Alertas de concepto nuevo**: marcar con 🆕 (RLS multi-tenant, JSONB,
   invitación de usuarios vía Admin API son todos conceptos nuevos respecto
   al proyecto personal — márcalos la primera vez que aparezcan).
6. **Modo revisión**: si Fernando comparte su propio código, preguntar qué
   cree que hace antes de corregirlo.

---

## 🧠 APRENDIZAJE AGÉNTICO — Registro de errores

Cada vez que Claude corrige un error, actualizar `ERRORES_APRENDIDOS.md`:

```
### [Fecha] — [Área: Frontend / Backend / Auth / RLS / BBDD]

**❌ Error:**
Descripción breve de qué estaba mal.

**✅ Corrección:**
Qué se cambió y por qué funciona así.

**🎓 Concepto aprendido:**
El principio técnico detrás de la corrección.
```

Presta especial atención a errores de **RLS** — un fallo de aislamiento
entre tenants es el tipo de bug más caro posible en este proyecto (filtra
datos de un entrenador o cliente a otro), así que merece su propia entrada
detallada siempre que ocurra, no una línea de pasada.

---

## REGLA DE INCREMENTOS — OBLIGATORIA

Cada feature se entrega en incrementos pequeños que conectan backend y
frontend. Nunca solo backend, nunca solo frontend. Cada incremento debe ser
funcional end-to-end. Al terminar cada incremento: **parar, resumir, esperar
señal de commit**.

**Además, en Kinovia:** el primer incremento grande no es "el editor de
plantillas completo" — es el recorrido mínimo de la sección 7.3 del doc de
escalado: un entrenador crea una plantilla simple → invita a un cliente → el
cliente entra y ve su plan → el cliente marca un entrenamiento como hecho.
Ese recorrido, feo pero completo, va antes que pulir cualquier pantalla.

---

## REGLAS DE FLUJO DE TRABAJO — OBLIGATORIAS

### Regla 1 — Commit atómico funcional
La unidad mínima es un commit que deja el sistema arrancable y coherente.

### Regla 2 — Esperar señal
Nunca pasar a la siguiente tarea por iniciativa propia.

### Regla 3 — Resumen obligatorio

```
📁 Archivos tocados:
  - archivo.jsx — qué hace el cambio en una línea

✅ Qué funciona ahora que antes no funcionaba

⏭️ Siguiente tarea pendiente

💾 Commit sugerido:
  git add <archivos>
  git commit -m "tipo(scope): descripción"
```

### Regla 4 — El usuario no debe leer el código para aprobar

### Regla 5 — Commits semánticos
```
feat(trainer): panel de creación de plantillas con fases y días
feat(auth): invitación de clientes vía Edge Function
fix(rls): corrige política que permitía leer clientes de otro entrenador
refactor(client): extrae lógica de progreso a hook compartido
test(rls): añade test de aislamiento entre entrenadores para plan_templates
```

### Regla 6 — Actualizar doc/ al tocar un módulo

| Módulo tocado | Archivo a actualizar |
|---|---|
| `modules/auth/` | `doc/modulos/auth.md` |
| `modules/trainer/` | `doc/modulos/trainer.md` |
| `modules/client/` | `doc/modulos/client.md` |
| `modules/plan-templates/` | `doc/modulos/plan-templates.md` |
| Políticas RLS / multi-tenancy | `doc/modulos/rls.md` |
| Arquitectura general | `doc/arquitectura.md` |
| Hoja de ruta, fases | `doc/fases.md` |
| Decisión con deuda | `doc/deuda-tecnica.md` |
| Bloque terminado | `doc/devlog.md` |

### Regla 7 — Code Review Checklist

| # | Pregunta | Si falla |
|---|---|---|
| 1 | ¿Tiene test? | No se mergea |
| 2 | Si toca RLS, ¿tiene test de aislamiento entre tenants? | No se mergea, sin excepción |
| 3 | ¿Actualiza documentación? | Añadir antes de commit |
| 4 | ¿Sigue las convenciones? | Refactorizar |
| 5 | ¿El commit message es semántico? | Reescribir |
| 6 | ¿Es el cambio más pequeño posible? (>100 líneas → ¿se divide?) | Dividir |
| 7 | ¿Hay credenciales en el código? (`service_role key` fuera de Edge Functions) | Eliminar, mover a Edge Function/secret |
| 8 | ¿Funciona el happy path Y los casos de error? | Completar |
| 9 | ¿Hay migración? ¿Tiene rollback y test? | Añadir |

---

## 1. Stack y comandos

- **Frontend:** React + Vite + Tailwind CSS + React Router — `frontend/`.
- **Iconos:** Boxicons (`npm install boxicons`).
- **Backend:** Supabase (Postgres + Auth + Storage + Edge Functions). Sin
  backend propio (FastAPI/Django/Node) — mismo principio que el proyecto
  personal, pero aquí sí hay build step real (Vite), a diferencia del
  `index.html` sin build de ese proyecto.
- **DB:** Postgres gestionado por Supabase. RLS obligatoria en cada tabla,
  sin excepción — es la frontera de privacidad entre entrenadores.
- **Auth:** Supabase Auth. Alta siempre por invitación (`inviteUserByEmail`
  desde una Edge Function con `service_role key`) — nunca alta pública.
- **"Migraciones":** archivos `.sql` en `supabase/migrations/`, escritos a
  mano, revisados antes de aplicarlos. Cada cambio de schema es un archivo
  nuevo; nunca se edita uno ya aplicado.
- **Hosting:** Cloudflare Pages (deploy automático al hacer `git push`).
- **Móvil/PC:** PWA (manifest + service worker) desde el día 1. Capacitor
  solo si se valida el producto y se quiere presencia en tiendas de apps.
- **Testing:** Vitest + React Testing Library (frontend), tests de
  aislamiento RLS contra Supabase (dos JWT de prueba, tenant A y tenant B).

```bash
# Frontend
cd frontend && npm run dev
npm run build

# Supabase (CLI)
supabase functions deploy invite-client
supabase secrets set MISTRAL_API_KEY=valor   # si se reutiliza el patrón de IA del proyecto personal

# Tests
npm run test
```

---

## 2. Arquitectura de ficheros — Feature-based Modules

```
frontend/src/modules/
  auth/                 ← login, invitación, aceptar invitación
    components/
    hooks/
    services/
    lib/
  trainer/              ← panel del entrenador: crear/editar plantillas, gestionar clientes
    components/
    hooks/
    services/
    lib/
  client/               ← vista del cliente: ver su plan, registrar entreno/dolor
    components/
    hooks/
    services/
    lib/
  plan-templates/       ← lógica compartida de la plantilla JSONB (fases→días→ejercicios)
    components/
    hooks/
    services/
    lib/
  core/                 ← lo verdaderamente compartido
    lib/                ← cx.js, api.js (cliente Supabase), navigation.js
    hooks/
    components/         ← ErrorBoundary, Spinner, AppShell

supabase/
  migrations/            ← *.sql versionado, con RLS incluida en el mismo archivo que crea la tabla
  functions/
    invite-client/       ← Edge Function con service_role key, nunca en el frontend
    exercise-tutorial/   ← si se reutiliza el patrón de IA del proyecto personal
```

### Regla de dependencias
- Los módulos de feature pueden importar de `core/`.
- Los módulos de feature **nunca** importan entre ellos — en particular,
  `trainer/` y `client/` no se importan mutuamente aunque compartan datos:
  lo compartido sube a `plan-templates/` o `core/`.

---

## 3. Arquitectura de capas dentro de cada feature

```
Componente JSX          ← solo pinta HTML. No hace fetch, no navega, no tiene lógica de negocio
      ↓
Custom Hook             ← orquesta estado, efectos y llamadas al servicio. Captura errores.
      ↓
Service (xService.js)   ← única puerta de entrada a la API. Solo hace fetch. Lanza errores.
      ↓
Model (xModel.js)       ← transforma y normaliza datos crudos del backend
      ↓
API (core/lib/api.js)   ← cliente Supabase configurado una vez
```

**Regla estricta:** un componente nunca hace `fetch`; un service nunca llama
a otro service; un modelo nunca importa React; un hook nunca importa `fetch`
directamente.

---

## 3.1 State Management — Cuándo usar qué

Igual que en el resto de proyectos de Fernando: `useState` para UI local,
cálculo en render para estado derivado, Context para sesión/auth, URL
(`useSearchParams`) para filtros compartibles, custom hook + Supabase para
estado de servidor. Zustand solo si aparece estado global que cruce
`trainer/` y `client/` sin pasar por props (poco probable al principio).

---

## 4. Convenciones de código

Arrow functions siempre (nunca `function foo() {}`), sin `if/else` en JSX
(Guard Clauses o funciones nombradas), sin `if/else` en handlers (funciones
nombradas con intención), `try/catch` solo en el hook, sin `for` ni `let`
(estructuras declarativas: `map`/`filter`/`reduce`). Mismas reglas y mismos
ejemplos que el `CLAUDE.md` general de Fernando — no se repiten aquí.

`cx(...classes)` en `core/lib/cx.js`.

---

## 5. Convención de nombrado

| Tipo | Convención | Ejemplo |
|---|---|---|
| Hook | `use[Feature][Descripción].jsx` | `useTrainerClients.jsx`, `usePlanTemplateEditor.jsx` |
| Context | `[Feature]Context.jsx` | `AuthSessionContext.jsx` |
| Service | `[feature]Service.js` | `planTemplatesService.js`, `invitesService.js` |
| Model | `[feature]Model.js` | `planTemplateModel.js` |
| Componente | `PascalCase.jsx` | `TrainerDashboard.jsx`, `ClientPlanView.jsx` |
| Config/Strategy | `[feature]Config.js` | `exerciseSubstitutionConfig.js` |
| Migración SQL | timestamp + descripción | `2026_08_01_plan_templates_rls.sql` |
| Test | `[module].test.js` | `planTemplatesService.test.js` |

---

## 6. Manejo de errores

`try/catch` SOLO en el hook. El service lanza (`throw`), nunca silencia
errores — mismo patrón que el proyecto personal.

## 6.1 React Error Boundaries

Una boundary por área principal: `trainer/`, `client/`, `auth/` — un error
en el editor de plantillas del entrenador no debe tumbar la vista del
cliente ni al revés, son superficies de la app con dueños distintos.

---

## 7. Principios aplicados — Shvets + SOLID

Guard Clauses y Strategy Pattern como en el resto de proyectos. El propio
motor de sustitución de ejercicios por condición física es el ejemplo canon
de Strategy en este proyecto:

```javascript
// Igual que STATUS_CONFIG en otros proyectos — añadir una condición nueva
// (rodilla, hombro...) es una entrada más en el objeto, cero cambios en la
// lógica que la consume.
export const CONDITION_SUBSTITUTIONS = {
  cadera_femoroacetabular: { avoid: ["flexión de cadera cargada"], swapWith: "core cadera neutra" },
  diastasis_abdominal: { avoid: ["flexión de tronco cargada"], swapWith: "core presión intraabdominal baja" },
};
export const getSubstitution = (condition) => CONDITION_SUBSTITUTIONS[condition] ?? null;
```

---

## 8. Lo que nunca hacemos

Todo lo del `CLAUDE.md` general (nunca `function foo(){}`, nunca `fetch` en
un componente, nunca `if/else` anidado en JSX, nunca lógica de negocio en la
UI, nunca un módulo de feature importando de otro, nunca `try/catch` en el
service, nunca credenciales hardcodeadas, nunca `create_all()`/equivalente
en producción, nunca estado derivado en `useState`+`useEffect`) **más, específico de Kinovia:**

| Práctica prohibida | Por qué |
|---|---|
| Tabla nueva sin RLS activada en el mismo commit | Es la única frontera de privacidad entre entrenadores — sin RLS, cualquier fila es de cualquiera |
| `service_role key` en cualquier archivo que llegue al navegador | Esa clave salta cualquier RLS — solo vive en Edge Functions/secrets |
| Alta pública de entrenadores o clientes | El modelo de negocio depende de que cada cliente llegue invitado por su entrenador |
| Referenciar la plantilla maestra en vivo desde el plan de un cliente en vez de copiarla | El entrenador debe poder editar su plantilla sin romper planes ya asignados |
| Pulir el editor de plantillas antes de validar demanda (sección 0.0) | Es la causa nº1 de fracaso en SaaS según la investigación (85% por falta de validación, no por ingeniería) |

---

## 9. Database Migrations — SQL versionado como fuente de verdad

Igual que el proyecto personal: no hay Alembic, cada cambio de schema es un
archivo nuevo en `supabase/migrations/`, revisado a mano antes de aplicarlo
en Supabase, nunca se edita uno ya aplicado.

**Regla adicional para Kinovia:** toda migración que cree o modifique una
tabla con datos de tenant (entrenador o cliente) incluye, en el mismo
archivo, las políticas RLS correspondientes — nunca se crea la tabla en una
migración y la política RLS en otra posterior. Una tabla sin su RLS en el
mismo commit no se considera terminada (ver Code Review Checklist, Regla 7).

---

## 10. Testing strategy

### Frontend (Vitest + React Testing Library)
Testea el hook, nunca el componente directamente — mismo patrón que el resto
de proyectos de Fernando.

### RLS / aislamiento multi-tenant (no negociable)

Esta es la categoría de test más importante de todo el proyecto. Patrón:

```javascript
describe('plan_templates RLS', () => {
  it('trainer A cannot read trainer B templates', async () => {
    // ARRANGE: dos clientes Supabase autenticados con JWT de trainer A y B
    // ACT: trainer A intenta leer una plantilla de trainer B por id
    // ASSERT: la respuesta viene vacía (RLS oculta la fila, no un error 403 explícito)
  });
});
```

Cada tabla nueva con RLS necesita al menos: un test de que el dueño ve sus
propias filas, y un test de que un tenant distinto no ve ni puede escribir
esas filas.

---

## 11. Caching Strategy

| Dato | Estrategia | TTL |
|---|---|---|
| Plantilla en edición (borrador del entrenador) | Cache local mientras se edita, guardar al confirmar | — |
| Plan asignado a un cliente | Sin caché agresivo — el cliente necesita ver cambios recientes | 0-30s |
| Tracking del cliente (dolor, peso, entrenos) | Sin caché, fetch fresco | 0 |
| Dashboard del entrenador (métricas de sus clientes) | Cache corto | 30-60s |

---

## 12. Hoja de ruta — Fases

La hoja de ruta específica de Kinovia vive en `doc/fases.md` una vez exista
el proyecto — de momento, el punto de partida es `doc/escalado-y-entrenadores.md`
(secciones 5 a 8) del proyecto personal, que ya cubre las fases 0-4 y el plan
de validación antes de construir.

---

## 13. Seguridad — OWASP + multi-tenancy

| Vulnerabilidad | Mitigación |
|---|---|
| SQL Injection | Supabase/PostgREST — queries parametrizadas siempre |
| Fuga de datos entre tenants | RLS en cada tabla + test de aislamiento obligatorio (sección 10) |
| Auth deficiente | Supabase Auth, alta solo por invitación, sin alta pública |
| XSS | React escapa HTML por defecto — nunca `dangerouslySetInnerHTML` |
| CORS incorrecto | Limitar a dominio real (`kinovia.io`), nunca `*` en producción |
| Secretos expuestos | `service_role key` solo en Edge Functions/secrets, nunca en frontend |
| Acceso desautorizado | RLS + verificación de rol (`trainer`/`client`) en cada Edge Function sensible |

---

## 14. Performance Budgets

| Métrica | Budget |
|---|---|
| Bundle JS inicial (gzip) | < 150 KB |
| Bundle JS total (gzip) | < 400 KB |
| Time to Interactive (TTI) | < 3s |
| API p95 | < 200ms |
| Queries SQL por vista | ≤ 5 |

---

## 15. Recursos y herramientas

| Recurso | Uso |
|---|---|
| **Boxicons** | Iconos: `<i className="bx bx-package" />` |
| **Supabase Studio** | Panel para revisar RLS, tablas y Edge Functions |
| **Cloudflare Pages** | Hosting con deploy automático |
| **Namecheap / OVH** | Confirmar disponibilidad real de `kinovia.io` antes de comprarlo |
| **Unlighthouse** (`npx unlighthouse --site <URL>`) | Auditoría Lighthouse de todo el sitio |

---

## 16. Matriz de decisiones rápidas

| Pregunta | Acción |
|---|---|
| ¿Escribo código nuevo? | Test unitario + integración antes de commit |
| ¿Toco una tabla o política RLS? | Test de aislamiento entre tenants obligatorio, sin excepción |
| ¿Cambio un archivo existente? | Actualiza `doc/` |
| ¿>100 líneas en el diff? | Divide en múltiples commits |
| ¿Cambio de schema en BD? | Migración SQL + RLS en el mismo archivo + test de migración |
| ¿Feature nueva arriesgada (p. ej. cambiar el modelo de plantilla)? | Feature flag desactivado por defecto |
| ¿Voy a pulir el editor de plantillas a fondo? | Primero: ¿ya hay 15-20 conversaciones de validación con entrenadores reales? |
| ¿Instalar dependencia? | Pasar checklist de dependencias (mantenimiento activo, tamaño, licencia) |
| ¿Algo se rompió? | Registra en `ERRORES_APRENDIDOS.md` |

---

**Versión:** 0.1 — Borrador previo a la creación del proyecto
**Mantenedor:** Fernando + Claude
