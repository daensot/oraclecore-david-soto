# README — oraclecore-david-soto

Prueba Técnica: Desarrollo Oracle PL/SQL para el Core Bancario · Credicorp Bank (v4, oct. 2026)
Proyecto: **CoreCatalog & Settlement** — catálogos parametrizables y consulta de cliente (bloque
**P0**, verificado) y **liquidación de transferencias entre cuentas (Sección C, verificado)**.

## 1. Herramientas

- Motor: **Oracle Database XE 21c** (`gvenzl/oracle-xe:21.3.0`, contenedor Docker local, PDB `XEPDB1`).
- Cliente SQL: **SQL*Plus** (incluido en el contenedor). Compatible con SQLcl / SQL Developer / DBeaver.
- Sin funcionalidades exclusivas de 23ai (el trabajo es portátil a 21c y 23ai Free).

## 2. Estructura

```
setup/    scripts del Anexo B, SIN modificaciones
ddl/      01 tipos (Object Types) · 02 tablas TTEM_* + auditoría · 03 datos iniciales · 04 ttem_load_error (A.5)
plsql/    pkg_ttem_catalog.pks/.pkb (A) · pkg_core_settlement.pks/.pkb (C) · pkg_ttem_load.pks/.pkb (A.5)
scripts/  seccion_b_consulta_cliente.sql (B) · pruebas_seccion_a.sql · pruebas_seccion_c.sql · pruebas_seccion_a5.sql
specs/    especificaciones funcionales por sección
```

## 3. Cómo ejecutar (pasos exactos, en orden)

```bash
# 0) Contenedor (si no está en ejecución):
docker run -d --name oracle-xe-21c -p 1521:1521 \
  -e ORACLE_PASSWORD=<clave_admin> gvenzl/oracle-xe:21.3.0
docker logs -f oracle-xe-21c   # esperar "DATABASE IS READY TO USE!"

# 1) Usuario CORE_DEV (contraseña pedida en runtime, como SYSTEM al PDB):
docker cp setup/00_setup_usuario.sql oracle-xe-21c:/tmp/
docker exec -it oracle-xe-21c sqlplus system/<clave_admin>@//localhost:1521/XEPDB1
SQL> @/tmp/00_setup_usuario.sql

# 2) Modelo del core del Anexo B (como CORE_DEV):
sql core_dev/<clave>@//localhost:1521/XEPDB1
SQL> @setup/01_core_ddl.sql
SQL> @setup/02_core_datos.sql
```

Verificación esperada de 02_core_datos.sql: CORE_CUSTOMER 6 · CORE_ACCOUNT 9 · OLB_USER 4 ·
CORE_TRX 11 · TTEM_ITEM_STG 12.

```sql
-- 3) Objetos propios (bloque P0, como CORE_DEV, en este orden):
SQL> @ddl/01_ttem_tipos.sql        -- Object Types typ_ttem_item / typ_ttem_item_tab
SQL> @ddl/02_ttem_tablas.sql       -- ttem_catalog, ttem_item, ttem_audit_log, SEQ_*, TRG_*
SQL> @ddl/03_ttem_datos.sql        -- MONEDA(PEN,USD) + TIPO_COMISION(COM_MANT)
SQL> @plsql/pkg_ttem_catalog.pks   -- spec del package de catalogos
SQL> @plsql/pkg_ttem_catalog.pkb   -- body del package de catalogos
SQL> @plsql/pkg_core_settlement.pks -- spec del package de liquidacion (Seccion C)
SQL> @plsql/pkg_core_settlement.pkb -- body del package de liquidacion (Seccion C)
SQL> @ddl/04_ttem_load_error.sql    -- tabla de errores de la carga masiva (A.5, P2)
SQL> @plsql/pkg_ttem_load.pks       -- spec del package de carga masiva (A.5, P2)
SQL> @plsql/pkg_ttem_load.pkb       -- body del package de carga masiva (A.5, P2)

-- 4) Verificación de compilación (esperado: sin filas):
SELECT name, line, text FROM user_errors;
```

## 4. Ejemplos de ejecución (probados en XE 21c)

**A.4 — Consulta JSON por ItemId** (`ddl/03_ttem_datos.sql` carga PEN id=1 y USD id=2):

```sql
DECLARE
  l_json CLOB;
BEGIN
  pkg_ttem_catalog.obtener_item_json(p_item_id => 2, p_json => l_json);
  DBMS_OUTPUT.PUT_LINE(l_json);
END;
/
```
Salida esperada / obtenida:
```json
{"itemId":2,"catalogId":1,"catalogCode":"MONEDA","itemCode":"USD","name":"Dolar estadounidense","value":"USD","status":"A","validFrom":"2026-01-01","validTo":null}
```

