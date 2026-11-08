# AGENT.MD — Contexto del agente (OpenCode / Claude Code / equivalente)

Proyecto: **Prueba Técnica — Desarrollador(a) Oracle PL/SQL · Core Bancario (Credicorp Bank)**
Solución: **CoreCatalog & Settlement — Catálogos parametrizables y liquidación de transacciones**
Versión del examen: 4 · Octubre de 2026 · Duración: 2 h 30 min (sin contar preparación del entorno).

Este archivo es el contexto que se entrega al agente de IA. Las especificaciones detalladas por
sección están en `specs/`. Las decisiones y la bitácora de IA van en `memory.md` y `AI-LOG.md`.

---

## 1. Reglas inquebrantables (el agente NUNCA debe violarlas)

1. **No modificar las tablas del core** (`CORE_CUSTOMER`, `CORE_ACCOUNT`, `OLB_USER`,
   `CORE_TRX`, `TTEM_ITEM_STG`) ni sus scripts de `setup/`. Son el contrato de un sistema
   externo. Solo se permiten índices o vistas adicionales, justificados.
2. **Prohibido `EXCEPTION WHEN OTHERS THEN NULL`** (ni capturar y no relanzar, ni ocultar el
   SQLCODE). Un `WHEN OTHERS` solo es aceptable si registra el error o hace `ROLLBACK TO`
   savepoint y **siempre relanza** la excepción original.
3. **SQL dinámico exclusivamente con bind variables** (`USING`). Nunca concatenar texto.
4. **Prohibido incluir contraseñas o datos de conexión reales** en scripts o commits. Usar
   `&param` / `connection.env` (excluido vía `.gitignore`) + `connection.env.example`.
5. **JSON solo con funciones nativas** (`JSON_OBJECT`, `JSON_ARRAYAGG`, …). Prohibido
   concatenar strings para armar JSON.
6. **Constraints, índices, secuencias y triggers con nombres según el estándar del Anexo C**
   (ver tabla en §4) y todo proyecto debe compilar: nunca dejar a medio escribir.
7. **Montos**: mayor que cero y máximo 2 decimales. **Idempotencia** en transferencias vía
   `REFERENCE` única.
8. **IA como borrador, no como veredicto**: revisar todo código generado, corregir patrones
   típicos de IA (excepciones silenciadas, falta de ROLLBACK, `WHEN OTHERS THEN NULL`,
   SQL dinámico concatenado) y registrar correcciones en `AI-LOG.md`.

## 2. Prioridades y estrategia de ejecución

Orden de prioridades: **P0 → P1 → P2**. No iniciar P1 hasta que todo P0 compile y se ejecute.

| Ref. | Requisito | Prioridad | Tiempo ref. |
|------|-----------|-----------|-------------|
| A.1  | Tablas TTEM_* + datos iniciales + primer commit | P0 | 15 min |
| A.2  | Package spec+body con CRUD y Object Types (compila antes del min. 25) | P0 | 25 min |
| A.3  | Validaciones + excepciones propias con rango −20000…−20999 | P0 | 15 min |
| A.4  | Consulta JSON por ItemId | P0 | 15 min |
| B    | Consulta de cliente por número de cuenta | P0 | 15 min |
| C    | Transferencia débito/acreditación con manejo de fallas | P1 | 30 min |
| D    | Propuesta de mejora (sin código, máx. 20 líneas) | P1 | 10 min |
| A.5  | Carga masiva BULK COLLECT / FORALL … SAVE EXCEPTIONS | P2 | 15 min |

**Regla del walking skeleton (obligatoria):** antes del **minuto 25** debe existir un commit
donde las tablas TTEM_* estén creadas y un package (spec + body) compile sin errores aunque
esté incompleto. Luego se enriquece con commits progresivos y mensajes descriptivos.
Reservar los últimos **25 minutos** para documentación (README, AI-LOG, STATUS).

## 3. Entorno

- Motor **fijo**: Oracle Database 23ai Free (`gvenzl/oracle-free:23.9`, PDB `FREEPDB1`) o
  XE 21c (`gvenzl/oracle-xe:21.3.0`, PDB `XEPDB1`). Declarar versión en README. Si se usa
  algo exclusivo de 23ai (p. ej. `BOOLEAN` en SQL), indicarlo.
- Esquema de desarrollo: **CORE_DEV**. Conexión local: `localhost:1521/FREEPDB1`.
- Contenedor: `docker run -d --name oracle-core -p 1521:1521 -e ORACLE_PASSWORD=<clave> gvenzl/oracle-free:23.9`
- Orden de setup: `setup/00_setup_usuario.sql` (como SYSTEM) → `setup/01_core_ddl.sql` →
  `setup/02_core_datos.sql` (como CORE_DEV). Verificación esperada: CORE_CUSTOMER 6,
  CORE_ACCOUNT 9, OLB_USER 4, CORE_TRX 11, TTEM_ITEM_STG 12.
