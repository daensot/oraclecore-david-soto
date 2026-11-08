-- =====================================================================
-- A.1 - Modelo de catalogos TTEM_*  (tablas, constraints, secuencias,
--       auditoria y bitacora opcional TTEM_AUDIT_LOG)
-- Estandar Anexo C: PK_/FK_/UK_/CK_/IX_/SEQ_/TRG_ en minusculas
-- =====================================================================
SET DEFINE OFF

CREATE TABLE ttem_catalog (
  catalog_id        NUMBER(10)        NOT NULL,
  catalog_code      VARCHAR2(30)      NOT NULL,
  catalog_name      VARCHAR2(100)     NOT NULL,
  description       VARCHAR2(200),
  status            CHAR(1)           DEFAULT 'A' NOT NULL,
  created_by        VARCHAR2(30)      NOT NULL,
  created_at        DATE              DEFAULT SYSDATE NOT NULL,
  updated_by        VARCHAR2(30)      NOT NULL,
  updated_at        DATE              DEFAULT SYSDATE NOT NULL,
  CONSTRAINT pk_ttem_catalog PRIMARY KEY (catalog_id),
  CONSTRAINT uk_ttem_catalog_code UNIQUE (catalog_code),
  CONSTRAINT ck_ttem_catalog_status CHECK (status IN ('A', 'I'))
);

CREATE TABLE ttem_item (
  item_id           NUMBER(10)        NOT NULL,
  catalog_id        NUMBER(10)        NOT NULL,
  item_code         VARCHAR2(30)      NOT NULL,
  item_name         VARCHAR2(100)     NOT NULL,
  item_value        VARCHAR2(200),
  display_order     NUMBER(5),
  status            CHAR(1)           DEFAULT 'A' NOT NULL,
  valid_from        DATE,
  valid_to          DATE,
  created_by        VARCHAR2(30)      NOT NULL,
  created_at        DATE              DEFAULT SYSDATE NOT NULL,
  updated_by        VARCHAR2(30)      NOT NULL,
  updated_at        DATE              DEFAULT SYSDATE NOT NULL,
  CONSTRAINT pk_ttem_item PRIMARY KEY (item_id),
  -- Regla A.1: la fecha "hasta", cuando se informe, no es anterior a la "desde"
  CONSTRAINT ck_ttem_item_vigencia CHECK (
    valid_from IS NULL OR valid_to IS NULL OR valid_to >= valid_from),
  CONSTRAINT fk_ttem_item_ttem_catalog FOREIGN KEY (catalog_id)
     REFERENCES ttem_catalog (catalog_id),
  CONSTRAINT uk_ttem_item_catalog_code UNIQUE (catalog_id, item_code),
  CONSTRAINT ck_ttem_item_status CHECK (status IN ('A', 'I'))
);

CREATE INDEX ix_ttem_item_catalog_id ON ttem_item (catalog_id);

-- ---------------------------------------------------------------------
-- TTEM_AUDIT_LOG (A.1 mejora opcional): bitacora de inserciones,
-- actualizaciones y eliminaciones de items con valores anteriores y
-- nuevos en formato JSON. Llenada por el trigger TRG_TTEM_ITEM_LOG.
-- ---------------------------------------------------------------------
CREATE TABLE ttem_audit_log (
  audit_log_id      NUMBER(10)        NOT NULL,
  item_id           NUMBER(10)        NOT NULL,
  action            CHAR(1)           NOT NULL,
  old_values        CLOB,
  new_values        CLOB,
  changed_by        VARCHAR2(30)      NOT NULL,
  changed_at        DATE              DEFAULT SYSDATE NOT NULL,
  CONSTRAINT pk_ttem_audit_log PRIMARY KEY (audit_log_id),
  CONSTRAINT ck_ttem_audit_log_action CHECK (action IN ('I', 'U', 'D'))
);

CREATE INDEX ix_ttem_audit_log_item_id ON ttem_audit_log (item_id);

CREATE SEQUENCE seq_ttem_catalog START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_ttem_item    START WITH 1 INCREMENT BY 1 NOCACHE;
CREATE SEQUENCE seq_ttem_audit_log START WITH 1 INCREMENT BY 1 NOCACHE;

