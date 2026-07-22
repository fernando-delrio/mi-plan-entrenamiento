# Normas inamovibles de código (Kinovia)

> Borrador preparado el 2026-07-21, antes de crear el proyecto. Cuando se
> cree el repositorio real de Kinovia, este archivo se mueve a su raíz tal
> cual (o casi — revísalo primero). Basado en `NORMAS_INAMOVIBLES.md` del
> plan de entrenamiento personal, con las reglas propias de un SaaS
> multi-tenant añadidas donde corresponde.

Este documento define el estándar no negociable de escritura de código.

## 1. Diseño y legibilidad

- Un módulo, una responsabilidad.
- Una función, una intención clara.
- Nombres semánticos y consistentes con el dominio (`trainer`, `client`,
  `plan_template`, `client_plan` — no `user1`/`user2` ni nombres genéricos).
- Reducir complejidad accidental en cada cambio.
- Preferir código explicativo antes que comentarios largos.

## 2. Patrones obligatorios

- `Guard clauses` en lugar de anidación innecesaria.
- `Extract function` cuando una función mezcla responsabilidades.
- `Strategy` cuando hay variaciones por estado/regla (p. ej. sustitución de
  ejercicio según condición física del cliente).
- `SOLID` aplicado de forma pragmática, no dogmática.

## 3. Arquitectura obligatoria

- Organización por feature, no por tipo técnico.
- Dependencias permitidas: `feature -> core`.
- Dependencias prohibidas: `feature -> otra feature`.
- Frontend por capas:
  - `Componente -> Hook -> Service -> Model -> core/lib/api`
- El panel del entrenador y la vista del cliente son áreas distintas de la
  app (`modules/trainer`, `modules/client`) — nunca se mezclan en el mismo
  componente aunque compartan datos.

## 4. Convenciones de implementación

- Componentes JSX no hacen `fetch`.
- Services no importan React.
- Hooks no hablan directamente con `fetch` fuera de la capa service.
- Modelos no contienen estado de UI.
- Errores se manejan en capa de orquestación (hook/service según aplique).

## 5. Flujo de cambio

- Cambios atómicos y funcionales.
- Siempre dejar el sistema arrancable.
- Commit semántico y descriptivo.
- No avanzar a otra tarea sin cerrar la actual.
- Cualquier decisión técnica relevante debe quedar documentada.
- **No se construye el editor de plantillas a fondo sin haber validado
  demanda real primero** (ver `doc/escalado-y-entrenadores.md`, sección 8.3
  del proyecto personal — mínimo 15-20 conversaciones con entrenadores
  reales antes de pulir esa pantalla).

## 6. Testing obligatorio

- Unit test mínimo para nueva lógica.
- Integration test si hay endpoint o flujo cross-layer.
- Casos felices y de error cubiertos.
- Cambios de schema:
  - migración SQL versionada en `supabase/migrations/`
  - test de migración up/down
- **Test de aislamiento entre tenants — no negociable, no opcional:** toda
  tabla nueva con RLS necesita al menos un test que confirme que un
  entrenador A no puede leer ni escribir ninguna fila de un entrenador B, y
  que un cliente no puede leer ni escribir datos de otro cliente ni de otro
  entrenador. Sin este test, la tabla no se considera terminada.

## 7. Seguridad no negociable

- Nunca secretos en código (la `service_role key` de Supabase vive solo en
  Edge Functions, nunca en el frontend).
- Ninguna tabla nueva se crea sin RLS activada en el mismo commit.
- Alta de usuarios siempre por invitación (`inviteUserByEmail` desde una
  Edge Function) — **nunca alta pública**, ni para entrenadores ni para
  clientes.
- Validación estricta de entrada.
- Autenticación y autorización en cada operación sensible.
- CORS y configuración de entorno correctos por ambiente.
- Nunca loguear password, tokens o secretos.

## 8. Regla documental

Si tocas un módulo, actualizas su documento de `doc/modulos/` y el documento
transversal que corresponda (`arquitectura`, `testing`, `deuda-tecnica`,
etc.). Si tocas una política RLS, además documentas en el propio archivo de
migración SQL qué aislamiento garantiza esa política y por qué.

## 9. Definición de hecho (DoD)

Un cambio se considera terminado solo si:

1. Cumple arquitectura y convenciones.
2. Tiene tests relevantes y pasan, incluyendo el test de aislamiento entre
   tenants si toca una tabla con RLS.
3. Incluye documentación mínima necesaria.
4. Se puede explicar claramente sin abrir el diff completo.
