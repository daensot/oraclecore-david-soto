# STATUS — Estado de avance del examen

Actualizado tras implementar y **verificar en Oracle Database XE 21c (21.3) el bloque P0
completo**: cero errores en `user_errors` y casos de prueba ejecutados. Estados del examen:
Hecho / Parcial / No hecho.

## 1. Preparación

| Requisito | Estado | Nota |
|-----------|--------|------|
| Scripts Anexo B en `setup/` sin modificar | Hecho | 00 / 01 / 02 (commit inicial del repositorio) |
| Base de datos local | Hecho | Contenedor `oracle-xe-21c` (gvenzl/oracle-xe:21.3.0) en ejecución, PDB `XEPDB1`; carga verificada 6/9/4/11/12 |
| Planificación (`specs/`, `agent.md`, `memory.md`) | Hecho | Fuente de verdad para el agente |
| `.gitignore` + `connection.env.example` | Hecho | Plantilla sin contraseñas reales |
| Commit «Inicio del examen» | n/d | El trabajo continuo de sesión previa partió con el commit inicial del Anexo B; si se reanuda en modalidad timed, marcar t=0 con el próximo commit |

## 2. Requisitos del examen

| Requisito | Estado | Nota |
|-----------|--------|------|
| Esqueleto funcional (≤ min. 25) | Hecho | Commit `5c2d32a` (A.1 DDL + datos) seguido de `c36e79e` (spec+body); todo compila en XE 21c |
| A.1 Modelo TTEM_* + datos iniciales | Hecho | `ttem_catalog` (2 catálogos), `ttem_item` (PEN, USD, COM_MANT), auditoria obligatoria + bitácora `ttem_audit_log` (I/U/D con valores anteriores y nuevos en JSON), secuencias y triggers; carga 2/3/3 verificada |
| A.2 Package CRUD + Object Types | Hecho | `pkg_ttem_catalog` spec+body VALID; operaciones insertar/actualizar/eliminar; `typ_ttem_item` / `typ_ttem_item_tab` usados como retorno (`consultar_items`, `obtener_item`) y como entrada (`insertar_items`); eliminación LÓGICA (status 'I', idempotente) |
| A.3 Validaciones y excepciones propias | Hecho | Existencia catálogo/ítem, duplicados, vigencias, datos obligatorios, estado A/I; códigos −20001…−20005 documentados (README §5); cero `WHEN OTHERS THEN NULL`: los `WHEN OTHERS` hacen ROLLBACK TO savepoint y relanzan |
| A.4 Consulta JSON por ItemId | Hecho | `obtener_item_json` con `JSON_OBJECT ... NULL ON NULL RETURNING CLOB`; salidas probadas: USD (formato exacto del contrato/ejemplo del enunciado) y −20001 para ítem inexistente |
| B Consulta de cliente por cuenta | Hecho | `scripts/seccion_b_consulta_cliente.sql`; LISTAGG con estado, nombre normalizado (TRIM + compresión de espacios), fecha de referencia con tipo; los 5 casos verificados (inexistente → 0 filas) |
| C Transferencia con falla simulada | Hecho | `pkg_core_settlement` spec+body VALID; 6 casos del enunciado en verde (duplicada → −20015, saldo → −20014, moneda → −20013, bloqueada → −20012, falla sim. → −20099 con saldos y CORE_TRX intactos) + extras (monto, referencia, cuentas iguales, inexistente); transacción controlada por el procedimiento (SAVEPOINT/COMMIT/ROLLBACK+RAISE) y bloqueo FOR UPDATE en orden ascendente de account_no. Bonus: `revertir` con idempotencia (−20018) |
| D Propuesta de mejora | No hecho | (P1) Único pendiente; estructura de 5 puntos esbozada en specs/04 |
| A.5 Carga masiva (P2) | No hecho | Solo si sobra tiempo; criterio 5 cargados / 7 rechazados |

## 3. Evidencia de verificación (Oracle XE 21c, esquema donde se probó)

- `user_errors` vacío; los 19 objetos propios en estado VALID (2 tablas catálogo, bitácora,
  3 secuencias, 3 triggers incluido `trg_ttem_item_log`, 2 tipos, package spec+body).
- `03_ttem_datos.sql`: TTEM_CATALOG 2, TTEM_ITEM 3, TTEM_AUDIT_LOG 3.
- Casos A: insertar EUR (código y nombre con espacios → normalizados), duplicado
  ORA-20003, JSON USD exacto, JSON inexistente ORA-20001, eliminar lógico → estado 'I',
  collection `consultar_items` con 3 ítems ordenados.
- Sección B: 4 cuentas con datos coincidentes al enunciado + cuenta inexistente (0 filas).

## 4. Próximos pasos

1. **D (P1)** — redacción final de la propuesta de mejora en README (≤ 20 líneas, sin código).
2. **A.5 (P2)** — carga masiva del lote `LOTE-2026-10` solo si queda tiempo (5 cargados / 7 rechazados).
3. Sincronizar final de README/STATUS/AI-LOG antes del último commit.
