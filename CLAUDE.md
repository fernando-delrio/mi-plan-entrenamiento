# CLAUDE.md — Guía de arquitectura y estilo · Plan de entrenamiento de Fernando

> Este archivo es la fuente de verdad para cualquier código generado en este proyecto.
> Antes de escribir cualquier línea, lee y aplica estas convenciones sin excepción.

---

## 0.0 Dominio del proyecto

**Plan de entrenamiento personal de Fernando** — no es un SaaS multiusuario, no hay
socios/entrenadores/clases/reservas. Es un plan de entrenamiento, nutrición y
seguimiento de salud de una sola persona (Fernando: choque femoroacetabular +
artrosis de cadera, objetivo de recomposición corporal y vuelta al enduro MTB).

**Premisa no negociable: debe seguir funcionando servido como HTML estático desde
GitHub Pages.** Nada de lo que se añada puede requerir un servidor propio.

Por eso el stack real es deliberadamente distinto al de la sección 1 de más abajo
(que describe el stack "por defecto" para *otros* proyectos de Fernando, tipo SaaS
con backend propio). Aquí:

- **Un único archivo** `index.html` — React 18 + Babel-standalone por CDN, **sin
  build, sin npm, sin bundler**. Se abre con doble clic o se sirve tal cual.
- **Backend:** Supabase (Postgres + Auth + Storage + Edge Functions), añadido vía
  `<script>` CDN (build UMD), nunca un backend propio (FastAPI/Django/Node) porque
  eso rompería la premisa de GitHub Pages.
- Sin `frontend/`, sin `backend/`, sin `features/`, sin Vite, sin Tailwind, sin
  Alembic. La sección 2 (arquitectura por feature-folders) y la sección 9
  (Alembic) **no aplican a este proyecto** — el equivalente aquí a una migración
  versionada es `supabase/migrations/*.sql`, revisado a mano antes de ejecutarlo
  en el SQL Editor de Supabase.
- El resto del documento (Coplien, Ousterhout, SOLID, DRY/KISS/YAGNI/SOC/LOD, modo
  de aprendizaje, reglas de incrementos y de flujo de trabajo, convenciones de
  JS de la sección 4) **sí aplica** — son principios de calidad de código
  independientes del stack.

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
- **Deep modules, thin interfaces**: interfaz simple, cuerpo profundo
- **Naming matters**: un nombre bueno es documentación; uno malo es deuda técnica
- **Un módulo, una responsabilidad**: si necesitas comentario para explicar qué hace, tiene dos responsabilidades
- **Evita cambios generales para casos especiales**: si añadir una feature requiere tocar 10 archivos, la arquitectura está mal

### 2. Alexander Shvets — "Dive Into Design Patterns" + "Dive Into Refactoring"
- **Strategy Pattern**: variación encapsulada en un objeto de configuración
- **Guard Clauses**: condiciones que saltan rápido, no if/else anidados
- **Extract Function**: si necesitas comentario, extrae a función nombrada

### 3. SOLID (Robert Martin)
- **S**ingle Responsibility: un módulo, una razón para cambiar
- **O**pen/Closed: abierto a extensión, cerrado a modificación
- **L**iskov Substitution: cualquier subclase funciona donde esperas la clase base
- **I**nterface Segregation: muchas interfaces específicas > una gorda
- **D**ependency Inversion: depende de abstracciones, no de implementaciones

```python
# ❌ INCORRECTO — Strategy hardcodeada, OCP violation
def calculate_discount(customer):
    if customer.tier == "gold":
        return 0.20
    elif customer.tier == "silver":
        return 0.10
    else:
        return 0.0

# ✅ CORRECTO — Strategy pattern
DISCOUNT_STRATEGY = {
    "gold": 0.20,
    "silver": 0.10,
    "bronze": 0.0,
}
def calculate_discount(customer):
    return DISCOUNT_STRATEGY.get(customer.tier, 0.0)
```

---

## 0.3 Los 5 principios — DRY · KISS · YAGNI · SOC · LOD

### DRY — Don't Repeat Yourself
Cada pieza de lógica vive en un solo sitio. Si copias y pegas, falta una función o modelo.

