-- =====================================================================
-- Pruebas de la Seccion C sobre PKG_CORE_SETTLEMENT
-- Reproduce los 6 casos del enunciado + validaciones extra + reversa.
-- Ejecutar en orden (los saldos de cada caso dependen del anterior).
-- Codigo ASCII puro para compatibilidad con cualquier cliente SQL.
-- =====================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

PROMPT =================================================================
PROMPT CASO 1: 1910001000011 -> 1910002000017, 100.00 PEN, REF-T001
PROMPT (esperado: exito, saldos 5150.00 y 450.50, movimiento TRF)
PROMPT =================================================================
DECLARE
  l_trx_id core_trx.trx_id%TYPE;
BEGIN
  pkg_core_settlement.transferir('1910001000011', '1910002000017', 100,
                                 'PEN', 'REF-T001', NULL, 'N', l_trx_id);
  DBMS_OUTPUT.PUT_LINE('OK - trx ' || l_trx_id);
END;
/

PROMPT =================================================================
PROMPT CASO 2: repetir REF-T001 -> rechazo por referencia duplicada
PROMPT =================================================================
DECLARE
  l_trx_id core_trx.trx_id%TYPE;
BEGIN
  pkg_core_settlement.transferir('1910001000011', '1910002000017', 100,
                                 'PEN', 'REF-T001', NULL, 'N', l_trx_id);
  DBMS_OUTPUT.PUT_LINE('NUNCA deberia ejecutarse');
EXCEPTION
  WHEN pkg_core_settlement.e_trx_referencia_duplicada THEN
    DBMS_OUTPUT.PUT_LINE('Rechazado (duplicado): ' || SQLERRM);
END;
/

PROMPT =================================================================
PROMPT CASO 3: 1910002000017 -> 1910001000011, 5000.00 PEN
PROMPT (esperado: saldo insuficiente)
PROMPT =================================================================
DECLARE
  l_trx_id core_trx.trx_id%TYPE;
BEGIN
  pkg_core_settlement.transferir('1910002000017', '1910001000011', 5000,
                                 'PEN', 'REF-T003', NULL, 'N', l_trx_id);
  DBMS_OUTPUT.PUT_LINE('NUNCA deberia ejecutarse');
EXCEPTION
  WHEN pkg_core_settlement.e_trx_saldo_insuficiente THEN
    DBMS_OUTPUT.PUT_LINE('Rechazado (saldo): ' || SQLERRM);
END;
/

PROMPT =================================================================
PROMPT CASO 4: 1910001000011 -> 1910001000029, 10.00 PEN
PROMPT (esperado: moneda distinta, destino en USD)
PROMPT =================================================================
DECLARE
  l_trx_id core_trx.trx_id%TYPE;
BEGIN
  pkg_core_settlement.transferir('1910001000011', '1910001000029', 10,
                                 'PEN', 'REF-T004', NULL, 'N', l_trx_id);
  DBMS_OUTPUT.PUT_LINE('NUNCA deberia ejecutarse');
EXCEPTION
  WHEN pkg_core_settlement.e_trx_moneda_mismatch THEN
    DBMS_OUTPUT.PUT_LINE('Rechazado (moneda): ' || SQLERRM);
END;
/

PROMPT =================================================================
PROMPT CASO 5: 1910003000013 -> 1910004000019, 50.00 PEN
PROMPT (esperado: cuenta de destino bloqueada)
PROMPT =================================================================
DECLARE
  l_trx_id core_trx.trx_id%TYPE;
BEGIN
  pkg_core_settlement.transferir('1910003000013', '1910004000019', 50,
                                 'PEN', 'REF-T005', NULL, 'N', l_trx_id);
  DBMS_OUTPUT.PUT_LINE('NUNCA deberia ejecutarse');
EXCEPTION
  WHEN pkg_core_settlement.e_trx_cuenta_no_activa THEN
    DBMS_OUTPUT.PUT_LINE('Rechazado (destino bloqueada): ' || SQLERRM);
END;
/

PROMPT =================================================================
PROMPT CASO 6: 1910001000011 -> 1910002000017, 100.00 PEN, REF-T002,
PROMPT con p_simular_falla = 'S' (error despues del debito, antes del
PROMPT haber) -> los saldos se conservan y no queda movimiento.
PROMPT =================================================================
DECLARE
  l_trx_id core_trx.trx_id%TYPE;
BEGIN
  pkg_core_settlement.transferir('1910001000011', '1910002000017', 100,
                                 'PEN', 'REF-T002', NULL, 'S', l_trx_id);
  DBMS_OUTPUT.PUT_LINE('NUNCA deberia ejecutarse');
EXCEPTION
  WHEN pkg_core_settlement.e_trx_falla_simulada THEN
    DBMS_OUTPUT.PUT_LINE('Error controlado: ' || SQLERRM);
