-- =====================================================================
-- A.5 (P2) - Spec del package de carga masiva PKG_TTEM_LOAD
-- Procesa lotes de TTEM_ITEM_STG con:
--   * BULK COLLECT ... LIMIT (fetch por bloques de 100 registros)
--   * FORALL ... SAVE EXCEPTIONS (un registro invalido no interrumpe el lote)
-- Tolera la normalizacion de datos crudos: TRIM en todos los campos y
-- UPPER en los codigos; los codigos se guardan normalizados (UNIQUE
-- compuesta de uk_ttem_item_catalog_code garantiza la unicidad).
-- Los rechazos se registran en TTEM_LOAD_ERROR con el motivo y el
-- registro de staging queda marcado S (cargado) o E (rechazado).
-- =====================================================================
SET DEFINE OFF

CREATE OR REPLACE PACKAGE pkg_ttem_load AS

  -- Codigos propios del dominio de carga (dentro del rango -20010..-20029)
  c_err_lote_sin_pendientes         CONSTANT PLS_INTEGER := -20020;
  c_err_stg_fecha_invalida          CONSTANT PLS_INTEGER := -20019;

  e_lote_sin_pendientes EXCEPTION; PRAGMA EXCEPTION_INIT(e_lote_sin_pendientes, -20020);
  e_stg_fecha_invalida  EXCEPTION; PRAGMA EXCEPTION_INIT(e_stg_fecha_invalida,  -20019);

  PROCEDURE procesar_lote (
    p_lote        IN  ttem_item_stg.load_batch%TYPE,
    p_cargados    OUT PLS_INTEGER,
    p_rechazados  OUT PLS_INTEGER);

END pkg_ttem_load;
/
SHOW ERROR

PROMPT Spec PKG_TTEM_LOAD creada.
