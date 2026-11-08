# AI-LOG — Bitácora de uso de Inteligencia Artificial

Bitácora obligatoria del examen (Sección 7.2). Registra herramientas, decisiones, prompts
representativos, correcciones a código de IA y estimación de código generado.

## 1. Herramientas de IA utilizadas

| Herramienta | Uso | Modalidad |
|-------------|-----|-----------|
| **OpenCode** (agente CLI en terminal) con modelo **GLM (Z.ai)** — `glm-5.3-flash-free` | Lectura del enunciado PDF, creación del archivo de contexto del agente, especificaciones, memoria y documentación (README/STATUS/AI-LOG, este archivo incluido) | Plan gratuito |

*(Se ampliará si durante el examen se usan otras herramientas.)*

## 2. Decisiones técnicas y su justificación (hasta el momento)

> Estado: decisiones **de planificación**. Las implementaciones se documentarán al
> materializarse (ver `memory.md` §2 para la versión viva).

- **Modelo de catálogos y auditoría.** Dos tablas (`ttem_catalog`, `ttem_item`) con
  auditoría obligatoria de creación/modificación y, como mejora, `ttem_audit_log`. Justificación:
  en un core bancario la trazabilidad de cambios de parámetros (comisiones, monedas) no es
  opcional; la bitácora de valores anteriores y nuevos es lo primero que se revisa tras un
  incidente de parametrización.
- **Eliminación lógica vs física.** Decisión preliminar: **lógica** (`status = 'I'` del
  ítem, nunca borrado físico). Justificación: preserva referencias y trazabilidad, y el
  sistema del Anexo A ya modela estados (A/I) del mismo modo.
- **Rango de errores propios: −20000 … −20029.** Justificación: diferenciar error de
  negocio (ítem inexistente, referencia duplicada) de error técnico; reservo un subrango
  pequeño y documentado por dominio (catálogos −2000x, transacciones −2001x, −2002x
  disponible) en lugar de códigos dispersos. La tabla completa está en el README.
- **Control transaccional (Sección C).** Decisión preliminar: el **procedimiento controla**
  la transacción (`SAVEPOINT sp_transferencia`, `ROLLBACK TO SAVEPOINT` ante falla,
  `COMMIT` al finalizar) porque la partida doble debe ser atómica desde la API, sin dejar
  esa responsabilidad al invocador. La falla simulada (`p_simular_falla = 'S'`) demostrará
  la atomicidad con saldos y `CORE_TRX` intactos.
- **JSON solo con funciones nativas** (`JSON_OBJECT ... RETURNING CLOB`) con atributos
  siempre presentes (incluso `null` explícito) y fechas `YYYY-MM-DD`. Justificación:
  contract-first; la concatenación de texto genera JSON inválido y no tipado.

## 3. Prompts representativos (texto exacto → resultado → qué hice con ello)

### Prompt 1 — Contexto del agente y planificación (OpenCode · GLM)
> **Texto exacto:** «creame el agent.md, el memory.md, las specs para el proyecto de evaluación contenido en este pdf» (con el PDF adjunto).

**Qué devolvió:** extrajo el texto del PDF (`pdftotext`), creó `agent.md` (reglas
inquebrantables, prioridades/tiempos, Anexo C de nomenclatura, estructura del repo), 5 specs
funcionales en `specs/` y `memory.md` con decisiones preliminares y tabla de códigos de error.

**Qué hice:** revisé contra el enunciado original; el contenido respeta prioridades
(P0 A.1–A.4/B · P1 C/D · P2 A.5), el estándar del Anexo C y las prohibiciones. Acepté la
estructura. Correcciones menores de erratas de redacción aplicadas durante la revisión.

### Prompt 2 — Documentación con estado real (OpenCode · GLM)
> **Texto exacto:** «ahora actualizame el READMe.md, STATUS.md y AI-LOG.md con el status real que tenemos del proyecto».

**Qué devolvió:** los tres archivos con el estado verificado del repositorio (setup filtrado por
`git log --stat`, carpetas `ddl/`, `plsql/`, `scripts/` vacías, contenedor no en
ejecución): planificación Hecho, requisitos del examen No hechos, pendientes declarados con
el «cómo los resolvería».

**Qué hice:** acepté la transparencia deliberada: el examen evalúa coherencia STATUS ↔
contenido real del repositorio, no avance ficticio. Este archivo es el resultado.

## 4. Casos documentados de corrección / rechazo de código generado por IA

Aún **no** se ha generado código PL/SQL por IA en este repositorio (no hay packages, DDL
propietario ni consultas implementadas). El examen exige documentar **al menos un caso**: el
primero se registrará aquí con el extracto del código, el patrón detectado y el motivo.

Patrones vigilados (vía `agent.md` §1 y §8 del enunciado):
- `EXCEPTION WHEN OTHERS THEN NULL` o capturar sin relanzar → **rechazo inmediato**.
- Falta de `ROLLBACK`/`SAVEPOINT` en operaciones con dos lados (débito/acreditación) → corrección obligatoria.
- SQL dinámico concatenado sin bind variables → corrección obligatoria.
- JSON por concatenación de strings en vez de `JSON_OBJECT` → corrección obligatoria.

## 5. Estimación de código generado por IA vs escrito por el candidato

| Momento | Código generado por IA | Escrito por el candidato |
|---------|------------------------|--------------------------|
| Preparación (documentación y specs) | ~100 % de los `.md` (revisados/ajustados por mí) | ~0 % (con correcciones de erratas y decisiones de contenido) |
| Implementación PL/SQL | 0 % por ahora | 0 % por ahora |

*(Se actualizará con el % final al cerrar el examen; compromiso: revisar todo lo generado
antes de compilarlo y explicar cada constraint y cada manejador de excepciones entregado.)*

## 6. Uso de agentes: contexto entregado

- Agente usado: **OpenCode** con modelo **GLM (Z.ai)**.
- Contexto entregado al agente: `agent.md` (creado por el agente en la fase de planificación
  siguiendo la sección 7.3 del enunciado, actúa como el archivo de contexto equivalente a
  `CLAUDE.md`). No se entregó ningún otro archivo de contexto explícito.
- Material base adicional: solo los scripts originales del Anexo B (entregados con el
  examen) y el propio enunciado. **No** se clonó repositorio con soluciones.
