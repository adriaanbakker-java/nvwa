
CREATE TABLE adriaan_log4 (
  ID           NUMBER(10)    NOT NULL,
  logmsg  VARCHAR2(50)  NOT NULL);


ALTER TABLE adriaan_log4 ADD (
  CONSTRAINT pk_adriaan_log4 PRIMARY KEY (ID));

CREATE SEQUENCE seq_adriaan_log4 START WITH 1000;


CREATE OR REPLACE TRIGGER adriaan_log4_bir
BEFORE INSERT ON adriaan_log4
FOR EACH ROW

BEGIN
  SELECT seq_adriaan_log4.NEXTVAL
  INTO   :new.id
  FROM   dual;
END;