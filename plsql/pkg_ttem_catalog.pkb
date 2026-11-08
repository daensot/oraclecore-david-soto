-- =====================================================================
-- A.2 / A.3 / A.4 - Body del package de catalogos TTEM
-- Reglas de implementacion:
--   * Cero SQL dinamico concatenado: si se requeriera SQL dinamico, sera
--     exclusivamente con bind variables.
--   * WHEN OTHERS solo revierte (ROLLBACK TO savepoint) y relanza:
--     prohibido ocultar errores.
--   * Validaciones A.3: existencia de catalogo/item, duplicados,
--     vigencias y datos obligatorios.
-- =====================================================================
SET DEFINE OFF

CREATE OR REPLACE PACKAGE BODY pkg_ttem_catalog AS

  ---------------------------------------------------------------------
  -- A.3 - Validaciones privadas (levantan excepciones propias)
  ---------------------------------------------------------------------
  PROCEDURE validar_catalogo (
    p_catalogo_id      IN ttem_catalog.catalog_id%TYPE,
    p_debe_estar_activo IN BOOLEAN DEFAULT FALSE) IS
    l_cnt    PLS_INTEGER;
    l_estado ttem_catalog.status%TYPE;
  BEGIN
    SELECT COUNT(*), MAX(status)
      INTO l_cnt, l_estado
      FROM ttem_catalog
     WHERE catalog_id = p_catalogo_id;

    IF l_cnt = 0 THEN
      RAISE_APPLICATION_ERROR(
        c_err_catalogo_no_existe,
        'El catalogo ' || TO_CHAR(p_catalogo_id) || ' no existe.');
    END IF;

    IF p_debe_estar_activo AND l_estado <> 'A' THEN
      RAISE_APPLICATION_ERROR(
        c_err_catalogo_no_existe,
        'El catalogo ' || TO_CHAR(p_catalogo_id) ||
        ' no esta activo (estado ' || l_estado || ').');
    END IF;
  END validar_catalogo;

  PROCEDURE validar_item_existe (p_item_id IN ttem_item.item_id%TYPE) IS
    l_cnt PLS_INTEGER;
  BEGIN
    SELECT COUNT(*)
      INTO l_cnt
      FROM ttem_item
     WHERE item_id = p_item_id;

    IF l_cnt = 0 THEN
      RAISE_APPLICATION_ERROR(
        c_err_item_no_existe,
        'El item ' || TO_CHAR(p_item_id) || ' no existe.');
    END IF;
  END validar_item_existe;

  PROCEDURE validar_item_duplicado (
    p_catalogo_id IN ttem_item.catalog_id%TYPE,
    p_item_code   IN ttem_item.item_code%TYPE) IS
    l_cnt PLS_INTEGER;
  BEGIN
    SELECT COUNT(*)
      INTO l_cnt
      FROM ttem_item
     WHERE catalog_id = p_catalogo_id
       AND UPPER(TRIM(item_code)) = p_item_code;   -- el codigo ya llega normalizado

    IF l_cnt > 0 THEN
      RAISE_APPLICATION_ERROR(
        c_err_duplicado,
        'Ya existe un item con codigo ' || p_item_code ||
        ' en el catalogo ' || TO_CHAR(p_catalogo_id) || '.');
    END IF;
  END validar_item_duplicado;

  PROCEDURE validar_vigencia (
    p_vigencia_desde IN ttem_item.valid_from%TYPE,
    p_vigencia_hasta IN ttem_item.valid_to%TYPE) IS
  BEGIN
    IF p_vigencia_desde IS NOT NULL AND p_vigencia_hasta IS NOT NULL
       AND p_vigencia_hasta < p_vigencia_desde THEN
      RAISE_APPLICATION_ERROR(
        c_err_vigencia_invalida,
        'La vigencia "hasta" (' ||
        TO_CHAR(p_vigencia_hasta, 'YYYY-MM-DD') ||
        ') no puede ser anterior a la fecha "desde" (' ||
        TO_CHAR(p_vigencia_desde, 'YYYY-MM-DD') || ').');
    END IF;
  END validar_vigencia;

  PROCEDURE validar_estado (p_estado IN VARCHAR2) IS
  BEGIN
    IF p_estado IS NULL OR p_estado NOT IN ('A', 'I') THEN
      RAISE_APPLICATION_ERROR(
        c_err_dato_obligatorio,
        'El estado de un item debe ser A (activo) o I (inactivo): ''' ||
        NVL(p_estado, '(nulo)') || '''.');
    END IF;
  END validar_estado;

  ---------------------------------------------------------------------
  -- A.2 - Operacion nucleo (sin COMMIT): la reutilizan insertar_item
  -- e insertar_items, que deciden quien hace COMMIT.
  -- ---------------------------------------------------------------------
  PROCEDURE insertar_item_core (
    p_item_id        OUT ttem_item.item_id%TYPE,
    p_catalogo_id    IN  ttem_item.catalog_id%TYPE,
    p_item_code      IN  ttem_item.item_code%TYPE,
    p_item_name      IN  ttem_item.item_name%TYPE,
    p_item_value     IN  ttem_item.item_value%TYPE,
    p_orden          IN  ttem_item.display_order%TYPE,
    p_estado         IN  ttem_item.status%TYPE,
    p_vigencia_desde IN  ttem_item.valid_from%TYPE,
    p_vigencia_hasta IN  ttem_item.valid_to%TYPE) IS

    l_code  ttem_item.item_code%TYPE := UPPER(TRIM(p_item_code));
    l_name  ttem_item.item_name%TYPE := TRIM(p_item_name);
    l_value ttem_item.item_value%TYPE := TRIM(p_item_value);
  BEGIN
    -- Datos obligatorios (codigo y nombre no pueden quedar vacios)
    IF l_code IS NULL OR l_name IS NULL THEN
      RAISE_APPLICATION_ERROR(
        c_err_dato_obligatorio,
        'El codigo y el nombre del item son obligatorios.');
    END IF;

    validar_catalogo(p_catalogo_id, p_debe_estar_activo => TRUE);
    validar_estado(p_estado);
    validar_vigencia(p_vigencia_desde, p_vigencia_hasta);
    validar_item_duplicado(p_catalogo_id, l_code);

    INSERT INTO ttem_item (item_id, catalog_id, item_code, item_name,
                           item_value, display_order, status,
                           valid_from, valid_to)
    VALUES (seq_ttem_item.NEXTVAL, p_catalogo_id, l_code, l_name,
            l_value, p_orden, p_estado, p_vigencia_desde, p_vigencia_hasta)
    RETURNING item_id INTO p_item_id;
  END insertar_item_core;

  ---------------------------------------------------------------------
  -- A.2 - Mantenimiento de catalogos
  ---------------------------------------------------------------------
  PROCEDURE insertar_catalogo (
    p_catalogo_id    OUT ttem_catalog.catalog_id%TYPE,
    p_catalogo_code  IN  ttem_catalog.catalog_code%TYPE,
    p_catalogo_name  IN  ttem_catalog.catalog_name%TYPE,
    p_descripcion    IN  ttem_catalog.description%TYPE   DEFAULT NULL,
    p_estado         IN  ttem_catalog.status%TYPE        DEFAULT 'A') IS

    l_code ttem_catalog.catalog_code%TYPE := UPPER(TRIM(p_catalogo_code));
    l_name ttem_catalog.catalog_name%TYPE := TRIM(p_catalogo_name);
    l_cnt  PLS_INTEGER;
  BEGIN
    IF l_code IS NULL OR l_name IS NULL THEN
      RAISE_APPLICATION_ERROR(
        c_err_dato_obligatorio,
        'El codigo y el nombre del catalogo son obligatorios.');
    END IF;

    validar_estado(p_estado);

    SELECT COUNT(*)
      INTO l_cnt
      FROM ttem_catalog
     WHERE UPPER(TRIM(catalog_code)) = l_code;

    IF l_cnt > 0 THEN
      RAISE_APPLICATION_ERROR(
        c_err_duplicado,
        'Ya existe un catalogo con codigo ' || l_code || '.');
    END IF;

    SAVEPOINT sp_insert_catalogo;

    INSERT INTO ttem_catalog (catalog_id, catalog_code, catalog_name,
                              description, status)
    VALUES (seq_ttem_catalog.NEXTVAL, l_code, l_name,
            TRIM(p_descripcion), p_estado)
    RETURNING catalog_id INTO p_catalogo_id;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO sp_insert_catalogo;
      RAISE;
  END insertar_catalogo;

  PROCEDURE actualizar_catalogo (
    p_catalogo_id    IN  ttem_catalog.catalog_id%TYPE,
    p_catalogo_name  IN  ttem_catalog.catalog_name%TYPE  DEFAULT NULL,
    p_descripcion    IN  ttem_catalog.description%TYPE   DEFAULT NULL,
    p_estado         IN  ttem_catalog.status%TYPE        DEFAULT NULL) IS
  BEGIN
    SAVEPOINT sp_act_catalogo;

    validar_catalogo(p_catalogo_id);

    IF p_estado IS NOT NULL THEN
      validar_estado(p_estado);
    END IF;

    UPDATE ttem_catalog
       SET catalog_name = NVL(TRIM(p_catalogo_name), catalog_name),
           description  = NVL(TRIM(p_descripcion),  description),
           status       = NVL(p_estado, status)
     WHERE catalog_id = p_catalogo_id;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO sp_act_catalogo;
      RAISE;
  END actualizar_catalogo;

  ---------------------------------------------------------------------
  -- A.2 / A.3 - CRUD de items
  ---------------------------------------------------------------------
  PROCEDURE insertar_item (
    p_item_id        OUT ttem_item.item_id%TYPE,
    p_catalogo_id    IN  ttem_item.catalog_id%TYPE,
    p_item_code      IN  ttem_item.item_code%TYPE,
    p_item_name      IN  ttem_item.item_name%TYPE,
    p_item_value     IN  ttem_item.item_value%TYPE      DEFAULT NULL,
    p_orden          IN  ttem_item.display_order%TYPE   DEFAULT NULL,
    p_estado         IN  ttem_item.status%TYPE          DEFAULT 'A',
    p_vigencia_desde IN  ttem_item.valid_from%TYPE      DEFAULT NULL,
    p_vigencia_hasta IN  ttem_item.valid_to%TYPE        DEFAULT NULL) IS
  BEGIN
    SAVEPOINT sp_insert_item;

    insertar_item_core(p_item_id, p_catalogo_id, p_item_code, p_item_name,
                       p_item_value, p_orden, p_estado,
                       p_vigencia_desde, p_vigencia_hasta);

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO sp_insert_item;
      RAISE;
  END insertar_item;

  PROCEDURE actualizar_item (
    p_item_id        IN  ttem_item.item_id%TYPE,
    p_item_name      IN  ttem_item.item_name%TYPE       DEFAULT NULL,
    p_item_value     IN  ttem_item.item_value%TYPE      DEFAULT NULL,
    p_orden          IN  ttem_item.display_order%TYPE   DEFAULT NULL,
    p_estado         IN  ttem_item.status%TYPE          DEFAULT NULL,
    p_vigencia_desde IN  ttem_item.valid_from%TYPE      DEFAULT NULL,
    p_vigencia_hasta IN  ttem_item.valid_to%TYPE        DEFAULT NULL) IS

    l_desde_actual ttem_item.valid_from%TYPE;
    l_hasta_actual ttem_item.valid_to%TYPE;
  BEGIN
    SAVEPOINT sp_act_item;

    validar_item_existe(p_item_id);

    -- Coherencia de vigencias sobre los valores resultantes
    SELECT NVL(p_vigencia_desde, valid_from), NVL(p_vigencia_hasta, valid_to)
      INTO l_desde_actual, l_hasta_actual
      FROM ttem_item
     WHERE item_id = p_item_id;

    validar_vigencia(l_desde_actual, l_hasta_actual);

    IF p_estado IS NOT NULL THEN
      validar_estado(p_estado);
    END IF;

    UPDATE ttem_item
       SET item_name      = NVL(TRIM(p_item_name), item_name),
           item_value     = NVL(TRIM(p_item_value), item_value),
           display_order  = NVL(p_orden, display_order),
           status         = NVL(p_estado, status),
           valid_from     = l_desde_actual,
           valid_to       = l_hasta_actual
     WHERE item_id = p_item_id;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO sp_act_item;
      RAISE;
  END actualizar_item;

  -- Eliminacion LOGICA (decision documentada): deja el item en I.
  -- Idempotente: si ya estaba inactivo, la operacion no altera nada.
  PROCEDURE eliminar_item (
    p_item_id        IN  ttem_item.item_id%TYPE) IS
  BEGIN
    SAVEPOINT sp_del_item;

    validar_item_existe(p_item_id);

    UPDATE ttem_item
       SET status = 'I'
     WHERE item_id = p_item_id
       AND status  <> 'I';

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO sp_del_item;
      RAISE;
  END eliminar_item;

  ---------------------------------------------------------------------
  -- A.2 - Consultas con Object Types
  ---------------------------------------------------------------------
  FUNCTION obtener_item (
    p_item_id IN ttem_item.item_id%TYPE) RETURN typ_ttem_item IS
    l_item typ_ttem_item;
  BEGIN
    SELECT typ_ttem_item(item_id, item_code, item_name, item_value,
                         display_order, status, valid_from, valid_to)
      INTO l_item
      FROM ttem_item
     WHERE item_id = p_item_id;

    RETURN l_item;
  EXCEPTION
    WHEN NO_DATA_FOUND THEN
      RAISE_APPLICATION_ERROR(
        c_err_item_no_existe,
        'El item ' || TO_CHAR(p_item_id) || ' no existe.');
  END obtener_item;

  FUNCTION consultar_items (
    p_catalogo_id IN ttem_item.catalog_id%TYPE) RETURN typ_ttem_item_tab IS
    l_items typ_ttem_item_tab;
  BEGIN
    validar_catalogo(p_catalogo_id);

    SELECT typ_ttem_item(item_id, item_code, item_name, item_value,
                         display_order, status, valid_from, valid_to)
      BULK COLLECT INTO l_items
      FROM ttem_item
     WHERE catalog_id = p_catalogo_id
     ORDER BY display_order NULLS LAST, item_code;

    RETURN l_items;
  END consultar_items;

  -- Carga masiva simple con el Object Type como parametro de entrada:
  -- transaccion unica (un solo COMMIT al final).
  PROCEDURE insertar_items (
    p_catalogo_id IN  ttem_item.catalog_id%TYPE,
    p_items       IN  typ_ttem_item_tab) IS
    l_nuevo_id ttem_item.item_id%TYPE;
  BEGIN
    IF p_items IS NULL OR p_items.COUNT = 0 THEN
      RAISE_APPLICATION_ERROR(
        c_err_dato_obligatorio,
        'La coleccion de items a insertar viene vacia.');
    END IF;

    validar_catalogo(p_catalogo_id, p_debe_estar_activo => TRUE);

    SAVEPOINT sp_insert_items;

    FOR i IN 1 .. p_items.COUNT LOOP
      insertar_item_core(l_nuevo_id, p_catalogo_id,
                         p_items(i).item_code,
                         p_items(i).item_name,
                         p_items(i).item_value,
                         p_items(i).display_order,
                         NVL(p_items(i).status, 'A'),
                         p_items(i).valid_from,
                         p_items(i).valid_to);
    END LOOP;

    COMMIT;
  EXCEPTION
    WHEN OTHERS THEN
      ROLLBACK TO sp_insert_items;
      RAISE;
  END insertar_items;

  ---------------------------------------------------------------------
  -- A.4 - Consulta JSON por ItemId
  ---------------------------------------------------------------------
  PROCEDURE obtener_item_json (
    p_item_id IN  ttem_item.item_id%TYPE,
    p_json    OUT CLOB) IS

    l_json CLOB;
  BEGIN
    -- ItemId inexistente: excepcion propia (-20001), nunca JSON vacio
    validar_item_existe(p_item_id);

    SELECT JSON_OBJECT(
             'itemId'      VALUE i.item_id,
             'catalogId'   VALUE i.catalog_id,
             'catalogCode' VALUE c.catalog_code,
             'itemCode'    VALUE i.item_code,
             'name'        VALUE i.item_name,
             'value'       VALUE i.item_value,
             'status'      VALUE i.status,
             'validFrom'   VALUE TO_CHAR(i.valid_from, 'YYYY-MM-DD'),
             'validTo'     VALUE TO_CHAR(i.valid_to, 'YYYY-MM-DD')
             NULL ON NULL RETURNING CLOB)
      INTO l_json
      FROM ttem_item i
      JOIN ttem_catalog c ON c.catalog_id = i.catalog_id
     WHERE i.item_id = p_item_id;

    p_json := l_json;
  END obtener_item_json;

END pkg_ttem_catalog;
/
SHOW ERROR

PROMPT Body PKG_TTEM_CATALOG compilado.
