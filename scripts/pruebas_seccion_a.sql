-- =====================================================================
-- Pruebas de la Seccion A (A.2, A.3 y A.4) sobre PKG_TTEM_CATALOG
-- Demuestra los casos de verificacion definidos en specs/01.
-- Codigo ASCII puro para compatibilidad con cualquier cliente SQL.
-- =====================================================================
SET SERVEROUTPUT ON SIZE UNLIMITED
SET DEFINE OFF

PROMPT ==============================================================
PROMPT CASO 1: insertar_item OK (EUR, catalogo MONEDA)
PROMPT ==============================================================
DECLARE
  l_cat_id  ttem_catalog.catalog_id%TYPE;
  l_item_id ttem_item.item_id%TYPE;
BEGIN
  SELECT catalog_id INTO l_cat_id
    FROM ttem_catalog WHERE catalog_code = 'MONEDA';

  pkg_ttem_catalog.insertar_item(p_item_id        => l_item_id,
                                 p_catalogo_id    => l_cat_id,
                                 p_item_code      => ' eur ',
                                 p_item_name      => 'Euro',
                                 p_item_value     => 'EUR',
                                 p_orden          => 3,
                                 p_vigencia_desde => DATE '2026-02-01');
  DBMS_OUTPUT.PUT_LINE('OK - item creado con id ' || l_item_id);
END;
/

PROMPT ==============================================================
PROMPT CASO 2: insertar_item duplicado (EUR ya existe) -> -20003
PROMPT ==============================================================
DECLARE
  l_cat_id  ttem_catalog.catalog_id%TYPE;
  l_item_id ttem_item.item_id%TYPE;
BEGIN
  SELECT catalog_id INTO l_cat_id
    FROM ttem_catalog WHERE catalog_code = 'MONEDA';

  pkg_ttem_catalog.insertar_item(p_item_id   => l_item_id,
                                 p_catalogo_id => l_cat_id,
                                 p_item_code  => 'EUR',
                                 p_item_name  => 'Euro duplicado');
END;
/
-- (el bloque anterior debe terminar con ORA-20004 por codigo duplicado)
PROMPT (es esperado que la llamada anterior falle con ORA-20004)

PROMPT ==============================================================
PROMPT CASO 3: consulta JSON por ItemId (USD, mantener del lote inicial)
PROMPT ==============================================================
DECLARE
  l_item_id ttem_item.item_id%TYPE;
  l_json    CLOB;
BEGIN
  SELECT item_id INTO l_item_id
    FROM ttem_item WHERE item_code = 'USD'
   ORDER BY item_id FETCH FIRST 1 ROW ONLY;

  pkg_ttem_catalog.obtener_item_json(p_item_id => l_item_id,
                                     p_json    => l_json);
  DBMS_OUTPUT.PUT_LINE('JSON: ' || l_json);
END;
/

PROMPT ==============================================================
PROMPT CASO 4: consulta JSON por ItemId inexistente -> -20001
PROMPT ==============================================================
DECLARE
  l_json CLOB;
BEGIN
  pkg_ttem_catalog.obtener_item_json(p_item_id => 999999,
                                     p_json    => l_json);
  DBMS_OUTPUT.PUT_LINE('NUNCA deberia ejecutarse: ' || l_json);
END;
/
PROMPT (es esperado que la llamada anterior falle con ORA-20001)

PROMPT ==============================================================
PROMPT CASO 5: eliminar_item (eliminacion LOGICA) sobre el item EUR
PROMPT ==============================================================
DECLARE
  l_item_id  ttem_item.item_id%TYPE;
  l_estado   ttem_item.status%TYPE;
BEGIN
  SELECT item_id INTO l_item_id
    FROM ttem_item WHERE item_code = 'EUR'
   ORDER BY item_id DESC
   FETCH FIRST 1 ROW ONLY;

  pkg_ttem_catalog.eliminar_item(p_item_id => l_item_id);

  SELECT status INTO l_estado
    FROM ttem_item WHERE item_id = l_item_id;

  DBMS_OUTPUT.PUT_LINE('OK - item ' || l_item_id || ' antes estado '
                       || l_estado || ' (deberia tener una fila con estado I)');
END;
/

PROMPT ==============================================================
PROMPT CASO 6: funcion consultar_items con Object Types (catalogo MONEDA)
PROMPT ==============================================================
DECLARE
  l_cat_id ttem_catalog.catalog_id%TYPE;
  l_items  typ_ttem_item_tab;
BEGIN
  SELECT catalog_id INTO l_cat_id
    FROM ttem_catalog WHERE catalog_code = 'MONEDA';

  l_items := pkg_ttem_catalog.consultar_items(p_catalogo_id => l_cat_id);

  FOR i IN 1 .. l_items.COUNT LOOP
    DBMS_OUTPUT.PUT_LINE('item ' || l_items(i).item_id
                         || ' ' || RPAD(l_items(i).item_code, 5)
                         || ' orden=' || l_items(i).display_order
                         || ' estado=' || l_items(i).status);
  END LOOP;
  DBMS_OUTPUT.PUT_LINE('total items en coleccion: ' || l_items.COUNT);
END;
/
