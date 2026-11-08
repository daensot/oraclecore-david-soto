-- =====================================================================
-- Anexo B.3 - Datos de referencia del core
-- Ejecutar conectado como CORE_DEV, despues de 01_core_ddl.sql.
-- Algunos datos contienen inconsistencias INTENCIONALES (ver Anexo A).
-- =====================================================================
SET DEFINE OFF
-- Clientes
INSERT INTO core_customer (customer_id, person_type, doc_type, doc_number, first_name,
last_name, business_name, birth_date, incorporation_date, email, status)
VALUES (1, 'N', 'DNI', '45871236', 'Maria Fernanda', 'Quispe Rojas', NULL,
DATE '1988-04-12', NULL, 'mquispe@correo.pe', 'A');
INSERT INTO core_customer (customer_id, person_type, doc_type, doc_number, first_name,
last_name, business_name, birth_date, incorporation_date, email, status)
VALUES (2, 'N', 'DNI', '70123458', ' jose luis ', 'RAMIREZ TORRES', NULL, NULL, NULL,
NULL, 'A');
INSERT INTO core_customer (customer_id, person_type, doc_type, doc_number, first_name,
last_name, business_name, birth_date, incorporation_date, email, status)
VALUES (3, 'J', 'RUC', '20512345671', NULL, NULL, 'Inversiones Andinas S.A.C.', NULL,
DATE '2010-08-03', 'tesoreria@invandinas.pe', 'A');
INSERT INTO core_customer (customer_id, person_type, doc_type, doc_number, first_name,
last_name, business_name, birth_date, incorporation_date, email, status)
VALUES (4, 'J', 'RUC', '20601234568', NULL, NULL, 'Comercial Lima Norte E.I.R.L.', NULL,
NULL, NULL, 'A');
INSERT INTO core_customer (customer_id, person_type, doc_type, doc_number, first_name,
last_name, business_name, birth_date, incorporation_date, email, status)
VALUES (5, 'N', 'CE', '001234567', 'Ana Sofia', 'Mendoza Vargas', NULL, DATE '1995-11-30',
NULL, 'amendoza@correo.pe', 'A');
INSERT INTO core_customer (customer_id, person_type, doc_type, doc_number, first_name,
last_name, business_name, birth_date, incorporation_date, email, status)
VALUES (900, 'J', 'RUC', '20100000001', NULL, NULL, 'CUENTAS INTERNAS DEL BANCO', NULL,
DATE '1990-01-01', NULL, 'A');
-- Cuentas. balance = saldo actual; el historico de CORE_TRX es parcial
-- y no concilia con el saldo.
INSERT INTO core_account (account_no, customer_id, product_type, currency, balance, status,
opened_at)
VALUES ('1910001000011', 1, 'AHO', 'PEN', 5250.00, 'A', DATE '2018-02-10');
INSERT INTO core_account (account_no, customer_id, product_type, currency, balance, status,
opened_at)
VALUES ('1910001000029', 1, 'CTE', 'USD', 1200.00, 'A', DATE '2020-07-01');
INSERT INTO core_account (account_no, customer_id, product_type, currency, balance, status,
opened_at)
VALUES ('1910001000037', 1, 'AHO', 'PEN', 0, 'C', DATE '2015-03-20');
INSERT INTO core_account (account_no, customer_id, product_type, currency, balance, status,
opened_at)
VALUES ('1910002000017', 2, 'AHO', 'PEN', 350.50, 'A', DATE '2022-01-15');
INSERT INTO core_account (account_no, customer_id, product_type, currency, balance, status,
opened_at)
VALUES ('1910003000013', 3, 'CTE', 'PEN', 48900.00, 'A', DATE '2011-01-05');
INSERT INTO core_account (account_no, customer_id, product_type, currency, balance, status,
opened_at)
VALUES ('1910003000021', 3, 'CTE', 'USD', 15000.00, 'A', DATE '2011-01-05');
INSERT INTO core_account (account_no, customer_id, product_type, currency, balance, status,
opened_at)
VALUES ('1910004000019', 4, 'AHO', 'PEN', 0, 'B', DATE '2023-06-30');
INSERT INTO core_account (account_no, customer_id, product_type, currency, balance, status,
opened_at)
VALUES ('1910005000015', 5, 'AHO', 'USD', 800.00, 'A', DATE '2024-09-12');
INSERT INTO core_account (account_no, customer_id, product_type, currency, balance, status,
opened_at)
VALUES ('1919990000001', 900, 'INT', 'PEN', 0, 'A', DATE '2000-01-01');
-- Usuarios de Banca en Linea
INSERT INTO olb_user (olb_user_id, customer_id, username, status, last_login_at)
VALUES (1, 1, 'mquispe', 'A', TIMESTAMP '2026-10-20 08:15:00');
INSERT INTO olb_user (olb_user_id, customer_id, username, status, last_login_at)
VALUES (2, 3, 'invandinas.admin', 'A', TIMESTAMP '2026-10-22 17:40:00');
INSERT INTO olb_user (olb_user_id, customer_id, username, status, last_login_at)
VALUES (3, 3, 'invandinas.tesoreria', 'B', TIMESTAMP '2026-08-30 09:05:00');
INSERT INTO olb_user (olb_user_id, customer_id, username, status, last_login_at)
VALUES (4, 5, 'amendoza', 'I', NULL);
-- Movimientos contables. debit_account_no = cuenta del Debe (cargo);
-- credit_account_no = cuenta del Haber (abono).
INSERT INTO core_trx (trx_id, trx_date, debit_account_no, credit_account_no, amount,
currency, trx_type, description, reference, reversal_flag, reversed_trx_id)
VALUES (1, TO_DATE('2026-09-01 09:00', 'YYYY-MM-DD HH24:MI'), '1910003000013',
'1910001000011', 2500.00, 'PEN', 'TRF', 'Pago de haberes septiembre', 'REF-0001', 'N',
NULL);
INSERT INTO core_trx (trx_id, trx_date, debit_account_no, credit_account_no, amount,
currency, trx_type, description, reference, reversal_flag, reversed_trx_id)
VALUES (2, TO_DATE('2026-09-05 11:20', 'YYYY-MM-DD HH24:MI'), '1910001000011',
'1910002000017', 150.00, 'PEN', 'TRF', 'Transferencia a tercero', 'REF-0002', 'N',
NULL);
INSERT INTO core_trx (trx_id, trx_date, debit_account_no, credit_account_no, amount,
currency, trx_type, description, reference, reversal_flag, reversed_trx_id)
VALUES (3, TO_DATE('2026-09-10 15:45', 'YYYY-MM-DD HH24:MI'), '1910001000011',
'1910003000013', 320.75, 'PEN', 'PAG', 'Pago a proveedor', 'REF-0003', 'N', NULL);
INSERT INTO core_trx (trx_id, trx_date, debit_account_no, credit_account_no, amount,
currency, trx_type, description, reference, reversal_flag, reversed_trx_id)
VALUES (4, TO_DATE('2026-09-12 10:00', 'YYYY-MM-DD HH24:MI'), '1910001000011',
'1910002000017', 1000.00, 'PEN', 'TRF', 'Transferencia a tercero', 'REF-0004', 'N',
NULL);
INSERT INTO core_trx (trx_id, trx_date, debit_account_no, credit_account_no, amount,
currency, trx_type, description, reference, reversal_flag, reversed_trx_id)
VALUES (5, TO_DATE('2026-09-12 16:30', 'YYYY-MM-DD HH24:MI'), '1910002000017',
'1910001000011', 1000.00, 'PEN', 'REV', 'Reversa de transferencia REF-0004',
'REF-0005', 'S', 4);
INSERT INTO core_trx (trx_id, trx_date, debit_account_no, credit_account_no, amount,
currency, trx_type, description, reference, reversal_flag, reversed_trx_id)
VALUES (6, TO_DATE('2026-09-20 23:59', 'YYYY-MM-DD HH24:MI'), '1910001000011',
'1919990000001', 12.50, 'PEN', 'COM', 'Comision de mantenimiento', 'REF-0006', 'N',
NULL);
INSERT INTO core_trx (trx_id, trx_date, debit_account_no, credit_account_no, amount,
currency, trx_type, description, reference, reversal_flag, reversed_trx_id)
VALUES (7, TO_DATE('2026-10-01 09:00', 'YYYY-MM-DD HH24:MI'), '1910003000013',
'1910001000011', 2500.00, 'PEN', 'TRF', 'Pago de haberes octubre', 'REF-0007', 'N',
NULL);
INSERT INTO core_trx (trx_id, trx_date, debit_account_no, credit_account_no, amount,
currency, trx_type, description, reference, reversal_flag, reversed_trx_id)
VALUES (8, TO_DATE('2026-10-03 18:10', 'YYYY-MM-DD HH24:MI'), '1910001000011',
'1910002000017', 200.00, 'PEN', 'TRF', 'Transferencia a tercero', 'REF-0008', 'N',
NULL);
INSERT INTO core_trx (trx_id, trx_date, debit_account_no, credit_account_no, amount,
currency, trx_type, description, reference, reversal_flag, reversed_trx_id)
VALUES (9, TO_DATE('2026-10-15 12:00', 'YYYY-MM-DD HH24:MI'), '1910003000021',
'1910001000029', 500.00, 'USD', 'TRF', 'Transferencia en dolares', 'REF-0009', 'N',
NULL);
INSERT INTO core_trx (trx_id, trx_date, debit_account_no, credit_account_no, amount,
currency, trx_type, description, reference, reversal_flag, reversed_trx_id)
VALUES (10, TO_DATE('2026-10-20 23:59', 'YYYY-MM-DD HH24:MI'), '1910001000011',
'1919990000001', 12.50, 'PEN', 'COM', 'Comision de mantenimiento', 'REF-0010', 'N',
NULL);
INSERT INTO core_trx (trx_id, trx_date, debit_account_no, credit_account_no, amount,
currency, trx_type, description, reference, reversal_flag, reversed_trx_id)
VALUES (11, TO_DATE('2026-10-21 08:30', 'YYYY-MM-DD HH24:MI'), '1910002000017',
'1910001000011', 75.00, 'PEN', 'TRF', ' devolucion de prestamo personal ', NULL,
'N', NULL);
-- Lote de items de catalogo pendiente de carga (Seccion A.5).
-- Contiene errores intencionales.
INSERT INTO ttem_item_stg (stg_id, load_batch, catalog_code, item_code, item_name,
item_value, valid_from_txt, valid_to_txt)
VALUES (1, 'LOTE-2026-10', 'MONEDA', 'EUR', 'Euro', 'EUR', '2026-10-01', NULL);
INSERT INTO ttem_item_stg (stg_id, load_batch, catalog_code, item_code, item_name,
	item_value, valid_from_txt, valid_to_txt)
