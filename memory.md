# MEMORY.MD — Memoria del proyecto

Registro vivo de decisiones técnicas, supuestos y estado. Se actualiza a medida que avanza el
examen. Complementa `agent.md` (contexto del agente) y `AI-LOG.md` (bitácora de uso de IA).

---

## 1. Estado del entorno

| Ítem | Valor |
|------|-------|
| Motor | Oracle Database 23ai Free (`gvenzl/oracle-free:23.9`, contenedor `oracle-core`) |
| PDB | `FREEPDB1` (equivalente XE: `XEPDB1`) |
| Esquema | `CORE_DEV` |
| Conexión | `localhost:1521/FREEPDB1` |
| Verificación de carga | CORE_CUSTOMER 6 · CORE_ACCOUNT 9 · OLB_USER 4 · CORE_TRX 11 · TTEM_ITEM_STG 12 |
| Repositorio | `oraclecore-david-soto` (GitHub, público) |

## 2. Decisiones técnicas (se completan con la justificación)

| # | Decisión | Estado | Justificación |
|---|----------|--------|---------------|
| D1 | Rango de errores propios: **−20001…−20005** para catálogos (Sección A) y **−20010…−20029** reservado para la Sección C | Implementado en `pkg_ttem_catalog` | Necesito diferenciar error de negocio de error técnico en code review del core |
| D2 | Eliminación de ítems de catálogo: **lógica** (`status = 'I'`, idempotente) | Implementada y probada | Preserva trazabilidad y es requerimiento de auditoría bancaria; el borrado físico rompe la bitácora |
| D3 | Control de transacción Sección C: **lo controla el procedimiento** con `SAVEPOINT` + `ROLLBACK TO savepoint` ante falla parcial y COMMIT al final | Por implementar (P1) | El invocador no debería preocuparse por consistencia de una partida doble; el savepoint permite simular la falla |
| D4 | Modelo de catálogos: `ttem_catalog` + `ttem_item` + bitácora `ttem_audit_log` (I/U/D con old/new en JSON, trigger `trg_ttem_item_log`) | Implementada | La bitácora suma puntaje y es obligatoria en contexto bancario (trazabilidad de cambios) |
| D5 | JSON construido con `JSON_OBJECT(... NULL ON NULL RETURNING CLOB)` | Implementada y probada (salida exacta con USD item 2) | Contrato exige atributos siempre presentes, incluso null; `JSON_OBJECT` es el modo nativo |
| D6 | Consulta Sección B con `LISTAGG` para usuarios OLB, `CASE` para tipo de persona y `TRIM+REGEXP_REPLACE` para nombre normalizado | Implementada y probada con las 5 cuentas | Consolidación en una sola columna exigida por el enunciado |
| D7 | El CRUD de catálogos controla su transacción dentro del package (SAVEPOINT + COMMIT + ROLLBACK/relanzar) | Implementada | Autonomía de la API del core; misma convención que se usará en la Sección C |

## 3. Tabla de códigos de error propios (duplicar en README)

| Código | Excepción (`E_*`) | Significado |
|--------|--------------------|-------------|
| -20001 | `E_ITEM_NO_EXISTE` | ItemId consultado no existe |
| -20002 | `E_CATALOGO_NO_EXISTE` | Catálogo no existe (o no está activo cuando se requiere) |
| -20003 | `E_DUPLICADO` | Código de ítem ya existe en el catálogo (o catálogo duplicado) |
| -20004 | `E_VIGENCIA_INVALIDA` | `valid_to < valid_from` |
| -20005 | `E_DATO_OBLIGATORIO` | Campo obligatorio vacío o estado distinto de A/I |
| -20010 | `E_TRX_MONTO_INVALIDO` | Monto ≤ 0 o más de 2 decimales (Sección C) |
| -20011 | `E_TRX_CUENTA_NO_EXISTE` | Cuenta origen/destino inexistente |
| -20012 | `E_TRX_CUENTA_NO_ACTIVA` | Cuenta en estado distinto de 'A' |
| -20013 | `E_TRX_MONEDA_MISMATCH` | Moneda no coincide con la de las cuentas |
| -20014 | `E_TRX_SALDO_INSUFICIENTE` | Saldo insuficiente en origen |
| -20015 | `E_TRX_REFERENCIA_DUPLICADA` | Referencia ya registrada (idempotencia) |
| -20016 | `E_TRX_CUENTAS_IGUALES` | Origen = destino |

*(Rango −20010…−20029 reservado para la Sección C: se implementa al desarrollarla y se
mantiene en sincronía con el README.)*

## 4. Supuestos documentados sobre datos inconsistentes

- Nombres de clientes con espacios sobrantes / mayúsculas irregulares se **normalizan al
  consultar** (Sección B): `TRIM` + formato según `person_type` — no se modifican los datos
  del core.
- `CORE_TRX` con `reference = NULL` (trx 11) es válido: la UK de Oracle admite múltiples NULL;
  la unicidad solo aplica a referencias informadas.
- Staging (`ttem_item_stg`): rechazos incluyen catálogo inexistente (`TIPO_SEGURO`), código o
  nombre NULL, fecha inválida (`2026-13-01`), vigencia incoherente, duplicado dentro del lote
  (`COM_TRF_INT` 2 veces) y duplicado con ítem existente (`PEN`).
- Cuentas del banco (`product_type = 'INT'`, cliente 900) participan como destino válido en
  transferencias mientras estén activas.

## 5. Estado de avance (sincronizar con STATUS.md)

| Requisito | Estado | Nota |
|-----------|--------|------|
| Esqueleto funcional (≤ min. 25) | Hecho | Commits `5c2d32a` + `c36e79e`; VALID en 21.3 |
| A.1 Modelo TTEM_* | Hecho | 2/3/3 filas verificadas (catálogo/ítem/bitácora) |
| A.2 Package CRUD + Object Types | Hecho | `pkg_ttem_catalog` VALID; collection y tipo en API |
| A.3 Validaciones + excepciones | Hecho | −20001…−20005 implementados y probados |
| A.4 JSON por ItemId | Hecho | Salida USD exacta al ejemplo del enunciado |
| B Consulta cliente | Hecho | 5 casos verificados; inexistente → 0 filas |
| C Transferencia | Pendiente (P1) | Siguiente bloque |
| D Propuesta de mejora | Pendiente (P1) | Redacción en README |
| A.5 Carga masiva | Pendiente (P2) | Solo si sobra tiempo |

## 6. Correcciones / rechazo de código generado por IA

| # | Qué generó la IA | Qué corregí / por qué |
|---|------------------|------------------------|
| 1 | *(completar — exigencia del examen: al menos 1 caso documentado)* | |

## 7. Registro de prompts representativos → texto exacto, resultado y acción
*(ver detalle en `AI-LOG.md`)*