### KISS — Keep It Simple, Stupid
Código simple > código inteligente. Si necesitas explicar cómo funciona, está mal.

### YAGNI — You Aren't Gonna Need It
No añadas features "por si acaso". Solo lo que necesitas HOY.

### SOC — Separation of Concerns
```python
# schemas.py  → valida los datos de entrada (Pydantic)
# service.py  → lógica de negocio, acceso a BD
# router.py   → orquesta: llama al service, delega efectos al background
```

### LOD — Law of Demeter
Máximo 1-2 puntos de acceso. Si ves más de 2 puntos en una expresión, extrae una propiedad.

```javascript
// ❌ INCORRECTO
const city = order.customer.company.billing_address.city

// ✅ CORRECTO
const city = order.getCustomerCity()
```

### Checklist de revisión rápida

| Principio | Pregunta | Si la respuesta es SÍ |
|---|---|---|
| **DRY** | ¿He escrito esta lógica antes? | Extrae a función/modelo compartido |
| **KISS** | ¿Puedo entenderlo en 10 segundos? | Si no → simplifica |
| **YAGNI** | ¿Alguien lo pidió hoy? | Si no → no lo escribas |
| **SOC** | ¿Esta función hace más de una cosa? | Extrae responsabilidades |
| **LOD** | ¿Tengo más de 2 puntos de acceso? | Añade un método/propiedad |

---

## 🎓 MODO DE APRENDIZAJE — Reglas pedagógicas obligatorias

> Fernando viene de 10 años como soldador y está en transición a desarrollador.
> El objetivo NO es solo que el código funcione — es que Fernando entienda
> cada decisión técnica para poder explicarla en una entrevista.

### Reglas obligatorias para Claude

1. **Antes de escribir código**, explicar en 2-3 líneas:
   - Qué vamos a hacer
   - Por qué este approach y no otro
   - Qué concepto clave entra en juego

2. **Comentarios en el código**: todo bloque de más de 15 líneas debe tener
   comentarios que expliquen el "por qué", no solo el "qué"

3. **Pregunta de comprensión**: después de cada bloque importante, una pregunta
   para verificar que Fernando ha entendido

4. **Nunca dar código sin contexto**: si Fernando pide "hazme el endpoint de X",
   Claude debe preguntar primero qué entiende Fernando por eso

5. **Alertas de concepto nuevo**: si se introduce un patrón nuevo, marcarlo con 🆕

6. **Modo revisión**: cuando Fernando comparta su propio código, Claude debe
   preguntar qué cree que hace ese código antes de corregirlo

---

## 🧠 APRENDIZAJE AGÉNTICO — Registro de errores

Cada vez que Claude corrige un error, indicar que se actualice:

📄 `ERRORES_APRENDIDOS.md`

```
### [Fecha] — [Área: Frontend / Backend / Auth / BBDD]

**❌ Error:**
Descripción breve de qué estaba mal.

**✅ Corrección:**
Qué se cambió y por qué funciona así.

**🎓 Concepto aprendido:**
El principio técnico detrás de la corrección.
```

---

## REGLA DE INCREMENTOS — OBLIGATORIA

> Cada feature se entrega en **incrementos pequeños que conectan backend y frontend**.
> Nunca solo backend. Nunca solo frontend. Cada incremento debe ser funcional end-to-end.

- Backend: modelo + endpoint mínimo para una funcionalidad concreta
- Frontend: service + hook + componente que usa ese endpoint
- El usuario puede ver y usar el resultado en el navegador al terminar
- Al terminar cada incremento: **parar, resumir, esperar señal de commit**

---

## REGLAS DE FLUJO DE TRABAJO — OBLIGATORIAS

### Regla 1 — Commit atómico funcional
La unidad mínima es un commit que deja el sistema arrancable y coherente.
Los archivos acoplados (model + schemas + service) se commitean juntos.

### Regla 2 — Esperar señal
Nunca pasar a la siguiente tarea por iniciativa propia. El usuario dice cuándo continuar.

### Regla 3 — Resumen obligatorio

```
📁 Archivos tocados:
  - archivo.py — qué hace el cambio en una línea

✅ Qué funciona ahora que antes no funcionaba

⏭️ Siguiente tarea pendiente

💾 Commit sugerido:
  git add <archivos>
  git commit -m "tipo(scope): descripción"
```

