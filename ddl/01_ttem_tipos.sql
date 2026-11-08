-- =====================================================================
-- A.1 / A.2 - Tipos de datos (Object Types) para catalogos TTEM
-- Estandar Anexo C: TYP_<NOMBRE> / TYP_<NOMBRE>_TAB
-- El Object Type se usa en la API del package PKG_TTEM_CATALOG:
--   * como retorno de FUNCION consultar_items (A.2)
--   * como parametro de entrada de PROCEDURE insertar_items (A.2)
-- =====================================================================
SET DEFINE OFF

CREATE OR REPLACE TYPE typ_ttem_item AS OBJECT (
  item_id        NUMBER(10),
  item_code      VARCHAR2(30),
  item_name      VARCHAR2(100),
  item_value     VARCHAR2(200),
  display_order  NUMBER(5),
  status         CHAR(1),
  valid_from     DATE,
  valid_to       DATE
);
/
SHOW ERROR

CREATE OR REPLACE TYPE typ_ttem_item_tab AS TABLE OF typ_ttem_item;
/
SHOW ERROR

PROMPT Tipos TTEM creados correctamente.
