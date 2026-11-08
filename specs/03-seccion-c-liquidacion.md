# SPEC 03 — Sección C: Liquidación — débito y acreditación entre cuentas [P1]

Fuente: Sección 4 · Sección C del examen. Tiempo de referencia: **30 min**.
Ubicación: `plsql/` (package) y `scripts/` (casos de prueba).

## 1. Requisito

Procedimiento de transferencia, preferiblemente en un package propio **`pkg_core_settlement`**.
Si se incluye en el package de la Sección A (`PKG_TTEM_CATALOG`), **justificarlo** en
`AI-LOG.md` (separación de dominios: catálogos ≠ settlement).

### Firma sugerida

```sql
PROCEDURE transferir (
  p_cuenta_origen  IN core_account.account_no%TYPE,
  p_cuenta_destino IN core_account.account_no%TYPE,
  p_monto          IN NUMBER,
  p_moneda         IN VARCHAR2,
  p_referencia     IN VARCHAR2,
  p_descripcion    IN VARCHAR2 DEFAULT NULL,
  p_simular_falla  IN VARCHAR2 DEFAULT 'N',
  p_trx_id         OUT core_trx.trx_id%TYPE);
```

## 2. Reglas de negocio (todas obligatorias)

1. **Monto**: mayor que cero y con **máximo 2 decimales** (rechazar −20010 si no).
2. **Cuentas**: ambas deben existir, ser **distintas** y estar **activas** (estado `A`).
   Nota: las cuentas internas del banco (`product_type = 'INT'`) son válidas como destino.
3. **Moneda**: la moneda indicada debe coincidir con la de **ambas** cuentas.
4. **Saldo**: disponibilidad suficiente en origen (no hay sobregiro).
5. **Partida doble**: se debita origen, se acredita destino y se registra **una única fila**
   en `CORE_TRX` (no dos): `trx_type='TRF'`, `debit_account_no=origen`,
   `credit_account_no=destino`, `amount>0`, `reversal_flag='N'`,
   `trx_id` desde `seq_core_trx` (inicia en 1000), `trx_date` = fecha contable del momento.
6. **Idempotencia**: la referencia es **única**. Si ya existe un movimiento con la misma
   referencia → rechazo con excepción propia (−20015). Verificar antes y/o capturar
   `ORA-00001` de `uk_core_trx_reference` previene carrera de homólogos.
7. **Atomicidad**: con `p_simular_falla = 'S'` el procedimiento **provoca un error
   deliberadamente después del débito y antes de la acreditación** (p. ej.
   `RAISE_APPLICATION_ERROR` o `raise e_falla_simulada` después de un savepoint). Debe
   demostrarse que: el **saldo de origen no queda modificado** y **no queda registrado**
   el movimiento. Estrategia: `SAVEPOINT` al inicio + `ROLLBACK TO` (y luego relanzar), o
   dejar que la excepción propague y el invocador haga ROLLBACK — decidir y documentar.
8. **Control de transacción**: definir y documentar **quién hace COMMIT** (el procedimiento
   o el invocador) y el rol de `SAVEPOINT`. Decisión recomendada (ver `memory.md` D3):
   el procedimiento controla la transacción con `SAVEPOINT sp_transferencia` +
   `ROLLBACK TO SAVEPOINT` en caso de falla + `COMMIT` al finalizar.

## 3. Valoración adicional (hacer si sobra tiempo)

- **Bloqueo consistente**: `SELECT ... FOR UPDATE` sobre ambas cuentas en un **orden
  consistente** (p. ej. siempre bloquear primero la cuenta de mayor `account_no`) para
  evitar deadlocks entre transferencias concurrentes.
- **Procedimiento de reversa** (opcional): inserta un movimiento `REV` que invierte débito
  y crédito, `reversal_flag='S'` + `reversed_trx_id` del original.

## 4. Casos de prueba (obligatorios → `scripts/`)

| # | Operación | Resultado esperado |
|---|-----------|--------------------|
| 1 | `1910001000011 → 1910002000017`, 100.00 PEN, ref `REF-T001` | ✅ Éxito: ambos saldos actualizados (5250→5150 / 350.50→450.50) y movimiento en `CORE_TRX` con id de `seq_core_trx` |
| 2 | Repetir caso 1 (misma ref `REF-T001`) | ❌ Rechazo: referencia duplicada (−20015) |
| 3 | `1910002000017 → 1910001000011`, 5000.00 PEN | ❌ Rechazo: saldo insuficiente (350.50 < 5000) (−20014) |
| 4 | `1910001000011 → 1910001000029`, 10.00 PEN | ❌ Rechazo: moneda distinta (destino USD) (−20013) |
| 5 | `1910003000013 → 1910004000019`, 50.00 PEN | ❌ Rechazo: cuenta destino **bloqueada** (estado B) (−20012) |
| 6 | `1910001000011 → 1910002000017`, 100.00 PEN, `REF-T002`, `p_simular_falla='S'` | ❌ Error controlado: **saldos intactos** y **sin** registro en `CORE_TRX` |

## 5. Salida de validación tras los 6 casos

Verificar con:

```sql
SELECT account_no, balance FROM core_account
 WHERE account_no IN ('1910001000011','1910002000017');
SELECT trx_id, debit_account_no, credit_account_no, amount, currency, trx_type, reference
  FROM core_trx WHERE reference IN ('REF-T001','REF-T002');
-- Esperado: solo REF-T001 (una fila de transferencia); saldos netos −100 / +100
```

## 6. Criterio de aceptación

- [ ] Package compila y la ejecución de los 6 casos reproduce la tabla §4.
- [ ] Cada rechazo levanta la excepción propia con su código, **sin** `WHEN OTHERS THEN NULL`.
- [ ] Falla simulada deja los saldos y `CORE_TRX` incambiados (atomicidad demostrada).
- [ ] Orden de bloqueo documentado (si se implementó `FOR UPDATE`).
- [ ] Estado del alcance y decisiones (`/plsql/` + `AI-LOG.md` + `STATUS.md`) sincronizados.
