-- =====================================================================
-- A.5 (P2) - Body del package de carga masiva PKG_TTEM_LOAD
-- Flujo:
--   1. BULK COLLECT (LIMIT 100) de registros pendientes del lote.
--   2. Normalizacion (TRIM/UPPER) y validacion por registro:
--      catalogo inexistente, codigo o nombre vacios, fecha invalida,
--      vigencia incoherente, duplicado con item existente o dentro del
--      mismo lote -> motivo de rechazo registrado en TTEM_LOAD_ERROR.
--   3. FORALL ... SAVE EXCEPTIONS inserta los validos (una carrera con
--      otro proceso que inserte la misma clave queda atrapado por la
--      constraint uk_ttem_item_catalog_code sin abortar el lote).
--   4. Staging actualizado: processed_flag = 'S' (cargado) o 'E'.
-- La transaccion la controla el PROCEDIMIENTO (SAVEPOINT + COMMIT;
-- ROLLBACK TO + RAISE ante error), como en la Seccion C.
-- =====================================================================
SET DEFINE OFF

CREATE OR REPLACE PACKAGE BODY pkg_ttem_load AS

  c_limite_bloque  CONSTANT PLS_INTEGER := 100;

  CURSOR c_stg (p_lote ttem_item_stg.load_batch%TYPE) IS
    SELECT stg_id, load_batch, catalog_code, item_code,
           item_name, item_value, valid_from_txt, valid_to_txt
      FROM ttem_item_stg
     WHERE load_batch = p_lote
       AND processed_flag = 'N'
     ORDER BY stg_id;

  TYPE t_rows IS TABLE OF c_stg%ROWTYPE;

  TYPE t_arr_stg IS TABLE OF ttem_item_stg.stg_id%TYPE INDEX BY PLS_INTEGER;
  TYPE t_arr_cat IS TABLE OF ttem_item.catalog_id%TYPE INDEX BY PLS_INTEGER;
  TYPE t_arr_code IS TABLE OF ttem_item.item_code%TYPE INDEX BY PLS_INTEGER;
  TYPE t_arr_name IS TABLE OF ttem_item.item_name%TYPE INDEX BY PLS_INTEGER;
  TYPE t_arr_val IS TABLE OF ttem_item.item_value%TYPE INDEX BY PLS_INTEGER;
  TYPE t_arr_date IS TABLE OF DATE INDEX BY PLS_INTEGER;
  TYPE t_arr_msg IS TABLE OF VARCHAR2(400) INDEX BY PLS_INTEGER;

  TYPE t_keys IS TABLE OF PLS_INTEGER INDEX BY VARCHAR2(200);

  e_bulk_exceptions EXCEPTION;
  PRAGMA EXCEPTION_INIT(e_bulk_exceptions, -24381);

  ---------------------------------------------------------------------
  -- Convierte la fecha en texto (YYYY-MM-DD) a DATE de forma segura.
  -- Un formato invalido levanta la excepcion propia -20019 (relanzada:
  -- prohibido ocultar errores); el bloque por registro decide entre
  -- rechazar el registro o seguir.
  ---------------------------------------------------------------------
  FUNCTION interpretar_fecha (p_txt IN VARCHAR2) RETURN DATE IS
  BEGIN
    IF p_txt IS NULL THEN
      RETURN NULL;
    END IF;
    RETURN TO_DATE(p_txt, 'YYYY-MM-DD');
  EXCEPTION
    WHEN OTHERS THEN
      RAISE_APPLICATION_ERROR(
        c_err_stg_fecha_invalida,
        'Fecha invalida (' || p_txt || '): se espera formato YYYY-MM-DD.');
  END interpretar_fecha;

  ---------------------------------------------------------------------
  -- A.5 - Procesamiento del lote
  ---------------------------------------------------------------------
  PROCEDURE procesar_lote (
    p_lote       IN  ttem_item_stg.load_batch%TYPE,
    p_cargados   OUT PLS_INTEGER,
    p_rechazados OUT PLS_INTEGER) IS

    l_rows        t_rows;
    l_pendientes  PLS_INTEGER;

    -- Colecciones de los registros VALIDOS para insertar con FORALL
    v_ok_stg   t_arr_stg;
    v_ok_cat   t_arr_cat;
    v_ok_code  t_arr_code;
    v_ok_name  t_arr_name;
    v_ok_val   t_arr_val;
    v_ok_from  t_arr_date;
    v_ok_to    t_arr_date;
    v_n_ok     PLS_INTEGER := 0;

    -- Colecciones de los registros RECHAZADOS
    v_err_stg  t_arr_stg;
    v_err_msg  t_arr_msg;
    v_n_err    PLS_INTEGER := 0;

    -- Mapa de claves (catalogo|codigo) ya vistas dentro del mismo lote
    v_keys     t_keys;

    -- Claves que fallaron en el FORALL (duplicidad por carrera, etc.)
    v_fallado  DBMS_SQL.NUMBER_TABLE;

    l_cat_id       ttem_catalog.catalog_id%TYPE;
    l_cnt_cat      PLS_INTEGER;
    l_cnt_dup      PLS_INTEGER;
    l_key          VARCHAR2(200);
    l_motivo       VARCHAR2(400);
    l_from         DATE;
    l_to           DATE;
    i              PLS_INTEGER;
    j              PLS_INTEGER;
    l_cargados_actual PLS_INTEGER;
  BEGIN
    SAVEPOINT sp_procesar_lote;

    SELECT COUNT(*)
      INTO l_pendientes
      FROM ttem_item_stg
     WHERE load_batch = p_lote
       AND processed_flag = 'N';

    IF l_pendientes = 0 THEN
      RAISE_APPLICATION_ERROR(
        c_err_lote_sin_pendientes,
        'El lote ' || p_lote || ' no tiene registros pendientes (flag N).');
    END IF;

    -- -------------------------------------------------------------
    -- 1) Carga por bloques con BULK COLLECT ... LIMIT
    -- -------------------------------------------------------------
    OPEN c_stg(p_lote);
    LOOP
      FETCH c_stg BULK COLLECT INTO l_rows LIMIT c_limite_bloque;
      EXIT WHEN l_rows.COUNT = 0;

      v_keys.DELETE;
      v_n_ok := 0;

      -- ---------------------------------------------------------
      -- 2) Normalizacion y validacion registro por registro
      -- ---------------------------------------------------------
      FOR k IN 1 .. l_rows.COUNT LOOP
        l_motivo := NULL;
        l_cat_id := NULL;
        l_from   := NULL;
        l_to     := NULL;

        DECLARE
          r        c_stg%ROWTYPE := l_rows(k);
          l_code   VARCHAR2(30)  := UPPER(TRIM(r.item_code));
          l_name   VARCHAR2(100) := TRIM(r.item_name);
          l_value  VARCHAR2(200) := TRIM(r.item_value);
          l_cat    VARCHAR2(30)  := UPPER(TRIM(r.catalog_code));
        BEGIN
          -- Codigos de catalogo e item obligatorios
          IF l_cat IS NULL THEN
            l_motivo := 'El codigo de catalogo es obligatorio.';
          ELSIF l_code IS NULL THEN
            l_motivo := 'El codigo de item es obligatorio (stg_id ' || r.stg_id || ').';
          ELSIF l_name IS NULL THEN
            l_motivo := 'El nombre de item es obligatorio (stg_id ' || r.stg_id || ').';
          END IF;

          -- Catalogo existente (normalizado)
          IF l_motivo IS NULL THEN
            SELECT COUNT(*), MAX(catalog_id)
              INTO l_cnt_cat, l_cat_id
              FROM ttem_catalog
             WHERE catalog_code = l_cat;

            IF l_cnt_cat = 0 THEN
              l_motivo := 'El catalogo ' || l_cat || ' no existe.';
            END IF;
          END IF;

          -- Fechas como texto YYYY-MM-DD (excepcion propia -20019)
          IF l_motivo IS NULL THEN
            BEGIN
              l_from := interpretar_fecha(TRIM(r.valid_from_txt));
            EXCEPTION
              WHEN e_stg_fecha_invalida THEN
                l_motivo := SQLERRM;
            END;
          END IF;
          IF l_motivo IS NULL THEN
            BEGIN
              l_to := interpretar_fecha(TRIM(r.valid_to_txt));
            EXCEPTION
              WHEN e_stg_fecha_invalida THEN
                l_motivo := SQLERRM;
            END;
          END IF;

          -- Coherencia de vigencias
          IF l_motivo IS NULL
             AND l_from IS NOT NULL AND l_to IS NOT NULL AND l_to < l_from THEN
            l_motivo := 'Vigencia incoherente: "hasta" (' ||
                        TO_CHAR(l_to, 'YYYY-MM-DD') ||
                        ') anterior a "desde" (' ||
                        TO_CHAR(l_from, 'YYYY-MM-DD') || ').';
          END IF;

          -- Duplicado dentro del mismo lote
          IF l_motivo IS NULL THEN
            l_key := l_cat || '|' || l_code;
            IF v_keys.EXISTS(l_key) THEN
              l_motivo := 'Item duplicado dentro del lote (' ||
                          l_cat || ' / ' || l_code || ').';
            ELSE
              v_keys(l_key) := 1;
            END IF;
          END IF;

          -- Duplicado contra un item existente del catalogo
          IF l_motivo IS NULL THEN
            SELECT COUNT(*)
              INTO l_cnt_dup
              FROM ttem_item
             WHERE catalog_id = l_cat_id
               AND UPPER(TRIM(item_code)) = l_code;

            IF l_cnt_dup > 0 THEN
              l_motivo := 'Item duplicado: ya existe ' || l_code ||
                          ' en el catalogo ' || l_cat || '.';
            END IF;
          END IF;

          -- Clasificacion del registro
          IF l_motivo IS NOT NULL THEN
            v_n_err := v_n_err + 1;
            v_err_stg(v_n_err) := r.stg_id;
            v_err_msg(v_n_err) := l_motivo;
          ELSE
            v_n_ok := v_n_ok + 1;
            v_ok_stg (v_n_ok) := r.stg_id;
            v_ok_cat (v_n_ok) := l_cat_id;
            v_ok_code(v_n_ok) := l_code;
            v_ok_name(v_n_ok) := l_name;
            v_ok_val (v_n_ok) := l_value;
            v_ok_from(v_n_ok) := l_from;
            v_ok_to  (v_n_ok) := l_to;
          END IF;
        END;
      END LOOP;

      -- ---------------------------------------------------------
      -- 3) Insercion masiva con FORALL ... SAVE EXCEPTIONS
      -- ---------------------------------------------------------
      IF v_n_ok > 0 THEN
        BEGIN
          FORALL i IN 1 .. v_n_ok SAVE EXCEPTIONS
            INSERT INTO ttem_item (item_id, catalog_id, item_code,
                                   item_name, item_value, display_order,
                                   status, valid_from, valid_to)
            VALUES (seq_ttem_item.NEXTVAL, v_ok_cat(i), v_ok_code(i),
                    v_ok_name(i), v_ok_val(i), NULL, 'A',
                    v_ok_from(i), v_ok_to(i));
        EXCEPTION
          WHEN e_bulk_exceptions THEN
            -- Un unico registro invalido NO interrumpe el lote:
            v_fallado.DELETE;
            FOR j IN 1 .. SQL%BULK_EXCEPTIONS.COUNT LOOP
              v_fallado(SQL%BULK_EXCEPTIONS(j).ERROR_INDEX) := 1;
              v_n_err := v_n_err + 1;
              v_err_stg(v_n_err) := v_ok_stg(SQL%BULK_EXCEPTIONS(j).ERROR_INDEX);
              v_err_msg(v_n_err) := 'Rechazo en insercion masiva (ORA-' ||
                                    TO_CHAR(-SQL%BULK_EXCEPTIONS(j).ERROR_CODE) ||
                                    '): registro duplicado por concurrencia o ' ||
                                    'violacion de integridad.';
            END LOOP;
        END;
      END IF;
    END LOOP;
    CLOSE c_stg;

    -- ---------------------------------------------------------
    -- 4) Log de rechazos y marcado del staging
    -- ---------------------------------------------------------
    IF v_n_err > 0 THEN
      FORALL j IN 1 .. v_n_err SAVE EXCEPTIONS
        INSERT INTO ttem_load_error (load_error_id, stg_id, load_batch, error_message)
        VALUES (seq_ttem_load_error.NEXTVAL, v_err_stg(j), p_lote, v_err_msg(j));
    END IF;

    l_cargados_actual := 0;
    FOR i IN 1 .. v_n_ok LOOP
      IF NOT v_fallado.EXISTS(i) THEN
        UPDATE ttem_item_stg
           SET processed_flag = 'S',
               processed_at   = SYSDATE
         WHERE stg_id = v_ok_stg(i);
        l_cargados_actual := l_cargados_actual + 1;
      END IF;
    END LOOP;

    FORALL j IN 1 .. v_n_err
      UPDATE ttem_item_stg
         SET processed_flag = 'E',
             processed_at   = SYSDATE
       WHERE stg_id = v_err_stg(j);

    COMMIT;

    p_cargados   := l_cargados_actual;
    p_rechazados := v_n_err;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO sp_procesar_lote;
      RAISE;
  END procesar_lote;

END pkg_ttem_load;
/
SHOW ERROR

PROMPT Body PKG_TTEM_LOAD compilado.
