-- =====================================================================
-- A.1 - Datos iniciales obligatorios:
--       Catalogo MONEDA con PEN y USD, y catalogo TIPO_COMISION con
--       COM_MANT. Sin tildes para evitar problemas de codificacion.
-- =====================================================================
SET DEFINE OFF

-- Catalogo MONEDA (catalog_id proveniente de seq_ttem_catalog)
INSERT INTO ttem_catalog (catalog_id, catalog_code, catalog_name, description, status)
  VALUES (seq_ttem_catalog.NEXTVAL, 'MONEDA', 'Monedas del core', 'Monedas soportadas por el core', 'A');

INSERT INTO ttem_catalog (catalog_id, catalog_code, catalog_name, description, status)
  VALUES (seq_ttem_catalog.NEXTVAL, 'TIPO_COMISION', 'Tipos de comision', 'Tipos de comision bancaria', 'A');

-- Items (item_id proveniente de seq_ttem_item)
INSERT INTO ttem_item (item_id, catalog_id, item_code, item_name, item_value,
                       display_order, status, valid_from, valid_to)
  VALUES (seq_ttem_item.NEXTVAL,
          (SELECT catalog_id FROM ttem_catalog WHERE catalog_code = 'MONEDA'),
          'PEN', 'Sol peruano', 'PEN', 1, 'A', DATE '2026-01-01', NULL);

INSERT INTO ttem_item (item_id, catalog_id, item_code, item_name, item_value,
                       display_order, status, valid_from, valid_to)
  VALUES (seq_ttem_item.NEXTVAL,
          (SELECT catalog_id FROM ttem_catalog WHERE catalog_code = 'MONEDA'),
          'USD', 'Dolar estadounidense', 'USD', 2, 'A', DATE '2026-01-01', NULL);

INSERT INTO ttem_item (item_id, catalog_id, item_code, item_name, item_value,
                       display_order, status, valid_from, valid_to)
  VALUES (seq_ttem_item.NEXTVAL,
          (SELECT catalog_id FROM ttem_catalog WHERE catalog_code = 'TIPO_COMISION'),
          'COM_MANT', 'Comision de mantenimiento', '12.50', 1, 'A', DATE '2026-01-01', NULL);

COMMIT;

PROMPT Verificacion de carga inicial TTEM_ (valores esperados entre parentesis):
SELECT 'TTEM_CATALOG (2)'    AS tabla, COUNT(*) AS filas FROM ttem_catalog
UNION ALL SELECT 'TTEM_ITEM (3)',            COUNT(*) FROM ttem_item
UNION ALL SELECT 'TTEM_AUDIT_LOG (3)',       COUNT(*) FROM ttem_audit_log;

PROMPT Contenido del catalogo MONEDA:
SELECT i.item_id, c.catalog_code, i.item_code, i.item_name, i.item_value, i.status,
       TO_CHAR(i.valid_from, 'YYYY-MM-DD') AS valid_from,
       TO_CHAR(i.valid_to, 'YYYY-MM-DD')   AS valid_to
  FROM ttem_item i
  JOIN ttem_catalog c ON c.catalog_id = i.catalog_id
 ORDER BY c.catalog_code, i.display_order;

PROMPT Ultimos eventos de la bitacora TTEM_AUDIT_LOG (auditoria, mejora A.1):
SELECT audit_log_id, item_id, action,
       TO_CHAR(changed_at, 'YYYY-MM-DD HH24:MI') AS changed_at,
       new_values
  FROM ttem_audit_log
 ORDER BY audit_log_id;

PROMPT Datos iniciales TTEM cargados correctamente.