- Los datos del core contienen **inconsistencias intencionales** (espacios sobrantes,
  mayúsculas irregulares, opcionales vacíos, cuentas bloqueadas, staging inválido). Detectar,
  tratar con criterio y documentar supuestos en `AI-LOG.md`.

## 4. Estándar de nomenclatura (Anexo C — obligatorio)

Minúsculas en el código; máximo 128 caracteres.

| Objeto | Patrón | Ejemplo |
|--------|--------|---------|
| Tabla de catálogos | `TTEM_<NOMBRE>` | `ttem_item` |
| PK | `PK_<TABLA>` | `pk_ttem_item` |
| FK | `FK_<TABLA>_<TABLA_REF>[_<ROL>]` | `fk_ttem_item_ttem_catalog` |
| UK | `UK_<TABLA>_<COLUMNAS>` | `uk_ttem_item_catalog_code` |
| CHECK | `CK_<TABLA>_<COLUMNA>` | `ck_ttem_item_status` |
| Índice | `IX_<TABLA>_<COLUMNAS>` | `ix_ttem_item_catalog_id` |
| Secuencia | `SEQ_<TABLA>` | `seq_ttem_item` |
| Trigger | `TRG_<TABLA>_<EVENTO>` | `trg_ttem_item_aud` |
| Object Type / colección | `TYP_<NOMBRE>` / `TYP_<NOMBRE>_TAB` | `typ_ttem_item_tab` |
| Package | `PKG_<DOMINIO>` | `pkg_ttem_catalog` |
| Procedimiento/función | verbo + sustantivo | `insertar_item`, `obtener_item_json` |
| Excepción | `E_<DESCRIPCIÓN>` | `e_item_no_existe` |
| Prefijos | `p_` parámetro · `l_` local · `c_` constante · `g_` global | `p_item_id` |

## 5. Estructura del repositorio

```
oraclecore-<nombre>/
|-- setup/                      scripts del Anexo B, SIN modificaciones
|-- ddl/                        tablas TTEM_*, constraints, Object Types, datos iniciales
|-- plsql/                      packages (spec + body) y procedimientos
|-- scripts/                    consulta Sección B y casos de prueba Sección C
|-- specs/                      especificaciones funcionales (fuente de verdad para el agente)
|-- README.md                   cómo ejecutar y probar; respuesta Sección D (≤20 líneas)
|-- AI-LOG.md                   bitácora obligatoria de uso de IA
|-- STATUS.md                   requisito → Hecho / Parcial / No hecho (+ qué falta y cómo resolverlo)
|-- agent.md                    este archivo (contexto del agente)
|-- memory.md                   memoria de decisiones y estado
`-- connection.env.example      variables de conexión, sin contraseñas reales
```

## 6. Datos de prueba clave (Anexo B)

- **Sección B:** `1910001000011` · `1910002000017` · `1910003000013` · `1910004000019` ·
  `9999999999999` (inexistente).
- **Sección C:** transferencias `REF-T001` (éxito + duplicado idempotente), saldo insuficiente
  (`1910002000017` → `1910001000011` por 5000), moneda distinta (→ `1910001000029` USD),
  destino bloqueado (`1910004000019`), falla simulada `REF-T002`.
- **Sección A.5:** lote `LOTE-2026-10` en `ttem_item_stg` → resultado control: **5 cargados,
  7 rechazados**.

## 7. Declaración de alcance

No se penaliza el alcance incompleto; **sí el incompleto no declarado**. Mantener `STATUS.md`
fiel al contenido real del repositorio. Para cada ítem parcial/no hecho: una línea con lo que
falta y cómo lo resolvería.

## 8. Flujo de trabajo por commit (guía para el agente)

1. `Inicio del examen` → marca el t=0 (kicker del cronómetro).
2. Commit A.1: `ddl/` con tablas TTEM_* + datos iniciales.
3. Commit “walking skeleton” (≤ min. 25): spec + body compilables.
4. Commits incrementales A.3 → A.4 → B, cada uno compilando y ejecutándose.
5. Commits P1 (C, D) y, si sobra tiempo, P2 (A.5).
6. Commit final de documentación.

## 9. Referencias

- Especificaciones: `specs/00-overview.md`, `specs/01-seccion-a-catalogos.md`,
  `specs/02-seccion-b-consulta-cliente.md`, `specs/03-seccion-c-liquidacion.md`,
  `specs/04-seccion-d-criterio.md`.
- Memoria de decisiones: `memory.md`. Bitácora de IA: `AI-LOG.md`.
- Fuente: *Prueba_Tecnica_Oracle_Core_Bancario_v4.pdf* (Anexos A, B y C incluidos en `setup/`).