### Regla 4 — El usuario no debe leer el código para aprobar
El resumen responde: ¿qué cambió y por qué? sin abrir ningún archivo.

### Regla 5 — Commits semánticos
```
feat(products): añade modelo Producto con precio y stock
fix(auth): corrige validación de token expirado
refactor(orders): extrae lógica de descuento a función nombrada
chore(seed): actualiza datos de prueba con nuevos campos
test(orders): añade integration test para createOrder
```

### Regla 6 — Actualizar doc/ al tocar un módulo

| Módulo tocado | Archivo a actualizar |
|---|---|
| `features/auth/` | `doc/modulos/auth.md` |
| `features/products/` | `doc/modulos/productos.md` |
| `features/orders/` | `doc/modulos/pedidos.md` |
| `features/customers/` | `doc/modulos/clientes.md` |
| Arquitectura general | `doc/arquitectura.md` |
| Hoja de ruta, fases | `doc/fases.md` |
| Decisión con deuda | `doc/deuda-tecnica.md` |
| Bloque terminado | `doc/devlog.md` |

### Regla 7 — Code Review Checklist

| # | Pregunta | Si falla |
|---|---|---|
| 1 | ¿Tiene test? | No se mergea |
| 2 | ¿Actualiza documentación? | Añadir antes de commit |
| 3 | ¿Sigue las convenciones? | Refactorizar |
| 4 | ¿El commit message es semántico? | Reescribir |
| 5 | ¿Es el cambio más pequeño posible? (>100 líneas → ¿se divide?) | Dividir |
| 6 | ¿Hay credenciales en el código? | Eliminar, mover a `.env` |
| 7 | ¿Funciona el happy path Y los casos de error? | Completar |
| 8 | ¿Hay migración? ¿Tiene rollback y test? | Añadir |

---

## 1. Stack y comandos

- **Frontend:** un único `index.html` — React 18 + ReactDOM + Babel-standalone
  cargados por `<script>` CDN. Sin npm, sin bundler, sin paso de build.
- **Backend:** Supabase (Postgres + Auth + Storage + Edge Functions), cliente
  `@supabase/supabase-js` cargado también por `<script>` CDN (build UMD, expone
  `window.supabase.createClient`). Sin servidor propio.
- **DB:** Postgres gestionado por Supabase. Seguridad por fila (RLS) en cada
  tabla — nunca una tabla sin políticas.
- **Auth:** Supabase Auth, email/contraseña. Alta pública desactivada en el
  dashboard (proyecto de un solo usuario).
- **"Migrations":** archivos `.sql` en `supabase/migrations/`, escritos a mano,
  revisados antes de pegarlos en el SQL Editor de Supabase. No hay Alembic ni
  autogenerate — cada cambio de schema es un archivo nuevo, nunca se edita uno
  ya aplicado.

```bash
# Abrir la app: doble clic en index.html, o Live Server en VS Code
# Desplegar: git push a main → GitHub Pages reconstruye solo

# Edge Functions (Supabase CLI)
supabase functions deploy <nombre>
supabase secrets set CLAVE=valor
```

---

## 2. Arquitectura de ficheros — Feature-based Modules

> ⚠️ **No aplica literalmente a este proyecto.** Aquí todo vive en `index.html`
> (secciones internas separadas por comentarios `// ─── NOMBRE ───`, no carpetas).
> Se deja esta sección como referencia del principio (separar por qué hace cada
> cosa, no por tipo de archivo) para cuando Fernando trabaje en sus otros
> proyectos con backend propio.

### ❌ Prohibido (arquitectura por tipo)
```
src/
  components/
  hooks/
  services/
```

