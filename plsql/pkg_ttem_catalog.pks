-- =====================================================================
-- A.2 / A.3 / A.4 - Spec del package de catalogos TTEM
-- API clara (operaciones pequeñas y validadas, no un bloque extenso).
--
-- Decisiones documentadas (ver README y AI-LOG):
--   * Eliminacion LOGICA de items (status = 'I'): preserva trazabilidad
--     y es coherente con el modelo de estados del core.
--   * El package controla la transaccion del CRUD: SAVEPOINT al inicio,
--     COMMIT al terminar y ROLLBACK TO SAVEPOINT + relanzar ante error.
--   * JSON solo con funciones nativas (JSON_OBJECT ... RETURNING CLOB).
--   * Incluye Object Type typ_ttem_item / typ_ttem_item_tab en la API:
--       - retorno de FUNCION consultar_items
--       - parametro de entrada del PROCEDURE insertar_items
-- =====================================================================
SET DEFINE OFF

CREATE OR REPLACE PACKAGE pkg_ttem_catalog AS

  -- -------------------------------------------------------------------
  -- A.3 - Codigo y excepciones propias con significado de negocio
  -- (rango propio definido entre -20000 y -20999: reservado -20000..-20029)
  -- -------------------------------------------------------------------
  c_err_item_no_existe     CONSTANT PLS_INTEGER := -20001;
  c_err_catalogo_no_existe CONSTANT PLS_INTEGER := -20002;
  c_err_duplicado          CONSTANT PLS_INTEGER := -20003;
  c_err_vigencia_invalida  CONSTANT PLS_INTEGER := -20004;
  c_err_dato_obligatorio   CONSTANT PLS_INTEGER := -20005;

  e_item_no_existe     EXCEPTION; PRAGMA EXCEPTION_INIT(e_item_no_existe,     -20001);
  e_catalogo_no_existe EXCEPTION; PRAGMA EXCEPTION_INIT(e_catalogo_no_existe, -20002);
  e_duplicado          EXCEPTION; PRAGMA EXCEPTION_INIT(e_duplicado,          -20003);
  e_vigencia_invalida  EXCEPTION; PRAGMA EXCEPTION_INIT(e_vigencia_invalida,  -20004);
  e_dato_obligatorio   EXCEPTION; PRAGMA EXCEPTION_INIT(e_dato_obligatorio,   -20005);

  -- -------------------------------------------------------------------
  -- A.2 - Mantenimiento de catalogos
  -- -------------------------------------------------------------------
  PROCEDURE insertar_catalogo (
    p_catalogo_id    OUT ttem_catalog.catalog_id%TYPE,
    p_catalogo_code  IN  ttem_catalog.catalog_code%TYPE,
    p_catalogo_name  IN  ttem_catalog.catalog_name%TYPE,
    p_descripcion    IN  ttem_catalog.description%TYPE   DEFAULT NULL,
    p_estado         IN  ttem_catalog.status%TYPE        DEFAULT 'A');

  -- Estado NULL en un parametro significa: no modificar el atributo
  PROCEDURE actualizar_catalogo (
    p_catalogo_id    IN  ttem_catalog.catalog_id%TYPE,
    p_catalogo_name  IN  ttem_catalog.catalog_name%TYPE  DEFAULT NULL,
    p_descripcion    IN  ttem_catalog.description%TYPE   DEFAULT NULL,
    p_estado         IN  ttem_catalog.status%TYPE        DEFAULT NULL);

  PROCEDURE insertar_item (
    p_item_id        OUT ttem_item.item_id%TYPE,
    p_catalogo_id    IN  ttem_item.catalog_id%TYPE,
    p_item_code      IN  ttem_item.item_code%TYPE,
    p_item_name      IN  ttem_item.item_name%TYPE,
    p_item_value     IN  ttem_item.item_value%TYPE      DEFAULT NULL,
    p_orden          IN  ttem_item.display_order%TYPE   DEFAULT NULL,
    p_estado         IN  ttem_item.status%TYPE          DEFAULT 'A',
    p_vigencia_desde IN  ttem_item.valid_from%TYPE      DEFAULT NULL,
    p_vigencia_hasta IN  ttem_item.valid_to%TYPE        DEFAULT NULL);

  PROCEDURE actualizar_item (
    p_item_id        IN  ttem_item.item_id%TYPE,
    p_item_name      IN  ttem_item.item_name%TYPE       DEFAULT NULL,
    p_item_value     IN  ttem_item.item_value%TYPE      DEFAULT NULL,
    p_orden          IN  ttem_item.display_order%TYPE   DEFAULT NULL,
    p_estado         IN  ttem_item.status%TYPE          DEFAULT NULL,
    p_vigencia_desde IN  ttem_item.valid_from%TYPE      DEFAULT NULL,
    p_vigencia_hasta IN  ttem_item.valid_to%TYPE        DEFAULT NULL);

  -- Eliminacion LOGICA: no elimina filas, marca status = 'I' (idempotente)
  PROCEDURE eliminar_item (
    p_item_id        IN  ttem_item.item_id%TYPE);

  -- -------------------------------------------------------------------
  -- A.2 - Consulta con Object Types en la API
  -- -------------------------------------------------------------------

  -- Devuelve el Item como Object Type; exige existencia (A.3)
  FUNCTION obtener_item (
    p_item_id        IN  ttem_item.item_id%TYPE) RETURN typ_ttem_item;

  -- Devuelve la coleccion de items de un catalogo (orden de presentacion)
  FUNCTION consultar_items (
    p_catalogo_id    IN  ttem_item.catalog_id%TYPE) RETURN typ_ttem_item_tab;

  -- A.2 - Carga de varios items usando el Object Type como entrada
  PROCEDURE insertar_items (
    p_catalogo_id    IN  ttem_item.catalog_id%TYPE,
    p_items          IN  typ_ttem_item_tab);

  -- -------------------------------------------------------------------
  -- A.4 - Consulta JSON por ItemId (contrato del enunciado)
  -- Atributos exactos: itemId, catalogId, catalogCode, itemCode, name,
  -- value, status, validFrom, validTo. Fechas YYYY-MM-DD y null de JSON
  -- explicito (NULL ON NULL). ItemId inexistente levanta la excepcion
  -- propia E_ITEM_NO_EXISTE (-20001); nunca CLOB nulo ni JSON vacio.
  -- -------------------------------------------------------------------
  PROCEDURE obtener_item_json (
    p_item_id        IN  ttem_item.item_id%TYPE,
    p_json           OUT CLOB);

END pkg_ttem_catalog;
/
SHOW ERROR

PROMPT Spec PKG_TTEM_CATALOG creada.
