-- =====================================================================
-- A.5 (P2) - Tabla de errores de carga masiva TTEM_LOAD_ERROR
-- Registra cada rechazo del lote con su stg_id y el motivo, para que
-- un registro invalido NO interrumpa el procesamiento del lote.
-- =====================================================================
SET DEFINE OFF

CREATE TABLE ttem_load_error (
  load_error_id     NUMBER(10)        NOT NULL,
  stg_id            NUMBER(10)        NOT NULL,
  load_batch        VARCHAR2(20)      NOT NULL,
  error_message     VARCHAR2(400)     NOT NULL,
  created_at        DATE              DEFAULT SYSDATE NOT NULL,
  CONSTRAINT pk_ttem_load_error PRIMARY KEY (load_error_id),
  CONSTRAINT fk_ttem_load_error_stg FOREIGN KEY (stg_id)
     REFERENCES ttem_item_stg (stg_id)
);

CREATE INDEX ix_ttem_load_error_stg_id ON ttem_load_error (stg_id);

CREATE SEQUENCE seq_ttem_load_error START WITH 1 INCREMENT BY 1 NOCACHE;

PROMPT TTEM_LOAD_ERROR creada correctamente.