### ✅ Correcto (arquitectura por feature)
```
frontend/src/modules/
  auth/
    components/
    hooks/
    services/
    lib/
  products/
    components/
    hooks/
    services/
    lib/
  orders/
    components/
    hooks/
    services/
    lib/
  customers/
    components/
    hooks/
    services/
    lib/
  [feature]/          ← cada feature nueva sigue este patrón
    components/
    hooks/
    services/
    lib/
  core/               ← lo verdaderamente compartido
    lib/              ← cx.js, api.js, navigation.js
    hooks/
    components/       ← ErrorBoundary, Spinner, AppShell, etc.

backend/
  main.py
  core/
    config.py         ← Settings (pydantic-settings, lee .env)
    database.py       ← SQLAlchemy engine, Base, get_db()
    security.py       ← hash_password, verify_password, create_access_token
    bootstrap.py      ← init_schema(), seed_admin(), seed_demo()
  features/
    auth/             ← model, schemas, service, dependencies, router
    products/         ← model, schemas, service, router
    orders/           ← model, schemas, service, router
    customers/        ← model, schemas, service, router
    [feature]/        ← cada feature nueva sigue este patrón
  migrations/
    versions/
    env.py
  alembic.ini
  tests/
    features/
      auth/
      products/
      orders/
```

### Regla de dependencias
- Los módulos de feature pueden importar de `core/`
- Los módulos de feature **nunca** importan entre ellos
- Si dos features necesitan compartir algo, ese algo sube a `core/`

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
API (core/lib/api.js)   ← URL base: import.meta.env.VITE_API_URL ?? 'http://localhost:8000'
```

**Regla estricta:**
- Un componente **nunca** hace `fetch`
- Un service **nunca** llama a otro service
- Un modelo **nunca** importa React
- Un hook **nunca** importa `fetch` directamente

---

## 3.1 State Management — Cuándo usar qué

| Tipo de estado | Herramienta | Cuándo subir de nivel |
|---|---|---|
| Estado de UI local | `useState` | Nunca — es el nivel correcto |
| Estado derivado de props | Cálculo en render | Nunca — si lo metes en state creas bug de sincronización |
| Estado de sesión/auth | Context (`AuthSessionContext`) | Si necesitas múltiples contextos → Zustand |
| Estado de URL | `useSearchParams` / `useParams` | Nunca — la URL es la fuente de verdad |
| Estado del servidor | Custom hook + fetch | Si necesitas caché automático → React Query |
| Estado global complejo | Zustand | Solo si múltiples features no relacionadas necesitan el mismo estado |

```javascript
// ❌ Estado derivado en useState — bug de sincronización
const [total, setTotal] = useState(0)
useEffect(() => setTotal(items.reduce((s, i) => s + i.price, 0)), [items])

// ✅ Cálculo en render — siempre sincronizado
const total = items.reduce((s, i) => s + i.price, 0)

// ❌ Filtro en estado local — se pierde al refrescar
const [filter, setFilter] = useState('all')

// ✅ Filtro en URL — compartible y persistente
const [params, setParams] = useSearchParams()
const filter = params.get('status') ?? 'all'
```

---

## 4. Convenciones de código

### Frontend

**Arrow functions siempre — NUNCA `function foo() {}`**
```jsx
// ❌ Prohibido
function MyComponent() { ... }
export function useHook() { ... }

// ✅ Correcto
const MyComponent = () => { ... }
export const useHook = () => { ... }
```

**Sin if/else en JSX — Guard Clauses o funciones nombradas**
```jsx
const loadingState = ({ isLoading }) => isLoading && <Spinner />
const errorState   = ({ error })     => error && <ErrorBanner msg={error} />
return loadingState(state) || errorState(state) || <Content />
```

**Sin if/else en handlers — funciones nombradas con intención**
```javascript
// ❌ Prohibido
const handleSubmit = async () => {
  if (!qty || qty <= 0) { setError('Cantidad inválida'); return }
  try { await onSubmit(qty) } catch { setError('Error') }
}

// ✅ Correcto
const isInvalidQty  = (q) => !q || q <= 0
const validationError = (q) => isInvalidQty(parseFloat(q)) ? 'Cantidad inválida' : null
const executeSubmit = async () => { /* lógica pura */ }
const handleSubmit  = () => validationError(qty) ? setError(validationError(qty)) : executeSubmit()
```

**try/catch solo en el hook — nunca en componentes ni servicios**

**Sin `for` ni `let` — estructuras declarativas**
```javascript
// ❌ Prohibido
for (let i = 0; i < items.length; i++) { ... }

