# README — oraclecore-david-soto

Prueba Técnica: Desarrollo Oracle PL/SQL para el Core Bancario · Credicorp Bank (v4, oct. 2026)
Proyecto: **CoreCatalog & Settlement** — catálogos parametrizables y liquidación de transferencias.

## 1. Herramientas

- Motor: **Oracle Database 23ai Free** (`gvenzl/oracle-free:23.9`, PDB `FREEPDB1`) en Docker. *(Objetivo declarado: verificar que el contenedor esté en ejecución antes de iniciar el examen.)*
- Cliente SQL: SQLcl / SQL*Plus incluido en el contenedor. *(Por confirmar en la primera sesión.)*
- Documentación y planificación: Markdown en `specs/`, `agent.md`, `memory.md`.

## 2. Estado actual del repositorio (lectura rápida)

| Área | Estado |
|------|--------|
| `setup/` (Anexo B, sin modificar) | ✅ Comprometido |
| Planificación: `specs/`, `agent.md`, `memory.md` | ✅ Comprometido |
| `ddl/` — tablas TTEM_*, constraints, Object Types, datos iniciales | ⬜ Vacío — pendiente (A.1) |
| `plsql/` — packages spec+body | ⬜ Vacío — pendiente (A.2–A.3–A.4, C) |
| `scripts/` — consulta Sección B y pruebas Sección C | ⬜ Vacío — pendiente (B y C) |
| `.gitignore` + `connection.env.example` | ⬜ Plantilla por completar |

El estado detallado por requisito está en `STATUS.md`.

## 3. Cómo ejecutar (pasos exactos)

```bash
# 1) Levantar el contenedor (primera vez):
docker run -d --name oracle-core -p 1521:1521 \
  -e ORACLE_PASSWORD=<clave_admin> gvenzl/oracle-free:23.9
docker logs -f oracle-core        # esperar "DATABASE IS READY TO USE!"

# 2) Crear el usuario CORE_DEV (contraseña pedida en runtime):
docker cp setup/00_setup_usuario.sql oracle-core:/tmp/
docker exec -it oracle-core sqlplus system@//localhost:1521/FREEPDB1
SQL> @/tmp/00_setup_usuario.sql

# 3) Modelo del core y datos (como CORE_DEV):
sql core_dev@//localhost:1521/FREEPDB1
SQL> @setup/01_core_ddl.sql
SQL> @setup/02_core_datos.sql
```

Verificación de carga esperada (última consulta de 02_core_datos.sql):

| Tabla | Filas |
|-------|-------|
| CORE_CUSTOMER | 6 |
| CORE_ACCOUNT | 9 |
| OLB_USER | 4 |
| CORE_TRX | 11 |
| TTEM_ITEM_STG | 12 |

> Pendiente: pasos 4 y 5 (compilación de objetos propios `ddl/` + `plsql/`). Se agregarán
> aquí con el orden exacto de ejecución cuando existan los scripts.

## 4. Ejemplo de ejecución

⬜ Por agregar (obligatorio al implementar A.4 y C):

```sql
-- (por completar) llamada a pkg_ttem_catalog.obtener_item_json y su salida esperada
-- (por completar) llamada a pkg_core_settlement.transferir y su salida esperada
```

## 5. Tabla de códigos de error propios (Sección A.3)

Rango adoptado: **−20000 … −20029** (errores de negocio; rango ampliable documentado).

| Código | Excepción | Significado |
|--------|------------|-------------|
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

*(Definida en planificación; se ajusta final en el momento de implementar A.3/C.)*

## 6. Comportamiento de la consulta de la Sección B ante cuenta inexistente

⬜ Por confirmar al implementar la Sección B. Plan declarado: la consulta devuelve **cero
filas** (no error), comportamiento que se documentará y demostrará con la cuenta de prueba
`9999999999999`.

## 7. Sección D — Propuesta de mejora (≤ 20 líneas)

⬜ Por escribir. Estructura comprometida (spec en `specs/04-seccion-d-criterio.md`):
automatización prioritaria del alta de ítems de catálogo con flujo de solicitud → aprobación
de segundo responsable → carga controlada con staging → auditoría con `ttem_audit_log` →
reversión; métrica de incidentes de vigencias mal configuradas.

## 8. Documentos complementarios

- `STATUS.md` — avance por requisito (Hecho / Parcial / No hecho + cómo resolver lo pendiente).
- `AI-LOG.md` — bitácora obligatoria de uso de IA (herramientas, prompts, correcciones).
- `agent.md` — contexto entregado al agente de programación.
- `memory.md` — decisiones técnicas y supuestos.
- `specs/` — especificaciones funcionales por sección (fuente de verdad).
