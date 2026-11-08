# STATUS — Estado de avance del examen

Última actualización: antes de iniciar el cronómetro de 2 h 30 min (sin commit "Inicio del
examen" todavía). Los estados usan la nomenclatura válida del examen: Hecho / Parcial / No hecho.

## 1. Preparación (fuera del tiempo del examen)

| Requisito | Estado | Nota |
|-----------|--------|------|
| Scripts Anexo B en `setup/` sin modificar | Hecho | 00 / 01 / 02 comprometidos en `198833a` |
| Repositorio GitHub `oraclecore-david-soto` | Hecho | Público, con commit inicial |
| Planificación previa (`specs/`, `agent.md`, `memory.md`) | Hecho | Fuente de verdad para el agente; commit `eb93127` |
| Verificación de base de datos (6/9/4/11/12 filas por tabla) | Parcial | Contenedor `oracle-core` no está en ejecución ahora mismo; re-levantar y verificar antes de t=0 |
| `.gitignore` + `connection.env.example` real | No hecho | La plantilla actual está vacía; crear `.gitignore` (`connection.env`, `*.log`, temporal) antes de t=0 |
| Commit «Inicio del examen» | No hecho | Será el primer commit del cronómetro |

## 2. Requisitos del examen

| Requisito | Estado | Nota |
|-----------|--------|------|
| Esqueleto funcional (≤ min. 25) | No hecho | `ddl/` y `plsql/` vacíos. Como resolvería: commit A.1 (DDL TTEM_* + datos iniciales) y en el mismo minuto un packaging spec+body mínimo compilable (`insertar_item`, `obtener_item`) |
| A.1 Modelo TTEM_* + datos iniciales | No hecho | DDL definido en `specs/01-seccion-a-catalogos.md` (columnas, constraints nombrados, auditoría, catálogos MONEDA y TIPO_COMISION) |
| A.2 Package CRUD + Object Types | No hecho | API definida: `pkg_ttem_catalog` con `typ_ttem_item` / `typ_ttem_item_tab`; decisión de eliminación lógica por documentar en código |
| A.3 Validaciones y excepciones propias | No hecho | Tabla de códigos −20000…−20029 ya propuesta (ver README §5) |
| A.4 Consulta JSON por ItemId | No hecho | Contrato de atributos exacto y formato YYYY-MM-DD definido en la spec A.4 |
| B Consulta de cliente por cuenta | No hecho | Columnas, LISTAGG y comportamiento ante cuenta inexistente (0 filas) definidos; por implementar y probar con las 5 cuentas |
| C Transferencia con falla simulada | No hecho | Firma y 6 casos de prueba con resultados esperados definidos en `specs/03-seccion-c-liquidacion.md` |
| D Propuesta de mejora | No hecho | Estructura de 5 puntos ya esbozada; redactar ≤ 20 líneas en README |
| A.5 Carga masiva (P2) | No hecho | Solo si sobra tiempo; criterio de control: 5 cargados / 7 rechazados |

## 3. Próximos pasos inmediatos (orden comprometido)

1. Verificar/levantar el contenedor Oracle y correr la verificación de carga (6/9/4/11/12).
2. Crear `.gitignore` + completar `connection.env.example` (sin contraseñas reales).
3. **`t=0` → commit «Inicio del examen».**
4. Commit A.1: DDL de `ttem_catalog` / `ttem_item` (+ `ttem_audit_log`) con datos MONEDA y TIPO_COMISION.
5. Commit walking skeleton (≤ min. 25): `pkg_ttem_catalog` spec+body compilables.
6. A.3 → A.4 → B → C → D, con commits por cada bloque funcionando.
7. Últimos 25 min: README (ejemplos, Sección D), AI-LOG y este STATUS.
