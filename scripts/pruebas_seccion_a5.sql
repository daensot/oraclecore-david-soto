-- =====================================================================
-- Prueba del A.5 (P2): carga del lote LOTE-2026-10 con PKG_TTEM_LOAD
-- Resultado de control esperado del enunciado: 5 cargados y 7 rechazados
-- (EUR, GBP, COM_ATM, COM_TRF_INT y CHF cargados; rechazados: stg 5
-- duplicado en lote, 6 catalogo inexistente, 7 codigo vacio, 8 nombre
-- vacio, 9 fecha invalida, 10 vigencia incoherente, 12 PEN duplicado).
-- Reinicio del staging incluido para poder reejecutar la prueba.
-- Codigo ASCII puro.
-- =====================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF
SET LINESIZE 200

PROMPT ==============================================================
PROMPT PASO 0: reinicio al estado base del enunciado (staging pendiente
PROMPT y sin el item EUR que queda de la prueba de la Seccion A)
PROMPT ==============================================================
DELETE FROM ttem_item WHERE item_code NOT IN ('PEN', 'USD', 'COM_MANT');
DELETE FROM ttem_load_error
 WHERE stg_id IN (SELECT stg_id FROM ttem_item_stg WHERE load_batch = 'LOTE-2026-10');
UPDATE ttem_item_stg
   SET processed_flag = 'N',
       processed_at   = NULL
 WHERE load_batch = 'LOTE-2026-10';
COMMIT;

PROMPT items TTEM antes de la carga (esperado 3):
SELECT COUNT(*) FROM ttem_item;

PROMPT ==============================================================
PROMPT PASO 1: procesar el lote (esperado: 5 cargados / 7 rechazados)
PROMPT ==============================================================
DECLARE
  l_cargados   PLS_INTEGER;
  l_rechazados PLS_INTEGER;
BEGIN
  pkg_ttem_load.procesar_lote(p_lote       => 'LOTE-2026-10',
                              p_cargados   => l_cargados,
                              p_rechazados => l_rechazados);
  DBMS_OUTPUT.PUT_LINE('cargados   = ' || l_cargados);
  DBMS_OUTPUT.PUT_LINE('rechazados = ' || l_rechazados);
END;
/

PROMPT ==============================================================
PROMPT PASO 1b: idempotencia (segunda corrida debe rechazar el lote
PROMPT SIN pendientes con ORA-20020, y no duplicar items)
PROMPT ==============================================================
DECLARE
  l_cargados   PLS_INTEGER;
  l_rechazados PLS_INTEGER;
BEGIN
  pkg_ttem_load.procesar_lote(p_lote       => 'LOTE-2026-10',
                              p_cargados   => l_cargados,
                              p_rechazados => l_rechazados);
  DBMS_OUTPUT.PUT_LINE('NUNCA deberia ejecutarse');
EXCEPTION
  WHEN pkg_ttem_load.e_lote_sin_pendientes THEN
    DBMS_OUTPUT.PUT_LINE('Segunda corrida correctamente rechazada: ' || SQLERRM);
END;
/

PROMPT ==============================================================
PROMPT PASO 2: verificacion (esperado: TTEM_ITEM 8 = 3 base + 5 del
PROMPT lote; staging S = 5 y E = 7; TTEM_LOAD_ERROR 7; audit log crece
PROMPT en 5 eventos I de la carga, mas eventos historicos previos)
PROMPT ==============================================================
SELECT 'TTEM_ITEM' AS tabla, COUNT(*) AS filas FROM ttem_item
UNION ALL SELECT 'TTEM_ITEM_STG S', COUNT(*) FROM ttem_item_stg WHERE processed_flag = 'S'
UNION ALL SELECT 'TTEM_ITEM_STG E', COUNT(*) FROM ttem_item_stg WHERE processed_flag = 'E'
UNION ALL SELECT 'TTEM_LOAD_ERROR',   COUNT(*) FROM ttem_load_error
UNION ALL SELECT 'TTEM_AUDIT_LOG',    COUNT(*) FROM ttem_audit_log;

PROMPT Items nuevos cargados (EUR, GBP, CHF mostrados; COM_ tambien):
SELECT i.catalog_id, c.catalog_code, i.item_code, i.item_name, i.item_value,
       TO_CHAR(i.valid_from, 'YYYY-MM-DD') AS valid_from,
       TO_CHAR(i.valid_to, 'YYYY-MM-DD') AS valid_to, i.status
  FROM ttem_item i JOIN ttem_catalog c ON c.catalog_id = i.catalog_id
 WHERE c.catalog_code IN ('MONEDA','TIPO_COMISION')
 ORDER BY c.catalog_code, i.item_code;

PROMPT ==============================================================
PROMPT PASO 3: detalle de los 7 rechazos en TTEM_LOAD_ERROR
PROMPT ==============================================================
SELECT e.stg_id, s.catalog_code, s.item_code, e.error_message
  FROM ttem_load_error e JOIN ttem_item_stg s ON s.stg_id = e.stg_id
 ORDER BY e.stg_id;

PROMPT Flag de procesamiento del staging (N/S/E):
SELECT stg_id, catalog_code, item_code, processed_flag,
       TO_CHAR(processed_at,'YYYY-MM-DD HH24:MI') AS processed_at
  FROM ttem_item_stg ORDER BY stg_id;