-- ---------------------------------------------------------------------
-- Auditoria automatica: usuario y fecha de creacion/ultima modificacion
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_ttem_catalog_aud
BEFORE INSERT OR UPDATE ON ttem_catalog
FOR EACH ROW
BEGIN
  :new.created_by := NVL(:new.created_by, USER);
  :new.created_at := NVL(:new.created_at, SYSDATE);
  :new.updated_by := USER;
  :new.updated_at := SYSDATE;
END;
/
SHOW ERROR

CREATE OR REPLACE TRIGGER trg_ttem_item_aud
BEFORE INSERT OR UPDATE ON ttem_item
FOR EACH ROW
BEGIN
  :new.created_by := NVL(:new.created_by, USER);
  :new.created_at := NVL(:new.created_at, SYSDATE);
  :new.updated_by := USER;
  :new.updated_at := SYSDATE;
END;
/
SHOW ERROR

-- ---------------------------------------------------------------------
-- Bitacora: registra INSERT/UPDATE/DELETE de items con valores
-- anteriores y nuevos (mejora opcional de A.1)
-- ---------------------------------------------------------------------
CREATE OR REPLACE TRIGGER trg_ttem_item_log
AFTER INSERT OR UPDATE OR DELETE ON ttem_item
FOR EACH ROW
DECLARE
  l_accion CHAR(1);
  l_old    CLOB;
  l_new    CLOB;
BEGIN
  IF INSERTING THEN
    l_accion := 'I';
    l_old    := NULL;
    l_new    := TO_CLOB(JSON_OBJECT(
                 'itemId'    VALUE :new.item_id,
                 'itemCode'  VALUE :new.item_code,
                 'itemName'  VALUE :new.item_name,
                 'itemValue' VALUE :new.item_value,
                 'status'    VALUE :new.status,
                 'validFrom' VALUE TO_CHAR(:new.valid_from, 'YYYY-MM-DD'),
                 'validTo'   VALUE TO_CHAR(:new.valid_to, 'YYYY-MM-DD')));
  ELSIF UPDATING THEN
    l_accion := 'U';
    l_old    := TO_CLOB(JSON_OBJECT(
                 'itemId'    VALUE :old.item_id,
                 'itemCode'  VALUE :old.item_code,
                 'itemName'  VALUE :old.item_name,
                 'itemValue' VALUE :old.item_value,
                 'status'    VALUE :old.status,
                 'validFrom' VALUE TO_CHAR(:old.valid_from, 'YYYY-MM-DD'),
                 'validTo'   VALUE TO_CHAR(:old.valid_to, 'YYYY-MM-DD')));
    l_new    := TO_CLOB(JSON_OBJECT(
                 'itemId'    VALUE :new.item_id,
                 'itemCode'  VALUE :new.item_code,
                 'itemName'  VALUE :new.item_name,
                 'itemValue' VALUE :new.item_value,
                 'status'    VALUE :new.status,
                 'validFrom' VALUE TO_CHAR(:new.valid_from, 'YYYY-MM-DD'),
                 'validTo'   VALUE TO_CHAR(:new.valid_to, 'YYYY-MM-DD')));
  ELSE
    l_accion := 'D';
    l_old    := TO_CLOB(JSON_OBJECT(
                 'itemId'    VALUE :old.item_id,
                 'itemCode'  VALUE :old.item_code,
                 'itemName'  VALUE :old.item_name,
                 'itemValue' VALUE :old.item_value,
                 'status'    VALUE :old.status,
                 'validFrom' VALUE TO_CHAR(:old.valid_from, 'YYYY-MM-DD'),
                 'validTo'   VALUE TO_CHAR(:old.valid_to, 'YYYY-MM-DD')));
    l_new    := NULL;
  END IF;

  INSERT INTO ttem_audit_log (audit_log_id, item_id, action,
                              old_values, new_values,
                              changed_by, changed_at)
  VALUES (seq_ttem_audit_log.NEXTVAL,
          NVL(:old.item_id, :new.item_id),
          l_accion,
          l_old,
          l_new,
          USER,
          SYSDATE);
END;
/
SHOW ERROR

PROMPT Modelo TTEM_* creado correctamente.
