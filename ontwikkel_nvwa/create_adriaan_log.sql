
CREATE TABLE adriaan_log3 (
  ID           NUMBER(10)    NOT NULL,
  logmsg  VARCHAR2(50)  NOT NULL);


ALTER TABLE adriaan_log3 ADD (
  CONSTRAINT pk_adriaan_log3 PRIMARY KEY (ID));

CREATE SEQUENCE seq_adriaan_log3 START WITH 1000;


CREATE OR REPLACE TRIGGER adriaan_log3_bir
BEFORE INSERT ON adriaan_log3
FOR EACH ROW

BEGIN
  SELECT seq_adriaan_log3.NEXTVAL
  INTO   :new.id
  FROM   dual;
END;