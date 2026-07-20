# Normas inamovibles de codigo (Entrenamientos)

Este documento define el estandar no negociable de escritura de codigo.

## 1. Diseno y legibilidad

- Un modulo, una responsabilidad.
- Una funcion, una intencion clara.
- Nombres semanticos y consistentes con el dominio.
- Reducir complejidad accidental en cada cambio.
- Preferir codigo explicativo antes que comentarios largos.

## 2. Patrones obligatorios

- `Guard clauses` en lugar de anidacion innecesaria.
- `Extract function` cuando una funcion mezcla responsabilidades.
- `Strategy` cuando hay variaciones por estado/regla.
- `SOLID` aplicado de forma pragmatica, no dogmatica.

## 3. Arquitectura obligatoria

- Organizacion por feature, no por tipo tecnico.
- Dependencias permitidas: `feature -> core`.
- Dependencias prohibidas: `feature -> otra feature`.
- Frontend por capas:
  - `Componente -> Hook -> Service -> Model -> core/lib/api`

## 4. Convenciones de implementacion

- Componentes JSX no hacen `fetch`.
- Services no importan React.
- Hooks no hablan directamente con `fetch` fuera de la capa service.
- Modelos no contienen estado de UI.
- Errores se manejan en capa de orquestacion (hook/service segun aplique).

## 5. Flujo de cambio

- Cambios atomicos y funcionales.
- Siempre dejar el sistema arrancable.
- Commit semantico y descriptivo.
- No avanzar a otra tarea sin cerrar la actual.
- Cualquier decision tecnica relevante debe quedar documentada.

## 6. Testing obligatorio

- Unit test minimo para nueva logica.
- Integration test si hay endpoint o flujo cross-layer.
- Casos felices y de error cubiertos.
- Cambios de schema:
  - migracion versionada
  - test de migracion up/down

## 7. Seguridad no negociable

- Nunca secretos en codigo.
- Validacion estricta de entrada.
- Autenticacion y autorizacion en endpoints sensibles.
- CORS y configuracion de entorno correctos por ambiente.
- Nunca loguear password, tokens o secretos.

## 8. Regla documental

Si tocas un modulo, actualizas su documento de `doc/modulos/` y el documento transversal que corresponda (`arquitectura`, `testing`, `deuda-tecnica`, etc.).

## 9. Definicion de hecho (DoD)

Un cambio se considera terminado solo si:

1. Cumple arquitectura y convenciones.
2. Tiene tests relevantes y pasan.
3. Incluye documentacion minima necesaria.
4. Se puede explicar claramente sin abrir el diff completo.

