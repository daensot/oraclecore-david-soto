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
| D1 | Rango de errores propios: **−20000 … −20029** (reservado a errores de negocio; −20999 queda para técnicos) | Definido | Necesito diferenciar error de negocio de error técnico en code review del core |
| D2 | Eliminación de ítems de catálogo: **lógica** (`status = 'I'`) | Por confirmar en código | Preserva trazabilidad y es requerimiento de auditoría bancaria; el borrado físico rompe la bitácora |
| D3 | Control de transacción Sección C: **lo controla el procedimiento** con `SAVEPOINT` + `ROLLBACK TO savepoint` ante falla parcial y COMMIT al final | Por confirmar en código | El invocador no debería preocuparse por consistencia de una partida doble; el savepoint permite simular la falla |
| D4 | Modelo de catálogos: tabla `ttem_catalog` + `ttem_item` + bitácora `ttem_audit_log` | Por implementar | La bitácora suma puntaje y es obligatoria en contexto bancario (trazabilidad de cambios) |
| D5 | JSON construido con `JSON_OBJECT(... RETURNING CLOB)` y `NULL ON NULL` explícito | Por implementar | Contrato exige atributos siempre presentes, incluso null; `JSON_OBJECT` es el modo nativo |
| D6 | Consulta Sección B con `LISTAGG` para usuarios OLB y `CASE`/`NVL` para nombre normalizado y fecha de referencia | Por implementar | Consolidación en una sola columna exigida por el enunciado |

## 3. Tabla de códigos de error propios (duplicar en README)

| Código | Excepción (`E_*`) | Significado |
|--------|--------------------|-------------|
| -20001 | `E_ITEM_NO_EXISTE` | ItemId consultado no existe |
| -20002 | `E_CATALOGO_NO_EXISTE` | Catálogo no existe |
| -20003 | `E_ITEM_DUPLICADO` | Código de ítem ya existe en el catálogo |
| -20004 | `E_VIGENCIA_INVALIDA` | `valid_to < valid_from` |
| -20005 | `E_DATO_OBLIGATORIO` | Campo obligatorio vacío (p. ej. nombre) |
| -20010 | `E_TRX_MONTO_INVALIDO` | Monto ≤ 0 o más de 2 decimales |
| -20011 | `E_TRX_CUENTA_NO_EXISTE` | Cuenta origen/destino inexistente |
| -20012 | `E_TRX_CUENTA_NO_ACTIVA` | Cuenta en estado distinto de 'A' |
| -20013 | `E_TRX_MONEDA_MISMATCH` | Moneda no coincide con la de las cuentas |
| -20014 | `E_TRX_SALDO_INSUFICIENTE` | Saldo insuficiente en origen |
| -20015 | `E_TRX_REFERENCIA_DUPLICADA` | Referencia ya registrada (idempotencia) |
| -20016 | `E_TRX_CUENTAS_IGUALES` | Origen = destino |
| (ajustar códigos según implementación final — mantener sincronía README) |

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
| Esqueleto funcional (≤ min. 25) | Pendiente | Crear `ddl/` + `plsql/` compilables |
| A.1 Modelo TTEM_* | Pendiente | |
| A.2 Package CRUD + Object Types | Pendiente | |
| A.3 Validaciones + excepciones | Pendiente | |
| A.4 JSON por ItemId | Pendiente | |
| B Consulta cliente | Pendiente | |
| C Transferencia | Pendiente | |
| D Propuesta de mejora | Pendiente | |
| A.5 Carga masiva | Pendiente (P2) | Solo si sobra tiempo |

## 6. Correcciones / rechazo de código generado por IA

| # | Qué generó la IA | Qué corregí / por qué |
|---|------------------|------------------------|
| 1 | *(completar — exigencia del examen: al menos 1 caso documentado)* | |

## 7. Registro de prompts representativos → texto exacto, resultado y acción
*(ver detalle en `AI-LOG.md`)*
