# SPEC 04 — Sección D: Criterio técnico — propuesta de mejora [P1]

Fuente: Sección 4 · Sección D del examen. Tiempo de referencia: **10 min**.
Ubicación: respuesta dentro de `README.md` (máximo **20 líneas**, **sin código**).

## 1. Escenario

El alta o la modificación de ítems de catálogo (p. ej. una nueva comisión) se solicita hoy
**por correo electrónico** y un desarrollador la ejecuta **manualmente en producción** con
scripts. Incidentes registrados:

- comisiones con **vigencias mal configuradas**;
- cambios **sin trazabilidad** de quién los aprobó.

## 2. La propuesta debe cubrir (en ≤ 20 líneas)

1. **Qué automatizar primero** y qué problema concreto resuelve.
2. **Pasos del proceso propuesto** y componentes involucrados (puede reutilizar lo
   construido en la Sección A).
3. **Controles**: aprobación por un segundo responsable, auditoría y mecanismo de reversión.
4. **Riesgos, dependencias y factibilidad**: esfuerzo aproximado y apoyo requerido de
   otras áreas.
5. **Cómo se medirá el resultado** (métrica/s).

## 3. Alineamiento con lo construido (referencias útiles)

- El modelo `TTEM_*` (ttem_catalog / ttem_item) y su paquete de mantenimiento son la base
  natural del flujo
- `ttem_audit_log` cubre la auditoría de quién cambió qué y cuándo.
- `valid_from` / `valid_to` (con UK y CHECK) evita vigencias incoherentes.
- El proceso propuesto puede apoyarse en un flujo de solicitudes (ticket) + aprobación
  (segundo responsable) + ejecución scriptada (o semi-automatizada) con tabla de carga
  tipo staging + reporte de rechazos (análogo a `ttem_item_stg` + `ttem_load_error`).

## 4. Expectativas / antipatrones

- **Esperado**: pasos identificados y el razonamiento que los sustenta, propuesta concreta
  y factible, no genérica.
- **No esperado**: código; listas genéricas de buenas prácticas; promesas sin plan.

## 5. Criterio de aceptación

- [ ] Respuesta en README, ≤ 20 líneas, sin código.
- [ ] Cubre los 5 puntos de §2 de forma concreta (con problema, pasos, controles, riesgos
      y métrica).
- [ ] Reutiliza explícita y razonablemente el modelo de la Sección A.
