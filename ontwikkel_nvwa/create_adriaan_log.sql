
CREATE TABLE adriaan_log (
  ID           NUMBER(10)    NOT NULL,
  logmsg  VARCHAR2(4000)  NOT NULL,
  clobwaarde);


ALTER TABLE adriaan_log ADD (
  CONSTRAINT pk_adriaan_log PRIMARY KEY (ID));

CREATE SEQUENCE seq_adriaan_log START WITH 1000;


CREATE OR REPLACE TRIGGER adriaan_log_bir
BEFORE INSERT ON adriaan_log
FOR EACH ROW

BEGIN
  SELECT seq_adriaan_log.NEXTVAL
  INTO   :new.id
  FROM   dual;
END;