// ✅ Correcto
const titles  = items.map((i) => i.title)
const active  = items.filter((i) => i.active)
const total   = items.reduce((sum, i) => sum + i.price, 0)
const rows    = Array.from({ length: 5 }, (_, idx) => idx + 1)
```

**Archivos en inglés** — todos los nombres de archivo y función en inglés

`cx(...classes)` en `core/lib/cx.js` — combina clases CSS

### Backend
- Errores de negocio: `raise ValueError(msg)` en service, el router lo convierte a `HTTPException`
- Proteger endpoints:
  ```python
  _: User = Depends(get_current_user)       # cualquier usuario autenticado
  _: User = Depends(require_role("admin"))  # solo admin
  ```
- Nuevos features: `backend/features/<nombre>/` con `model.py`, `schemas.py`, `service.py`, `router.py`
- Registrar router en `registry.py` + importar model en `bootstrap.py`

---

## 5. Convención de nombrado

| Tipo | Convención | Ejemplo |
|---|---|---|
| Hook | `use[Feature][Descripción].jsx` | `useAuthSession.jsx`, `useProductForm.jsx` |
| Context | `[Feature]Context.jsx` | `AuthSessionContext.jsx` |
| Service | `[feature]Service.js` | `authService.js`, `productsService.js` |
| Model | `[feature]Model.js` | `productsModel.js` |
| Componente | `PascalCase.jsx` | `LoginPage.jsx`, `ProductCard.jsx` |
| Config/Strategy | `[feature]Config.js` | `statusConfig.js`, `priceConfig.js` |
| Utilidades | `[descripción].js` | `cx.js`, `api.js` |
| Error Boundary | `[Scope]ErrorBoundary.jsx` | `RouteErrorBoundary.jsx` |
| Migración Alembic | auto (timestamp + descripción) | `2026_07_01_add_stock_to_products.py` |
| Test | `test_[module].py` / `[module].test.js` | `test_products_service.py` |

---

## 6. Manejo de errores

```javascript
// service.js — lanza el error
const getProducts = async () => {
  const res = await fetch(...)
  if (!res.ok) throw new Error('Error al obtener productos')
  return res.json()
}

// hook — captura el error
try {
  const data = await getProducts()
  setProducts(data)
} catch (error) {
  setError(error.message)
}
```

**Regla:** `try/catch` SOLO en el hook. El service lanza (`throw`), nunca silencia errores.

---

## 6.1 React Error Boundaries

Una boundary por ruta principal — un error en una sección no tumba la app entera.

```jsx
// core/components/RouteErrorBoundary.jsx
class RouteErrorBoundary extends Component {
  state = { hasError: false, error: null }

  static getDerivedStateFromError(error) {
    return { hasError: true, error }
  }

  componentDidCatch(error, errorInfo) {
    console.error('RouteErrorBoundary caught:', error, errorInfo)
    // En producción: Sentry.captureException(error, { extra: errorInfo })
  }

  handleReset = () => this.setState({ hasError: false, error: null })

