# SPEC 02 — Sección B: Consulta de cliente por número de cuenta [P0]

Fuente: Sección 4 · Sección B del examen. Tiempo de referencia: **15 min** (bloque A.4 + B:
30 min juntos).
Ubicación: `scripts/` (consulta SQL final, lista para ejecutarse con bind variable).

## 1. Requisito

Consulta **SQL** (no PL/SQL) que reciba el número de cuenta en una **variable de sustitución
o bind variable** y devuelva **una sola fila por cuenta** con:

### Datos de la cuenta (`core_account`)
- `account_no` — número de cuenta.
- `product_type` — tipo de producto (AHO / CTE / INT).
- `currency` — moneda (PEN / USD).
- `balance` — saldo.
- `status` — estado (A / B / C).

### Datos del cliente (`core_customer`, vía FK)
- `customer_id`.
- Tipo de persona **traducido**: «Natural» (N) o «Jurídica» (J).
- Tipo y número de documento (`doc_type`, `doc_number`).
- **Nombre normalizado**, sin espacios sobrantes:
  - persona natural → nombres + apellidos (`first_name || ' ' || last_name`),
  - persona jurídica → `business_name`.
  - Usar `TRIM(...)`; los datos reales incluyen valores como `'         jose luis '` y
    `'RAMIREZ       TORRES'`, y hay que tratar esos espacios sobrantes.

### Fecha de referencia y su tipo
- Persona natural → `birth_date`, tipo = «Nacimiento».
- Persona jurídica → `incorporation_date`, tipo = «Constitución».
- **Si el dato no existe**: la fecha se muestra vacía (NULL) y el tipo como «No registrada».
- Solución típica: `CASE` sobre `person_type`.

### Usuarios de Banca en Línea (`olb_user`)
- **Consolidados en una sola columna** con `LISTAGG` (ej. `mquispe;invandinas.admin` o
  separador `', '`), incluyendo su estado (p. ej. `username (estado)`).
- Si el cliente no tiene usuarios → columna vacía (evitar `(null)` con `LISTAGG` normaliza
  NULL por diseño; verificar en el cliente final).

## 2. Casos de prueba obligatorios

| Cuenta | Caso que debe cubrir |
|--------|----------------------|
| `1910001000011` | Natural con fecha de nacimiento y 1 usuario OLB (`mquispe`, activo) |
| `1910002000017` | Natural **sin** fecha de nacimiento, sin usuarios, nombre que requiere normalización (espacios y mayúsculas) |
| `1910003000013` | Jurídica con 2 usuarios OLB (uno **bloqueado**: `invandinas.tesoreria` estado B) |
| `1910004000019` | Jurídica **sin** fecha de constitución y cuenta **bloqueada** (estado B) |
| `9999999999999` | Cuenta inexistente → **documentar en README el comportamiento** (0 filas) |

## 3. Decisiones a documentar

- Comportamiento ante cuenta inexistente: la consulta devuelve **cero filas** (no error);
  declarar en README.
- LISTAGG y versión: en Oracle 21c+/23ai disponible tanto `LISTAGG` clásico como
  `LISTAGG(... ON OVERFLOW TRUNCATE)` y `LISTAGG DISTINCT`; en 21c hay soporte. No requiere
  feature exclusiva de 23ai; si se usa alguna, verificar compatibilidad.
- Indexación adicional: `ix_core_account_*` ya existe sobre `customer_id`; los índices del
  Anexo B bastan para esta consulta. Cualquier índice adicional debe justificarse.

## 4. Formato de entrega en `scripts/`

```
scripts/seccion_b_consulta_cliente.sql
```

- Recibir parámetro: variable de sustitución `ACCEPT p_cuenta ...` o bind `:p_cuenta`.
- Incluye comentario cabecera con el propósito y los casos de prueba.
- No modificar nada del core: solo SELECT + joines `core_customer`, `core_account`,
  `olb_user` (LEFT JOIN para usuarios).

## 5. Criterio de aceptación

- [ ] Recibe el número de cuenta por bind/sustitución (sin hardcode).
- [ ] Devuelve 1 fila con las columnas del §1 (cuenta + cliente + fecha de referencia con
      tipo, o vacío/«No registrada» + usuarios consolidados).
- [ ] Nombre normalizado (TRIM y espacio múltiple tratado cuando se decida un criterio).
- [ ] Los 5 casos de prueba ejecutados y su salida verificada (imagen de salida en README).