**A.3 — Validaciones**: `pkg_ttem_catalog.insertar_item` con código duplicado levanta
`ORA-20003: Ya existe un item con codigo EUR en el catalogo 1.`; ItemId inexistente en el
JSON → `ORA-20001: El item 999999 no existe.` La eliminación de items es **lógica**
(`status='I'`, idempotente) y la bitácora `ttem_audit_log` registra I/U/D con valores
anteriores/nuevos en JSON.

Ejecución completa de casos: `@scripts/pruebas_seccion_a.sql` (6 casos, errores esperados
incluidos).

**C — Liquidación** (`plsql/pkg_core_settlement.pkb`, probado con
`scripts/pruebas_seccion_c.sql`):

```sql
DECLARE
  l_trx_id core_trx.trx_id%TYPE;
BEGIN
  pkg_core_settlement.transferir('1910001000011', '1910002000017', 100,
                                 'PEN', 'REF-T001', NULL, 'N', l_trx_id);
  DBMS_OUTPUT.PUT_LINE('trx: ' || l_trx_id);   -- exito: saldos 5150.00 / 450.50
END;
/
```

Los 6 casos del enunciado pasan: éxito con partida doble en una única fila `TRF`
(id del `SEQ_CORE_TRX`), duplicado `REF-T001` → ORA-20015 (idempotencia), saldo
insuficiente → ORA-20014, moneda distinta → ORA-20013, destino bloqueada → ORA-20012 y
`p_simular_falla='S'` → ORA-20099 **dejando saldos y `CORE_TRX` intactos** (atomicidad
demostrada). Bonus: `pkg_core_settlement.revertir` genera el movimiento `REV` que invierte
las cuentas y restituye saldos; una segunda reversa se rechaza con ORA-20018.
Decisiones: la transacción la controla el **procedimiento** (`SAVEPOINT sp_transferencia`,
`COMMIT` al final, `ROLLBACK TO` + `RAISE` ante error) y las cuentas se bloquean con
`SELECT ... FOR UPDATE` en orden ascendente de `account_no` para evitar deadlocks.

**A.5 — Carga masiva del lote** (`plsql/pkg_ttem_load.pkb`, probado con
`scripts/pruebas_seccion_a5.sql`):

```sql
DECLARE
  l_cargados   PLS_INTEGER;
  l_rechazados PLS_INTEGER;
BEGIN
  pkg_ttem_load.procesar_lote('LOTE-2026-10', l_cargados, l_rechazados);
  DBMS_OUTPUT.PUT_LINE('cargados ' || l_cargados || ' / rechazados ' || l_rechazados);
END;
/
-- salida: cargados 5 / rechazados 7   (criterio de control del enunciado)
```

`BULK COLLECT ... LIMIT 100` + `FORALL ... SAVE EXCEPTIONS`; un registro inválido no
interrumpe el lote: los 7 rechazos del criterio de control quedan en `ttem_load_error` con
motivo (duplicado en lote, catálogo inexistente, código/nombre vacíos, fecha inválida,
vigencia incoherente, PEN duplicado) y el staging queda `S`/`E` con `processed_at`.
Segunda corrida del mismo lote → `ORA-20020` (sin pendientes, no duplica items).

## 5. Tabla de códigos de error propios (Sección A.3)

Rango adoptado: **−20000 … −20099** (negocio). Dominios: −20001…−20005 catálogos (Sección A);
−20010…−20029 transacciones y carga masiva (Sección C y A.5); −20099 error controlado de
falla simulada.

| Código | Excepción | Significado |
|--------|------------|-------------|
| -20001 | `E_ITEM_NO_EXISTE` | ItemId consultado no existe |
| -20002 | `E_CATALOGO_NO_EXISTE` | Catálogo no existe |
| -20003 | `E_DUPLICADO` | Ítem o catálogo cuyo código ya existe (UNIQUE) |
| -20004 | `E_VIGENCIA_INVALIDA` | `valid_to < valid_from` |
| -20005 | `E_DATO_OBLIGATORIO` | Campo obligatorio vacío / estado inválido |
| -20010 | `E_TRX_MONTO_INVALIDO` | Monto nulo, ≤ 0 o con más de 2 decimales (Sección C) |
| -20011 | `E_TRX_CUENTA_NO_EXISTE` | Cuenta origen/destino inexistente (Sección C) |
| -20012 | `E_TRX_CUENTA_NO_ACTIVA` | Cuenta (origen o destino) en estado distinto de 'A' (Sección C) |
| -20013 | `E_TRX_MONEDA_MISMATCH` | Moneda no coincide con la de ambas cuentas (Sección C) |
| -20014 | `E_TRX_SALDO_INSUFICIENTE` | Saldo insuficiente en origen (Sección C) |
| -20015 | `E_TRX_REFERENCIA_DUPLICADA` | Referencia ya registrada (idempotencia, Sección C) |
| -20016 | `E_TRX_CUENTAS_IGUALES` | Origen = destino (Sección C) |
| -20017 | `E_TRX_DATO_OBLIGATORIO` | Referencia o moneda vacía / modo inválido (Sección C) |
| -20018 | `E_TRX_NO_REVERSIBLE` | Movimiento no revertible o ya revertido (reversa, Sección C) |
| -20099 | `E_TRX_FALLA_SIMULADA` | Error controlado para demostrar atomicidad (`p_simular_falla='S'`) |
| -20019 | `E_STG_FECHA_INVALIDA` | Fecha de staging con formato distinto a YYYY-MM-DD (A.5) |
| -20020 | `E_LOTE_SIN_PENDIENTES` | Lote solicitado sin registros pendientes (flag N) (A.5) |

