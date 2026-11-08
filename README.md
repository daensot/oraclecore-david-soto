# README — oraclecore-david-soto

Prueba Técnica: Desarrollo Oracle PL/SQL para el Core Bancario · Credicorp Bank (v4, oct. 2026)
Proyecto: **CoreCatalog & Settlement** — catálogos parametrizables (Sección A) y consulta de cliente
por cuenta (Sección B), bloque **P0** completo y verificado.

## 1. Herramientas

- Motor: **Oracle Database XE 21c** (`gvenzl/oracle-xe:21.3.0`, contenedor Docker local, PDB `XEPDB1`).
- Cliente SQL: **SQL*Plus** (incluido en el contenedor). Compatible con SQLcl / SQL Developer / DBeaver.
- Sin funcionalidades exclusivas de 23ai (el trabajo es portátil a 21c y 23ai Free).

## 2. Estructura

```
setup/    scripts del Anexo B, SIN modificaciones
ddl/      01 tipos (Object Types) · 02 tablas TTEM_* + auditoría · 03 datos iniciales
plsql/    pkg_ttem_catalog.pks (spec) · pkg_ttem_catalog.pkb (body)
scripts/  seccion_b_consulta_cliente.sql (Sección B) · pruebas_seccion_a.sql (casos A)
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
SQL> @plsql/pkg_ttem_catalog.pks   -- spec del package
SQL> @plsql/pkg_ttem_catalog.pkb   -- body del package

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

## 5. Tabla de códigos de error propios (Sección A.3)

Rango adoptado: **−20000 … −20029** (negocio). Dominios: −20001…−20005 catálogos (Sección A);
−20010…−20029 reservado para la Sección C (transacciones).

| Código | Excepción | Significado |
|--------|------------|-------------|
| -20001 | `E_ITEM_NO_EXISTE` | ItemId consultado no existe |
| -20002 | `E_CATALOGO_NO_EXISTE` | Catálogo no existe |
| -20003 | `E_DUPLICADO` | Ítem o catálogo cuyo código ya existe (UNIQUE) |
| -20004 | `E_VIGENCIA_INVALIDA` | `valid_to < valid_from` |
| -20005 | `E_DATO_OBLIGATORIO` | Campo obligatorio vacío / estado inválido |

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

⬜ Por escribir (P1). Estructura comprometida en `specs/04-seccion-d-criterio.md`.

## 8. Documentos complementarios

- `STATUS.md` — avance por requisito con evidencia de verificación.
- `AI-LOG.md` — bitácora obligatoria de IA (prompts, decisiones, casos corregidos).
- `agent.md` / `memory.md` / `specs/` — contexto del agente, decisiones y specs.
