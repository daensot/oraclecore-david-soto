-- =====================================================================
-- Seccion B - Consulta de cliente por numero de cuenta
-- Recibe el numero de cuenta por variable de sustitucion y devuelve
-- UNA fila por cuenta (o cero filas si la cuenta no existe).
--
-- Comportamiento ante cuenta inexistente (documentado en README):
-- la consulta devuelve 0 filas y no genera error.
-- =====================================================================
SET DEFINE ON
SET LINESIZE 200
SET PAGESIZE 100

ACCEPT p_cuenta CHAR PROMPT 'Numero de cuenta (ej. 1910001000011): '

SELECT a.account_no,
       a.product_type   AS producto,
       a.currency       AS moneda,
       a.balance        AS saldo,
       a.status         AS estado_cuenta,
       c.customer_id,
       CASE
         WHEN c.person_type = 'N' THEN 'Natural'
         WHEN c.person_type = 'J' THEN 'Juridica'
         ELSE 'No registrada'
       END                                         AS tipo_persona,
       c.doc_type                                  AS tipo_doc,
       c.doc_number                                AS nro_doc,
       CASE
         WHEN c.person_type = 'N' THEN
           TRIM(REGEXP_REPLACE(TRIM(c.first_name) || ' ' || TRIM(c.last_name),
                               ' {2,}', ' '))
         WHEN c.person_type = 'J' THEN
           TRIM(REGEXP_REPLACE(c.business_name, ' {2,}', ' '))
         ELSE NULL
       END                                         AS nombre_cliente,
       CASE
         WHEN c.person_type = 'N' AND c.birth_date IS NOT NULL
             THEN 'Nacimiento'
         WHEN c.person_type = 'J' AND c.incorporation_date IS NOT NULL
             THEN 'Constitucion'
         ELSE 'No registrada'
       END                                         AS tipo_fecha_referencia,
       CASE
         WHEN c.person_type = 'N' THEN c.birth_date
         WHEN c.person_type = 'J' THEN c.incorporation_date
         ELSE NULL
       END                                         AS fecha_referencia,
       -- Usuarios de Banca en Linea consolidados en una sola columna
       -- con su estado; vacia (NULL) si el cliente no tiene usuarios.
       (SELECT LISTAGG(
                 u.username || ' (' ||
                 CASE u.status
                   WHEN 'A' THEN 'Activo'
                   WHEN 'B' THEN 'Bloqueado'
                   WHEN 'I' THEN 'Inactivo'
                   ELSE u.status
                 END || ')', '; ')
                WITHIN GROUP (ORDER BY u.username)
          FROM olb_user u
         WHERE u.customer_id = c.customer_id)      AS usuarios_olb
  FROM core_account a
  JOIN core_customer c ON c.customer_id = a.customer_id
 WHERE a.account_no = UPPER(TRIM('&p_cuenta'));

SET DEFINE OFF
