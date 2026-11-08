# SPEC 00 — Visión general, prioridades y entrega

Fuente: *Prueba Técnica Oracle PL/SQL · Core Bancario* v4 (Credicorp Bank), oct. 2026.

## 1. Objetivo

Construir objetos PL/SQL que:
1. **(A)** administren los catálogos parametrizables del core (tablas `TTEM_*`, con paquete
   de mantenimiento, excepciones propias y consulta JSON);
2. **(B)** expongan información de clientes a partir del modelo de datos existente;
3. **(C)** ejecuten la liquidación de transferencias (débito + acreditación) con tratamiento
   de fallas; y
4. **(D)** razonen sobre mejora de un proceso (sin código).

El modelo del core **no se diseña**: se recibe (Anexo A / `setup/`). No es modificable.

## 2. Prioridades y tiempos

| Ref. | Requisito | Prioridad | Tiempo de referencia |
|------|-----------|-----------|----------------------|
| A.1 | Tablas TTEM_* + datos iniciales + commit | P0 | 15 min |
| A.2 | Package spec+body (CRUD + Object Types) compilable antes del min. 25 | P0 | 25 min |
| A.3 | Validaciones y excepciones propias | P0 | 15 min |
| A.4 | Consulta JSON por ItemId | P0 | 15 min |
| B | Consulta de cliente por cuenta | P0 | 15 min |
| C | Liquidación con manejo de fallas | P1 | 30 min |
| D | Propuesta de mejora | P1 | 10 min |
| A.5 | Carga masiva staging | P2 | 15 min |

- P0 suma **85 min**; P1 **40 min**; reservar **25 min** para documentación y commit final
  (150 min totales).
- **Walking skeleton obligatorio (≤ min. 25):** commit con tablas TTEM_* creadas y un
  package spec+body compilando, aunque esté incompleto.
- No iniciar P1 hasta que los P0 compilen y se ejecuten.
- Los commits deben mostrar avance progresivo (nunca un único commit final).

## 3. Qué se evalúa (con peso) / qué no

| Dimensión | Peso |
|-----------|------|
| Modelamiento y SQL (A.1, B) | 20 % |
| PL/SQL (A.2–A.4): package, Object Types, excepciones de negocio, JSON | 25 % |
| Transacciones (C): COMMIT/ROLLBACK/SAVEPOINT, fallas parciales | 20 % |
| Criterio técnico (D) | 10 % |
| Procesamiento masivo (A.5), si se abordó | 5 % |
| Uso efectivo de IA (acelerar + cuestionar) | 10 % |
| AI-LOG y STATUS (decisiones + transparencia) | 5 % |
| README y experiencia de uso (clonar-compilar-probar < 5 min) | 5 % |

**No se evalúa:** completar 100 % de las secciones; memorizar sintaxis; tuning avanzado
(basta mencionar cuando aplique); diseño visual de consola; cobertura de pruebas 100 %.
Se evalúa priorización con tiempo limitado y transparencia de lo pendiente.

## 4. Restricciones de stack

- Motor **fijo**: Oracle XE 21c **o** 23ai Free (declarar versión en README e indicar si se
  usan features exclusivas de 23ai, p. ej. `BOOLEAN` en SQL).
- Cliente SQL libre (SQLcl, SQL Developer, DBeaver, VS Code, TOAD, DataGrip…).
- Sin interfaz gráfica: todo se valida por consola.
- Sin contraseñas ni datos de conexión en el repo (`&param`, `connection.env` ignorado por
  git + `connection.env.example` como plantilla).
- Se puede usar IA generativa para no reiniciar de cero, pero TODO constraint y bloque de
  manejo de excepciones debe poder explicarse.

## 5. Entregables (carpetas)

| Carpeta | Contenido |
|---------|-----------|
| `setup/` | Scripts del Anexo B, sin modificaciones |
| `ddl/` | DDL de `TTEM_*`, constraints, Object Types, datos iniciales |
| `plsql/` | Packages (spec + body) y procedimientos |
| `scripts/` | Consulta Sección B y casos de prueba Sección C |
| `specs/` | Este conjunto de especificaciones |

## 6. Documentos obligatorios

| Archivo | Contenido mínimo |
|---------|------------------|
| `README.md` | Herramientas + versión Oracle; pasos exactos de ejecución (orden de scripts); ejemplo JSON + transferencia con salida esperada; tabla de códigos de error propios; comportamiento ante cuenta inexistente (B); respuesta Sección D (≤20 líneas) |
| `AI-LOG.md` | Herramientas IA usadas; decisiones técnicas justificadas (modelo, códigos error, tipo de eliminación, control transaccional C); prompts representativos con texto exacto y resultado; ≥1 caso en que se corrigió/rechazó código IA (motivo); % de código generado por IA |
| `STATUS.md` | Tabla requisito → Hecho / Parcial / No hecho; para parciales y no hechos: qué falta y cómo lo resolvería |
| `CLAUDE.md`/equivalente | Si se usó Claude Code (o análogo), el archivo de contexto entregado; si no, declararlo |
| `connection.env.example` | Variables de conexión sin credenciales reales |

## 7. Entrega

- Repositorio **público** llamado `oraclecore-<nombre>`.
- Commits frecuentes y descriptivos; cierre a la hora límite (ajustes menores después, cuerpo
  del examen dentro del plazo).
- Enlace por el canal indicado en los Datos de la convocatoria.

## 8. Verificación del entorno (antes de t=0)

- Contenedor Oracle listo y conexión `CORE_DEV` OK.
- `02_core_datos.sql` muestra: CORE_CUSTOMER 6 · CORE_ACCOUNT 9 · OLB_USER 4 · CORE_TRX 11 ·
  TTEM_ITEM_STG 12.
- `git --version` OK, `user.name`/`user.email` configurados, push de prueba exitoso.
- Cliente SQL conectado, editor operativo, herramienta IA con sesión activa.
- Commit inicial: **“Inicio del examen”**.
