# AI-LOG — Bitácora de uso de Inteligencia Artificial

Bitácora obligatoria del examen (Sección 7.2). Registra herramientas, decisiones, prompts
representativos, correcciones a código de IA y estimación de código generado.

## 1. Herramientas de IA utilizadas

| Herramienta | Uso | Modalidad |
|-------------|-----|-----------|
| **OpenCode** (agente CLI en terminal) con modelo **GLM (Z.ai)** — `glm-5.3-flash-free` | Lectura del enunciado PDF, archivo de contexto del agente, specs, documentación, generación de DDL/PL/SQL/scripts y pruebas contra Oracle XE 21c | Plan gratuito |

*(Se ampliará si durante el examen se usan otras herramientas.)*

## 1bis. Registro de la fase de implementación P0 (A.1–A.4 y B)

- Desarrollados y **verificados en `gvenzl/oracle-xe:21.3.0` (XEPDB1)**: DDL TTEM_*,
  object types, package spec+body, datos iniciales, consulta Sección B y script de pruebas.
- `user_errors` vacío y 19 objetos en estado VALID.
- Commits progresivos: `5c2d32a` (A.1) → `c36e79e` (A.2–A.4) → `c046299` (B y pruebas).
- Los casos de prueba con error business esperado (−20003 duplicado, −20001 inexistente)
  se ejecutaron y documentaron en `scripts/pruebas_seccion_a.sql` y README §4.

## 1ter. Registro de la fase de implementación P1 — Sección C

- Desarrollado y **verificado en XEPDB1**: `plsql/pkg_core_settlement.pks` / `.pkb` con
  `transferir` (8 reglas) y bonus `revertir`; `scripts/pruebas_seccion_c.sql` con los 6
  casos del enunciado + 6 validaciones extra + prueba de reversa.
- `user_errors` vacío tras compilar el nuevo package; 24 objetos en estado VALID.
- Corrida limpia tras restaurar los saldos de referencia (5250 / 350.50):
  - Caso 1 éxito: trx desde `SEQ_CORE_TRX`, saldos 5150 / 450.50 y una única fila TRF.
  - Casos 2–5: excepciones propias −20015 (duplicada), −20014 (saldo), −20013 (moneda),
    −20012 (destino bloqueada) — el script maneja las excepciones **por nombre**.
  - Caso 6 (falla simulada −20099): el débito se deshace; demostrado que los saldos no
    cambian y que no queda fila REF-T002 en `CORE_TRX` (atomicidad).
  - Bonus: reversa (fila REV con cuentas invertidas, saldos 5250 / 350.50); la segunda
    reversa se rechaza con −20018.

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

### Caso 3 (durante la implementación de la Sección C): verificador del script de pruebas

- **Código generado por IA:** en `scripts/pruebas_seccion_c.sql`, el manejador del bloque
  de validaciones extra usaba `CASE SQLCODE WHEN a OR b THEN ...` (con un `||` mezclado
  entre los operadores).
- **Qué pasó:** el rechazo esperado de "cuentas iguales" (−20016) no entraba por la rama
  correcta: se interpretó como *FALLA INESPERADA* y el bloque terminó con error aunque el
  package se comportó bien.
- **Corrección:** simplificar a `IF SQLCODE IN (...) THEN ... ELSE ... RAISE; END IF` con
  la lista completa de códigos esperados. Re-corrida limpia: los 13 controles en verde.
- **Lección:** el error estaba en el **script de prueba**, no en el package; separar la
  lógica de negocio de la de verificación evita culpar al código correcto.

### Caso 1 (12-nov-2026 durante la implementación de A.1): trigger de bitácora con predicados en CASE

- **Código generado por IA:** trigger `trg_ttem_item_log` que llenaba `ttem_audit_log`
  construyendo `action` y los CLOB de old/new values con expresiones
  `CASE WHEN INSERTING THEN ... END` directamente en la lista `VALUES` del INSERT.
- **Qué pasó al compilar (XEPDB1, 21.3):** `ORA-00920: invalid relational operator`;
  `user_errors` apuntaba a la línea del primer CASE dentro del VALUES, y por el trigger
  inválido fallaban **todos** los insert de ítems con `ORA-04098` (el lote inicial quedó
  con 0 ítems: detalle que solo se detectó porque se ejecutó y verificó las cargas de
  `03_ttem_datos.sql`).
- **Corrección:** reestructurar el trigger para **decidir con IF/ELSIF en el bloque
  PL/SQL** (`l_accion`, `l_old`, `l_new`) e insertar los valores ya preparados. El trigger
  compiló, la carga quedó 2/3/3 y la bitácora registra los tres tipos de evento.
- **Lección:** los predicados condicionales (`INSERTING/UPDATING/DELETING`) son datos de
  control, no expresiones de SQL dentro de `VALUES`: si la IA los mete en el INSERT, hay
  que validar con `user_errors` y no solo con el mensaje "Trigger created". También
  confirma que **compilar no es suficiente**: se requiere ejecutar la carga y comparar
  cantidades.

### Caso 2: prompts con instrucciones anti-patrón (prevención)

Al pedir el CRUD al agente se fijaron por adelantado las restricciones (cero
`WHEN OTHERS THEN NULL`, bind variables, JSON nativo, savepoints). El cuerpo generado
respetó el patrón; los `WHEN OTHERS` existentes hacen `ROLLBACK TO` savepoint y relanzan.
*(Si apareciera alguno silenciador durante las próximas secciones, se documentará aquí.)*

## 5. Estimación de código generado por IA vs escrito por el candidato

| Momento | Código generado por IA | Escrito por el candidato |
|---------|------------------------|--------------------------|
| Preparación (documentación y specs) | ~100 % de los `.md` (revisados/ajustados por mí) | ~0 % (con correcciones de erratas y decisiones de contenido) |
| Implementación P0 (DDL, PL/SQL, scripts y pruebas) | ~90 % del texto de los scripts, instruido con las restricciones del `agent.md` | ~10 % (estructura de espec, decisiones de API, ajuste del trigger de bitácora, revisión línea a línea y verificación ejecutada por mí: cada constraint y cada manejador fue revisado y aceptado) |

*(Compromiso: revisar todo lo generado antes de compilarlo y poder explicar cada constraint
y cada bloque de manejo de excepciones entregado — cumplido en la pasada de revisión
documentada en §2 y en el caso 1 de §4.)*

## 6. Uso de agentes: contexto entregado

- Agente usado: **OpenCode** con modelo **GLM (Z.ai)**.
- Contexto entregado al agente: `agent.md` (creado por el agente en la fase de planificación
  siguiendo la sección 7.3 del enunciado, actúa como el archivo de contexto equivalente a
  `CLAUDE.md`). No se entregó ningún otro archivo de contexto explícito.
- Material base adicional: solo los scripts originales del Anexo B (entregados con el
  examen) y el propio enunciado. **No** se clonó repositorio con soluciones.
