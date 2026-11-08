# SPEC 01 — Sección A: Catálogos parametrizables (TTEM_*)

Fuente: Sección 4 · Sección A del examen. Prioridades: A.1–A.4 **P0**, A.5 **P2**.

## A.1 [P0] Modelo de catálogos — minutos 0–15

### Tablas a crear (DDL en `ddl/`)

**`ttem_catalog`** — catálogos do solo cada elemento: id (PK, de secuencia), código único
(p. ej. `MONEDA`), nombre, descripción, estado.

| Columna | Tipo | Nulo | Notas |
|---------|------|------|-------|
| catalog_id | NUMBER(10) | No | PK, de `seq_ttem_catalog` |
| catalog_code | VARCHAR2(30) | No | **UK** |
| catalog_name | VARCHAR2(100) | No | |
| description | VARCHAR2(200) | Sí | |
| status | CHAR(1) | No | CHECK en ('A','I') |
| created_by / created_at / updated_by / updated_at | VARCHAR2(30)/DATE | Variable | **Auditoría obligatoria** |

**`ttem_item`** — cada elemento dentro de un catálogo, en orden.

| Columna | Tipo | Nulo | Notas |
|---------|------|------|-------|
| item_id | NUMBER(10) | No | PK, de `seq_ttem_item` |
| catalog_id | NUMBER(10) | No | **FK → ttem_catalog** |
| item_code | VARCHAR2(30) | No | **UK (catalog_id, item_code)** — único *dentro* de su catálogo |
| item_name | VARCHAR2(100) | No | obligatorio |
| item_value | VARCHAR2(200) | Sí | texto opcional |
| display_order | NUMBER(5) | Sí | orden de presentación |
| status | CHAR(1) | No | CHECK en ('A','I') |
| valid_from | DATE | Sí | |
| valid_to | DATE | Sí | CHECK: **valid_to ≥ valid_from cuando se informe** |
| created_by / created_at / updated_by / updated_at | — | — | **Auditoría obligatoria** |

**`ttem_audit_log`** *(opcional, suma puntaje)* — bitácora de cambios de ítems:
`log_id`, `item_id`, `action` ('I','U','D'), `old_values`/`new_values`, `changed_by`, `changed_at`.

### Requisitos del modelado

- Constraints **nombrados** según Anexo C: `PK_TTEM_*`, `FK_TTEM_ITEM_TTEM_CATALOG`,
  `UK_TTEM_*_*`, `CK_TTEM_*_*`; índices con `IX_<TABLA>_<COLUMNAS>` (al menos sobre FK).
- Secuencias `seq_ttem_catalog` y `seq_ttem_item` (o `IDENTITY`, declarar en README).
- Trigger opcional de auditoría (`trg_..._aud`) para llenar `updated_at/by` y la bitácora.
- **Datos iniciales obligatorios** (commit propio):
  - catálogo `MONEDA` con ítems `PEN` (sol peruano) y `USD` (dólar estadounidense);
  - catálogo `TIPO_COMISION` con ítem `COM_MANT` (comisión de mantenimiento).
- Este commit **también es el walking skeleton** cuando se acompañe del package A.2 compilable.

## A.2 [P0] Package de mantenimiento — minutos 15–40

Package `pkg_ttem_catalog` (spec + body en `plsql/`) que **compile sin errores** con:

- Operaciones de mantenimiento: `insertar_item`, `actualizar_item`, `eliminar_item`
  (+ `insertar_catalogo`/`actualizar_catalogo` si se considera necesario).
- Al menos un **Object Type** `typ_ttem_item` y su **colección** `typ_ttem_item_tab`
  (creados en `ddl/`), usados **en la API del package**: como parámetro de entrada (p. ej.
  carga en bloque) o como **retorno** de una función de consulta (recomendado).
- **Decisión documentada**: eliminación lógica (`status='I'` + bitácora) o física, con
  justificación en `AI-LOG.md`. Recomendado: lógica, por trazabilidad bancaria.
- Antes del min. 25: spec + body **compilando** con operaciones mínimas; se enriquece después.

## A.3 [P0] Validaciones y excepciones propias — minutos 40–55

- Validar antes de operar: existencia de catálogo, existencia de ítem, duplicados de código
  dentro del catálogo, coherencia de vigencias y campos obligatorios.
