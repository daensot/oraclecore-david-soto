-- =====================================================================
-- Anexo B.1 - Creacion del usuario de desarrollo CORE_DEV
-- Ejecutar conectado como SYSTEM al PDB:
-- Oracle Database 23ai Free : FREEPDB1
-- Oracle Database XE 21c : XEPDB1
-- La contrasena se solicita en tiempo de ejecucion (no queda en el script).
-- =====================================================================
SET VERIFY OFF
SET DEFINE ON
ACCEPT app_password CHAR PROMPT 'Contrasena para el usuario CORE_DEV: ' HIDE
CREATE USER core_dev IDENTIFIED BY "&app_password"
DEFAULT TABLESPACE users
QUOTA UNLIMITED ON users;
GRANT CREATE SESSION, CREATE TABLE, CREATE VIEW, CREATE SEQUENCE,
CREATE PROCEDURE, CREATE TYPE, CREATE TRIGGER
TO core_dev;
PROMPT Usuario CORE_DEV creado correctamente.