  render() {
    return this.state.hasError ? (
      <div className="flex flex-col items-center justify-center min-h-[60vh] gap-4">
        <h2 className="text-xl font-semibold text-red-600">Algo salió mal</h2>
        <button onClick={this.handleReset} className="px-4 py-2 bg-blue-600 text-white rounded-lg">
          Reintentar
        </button>
      </div>
    ) : this.props.children
  }
}
```

---

## 7. Principios aplicados — Shvets + SOLID

### Guard Clauses
```javascript
const bootstrapping   = ({ isSessionBootstrapped }) => !isSessionBootstrapped && <Splash />
const unauthenticated = ({ token }) => !token && <Navigate to="/login" replace />
const ProtectedRoute  = () => bootstrapping(session) || unauthenticated(session) || <Outlet />
```

### Strategy Pattern
```javascript
// Agregar estado nuevo = solo una línea en el objeto. Cero cambios en lógica.
export const STATUS_CONFIG = {
  pending:    { label: 'Pendiente',  next: 'processing', color: 'amber' },
  processing: { label: 'En proceso', next: 'shipped',    color: 'sky' },
  shipped:    { label: 'Enviado',    next: 'delivered',  color: 'violet' },
  delivered:  { label: 'Entregado',  next: null,         color: 'emerald' },
}
export const getStatusConfig = (status) => STATUS_CONFIG[status] ?? STATUS_CONFIG.pending
```

### Extract Function
Si necesitas un comentario para explicar un bloque, ese bloque debe ser una función con nombre.

---

## 8. Lo que nunca hacemos

| Práctica prohibida | Por qué |
|---|---|
| `function foo() {}` en el frontend | Usar siempre arrow functions |
| `fetch` directo en un componente JSX | Viola SRP |
| `if/else` anidados en JSX | Guard Clauses o Extract Function |
| `switch` repetido en varios sitios | Strategy (objeto de configuración) |
| Variables sin nombre descriptivo (`fn`, `data`, `res`) | Viola "nombres que revelan intención" |
| Lógica de negocio en un componente de UI | Muévela al hook o al service |
| Un módulo de feature importando de otro feature | Solo se importa de `core/` |
| `try/catch` en el service | El service lanza, el hook captura |
| `if/else` en handlers de componentes | Extraer a funciones nombradas |
| Lógica anónima dentro de un handler | Si necesita explicación, necesita un nombre |
| Credenciales o URLs hardcodeadas | Siempre en variables de entorno |
| `create_all()` en producción | Usar Alembic migrations |
| Estado derivado en `useState` + `useEffect` | Calcular en render |

---

## 8.1 API Design Conventions

### URLs REST semánticas
```
GET    /products              ← listar (con paginación)
GET    /products/{id}         ← obtener uno
POST   /products              ← crear
PATCH  /products/{id}         ← actualizar parcial
DELETE /products/{id}         ← eliminar
GET    /products/{id}/reviews ← sub-recurso
```

**Regla de orden:** rutas con segmento literal (`/search`, `/me`) SIEMPRE antes que parámetros dinámicos (`/{id}`).

### Paginación estándar (obligatoria desde el principio)
```python
class PaginatedResponse(BaseModel, Generic[T]):
    items: list[T]
    total: int
    page: int
    size: int
    pages: int
```

### Formato de error estándar
```json
{ "detail": "Producto no encontrado", "code": "NOT_FOUND", "fields": null }
```

---

## 8.2 Dependency Management

Antes de instalar cualquier dependencia:

| Pregunta | Criterio mínimo |
|---|---|
| ¿Tiene mantenimiento activo? | Commits en últimos 6 meses |
| ¿Tamaño razonable? | No añade >50KB gzip para una sola función |
| ¿Puedo hacerlo en <50 líneas? | Si sí → hacerlo a mano |
| ¿Licencia compatible? | MIT, Apache 2.0, BSD |

```bash
# Auditoría mensual obligatoria
pip-audit        # backend
npm audit        # frontend
```

---

## 9. Database Migrations — Alembic como fuente de verdad

> ⚠️ **No aplica aquí** — no hay Alembic ni SQLAlchemy. Ver "Migrations" en la
> sección 1: el equivalente real en este proyecto es un archivo nuevo en
> `supabase/migrations/`, revisado a mano, nunca editado una vez aplicado.

**Flujo obligatorio para todo cambio de schema:**
```bash
# 1. Modifica el modelo Python
# 2. Genera la migración
alembic revision --autogenerate -m "add stock_quantity to products"
# 3. REVISA el archivo generado
# 4. Aplica
alembic upgrade head
# 5. Test
pytest backend/tests/
# 6. Commit todo junto: modelo + migración + test
```

**Reglas inmutables:**
- Toda migración tiene `upgrade()` Y `downgrade()`
- Columnas nuevas con `nullable=True` o `server_default`
- Nunca editar una migración ya aplicada
- `autogenerate` es un borrador — siempre revisar antes de aplicar

---

## 10. Testing strategy

### Backend (pytest)
- **Unit**: funciones puras, validators, helpers
- **Integration**: endpoint HTTP real con SQLite in-memory
- **Estructura AAA**: Arrange → Act → Assert

```python
def test_create_product_requires_admin(async_client, db):
    # ARRANGE
    operario = UserFactory.create(role="operario")
    token = create_access_token(operario.id)
    # ACT
    response = await async_client.post("/products", json={...}, headers={"Authorization": f"Bearer {token}"})
    # ASSERT
    assert response.status_code == 403