END;
/

PROMPT =================================================================
PROMPT VALIDACIONES EXTRA
PROMPT =================================================================
DECLARE
  l_trx_id core_trx.trx_id%TYPE;

  PROCEDURE intentar(p_desc VARCHAR2, p_origen VARCHAR2, p_destino VARCHAR2,
                     p_monto NUMBER, p_moneda VARCHAR2, p_ref VARCHAR2) IS
  BEGIN
    pkg_core_settlement.transferir(p_origen, p_destino, p_monto,
                                   p_moneda, p_ref, NULL, 'N', l_trx_id);
    DBMS_OUTPUT.PUT_LINE(p_desc || ': NUNCA deberia pasar');
  EXCEPTION
    WHEN OTHERS THEN
      IF SQLCODE IN (pkg_core_settlement.c_err_trx_monto_invalido,
                     pkg_core_settlement.c_err_trx_dato_obligatorio,
                     pkg_core_settlement.c_err_trx_cuenta_no_existe,
                     pkg_core_settlement.c_err_trx_moneda_mismatch,
                     pkg_core_settlement.c_err_trx_saldo_insuficiente,
                     pkg_core_settlement.c_err_trx_cuentas_iguales) THEN
        DBMS_OUTPUT.PUT_LINE(p_desc || ': ' || SQLERRM);
      ELSE
        DBMS_OUTPUT.PUT_LINE(p_desc || ': FALLA INESPERADA ' || SQLERRM);
        RAISE;
      END IF;
  END intentar;
BEGIN
  intentar('Monto negativo        ' , '1910001000011', '1910002000017', -50,    'PEN', 'REF-X01');
  intentar('Monto 3 decimales     ', '1910001000011', '1910002000017', 10.005, 'PEN', 'REF-X02');
  intentar('Referencia vacia      ', '1910001000011', '1910002000017', 10,     'PEN', '   ');
  intentar('Cuentas iguales       ', '1910001000011', '1910001000011', 10,     'PEN', 'REF-X03');
  intentar('Cuenta inexistente    ', '1919999999999', '1910002000017', 10,     'PEN', 'REF-X04');
  intentar('Moneda no informada   ', '1910001000011', '1910002000017', 10,     NULL,  'REF-X05');
END;
/

PROMPT =================================================================
PROMPT VERIFICACION DE ATOMICIDAD Y PARTIDA DOBLE
PROMPT (esperado: 5150.00 y 450.50; solo REF-T001 en CORE_TRX)
PROMPT =================================================================
SELECT account_no, balance FROM core_account
 WHERE account_no IN ('1910001000011','1910002000017')
 ORDER BY account_no;

SELECT trx_id, trx_type, debit_account_no, credit_account_no, amount, currency,
       reference, reversal_flag, reversed_trx_id
  FROM core_trx
 WHERE reference IN ('REF-T001','REF-T002') OR reversal_flag = 'S'
 ORDER BY trx_id;

PROMPT =================================================================
PROMPT CASO 7 (BONUS): reversa del movimiento REF-T001
PROMPT (esperado: 5250.00 y 350.50, fila REV que invierte las cuentas)
PROMPT =================================================================
DECLARE
  l_trx_origen   core_trx.trx_id%TYPE;
  l_trx_reversa  core_trx.trx_id%TYPE;
  l_reverso_id   core_trx.trx_id%TYPE;
BEGIN
  SELECT trx_id INTO l_trx_origen FROM core_trx WHERE reference = 'REF-T001';

  pkg_core_settlement.revertir(l_trx_origen, l_trx_reversa);

  DBMS_OUTPUT.PUT_LINE('OK - reversa creada trx ' || l_trx_reversa);

  -- Idempotencia de la reversa: segunda llamada debe rechazarse
  BEGIN
    pkg_core_settlement.revertir(l_trx_origen, l_reverso_id);
    DBMS_OUTPUT.PUT_LINE('NUNCA: la reversa se genero 2 veces');
  EXCEPTION
    WHEN pkg_core_settlement.e_trx_no_reversible THEN
      DBMS_OUTPUT.PUT_LINE('Segunda reversa rechazada: ' || SQLERRM);
  END;
END;
/

PROMPT =================================================================
PROMPT ESTADO FINAL (esperado: 5250.00 y 350.50, una fila REV)
PROMPT =================================================================
SELECT account_no, balance FROM core_account
 WHERE account_no IN ('1910001000011','1910002000017')
 ORDER BY account_no;

SELECT trx_id, trx_type, debit_account_no, credit_account_no, amount, currency,
       reference, reversal_flag, reversed_trx_id
  FROM core_trx
 WHERE reference = 'REF-T001' OR reversal_flag = 'S'
 ORDER BY trx_id;
