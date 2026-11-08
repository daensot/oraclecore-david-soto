-- =====================================================================
-- Seccion C - Spec del package de liquidacion PKG_CORE_SETTLEMENT
--
-- Decisiones documentadas (README y AI-LOG):
--   * Quien controla la transaccion: el PROCEDIMIENTO. SAVEPOINT al
--     inicio, COMMIT al finalizar y ROLLBACK TO SAVEPOINT + RAISE ante
--     cualquier error (el invocador no debe garantizar la partida doble).
--   * Bloqueo consistente: ambas cuentas se bloquean con
--     SELECT ... FOR UPDATE en orden ASCENDENTE por account_no para
--     evitar deadlocks entre transferencias concurrentes.
--   * Idempotencia: la referencia es obligatoria y unica; el duplicado
--     se rechaza con excepcion propia (pre-check + captura ORA-00001).
--   * p_simular_falla = 'S' provoca un error controlado DESPUES del
--     debito y ANTES del haber para demostrar la atomicidad.
-- =====================================================================
SET DEFINE OFF

CREATE OR REPLACE PACKAGE pkg_core_settlement AS

  -- -------------------------------------------------------------------
  -- Codigo y excepciones propias (rango Seccion C: -20010..-20029)
  -- -------------------------------------------------------------------
  c_err_trx_monto_invalido        CONSTANT PLS_INTEGER := -20010;
  c_err_trx_cuenta_no_existe      CONSTANT PLS_INTEGER := -20011;
  c_err_trx_cuenta_no_activa      CONSTANT PLS_INTEGER := -20012;
  c_err_trx_moneda_mismatch       CONSTANT PLS_INTEGER := -20013;
  c_err_trx_saldo_insuficiente    CONSTANT PLS_INTEGER := -20014;
  c_err_trx_referencia_duplicada  CONSTANT PLS_INTEGER := -20015;
  c_err_trx_cuentas_iguales       CONSTANT PLS_INTEGER := -20016;
  c_err_trx_dato_obligatorio      CONSTANT PLS_INTEGER := -20017;
  c_err_trx_no_reversible         CONSTANT PLS_INTEGER := -20018;
  c_err_trx_falla_simulada        CONSTANT PLS_INTEGER := -20099;

  e_trx_monto_invalido       EXCEPTION; PRAGMA EXCEPTION_INIT(e_trx_monto_invalido,       -20010);
  e_trx_cuenta_no_existe     EXCEPTION; PRAGMA EXCEPTION_INIT(e_trx_cuenta_no_existe,     -20011);
  e_trx_cuenta_no_activa     EXCEPTION; PRAGMA EXCEPTION_INIT(e_trx_cuenta_no_activa,     -20012);
  e_trx_moneda_mismatch      EXCEPTION; PRAGMA EXCEPTION_INIT(e_trx_moneda_mismatch,      -20013);
  e_trx_saldo_insuficiente   EXCEPTION; PRAGMA EXCEPTION_INIT(e_trx_saldo_insuficiente,   -20014);
  e_trx_referencia_duplicada EXCEPTION; PRAGMA EXCEPTION_INIT(e_trx_referencia_duplicada, -20015);
  e_trx_cuentas_iguales      EXCEPTION; PRAGMA EXCEPTION_INIT(e_trx_cuentas_iguales,      -20016);
  e_trx_dato_obligatorio     EXCEPTION; PRAGMA EXCEPTION_INIT(e_trx_dato_obligatorio,     -20017);
  e_trx_no_reversible        EXCEPTION; PRAGMA EXCEPTION_INIT(e_trx_no_reversible,        -20018);
  e_trx_falla_simulada       EXCEPTION; PRAGMA EXCEPTION_INIT(e_trx_falla_simulada,       -20099);

  -- -------------------------------------------------------------------
  -- Liquidacion: debito y acreditacion entre cuentas (partida doble en
  -- una unica fila CORE_TRX: tipo TRF, Debe = origen, Haber = destino)
  -- -------------------------------------------------------------------
  PROCEDURE transferir (
    p_cuenta_origen   IN core_account.account_no%TYPE,
    p_cuenta_destino  IN core_account.account_no%TYPE,
    p_monto           IN NUMBER,
    p_moneda          IN VARCHAR2,
    p_referencia      IN VARCHAR2,
    p_descripcion     IN VARCHAR2 DEFAULT NULL,
    p_simular_falla   IN VARCHAR2 DEFAULT 'N',
    p_trx_id          OUT core_trx.trx_id%TYPE);

  -- Reversa opcional (valorada adicional): inserta el movimiento REV que
  -- invierte las cuentas del original y restituye los saldos.
  PROCEDURE revertir (
    p_trx_id          IN core_trx.trx_id%TYPE,
    p_trx_id_reversa  OUT core_trx.trx_id%TYPE);

END pkg_core_settlement;
/
SHOW ERROR

PROMPT Spec PKG_CORE_SETTLEMENT creada.
