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
| C Transferencia con falla simulada | Hecho | `pkg_core_settlement` spec+body VALID; 6 casos del enunciado en verde (duplicada → −20015, saldo → −20014, moneda → −20013, bloqueada → −20012, falla sim. → −20099 con saldos y CORE_TRX intactos) + extras; bonus `revertir` con idempotencia (−20018) |
| D Propuesta de mejora | Hecho | Respuesta en README §7 dentro de ≤ 20 líneas, sin código: flujo solicitud → aprobación (maker–checker) → carga via staging con `pkg_ttem_load` → reversión con `ttem_audit_log`; riesgos y metricas definidas |
| A.5 Carga masiva (P2) | Hecho | `pkg_ttem_load` con BULK COLLECT LIMIT 100 + FORALL SAVE EXCEPTIONS; lote LOTE-2026-10 termina con **5 cargados / 7 rechazados** (criterio de control exacto); log en `ttem_load_error`, staging S/E; segunda corrida → ORA-20020 |

## 3. Evidencia de verificación (Oracle XE 21c, esquema donde se probó)

- Verificado en **dos esquemas**: `CORE_DEV` (esquema de desarrollo del Anexo B, secuencia
  completa del README: setup 01/02 + ddl + packages + los 4 scripts de pruebas en verde)
  y, de forma previa, en un esquema espejo de prueba con el mismo resultado.
- `user_errors` vacío; los 27 objetos propios en estado VALID (tablas TTEM catálogo + bitácora
  + errores, 4 secuencias, 3 triggers, 2 tipos, 3 packages spec+body, índices propios).
- Cargas: `03_ttem_datos.sql` → TTEM_CATALOG 2, TTEM_ITEM 3, TTEM_AUDIT_LOG 3;
  `pruebas_seccion_a5.sql` → TTEM_ITEM 8, staging S=5 E=7, TTEM_LOAD_ERROR=7.
- Casos A: insertar EUR (código y nombre con espacios → normalizados), duplicado
  ORA-20003, JSON USD exacto, JSON inexistente ORA-20001, eliminar lógico → estado 'I',
  collection `consultar_items` con 3 ítems ordenados.
- Sección B: 4 cuentas con datos coincidentes al enunciado + cuenta inexistente (0 filas).
- Sección C: 6 casos del enunciado + 6 validaciones extra + reversa y su idempotencia (ver AI-LOG §1ter).
- A.5: los 7 motivos de rechazo coinciden uno a uno con los datos inconsistentes del
  lote (duplicado en lote, catálogo inexistente, código/nombre vacíos, fecha inválida
  `2026-13-01`, vigencia incoherente, PEN duplicado).

## 4. Próximos pasos

1. Opcional: primera corrida end-to-end limpia (todo el setup y todas las pruebas) en una
   instancia XE/23ai nueva, siguiendo el README, para comprobar la experiencia de
   "clonar, compilar y probar en menos de 5 minutos".