- Excepciones declaradas con significado de negocio (`E_*`) y mapeadas con
  `RAISE_APPLICATION_ERROR` en un **rango propio** definido entre −20000 y −20999
  (sugerido: −20000…−20029 negocio). Tabla de códigos duplicada en README (ver `memory.md` §3).
- **Prohibido** `WHEN OTHERS THEN NULL`. Un `WHEN OTHERS` solo si registra el error o hace
  `ROLLBACK TO` savepoint, y **siempre vuelve a lanzar** sin ocultar el original.
- Anticipar ORA-00001 (duplicado) / ORA-02290 (check) con excepciones predificadas y
  traducirlos a códigos propios.

## A.4 [P0] Consulta JSON por ItemId — minutos 55–70

Procedimiento `obtener_item_json` en `pkg_ttem_catalog`:

```sql
PROCEDURE obtener_item_json (p_item_id IN ttem_item.item_id%TYPE,
                             p_json    OUT CLOB);
```

Requisitos:

1. Construcción **exclusivamente con JSON nativo**: `JSON_OBJECT(... RETURNING CLOB)`.
   Prohibido concatenar texto.
2. **Contrato exacto de atributos**: `itemId`, `catalogId`, `catalogCode`, `itemCode`,
   `name`, `value`, `status`, `validFrom`, `validTo` (se pueden agregar otros).
3. Fechas como texto `YYYY-MM-DD` (`TO_CHAR(...,'YYYY-MM-DD')`).
4. **NULL explícito**: atributo presente con `null` de JSON, nunca omitido (usar
   `NULL ON NULL` y `FORMAT JSON`).
5. Si el ItemId no existe → **excepción propia documentada** (ej. −20001). Nunca devolver
   JSON vacío ni CLOB nulo.

Salida esperada (valores según carga inicial):

```json
{"itemId":2,"catalogId":1,"catalogCode":"MONEDA","itemCode":"USD",
 "name":"Dolar estadounidense","value":"USD","status":"A",
 "validFrom":"2026-01-01","validTo":null}
```

## A.5 [P2] Carga masiva desde staging — solo si sobra tiempo

Procesar lote `LOTE-2026-10` de `ttem_item_stg` (12 registros) con:

- **`BULK COLLECT ... LIMIT`** (p. ej. LIMIT 100–200) y
  **`FORALL ... SAVE EXCEPTIONS`**.
- **Normalización previa**: `TRIM` en todos los campos, `UPPER` en códigos; fechas en texto
  `YYYY-MM-DD` → `TO_DATE`.
- Un registro **inválido NO interrumpe el lote**. Motivos de rechazo: catálogo inexistente,
  código o nombre vacíos, fecha inválida, vigencia incoherente, **duplicado** (con ítem
  existente **o** dentro del mismo lote). Los duplicados se rechazan y **no actualizan** el
  ítem existente.
- Registrar cada rechazo en tabla propia **`ttem_load_error`** (`stg_id`, `error_message`/
  motivo, fecha) y marcar en staging: `processed_flag = 'S'` (cargado) o `'E'` (error) +
  `processed_at`.
- **Criterio de control: 5 cargados y 7 rechazados.**
- Bitácora de rechazos esperada (según datos del Anexo B.3): stg 6 (catálogo `TIPO_SEGURO`
  no existe), 7 (item_code NULL), 8 (item_name NULL / valor con coma), 9 (fecha inválida
  `2026-13-01`), 10 (vigencia incoherente), 11 (normaliza OK → cargado), 5 y 12 (duplicados).
  Verificar la lectura real del lote antes de codificar.

## Casos de verificación (A.2–A.5)

| Caso | Resultado esperado |
|------|--------------------|
| `insertar_item` con catálogo inexistente | RAISE −20002 |
| `insertar_item` duplicado en catálogo | RAISE −20003 |
| `insertar_item` con valid_to < valid_from | RAISE −20004 |
| `actualizar_item` inexistente | RAISE −20001 |
| `eliminar_item` lógico → status 'I' + fila en bitácora | OK |
| `obtener_item_json` con ítem existente | JSON del contrato, null explícito |
| `obtener_item_json` con ítem inexistente | RAISE −20001, no devolver null |
| Carga `LOTE-2026-10` | 5 cargados / 7 rechazados, staging marcado |