## 6. Comportamiento de la consulta de la Sección B

Recibe la cuenta por variable de sustitución (`ACCEPT p_cuenta`) y devuelve **una fila** con
datos de cuenta, datos del cliente (tipo persona «Natural»/«Jurídica», documento, nombre
normalizado sin espacios sobrantes), fecha de referencia con su tipo («Nacimiento» /
«Constitución» / «No registrada») y los usuarios de Banca en Línea consolidados con
`LISTAGG` (vacía si no tiene).

**Cuenta inexistente (`9999999999999`):** la consulta devuelve **cero filas** — no genera
error; decisión documentada porque es una consulta de consulta, no una operación.

Casos verificados con los datos del Anexo B: `1910001000011` (natural + nacimiento + 1
usuario), `1910002000017` (sin fecha ni usuarios; nombre normalizado), `1910003000013`
(jurídica + 2 usuarios, uno bloqueado), `1910004000019` (jurídica sin constitución y cuenta
bloqueada), `9999999999999` (0 filas).

## 7. Sección D — Propuesta de mejora (≤ 20 líneas)

Escenario: el alta de ítems de catálogo (comisiones) se pide por correo y la ejecuta a mano
un desarrollador en producción. Hubo incidentes de vigencias mal configuradas y cambios sin
trazabilidad de aprobación.

1. **Automatizar primero y qué resuelve:** el canal de solicitud/ejecución — pasar el
   "correo + script manual" a un flujo de solicitud y carga en la BD con validación
   automática del modelo de la Sección A. Resuelve los dos problemas concretos: vigencias
   incoherentes (se rechazan al instante, como en `ttem_item_stg`) y ausencia de trazabilidad
   de aprobación.
2. **Pasos y componentes:** (1) solicitud en formulario/ticket con los datos del ítem
   (catálogo, código, vigencias) que se validan en vivo contra `ttem_catalog`/`ttem_item`;
   (2) la solicitud queda `PENDIENTE`; (3) **aprobación del segundo responsable** (no puede
   aprobar quien creó la solicitud); (4) carga a staging `ttem_item_stg` y ejecución del
   package de carga (`pkg_ttem_load`): normaliza TRIM/UPPER, valida por registro y genera
   el reporte de rechazos en `ttem_load_error`; (5) notificación del resultado al
   solicitante con el detalle de los rechazos.
3. **Controles:** maker–checker (crear ≠ aprobar), auditoría completa ya disponible en
   `ttem_audit_log` (quién cambió qué, valores anteriores y nuevos en JSON), reversión por
   ítem restituyendo los `old_values` del último evento, y eventuales vigencias siempre
   `valid_to >= valid_from` (constraint ya existente).
4. **Riesgos / dependencias / factibilidad:** requiere mitigar el hábito del "arreglo
   rápido en producción" (gobernanza, no tecnología); dependencia de un canal de ticket
   formal y de designar aprobadores por área; factibilidad alta porque reutiliza el modelo
   y el package ya construidos (esfuerzo estimado: 2-3 semanas del equipo core-PL/SQL).
5. **Medición:** incidentes de vigencias mal configuradas → 0; 100 % de cambios con
   aprobador registrado; tiempo de alta de un ítem (hoy: minutos/horas de un desarrollador
   con riesgo humano, objetivo < 1 hora sin intervención de TI); proporción de solicitudes
   rechazadas por el validador automático (indicador de calidad de captura).

## 8. Documentos complementarios

- `STATUS.md` — avance por requisito con evidencia de verificación.
- `AI-LOG.md` — bitácora obligatoria de IA (prompts, decisiones, casos corregidos).
- `agent.md` / `memory.md` / `specs/` — contexto del agente, decisiones y specs.