```

### Frontend (Vitest + React Testing Library)
**Regla de oro:** testea el hook, nunca el componente directamente.
El componente solo pinta; el hook orquesta la lógica.

```javascript
describe('useProductsPage', () => {
  it('fetches products on mount', async () => {
    const { result } = renderHook(() => useProductsPage())
    await waitFor(() => expect(result.current.products).toHaveLength(3))
  })
})
```

---

## 11. Caching Strategy

| Dato | Estrategia | TTL |
|---|---|---|
| Métricas de dashboard | Cache en memoria con TTL | 30-60 seg |
| Catálogo / config estática | Cache largo | 15 min |
| Lista de pedidos del usuario | Sin caché (fetch fresco) | 0 |
| Precio de productos | Cache corto | 10-15 seg |
| Perfil del usuario | Cache hasta logout | — |

---

## 12. Hoja de ruta — Fases

> **Este archivo es un template genérico y NO declara fases.**
>
> Una hoja de ruta es siempre específica de un proyecto. Cada proyecto define
> las suyas en su propio `doc/fases.md`, que es la única fuente de verdad.
>
> **Regla para Claude:** si trabajas en un proyecto y no encuentras su
> `doc/fases.md`, pregunta cuáles son las fases. Nunca las asumas ni las
> heredes de otro proyecto.

**Por qué esta sección está vacía a propósito:** antes contenía la hoja de ruta
de un e-commerce (productos, carrito, Stripe) que no pertenecía a ningún
proyecto real. Al cargarse en cada sesión, hacía que Claude arrancara asumiendo
que se estaba construyendo una tienda online — en `tools equip`, en `Weldix` y
en cualquier otro proyecto bajo esta carpeta. Documentación que miente es una
fuente de bugs cuando hay un agente leyéndola.

---

## 13. Seguridad — OWASP Top 10

| Vulnerabilidad | Mitigación |
|---|---|
| SQL Injection | SQLAlchemy — queries parametrizadas siempre |
| Auth deficiente | JWT + bcrypt, rate limiting en login (5 intentos → bloqueo 10 min) |
| XSS | React escapa HTML por defecto — nunca `dangerouslySetInnerHTML` |
| CORS incorrecto | Limitar a dominio real, nunca `*` en producción |
| Config insegura | `/docs` deshabilitado en producción, secrets en `.env` |
| Acceso desautorizado | `require_role("admin")` en todos los endpoints protegidos |

---

## 14. Performance Budgets

| Métrica | Budget |
|---|---|
| Bundle JS inicial (gzip) | < 150 KB |
| Bundle JS total (gzip) | < 400 KB |
| Time to Interactive (TTI) | < 3s |
| API p95 | < 200ms |
| Queries SQL por endpoint | ≤ 5 |

```javascript
// Lazy loading obligatorio para rutas pesadas
const AdminPanel   = lazy(() => import('@/modules/admin/components/AdminPanel'))
const ProductsPage = lazy(() => import('@/modules/products/components/ProductsPage'))
```

---

## 15. Recursos y herramientas

| Recurso | Uso |
|---|---|
| **Boxicons** (`npm install boxicons`) | Iconos: `<i className="bx bx-package" />` |
| **Fontsource** | Fuentes self-hosted, GDPR compliant |
| **Unlighthouse** (`npx unlighthouse --site <URL>`) | Auditoría Lighthouse de todo el sitio |

---

## 16. Matriz de decisiones rápidas

| Pregunta | Acción |
|---|---|
| ¿Escribo código nuevo? | Test unitario + integración antes de commit |
| ¿Cambio un archivo existente? | Actualiza `doc/` |
| ¿>100 líneas en el diff? | Divide en múltiples commits |
| ¿Cambio de schema en BD? | Alembic migration + test de migración + rollback |
| ¿Feature nueva arriesgada? | Feature flag desactivado por defecto |
| ¿Instalar dependencia? | Pasar checklist de dependencias (sección 8.2) |
| ¿Algo se rompió? | Registra en `ERRORES_APRENDIDOS.md` |

---

**Versión:** 1.0 — Template genérico  
**Mantenedor:** Fernando + Claude
