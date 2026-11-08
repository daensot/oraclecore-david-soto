-- =====================================================================
-- Seccion C - Body del package PKG_CORE_SETTLEMENT
-- Reglas implementadas (specs/03):
--   1. monto > 0 y maximo 2 decimales                -> -20010
--   2. cuentas existen / distintas / activas (A)     -> -20011/-20016/-20012
--   3. moneda coincide con ambas cuentas             -> -20013
--   4. saldo suficiente en origen                    -> -20014
--   5. una unica fila CORE_TRX (TRF, Debe/Haber)
--   6. referencia obligatoria y unica                -> -20015 (idempotencia)
--   7. p_simular_falla = 'S': error tras el debito   -> -20099
--      y antes del haber: saldos y CORE_TRX intactos
--   8. la transaccion la controla el procedimiento (SAVEPOINT/COMMIT)
-- ---------------------------------------------------------------------
SET DEFINE OFF

CREATE OR REPLACE PACKAGE BODY pkg_core_settlement AS

  ---------------------------------------------------------------------
  -- Registro local para lectura bloqueada de una cuenta
  ---------------------------------------------------------------------
  TYPE t_cuenta_rec IS RECORD (
    balance  core_account.balance%TYPE,
    currency core_account.currency%TYPE,
    status   core_account.status%TYPE);

  ---------------------------------------------------------------------
  -- Bloquea la cuenta (SELECT ... FOR UPDATE) y devuelve su estado.
  -- Transaccion fallida: ROLLBACK TO savepoint NO libera bloqueos;
  -- el orden de bloqueo se controla en transferir (menor account_no
  -- primero) y el relanzamiento deja el fin de transaccion al
  -- invocador de su propia sesion.
  ---------------------------------------------------------------------
  PROCEDURE bloquear_cuenta (
    p_cuenta IN  core_account.account_no%TYPE,
    p_datos  OUT NOCOPY t_cuenta_rec) IS
  BEGIN
    SELECT balance, currency, status
      INTO p_datos
      FROM core_account
     WHERE account_no = p_cuenta
       FOR UPDATE;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(
        c_err_trx_cuenta_no_existe,
        'La cuenta ' || p_cuenta || ' no existe.');
  END bloquear_cuenta;

  ---------------------------------------------------------------------
  -- C: transferir
  ---------------------------------------------------------------------
  PROCEDURE transferir (
    p_cuenta_origen   IN  core_account.account_no%TYPE,
    p_cuenta_destino  IN  core_account.account_no%TYPE,
    p_monto           IN  NUMBER,
    p_moneda          IN  VARCHAR2,
    p_referencia      IN  VARCHAR2,
    p_descripcion     IN  VARCHAR2 DEFAULT NULL,
    p_simular_falla   IN  VARCHAR2 DEFAULT 'N',
    p_trx_id          OUT core_trx.trx_id%TYPE) IS

    l_o            t_cuenta_rec;
    l_d            t_cuenta_rec;
    l_primero      t_cuenta_rec;
    l_segundo      t_cuenta_rec;
    l_cuenta_prim  core_account.account_no%TYPE;
    l_cuenta_seg   core_account.account_no%TYPE;
    l_ref          core_trx.reference%TYPE := UPPER(TRIM(p_referencia));
    l_moneda       core_trx.currency%TYPE  := UPPER(TRIM(p_moneda));
    l_falla        VARCHAR2(1)             := UPPER(TRIM(NVL(p_simular_falla, 'N')));
    l_cnt          PLS_INTEGER;
  BEGIN
    SAVEPOINT sp_transferencia;

    -- (regla 1) Monto: obligatorio, mayor que cero y maximo 2 decimales
    IF p_monto IS NULL OR p_monto <= 0 THEN
      RAISE_APPLICATION_ERROR(
        c_err_trx_monto_invalido,
        'El monto debe ser mayor que cero y con como mucho dos decimales.');
    ELSIF p_monto <> ROUND(p_monto, 2) THEN
      RAISE_APPLICATION_ERROR(
        c_err_trx_monto_invalido,
        'El monto debe tener como maximo dos decimales: ' || p_monto || '.');
    END IF;

    -- Datos obligatorios (referencia y moneda)
    IF l_ref IS NULL THEN
      RAISE_APPLICATION_ERROR(
        c_err_trx_dato_obligatorio,
        'La referencia de la transferencia es obligatoria (control de idempotencia).');
    END IF;
    IF l_moneda IS NULL THEN
      RAISE_APPLICATION_ERROR(
        c_err_trx_dato_obligatorio,
        'La moneda de la transferencia es obligatoria.');
    END IF;
    IF l_falla NOT IN ('N', 'S') THEN
      RAISE_APPLICATION_ERROR(
        c_err_trx_dato_obligatorio,
        'p_simular_falla admite unicamente N o S.');
    END IF;

    -- (regla 2) Cuentas distintas
    IF p_cuenta_origen = p_cuenta_destino THEN
      RAISE_APPLICATION_ERROR(
        c_err_trx_cuentas_iguales,
        'La cuenta de origen y la de destino deben ser distintas.');
    END IF;

    -- (regla 2/4) Bloqueo consistente: menor account_no primero
    l_cuenta_prim := LEAST(p_cuenta_origen, p_cuenta_destino);
    l_cuenta_seg  := GREATEST(p_cuenta_origen, p_cuenta_destino);

    bloquear_cuenta(l_cuenta_prim, l_primero);
    bloquear_cuenta(l_cuenta_seg,  l_segundo);

    IF l_cuenta_prim = p_cuenta_origen THEN
      l_o := l_primero;
      l_d := l_segundo;
    ELSE
      l_o := l_segundo;
      l_d := l_primero;
    END IF;

    -- (regla 2) Ambas cuentas activas (estado A)
    IF l_o.status <> 'A' THEN
      RAISE_APPLICATION_ERROR(
        c_err_trx_cuenta_no_activa,
        'La cuenta de origen ' || p_cuenta_origen || ' no esta activa (estado ' ||
        l_o.status || ').');
    END IF;
    IF l_d.status <> 'A' THEN
      RAISE_APPLICATION_ERROR(
        c_err_trx_cuenta_no_activa,
        'La cuenta de destino ' || p_cuenta_destino || ' no esta activa (estado ' ||
        l_d.status || ').');
    END IF;

    -- (regla 3) Moneda coherente con ambas cuentas
    IF l_o.currency <> l_moneda OR l_d.currency <> l_moneda THEN
      RAISE_APPLICATION_ERROR(
        c_err_trx_moneda_mismatch,
        'La moneda de la transferencia (' || l_moneda || ') no coincide con la de ' ||
        CASE WHEN l_o.currency <> l_moneda
             THEN 'la cuenta de origen (' || l_o.currency || ')'
             ELSE 'la cuenta de destino (' || l_d.currency || ')'
        END || '.');
    END IF;

    -- (regla 4) Saldo suficiente en origen
    IF l_o.balance < p_monto THEN
      RAISE_APPLICATION_ERROR(
        c_err_trx_saldo_insuficiente,
        'Saldo insuficiente en ' || p_cuenta_origen || ' (disponible ' ||
        l_o.balance || ', solicitado ' || p_monto || ' ' || l_moneda || ').');
    END IF;

    -- (regla 6) Idempotencia pre-check de la referencia
    SELECT COUNT(*)
      INTO l_cnt
      FROM core_trx
     WHERE reference = l_ref;

    IF l_cnt > 0 THEN
      RAISE_APPLICATION_ERROR(
        c_err_trx_referencia_duplicada,
        'Ya existe un movimiento con la referencia ' || l_ref || ' (operacion rechazada).');
    END IF;

    -- Debito (Debe): sale el dinero de la cuenta de origen
    UPDATE core_account
       SET balance = balance - p_monto
     WHERE account_no = p_cuenta_origen;

    -- (regla 7) Falla simulada: DESPUES del debito y ANTES del haber
    IF l_falla = 'S' THEN
      RAISE_APPLICATION_ERROR(
        c_err_trx_falla_simulada,
        'Falla simulada: el debito se deshace; la acreditacion y el movimiento no se registran.');
    END IF;

    -- Acreditacion (Haber): ingresa el dinero a la cuenta de destino
    UPDATE core_account
       SET balance = balance + p_monto
     WHERE account_no = p_cuenta_destino;

    -- (regla 5) Partida doble: UNICA fila en CORE_TRX
    BEGIN
      INSERT INTO core_trx (trx_id, trx_date, debit_account_no, credit_account_no,
                            amount, currency, trx_type, description, reference,
                            reversal_flag)
      VALUES (seq_core_trx.NEXTVAL, SYSDATE, p_cuenta_origen, p_cuenta_destino,
              p_monto, l_moneda, 'TRF', TRIM(p_descripcion), l_ref, 'N')
      RETURNING trx_id INTO p_trx_id;
    EXCEPTION
      WHEN DUP_VAL_ON_INDEX THEN
        -- Carrera de homologos: la UK uk_core_trx_reference detecto el duplicado
        RAISE_APPLICATION_ERROR(
          c_err_trx_referencia_duplicada,
          'Referencia ' || l_ref || ' registrada concurrentemente por otra operacion.');
    END;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO sp_transferencia;
      RAISE;
  END transferir;

  ---------------------------------------------------------------------
  -- C (bonus): reversa de una transferencia
  ---------------------------------------------------------------------
  PROCEDURE revertir (
    p_trx_id         IN  core_trx.trx_id%TYPE,
    p_trx_id_reversa OUT core_trx.trx_id%TYPE) IS

    l_debito    core_trx.debit_account_no%TYPE;
    l_haber     core_trx.credit_account_no%TYPE;
    l_monto     core_trx.amount%TYPE;
    l_moneda    core_trx.currency%TYPE;
    l_tipo      core_trx.trx_type%TYPE;
    l_flag      core_trx.reversal_flag%TYPE;
    l_reversada core_trx.reversed_trx_id%TYPE;
    l_cnt       PLS_INTEGER;
    l_primero   t_cuenta_rec;
    l_segundo   t_cuenta_rec;
    l_cuenta_prim core_account.account_no%TYPE;
    l_cuenta_seg  core_account.account_no%TYPE;
  BEGIN
    SAVEPOINT sp_revertir;

    SELECT debit_account_no, credit_account_no, amount, currency,
           trx_type, reversal_flag, reversed_trx_id
      INTO l_debito, l_haber, l_monto, l_moneda, l_tipo, l_flag, l_reversada
      FROM core_trx
     WHERE trx_id = p_trx_id
       FOR UPDATE;

    IF l_tipo <> 'TRF' THEN
      RAISE_APPLICATION_ERROR(
        c_err_trx_no_reversible,
        'Solo se reversan transferencias (tipo TRF); el movimiento ' ||
        p_trx_id || ' es tipo ' || l_tipo || '.');
    END IF;
    IF l_flag = 'S' THEN
      RAISE_APPLICATION_ERROR(
        c_err_trx_no_reversible,
        'El movimiento ' || p_trx_id || ' ya es una reversa.');
    END IF;
    IF l_reversada IS NOT NULL THEN
      RAISE_APPLICATION_ERROR(
        c_err_trx_no_reversible,
        'El movimiento ' || p_trx_id || ' ya fue revertido.');
    END IF;

    SELECT COUNT(*)
      INTO l_cnt
      FROM core_trx
     WHERE reversed_trx_id = p_trx_id
       AND reversal_flag   = 'S';

    IF l_cnt > 0 THEN
      RAISE_APPLICATION_ERROR(
        c_err_trx_no_reversible,
        'El movimiento ' || p_trx_id || ' ya fue revertido por otro id.');
    END IF;

    -- Bloqueo consistente de las cuentas intervinientes
    l_cuenta_prim := LEAST(l_debito, l_haber);
    l_cuenta_seg  := GREATEST(l_debito, l_haber);
    bloquear_cuenta(l_cuenta_prim, l_primero);
    bloquear_cuenta(l_cuenta_seg,  l_segundo);

    -- Movimiento REV: invierte las cuentas del original
    INSERT INTO core_trx (trx_id, trx_date, debit_account_no, credit_account_no,
                          amount, currency, trx_type, description, reference,
                          reversal_flag, reversed_trx_id)
    VALUES (seq_core_trx.NEXTVAL, SYSDATE, l_haber, l_debito,
            l_monto, l_moneda, 'REV',
            'Reversa de transferencia ' || p_trx_id, NULL,
            'S', p_trx_id)
    RETURNING trx_id INTO p_trx_id_reversa;

    -- Restitucion de saldos
    UPDATE core_account
       SET balance = balance + l_monto
     WHERE account_no = l_debito;

    UPDATE core_account
       SET balance = balance - l_monto
     WHERE account_no = l_haber;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO sp_revertir;
      RAISE;
  END revertir;

END pkg_core_settlement;
/
SHOW ERROR

PROMPT Body PKG_CORE_SETTLEMENT compilado.