VALUES (2, 'LOTE-2026-10', 'MONEDA', 'GBP', 'Libra esterlina', 'GBP', '2026-10-01', NULL);
INSERT INTO ttem_item_stg (stg_id, load_batch, catalog_code, item_code, item_name,
item_value, valid_from_txt, valid_to_txt)
VALUES (3, 'LOTE-2026-10', 'TIPO_COMISION', 'COM_ATM',
'Comision por retiro en cajero de otra red', '8.00', '2026-10-01', '2026-12-31');
INSERT INTO ttem_item_stg (stg_id, load_batch, catalog_code, item_code, item_name,
item_value, valid_from_txt, valid_to_txt)
VALUES (4, 'LOTE-2026-10', 'TIPO_COMISION', 'COM_TRF_INT',
'Comision por transferencia interbancaria', '7.00', '2026-10-01', NULL);
INSERT INTO ttem_item_stg (stg_id, load_batch, catalog_code, item_code, item_name,
item_value, valid_from_txt, valid_to_txt)
VALUES (5, 'LOTE-2026-10', 'TIPO_COMISION', 'COM_TRF_INT',
'Comision por transferencia interbancaria', '7.50', '2026-11-01', NULL);
INSERT INTO ttem_item_stg (stg_id, load_batch, catalog_code, item_code, item_name,
item_value, valid_from_txt, valid_to_txt)
VALUES (6, 'LOTE-2026-10', 'TIPO_SEGURO', 'SEG_DESG', 'Seguro de desgravamen', '0.045',
'2026-10-01', NULL);
INSERT INTO ttem_item_stg (stg_id, load_batch, catalog_code, item_code, item_name,
item_value, valid_from_txt, valid_to_txt)
VALUES (7, 'LOTE-2026-10', 'MONEDA', NULL, 'Peso chileno', 'CLP', '2026-10-01', NULL);
INSERT INTO ttem_item_stg (stg_id, load_batch, catalog_code, item_code, item_name,
item_value, valid_from_txt, valid_to_txt)
VALUES (8, 'LOTE-2026-10', 'TIPO_COMISION', 'COM_SOB', NULL, '15,00', '2026-10-01', NULL);
INSERT INTO ttem_item_stg (stg_id, load_batch, catalog_code, item_code, item_name,
item_value, valid_from_txt, valid_to_txt)
VALUES (9, 'LOTE-2026-10', 'MONEDA', 'JPY', 'Yen japones', 'JPY', '2026-13-01', NULL);
INSERT INTO ttem_item_stg (stg_id, load_batch, catalog_code, item_code, item_name,
item_value, valid_from_txt, valid_to_txt)
VALUES (10, 'LOTE-2026-10', 'TIPO_COMISION', 'COM_EXT',
'Comision por retiro en el extranjero', '20.00', '2026-12-01', '2026-06-30');
INSERT INTO ttem_item_stg (stg_id, load_batch, catalog_code, item_code, item_name,
item_value, valid_from_txt, valid_to_txt)
VALUES (11, 'LOTE-2026-10', ' moneda', 'chf ', ' franco suizo ', 'CHF', '2026-10-01',
NULL);
INSERT INTO ttem_item_stg (stg_id, load_batch, catalog_code, item_code, item_name,
item_value, valid_from_txt, valid_to_txt)
VALUES (12, 'LOTE-2026-10', 'MONEDA', 'PEN', 'Sol', 'PEN', '2026-01-01', NULL);
COMMIT;
PROMPT Verificacion de carga (valores esperados entre parentesis):
SELECT 'CORE_CUSTOMER (6)' AS tabla, COUNT(*) AS filas FROM core_customer
UNION ALL SELECT 'CORE_ACCOUNT (9)', COUNT(*) FROM core_account
UNION ALL SELECT 'OLB_USER (4)', COUNT(*) FROM olb_user
UNION ALL SELECT 'CORE_TRX (11)', COUNT(*) FROM core_trx
UNION ALL SELECT 'TTEM_ITEM_STG (12)', COUNT(*) FROM ttem_item_stg;

