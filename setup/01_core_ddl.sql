-- =====================================================================
-- Anexo B.2 - Modelo de datos del core (contrato externo: NO MODIFICAR)
-- Ejecutar conectado como CORE_DEV.
-- =====================================================================
SET DEFINE OFF
CREATE TABLE core_customer (
customer_id NUMBER(10) NOT NULL,
person_type CHAR(1) NOT NULL,
doc_type VARCHAR2(5) NOT NULL,
doc_number VARCHAR2(20) NOT NULL,
first_name VARCHAR2(60),
last_name VARCHAR2(60),
business_name VARCHAR2(120),
birth_date DATE,
incorporation_date DATE,
email VARCHAR2(120),
status CHAR(1) DEFAULT 'A' NOT NULL,
created_at DATE DEFAULT SYSDATE NOT NULL,
CONSTRAINT pk_core_customer PRIMARY KEY (customer_id),
CONSTRAINT uk_core_customer_doc UNIQUE (doc_type, doc_number),
CONSTRAINT ck_core_customer_person_type CHECK (person_type IN ('N', 'J')),
CONSTRAINT ck_core_customer_status CHECK (status IN ('A', 'I'))
);
CREATE TABLE core_account (
account_no VARCHAR2(20) NOT NULL,
customer_id NUMBER(10) NOT NULL,
product_type VARCHAR2(3) NOT NULL,
currency CHAR(3) NOT NULL,
balance NUMBER(18,2) DEFAULT 0 NOT NULL,
status CHAR(1) DEFAULT 'A' NOT NULL,
opened_at DATE NOT NULL,
CONSTRAINT pk_core_account PRIMARY KEY (account_no),
CONSTRAINT fk_core_account_core_customer FOREIGN KEY (customer_id)
REFERENCES core_customer (customer_id),
CONSTRAINT ck_core_account_product_type CHECK (product_type IN ('AHO', 'CTE', 'INT')),
CONSTRAINT ck_core_account_currency CHECK (currency IN ('PEN', 'USD')),
CONSTRAINT ck_core_account_status CHECK (status IN ('A', 'B', 'C'))
);
CREATE INDEX ix_core_account_customer_id ON core_account (customer_id);
CREATE TABLE olb_user (
olb_user_id NUMBER(10) NOT NULL,
customer_id NUMBER(10) NOT NULL,
username VARCHAR2(40) NOT NULL,
status CHAR(1) DEFAULT 'A' NOT NULL,
last_login_at TIMESTAMP,
created_at DATE DEFAULT SYSDATE NOT NULL,
CONSTRAINT pk_olb_user PRIMARY KEY (olb_user_id),
CONSTRAINT uk_olb_user_username UNIQUE (username),
CONSTRAINT fk_olb_user_core_customer FOREIGN KEY (customer_id)
REFERENCES core_customer (customer_id),
CONSTRAINT ck_olb_user_status CHECK (status IN ('A', 'B', 'I'))
);
CREATE INDEX ix_olb_user_customer_id ON olb_user (customer_id);
CREATE TABLE core_trx (
trx_id NUMBER(12) NOT NULL,
trx_date DATE NOT NULL,
debit_account_no VARCHAR2(20) NOT NULL,
credit_account_no VARCHAR2(20) NOT NULL,
amount NUMBER(18,2) NOT NULL,
currency CHAR(3) NOT NULL,
trx_type VARCHAR2(3) NOT NULL,
description VARCHAR2(200),
reference VARCHAR2(40),
reversal_flag CHAR(1) DEFAULT 'N' NOT NULL,
reversed_trx_id NUMBER(12),
created_at TIMESTAMP DEFAULT SYSTIMESTAMP NOT NULL,
CONSTRAINT pk_core_trx PRIMARY KEY (trx_id),
CONSTRAINT uk_core_trx_reference UNIQUE (reference),
CONSTRAINT fk_core_trx_core_account_debit FOREIGN KEY (debit_account_no)
REFERENCES core_account (account_no),
CONSTRAINT fk_core_trx_core_account_credit FOREIGN KEY (credit_account_no)
REFERENCES core_account (account_no),
CONSTRAINT fk_core_trx_core_trx_reversed FOREIGN KEY (reversed_trx_id)
REFERENCES core_trx (trx_id),
CONSTRAINT ck_core_trx_amount CHECK (amount > 0),
CONSTRAINT ck_core_trx_accounts CHECK (debit_account_no <> credit_account_no),
CONSTRAINT ck_core_trx_trx_type CHECK (trx_type IN ('TRF', 'PAG', 'COM', 'REV')),
CONSTRAINT ck_core_trx_reversal CHECK (
(reversal_flag = 'N' AND reversed_trx_id IS NULL)
OR (reversal_flag = 'S' AND reversed_trx_id IS NOT NULL))
);
CREATE INDEX ix_core_trx_debit_account ON core_trx (debit_account_no, trx_date);
CREATE INDEX ix_core_trx_credit_account ON core_trx (credit_account_no, trx_date);
CREATE SEQUENCE seq_core_trx START WITH 1000 INCREMENT BY 1 NOCACHE;
CREATE TABLE ttem_item_stg (
stg_id NUMBER(10) NOT NULL,
load_batch VARCHAR2(20) NOT NULL,
catalog_code VARCHAR2(30),
item_code VARCHAR2(30),
item_name VARCHAR2(200),
item_value VARCHAR2(200),
valid_from_txt VARCHAR2(20),
valid_to_txt VARCHAR2(20),
processed_flag CHAR(1) DEFAULT 'N' NOT NULL,
processed_at DATE,
CONSTRAINT pk_ttem_item_stg PRIMARY KEY (stg_id),
CONSTRAINT ck_ttem_item_stg_processed CHECK (processed_flag IN ('N', 'S', 'E'))
);
PROMPT Modelo del core creado correctamente.

