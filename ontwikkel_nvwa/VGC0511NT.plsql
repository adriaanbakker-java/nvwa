CREATE OR REPLACE PACKAGE BODY VGC_WS_TRACES_NT IS

G_PACKAGE_NAME CONSTANT VARCHAR2(30) := 'VGC_WS_TRACES_NT#02';

V_OBJECTNAAM VARCHAR2(60);
/* Generieke controle van een bestaande request uit tabel VGC_REQUESTS. */
PROCEDURE CHECK_BESTAANDE_RQT
 (R_RQT IN OUT VGC_REQUESTS%ROWTYPE
 ,P_ERROR_HANDLING IN VARCHAR2 := 'J'
 );
PROCEDURE ESCAPE_XML
 (P_BERICHT IN OUT VGC_REQUESTS.WEBSERVICE_BERICHT%TYPE
 )
 IS
v_objectnaam   vgc_batchlog.proces%TYPE := g_package_name ||'.ESCAPE_XML#2';
/*********************************************************************
Wijzigingshistorie
doel:
Omzetten van bijzonderen tekens naar romaanse tekens

Versie  Wanneer     Wie            Wat
------- ----------  --------------------------------------------------
  2   05-11-2013  D.de Visser     Ampersant niet als teken, maar als variabele
  1   27-04-2013  G.L.Rijkers     Aanmaak
*********************************************************************/
  CURSOR c_char
  IS
    SELECT a.karakter_origineel
    ,      a.karakter_romaans
    FROM   vgc_karakter_vertaling a
    WHERE  land_code = 'XML'
  ;
--
  v_amp     VARCHAR2(1 CHAR) := CHR(38);
--
  FUNCTION fn_replace_clob  (p_lob IN CLOB
                            ,p_wat IN VARCHAR2
                            ,p_met IN VARCHAR2 := NULL  )
  RETURN CLOB
  IS
    v_watlen  PLS_INTEGER := LENGTH(p_wat);
    v_metlen  PLS_INTEGER := LENGTH(p_met);
    v_return  CLOB := empty_clob();
    v_segment CLOB := empty_clob();
    v_pos     PLS_INTEGER := 1 - v_metlen;
    v_offset  PLS_INTEGER := 1;
  --
  BEGIN
    IF p_wat IS NOT NULL
    THEN
      WHILE v_offset < DBMS_LOB.GETLENGTH(p_lob)
      LOOP
        v_segment := o2w_util.blob_to_clob(DBMS_LOB.SUBSTR(o2w_util.clob_to_blob(p_lob),32767,v_offset));
        LOOP
          v_pos := DBMS_LOB.INSTR(v_segment,p_wat,v_pos + v_metlen);
           EXIT WHEN (NVL(v_pos,0) = 0) OR (v_pos = 32767 - v_metlen);
          v_segment := TO_CLOB(DBMS_LOB.SUBSTR(v_segment,v_pos - 1)
                             ||p_met
                             ||DBMS_LOB.SUBSTR(v_segment,32767 - v_watlen - v_pos - v_watlen + 1, v_pos + v_watlen)
                               );
        END LOOP;
        v_return := v_return||v_segment;
        IF v_pos = 0
        THEN
          v_offset := v_offset + 32767;
        ELSE
           v_offset := v_offset + 32767 - v_watlen;
         END IF;
      END LOOP;
    END IF;
    --
    RETURN( v_return );
  END;
BEGIN
 FOR r_char IN c_char
 LOOP
   p_bericht := fn_replace_clob(p_bericht, r_char.karakter_origineel, v_amp||'#'||r_char.karakter_romaans||';');

 END LOOP;
END escape_xml;
PROCEDURE TRACE
 (P_PROCEDURE IN varchar2
 )
 IS
/*********************************************************************
Wijzigingshistorie
doel:
Debug informatie verschaffen aan ontwikkelaars

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  1     05-08-2003 JVI     creatie
*********************************************************************/
--
BEGIN
  qms$errors.show_debug_info (g_package_name||'.'||p_procedure );
  RETURN;
END trace;
/* Bepaal de URL voor het aanroepen van het betreffende scherm van Traces */
FUNCTION GET_URL_TRACES
 (I_TRACES_ID IN VGC_PARTIJEN.TRACES_CERTIFICAAT_ID%TYPE
 ,I_TYPE IN VGC_PARTIJEN.PTJ_TYPE%TYPE
 )
 RETURN VARCHAR2
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.GET_URL_TRACES#1';
/*********************************************************************
Wijzigingshistorie
doel:
Bepaal de URL voor het aanroepen van het betreffende scherm van Traces

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  1     16-11-2010 GTI     bvg BBO101116
*********************************************************************/
--
  v_url        VARCHAR2 (4000 CHAR);
--
BEGIN
  vgc_blg.write_log ('Start', v_objectnaam, 'J', 1);
  vgc_blg.write_log ('I_TRACES_ID: '||I_TRACES_ID, v_objectnaam, 'J', 5);
  vgc_blg.write_log ('I_TYPE: '||I_TYPE, v_objectnaam, 'J', 5);
  -- Haal parameters op om de URL samen te stellen voor het Tracesscherm
  IF i_type = 'LPJ'
  THEN
    v_url := vgc$algemeen.get_appl_register ('TRACES_LEVEND_URL');
  ELSIF i_type = 'NPJ'
  THEN
    v_url := vgc$algemeen.get_appl_register ('TRACES_PRODUCT_URL');
  ELSE
    raise_application_error (-20000, 'Ongeldige waarde voor i_type ontvangen!');
  END IF;
  --
  v_url := v_url||i_traces_id;
  --
  vgc_blg.write_log ('URL: '||V_URL, v_objectnaam, 'J', 5);
  vgc_blg.write_log ('Einde', v_objectnaam, 'J', 1);
  RETURN v_url;
EXCEPTION
  WHEN OTHERS
  THEN
    vgc_blg.write_log (substr('Exception: ' || SQLERRM, 1, 2000), v_objectnaam, 'N', 1);
    RAISE;
END get_url_traces;
/* Synchroniseer GN-codes */
PROCEDURE VGC0501NT
 (P_TYPE IN VGC_COLLI.CLO_TYPE%TYPE
  )
 IS
v_objectnaam            vgc_batchlog.proces%TYPE                 := g_package_name || '.VGC0501NT#1';
/*********************************************************************
Wijzigingshistorie
doel:
Synchroniseren van GN-Codes

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  1     31-12-2019 GLR     creatie
*********************************************************************/
  CURSOR c_lock
  IS
    SELECT 1
    FROM   vgc_applicatie_registers arr
    WHERE   arr.variabele = 'TNT_USERNAME'
    FOR UPDATE NOWAIT
  ;
--
  k_animals               CONSTANT VARCHAR2(5 CHAR)                        := 'cheda';
  k_animalproducts        CONSTANT VARCHAR2(5 CHAR)                        := 'chedp';
  k_nonanimalproducts     CONSTANT VARCHAR2(5 CHAR)                        := 'chedd';
  k_fytoproducts          CONSTANT VARCHAR2(6 CHAR)                        := 'chedpp';
--
  l_timestamp_char        VARCHAR2(100);
  l_trx_timestamp_char    VARCHAR2(100);
  v_username              VARCHAR2(100);
  v_password              VARCHAR2(100);
  l_CreateTimestampString VARCHAR2(100);
  l_ExpireTimestampString VARCHAR2(100);
  v_timestamp             TIMESTAMP;
  l_nonce_raw             RAW(100);
  l_nonce_b64             VARCHAR2(24);
  l_password_digest_b64   VARCHAR2(100);
--
--
  k_laatste_sync_var CONSTANT  vgc_applicatie_registers.variabele%TYPE := 'VGC0501NT_LAATSTE_SYNC';
  v_laatste_sync               vgc_applicatie_registers.waarde%TYPE    := vgc$algemeen.get_appl_register(k_laatste_sync_var);
  v_server_side_date           vgc_applicatie_registers.waarde%TYPE    := NULL;
  v_antwoord                   xmltype;
  v_ws_naam               VARCHAR2(100 CHAR)                                := 'retrieveReferenceData';
  r_rqt                        vgc_requests%ROWTYPE;
  -- cursor voor lock zodat niet twee synchronisaties tegelijk kunnen runnen
  resource_busy   EXCEPTION;
  PRAGMA EXCEPTION_INIT( resource_busy, -54 );
--
-- Stelt bericht op voor aanroep
--
  PROCEDURE maak_bericht( i_retrieval_type IN VARCHAR2)
  IS
  --
    CURSOR c_xml
    IS
      SELECT xmlelement("soapenv:Envelope"
      ,        xmlattributes ( 'http://schemas.xmlsoap.org/soap/envelope/' AS "xmlns:soapenv"
                             , 'http://ec.europa.eu/sanco/tracesnt/base/v3'  AS "xmlns:v3"
                             , 'http://ec.europa.eu/tracesnt/body/v3' as "xmlns:v31"
                             , 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'  AS "xmlns:oas"
                             , 'http://ec.europa.eu/tracesnt/certificate/ched/submission/v01' as "xmlns:v01"
                             , 'urn:un:unece:uncefact:data:standard:SPSCertificate:17' as "xmlns:rsm"
                             , 'urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:21' AS "xmlns:ram"
                             , 'urn:un:unece:uncefact:data:standard:UnqualifiedDataType:21' AS "xmlns:udt")
     ,        xmlelement("soapenv:Header"
      ,          xmlattributes( 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd' AS "xmlns:wsse"
                              , 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'  AS "xmlns:wsu")
      ,          xmlelement("wsse:Security"
      ,            xmlelement("wsse:UsernameToken"
      ,            xmlattributes( 'UsernameToken-A5B8D7123A55CB6A75153751937547586' AS "wsu:Id" )
      ,              xmlelement("wsse:Username", v_username)
      ,              xmlelement("wsse:Password"
      ,                xmlattributes( 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest' AS "Type" )
      ,                l_password_digest_b64)
      ,              xmlelement("wsse:Nonce", l_nonce_b64)
      ,              xmlelement("wsu:Created", l_CreateTimestampString)
                   )
      ,            xmlelement("wsu:Timestamp"
      ,              xmlelement("wsu:Created", l_CreateTimestampString)
      ,              xmlelement("wsu:Expires", l_ExpireTimestampString)
                   )
                 )
      ,          xmlelement("v3:LanguageCode",'nl')
      ,          xmlelement("v3:WebServiceClientId",'vgc-client')
               )
      ,        xmlelement("soapenv:Body"
      ,          xmlattributes( 'http://schemas.xmlsoap.org/soap/envelope/' AS "xmlns:soapenv")
      ,          xmlelement("v1:GetClassificationTreeRequest"
      ,            xmlattributes( 'http://ec.europa.eu/tracesnt/referencedata/v1' AS "xmlns:v1")

      ,            xmlelement("v1:TreeID", i_retrieval_type)
                 )
               )
             ).getClobval()
      FROM dual
    ;
  --
  BEGIN
  -- Ophalen credentials
  IF i_retrieval_type = 'chedp'
  THEN
    v_username := vgc$algemeen.get_appl_register('TNT_USERNAME_GN_CHEDP');
    v_password := vgc$algemeen.get_appl_register('TNT_PASSWORD_GN_CHEDP');
  ELSIF i_retrieval_type = 'cheda'
  THEN
    v_username := vgc$algemeen.get_appl_register('TNT_USERNAME_GN_CHEDA');
    v_password := vgc$algemeen.get_appl_register('TNT_PASSWORD_GN_CHEDA');
  ELSIF i_retrieval_type = 'chedd'
  THEN
    v_username := vgc$algemeen.get_appl_register('TNT_USERNAME_GN_CHEDD');
    v_password := vgc$algemeen.get_appl_register('TNT_PASSWORD_GN_CHEDD');
  ELSE
    v_username := vgc$algemeen.get_appl_register('TNT_USERNAME_GN_CHEDPP');
    v_password := vgc$algemeen.get_appl_register('TNT_PASSWORD_GN_CHEDPP');
  END IF;
  --
    v_timestamp := SYSTIMESTAMP;
--  l_timestamp_char      := TO_CHAR(v_timestamp,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
--  l_trx_timestamp_char  := TO_CHAR(v_timestamp,'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM');
  l_timestamp_char      := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
  l_trx_timestamp_char  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM');
--  l_timestamp_char      := '2020-01-02T13:01:52.903Z';--TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
--  l_trx_timestamp_char  := '2020-01-02T13:04:52+01:00';--TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM');
    l_nonce_raw           := utl_i18n.string_to_raw(dbms_random.string('a',16),'utf8');
    l_nonce_b64           := utl_i18n.raw_to_char(utl_encode.base64_encode(l_nonce_raw),'utf8');
    l_password_digest_b64 := utl_i18n.raw_to_char
                           ( utl_encode.base64_encode
                             ( dbms_crypto.hash
                               ( l_nonce_raw||utl_i18n.string_to_raw(l_timestamp_char||v_password,'utf8')
                               , dbms_crypto.hash_sh1
                               )
                             )
                           , 'utf8'
                           );
  --
    l_CreateTimestampString := TO_CHAR(v_timestamp,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
    v_timestamp :=v_timestamp + 3/1440;
    l_ExpireTimestampString := TO_CHAR(v_timestamp,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
  -- Opstellen bericht
    OPEN c_xml;
    FETCH c_xml INTO  r_rqt.webservice_bericht;
    CLOSE c_xml;
    escape_xml(r_rqt.webservice_bericht);
    --
  EXCEPTION
    WHEN OTHERS
    THEN
      IF c_xml%ISOPEN
      THEN
        CLOSE c_xml;
      END IF;
      RAISE;
  END maak_bericht;
--
-- Verwerkt het binnengekomen resultaat
--
  FUNCTION verwerk (i_retrieval_type IN VARCHAR2)
  RETURN BOOLEAN
  IS
    l_sysdate    date := sysdate;
    l_user      varchar2(35) := user;
    -- foutafhandeling
    v_generalOperationResult  VARCHAR2(200 CHAR);
    v_specificOperationResult VARCHAR2(200 CHAR);
    -- tijdelijke variabelen voor verwerken XML
    v_response          xmltype;
    v_commodities       xmltype;
    v_ns                varchar2(400 char) := 'xmlns:ns8="http://ec.europa.eu/tracesnt/referencedata/classificationtree/v1" xmlns:ns7="http://ec.europa.eu/tracesnt/referencedata/certificatemodel/v1" xmlns:ns9="http://ec.europa.eu/tracesnt/referencedata/nodeattribute/v1" xmlns:ns1="http://ec.europa.eu/tracesnt/referencedata/v1"';
    -- Query voor uitlezen commodities uit response
    CURSOR c_cmy(i_xml xmltype, i_ns varchar2)
    IS
      SELECT extract(VALUE(rqt), '/ns8:Node/ns8:CNCode/text()',i_ns).getStringVal() gn_code
      ,      extract(VALUE(rqt), '/ns8:Node/ns8:Description/text()',i_ns).getStringVal() gn_code_meaning
      ,      extract(VALUE(rqt), '/ns8:Node/@path', i_ns).getStringVal() Pad
      ,      decode(
               instr(
                 ltrim(extract(VALUE(rqt), '/ns8:Node/@path', i_ns).getStringVal(),'R/')
      ,          '/'), 0, null
      ,         substr(
                  ltrim(extract(VALUE(rqt), '/ns8:Node/@path', i_ns).getStringVal(),'R/')
      ,           instr(
                    ltrim(extract(VALUE(rqt), '/ns8:Node/@path', i_ns).getStringVal(),'R/')
      ,           '/',-1)-7,7)) pad_code_vader
      ,      substr(ltrim(extract(VALUE(rqt), '/ns8:Node/@path', i_ns).getStringVal(),'R/')
      ,        instr(ltrim(extract(VALUE(rqt), '/ns8:Node/@path', i_ns).getStringVal(),'R/'),'/',-1)+1,7) pad_code
      ,      decode(extract(VALUE(rqt), '/ns8:Node/@allowedForSelection', i_ns).getStringVal(),'true','E','G') Selecteerbaar
      FROM TABLE( xmlsequence(i_xml)) rqt
    ;
    --
    CURSOR c_tte
    IS
      SELECT tte.id
      ,      tte.gn_code
      ,      tte.pad_code
      ,      tte.pad_code_vader
      FROM    vgc_tnt_gn_codes_tree tte
      WHERE  tte.soort = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F')
      ORDER BY tte.gn_code
    ;
    --
    CURSOR c_tte2 (b_pad_code_vader in vgc_tnt_gn_codes_tree.pad_code%type)
    IS
      SELECT tte2.gn_code
      FROM   vgc_v_tnt_gn_codes_tree tte2
      WHERE  tte2.soort = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F')
      AND    tte2.pad_code = b_pad_code_vader
    ;
    --
    r_tte2 c_tte2%ROWTYPE;
    --
    CURSOR c_tte3
    IS
      SELECT tte3.id
      ,      tte3.gn_code
      ,      tte3.pad_code
      FROM   vgc_tnt_gn_codes_tree tte3
      WHERE  tte3.soort = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F')
      AND    tte3.gn_code LIKE 'N%'
      ORDER BY tte3.gn_code
    ;
    --
    CURSOR c_tte4 (b_pad_code in vgc_tnt_gn_codes_tree.pad_code%type)
    IS
      SELECT tte4.gn_code
      ,      CASE WHEN substr (tte4.gn_code,1,1) = 'N'
                    THEN tte4.gn_code
                    ELSE substr(tte4.gn_code,1,length(tte4.gn_code)-1)
             END gn_code_vader
      FROM   vgc_v_tnt_gn_codes_tree tte4
      where  tte4.soort = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F')
      and    tte4.pad_code_vader = b_pad_code
      ;
    --
    r_tte4 c_tte4%ROWTYPE;
    --
    CURSOR c_tte5 (b_gn_code in vgc_tnt_gn_codes_tree.gn_code%type)
    IS
      SELECT tte5.gn_code
      FROM   vgc_v_tnt_gn_codes_tree tte5
      WHERE  tte5.soort = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F')
      AND    tte5.gn_code = b_gn_code
    ;
    --
    r_tte5 c_tte5%ROWTYPE;
    --
    CURSOR c_tte6
    IS
      SELECT tte6.gn_code
      FROM   vgc_v_tnt_gn_codes_tree tte6
      where  tte6.soort = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F')
      and    length(tte6.gn_code) <= length(tte6.gn_code_vader)
      AND    tte6.type = 'S'
      ;
    --
      r_tte6 c_tte6%ROWTYPE;
    --
    CURSOR c_tte7 (b_gn_code in vgc_tnt_gn_codes_tree.gn_code%type)
    IS
      SELECT tte7.gn_code
      FROM   vgc_v_tnt_gn_codes_tree tte7
      WHERE  tte7.soort = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F')
      AND    tte7.gn_code = b_gn_code
    ;
    --
    r_tte7 c_tte7%ROWTYPE;
    --
    i NUMBER;
    l_gn_code VARCHAR2(20 CHAR);

  BEGIN
    -- init variabelen voor verwerken
  v_response          :=      vgc_xml.extractxml(v_antwoord,'//ns1:GetClassificationTreeResponse', 'xmlns:ns1="http://ec.europa.eu/tracesnt/referencedata/v1"');
  v_commodities       :=      vgc_xml.extractxml(v_response, '//ns8:Node',v_ns);
    -- controleer of server een fout terug heeft gegeven
    v_generalOperationResult := vgc_xml.extractxml_str(v_response, '/retrieveReferenceDataReturn/generalOperationResult/text()',NULL);
    IF v_generalOperationResult IS NOT NULL
    THEN
      COMMIT;
      vgc_blg.write_log('Fout ontvangen: ' || v_generalOperationResult, v_objectnaam, 'J' , 5);
      raise_application_error(-20000, 'VGC-00502 #1' || v_ws_naam ||': Webservice geeft OperationResult: ' || v_generalOperationResult);
    END IF;
    --
    v_specificOperationResult := vgc_xml.extractxml_str(v_response, '/retrieveReferenceDataReturn/specificOperationResult/text()',NULL);
    IF v_specificOperationResult = 'CALLED_OUTSIDE_OPENING_TIME' OR v_specificOperationResult = 'TOO_MANY_INITIAL_LOADS'
    THEN
      COMMIT;
      vgc_blg.write_log('Fout ontvangen: ' || v_specificOperationResult, v_objectnaam, 'J', 5);
      raise_application_error(-20000, 'VGC-00502 #1' || v_ws_naam ||': Webservice geeft OperationResult: ' || v_specificOperationResult);
    END IF;
    --
    IF v_server_side_date IS NULL
    THEN
      v_server_side_date := l_sysdate;
    END IF;
    --
    -- verwerk commodities
    --
    DELETE FROM vgc_tnt_gn_codes_tree
    WHERE soort = decode(i_retrieval_type,'cheda','L','chedp','P','chedd','V','F')
    ;
    COMMIT;
    --
    FOR r_cmy IN c_cmy(v_commodities, v_ns)
    LOOP
      DECLARE
        v_gte vgc_tnt_gn_codes_tree%ROWTYPE;
      BEGIN

        v_gte.id               := vgc_gte_seq1.nextval;
        v_gte.gn_code          := nvl(r_cmy.gn_code,'N'||v_gte.id);
        v_gte.gn_code_meaning  := REPLACE(REPLACE(REPLACE(r_cmy.gn_code_meaning,chr(38)||'apos;',''''),chr(38)||'amp;','"'),chr(38)||'quot;','"');
        v_gte.pad              := REPLACE(r_cmy.pad,'R/','');
        v_gte.pad_code         := r_cmy.pad_code;
        v_gte.pad_code_vader   := r_cmy.pad_code_vader;
        v_gte.type             := r_cmy.selecteerbaar;
        v_gte.beheerstatus     := 2;
        v_gte.creation_date    := l_sysdate;
        v_gte.created_by       := l_user;
        v_gte.last_update_date := l_sysdate;
        v_gte.last_updated_by  := l_user;
        --
        IF i_retrieval_type = 'cheda'
        THEN
          v_gte.soort := 'L';
        ELSIF i_retrieval_type = 'chedp'
        THEN
          v_gte.soort := 'P';
        ELSIF i_retrieval_type = 'chedpp'
        THEN
          v_gte.soort := 'F';
        ELSE
          v_gte.soort := 'V';
        END IF;
        --
        BEGIN
          INSERT INTO vgc_tnt_gn_codes_tree
          VALUES v_gte;
        EXCEPTION
          WHEN dup_val_on_index
          THEN
            vgc_blg.write_log('3 Fout bij insert van: ' || v_gte.gn_code, v_objectnaam, 'N', 1);
            UPDATE vgc_tnt_gn_codes_tree gte
              SET  gte.gn_code_vader    = v_gte.gn_code_vader
              ,    gte.gn_code_meaning  = v_gte.gn_code_meaning
              ,    gte.beheerstatus     = 3
              ,    gte.pad              = v_gte.pad
              ,    gte.pad_code         = v_gte.pad_code
              ,    gte.pad_code_vader   = v_gte.pad_code_vader
              ,    gte.type             = v_gte.type
              ,    gte.last_update_date = v_gte.last_update_date
              ,    gte.last_updated_by  = v_gte.last_updated_by
            WHERE  gte.gn_code        = v_gte.gn_code
              AND  gte.type           = v_gte.type
              AND  (nvl(gte.pad,'*')  != nvl(v_gte.pad,'*')
               OR  gte.soort         != v_gte.soort
               OR  gte.gn_code_meaning != v_gte.gn_code_meaning)
              ;
            WHEN OTHERS
            THEN
              RAISE;
          END;
       END;
    END LOOP;
     --
     -- Bijwerken van tussennodes
     --
    vgc_blg.write_log('Update tussennodes ' , v_objectnaam, 'N', 1);
    FOR r_tte IN c_tte
    LOOP
      OPEN c_tte2 (b_pad_code_vader => r_tte.pad_code_vader);
      FETCH c_tte2 INTO r_tte2;
      IF c_tte2%FOUND
      THEN
        CLOSE c_tte2;
        BEGIN
          UPDATE vgc_tnt_gn_codes_tree
          SET gn_code_vader = r_tte2.gn_code
          WHERE id = r_tte.id
         ;
        EXCEPTION
        WHEN OTHERS
          THEN
            NULL;
        END;
      ELSE
        CLOSE c_tte2;
      END IF;
    END LOOP;
     --
     -- Bijwerken GN_CODE_VADER
     --
     vgc_blg.write_log('Update gn_code_vader ' , v_objectnaam, 'N', 1);
    FOR r_tte3 IN c_tte3
    LOOP
      OPEN c_tte4 (b_pad_code => r_tte3.pad_code);
      FETCH c_tte4 INTO r_tte4;
      IF c_tte4%FOUND
      THEN
        IF substr(r_tte4.gn_code_vader,1,1) != 'N'
        THEN
          FOR i IN 4..length(r_tte4.gn_code_vader)
          LOOP
            l_gn_code := substr(r_tte4.gn_code_vader,1,i);
            OPEN c_tte5(b_gn_code => l_gn_code);
            FETCH c_tte5 INTO r_tte5;
            IF c_tte5%NOTFOUND
            THEN
              CLOSE c_tte5;
              EXIT;
            ELSE
              CLOSE c_tte5;
            END IF;
          END LOOP;
          --
          BEGIN
            UPDATE vgc_tnt_gn_codes_tree
            SET gn_code_vader = l_gn_code
            WHERE pad_code_vader = r_tte3.pad_code
            AND soort = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F')
            ;
            UPDATE vgc_tnt_gn_codes_tree
            SET gn_code = l_gn_code
            ,   type = 'S'
            WHERE id = r_tte3.id
            ;
          EXCEPTION
          WHEN OTHERS
            THEN NULL;
          END;
        END IF;
        CLOSE c_tte4;
      ELSE
        CLOSE c_tte4;
      END IF;
    END LOOP;
    --
    -- verwijderen obsolete paden
    --
    vgc_blg.write_log('verwijder obsolete paden ' , v_objectnaam, 'N', 1);
    DELETE FROM vgc_tnt_gn_codes_tree gte
    WHERE gte.gn_code LIKE 'N%'
    AND   gte.soort = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F')
    AND   gte.beheerstatus != '1'
   ;
    --
    -- Bijwerken GN_CODE_VADER
    --
    vgc_blg.write_log('Update gn_code_vader ' , v_objectnaam, 'N', 1);
    FOR r_tte6 IN c_tte6
    LOOP
      l_gn_code := r_tte6.gn_code;
      FOR i IN 1..length(r_tte6.gn_code)-4
      LOOP
        l_gn_code := substr(l_gn_code,1,length(r_tte6.gn_code)-i);
        OPEN c_tte7(b_gn_code => l_gn_code);
        FETCH c_tte7 INTO r_tte7;
        IF c_tte7%FOUND
        THEN
          CLOSE c_tte7;
          EXIT;
        ELSE
          CLOSE c_tte7;
        END IF;
      END LOOP;
      --
    vgc_blg.write_log('Update gn_code_vader '||l_gn_code , v_objectnaam, 'N', 1);
      BEGIN
        UPDATE vgc_tnt_gn_codes_tree
        SET gn_code_vader = l_gn_code
        WHERE gn_code = r_tte6.gn_code
        AND soort = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F')
        ;
      EXCEPTION
      WHEN OTHERS
        THEN NULL;
      END;
    END LOOP;
    --
    COMMIT;
    --
    RETURN TRUE;
    --
  EXCEPTION
    WHEN OTHERS
    THEN
      IF c_cmy%ISOPEN
      THEN
        CLOSE c_cmy;
      END IF;
      RAISE;
  END verwerk;
--
-- voert synchronisatie uit voor het opgegeven retrieval_type
--
  PROCEDURE sync(i_retrieval_type IN VARCHAR2)
  IS
    v_page_number         NUMBER(9)       := 1;
    v_verwerking_klaar    BOOLEAN         := FALSE;
  --
  BEGIN
    v_verwerking_klaar := FALSE;
    WHILE v_verwerking_klaar = FALSE
    LOOP
      -- initialiseren request
      r_rqt.request_id := NULL;
      r_rqt.status := vgc_ws_requests.kp_in_uitvoering;
      r_rqt.resultaat := i_retrieval_type;
      -- opstellen bericht
      maak_bericht( i_retrieval_type);
      -- aanroepen webservice
      vgc_ws_requests_nt.maak_http_request (r_rqt);
      vgc_ws_requests_nt.log_request(r_rqt);
      -- indien fout bij aanroepen webservice geef foutmelding en stop verwerking
      IF r_rqt.webservice_returncode <> 200
      THEN
        vgc_blg.write_log('Webservice geeft http-code: ' || r_rqt.webservice_returncode, v_objectnaam, 'J', 5);
        raise_application_error(-20000, 'VGC-00502 #1' || v_ws_naam ||': Webservice geeft HTTP-code: ' || r_rqt.webservice_returncode);
      END IF;
      --
      v_antwoord := xmltype(r_rqt.webservice_antwoord);
      -- Verwerk indien nodig het gewijzigde wachtwoord
      --check_password_reset(i_response => v_antwoord);
      -- verwerk response
      v_verwerking_klaar := verwerk (i_retrieval_type);
      v_page_number := v_page_number + 1;
    END LOOP;
  EXCEPTION
    WHEN OTHERS
    THEN
      vgc_blg.write_log('Fout bij synchroniseren: ' || SQLERRM, v_objectnaam, 'J', 5);
      RAISE;
  END sync;
--
-- tel de wijzigingen en zet alles op geverifieerd (beheerstatus 1)
--
  PROCEDURE resumeer
  IS
    CURSOR c_gvt
    IS
      SELECT SUM(decode(beheerstatus,'1', 1, 0)) aantal_status_1
      ,      SUM(decode(beheerstatus,'2', 1, 0)) aantal_status_2
      ,      SUM(decode(beheerstatus,'3', 1, 0)) aantal_status_3
      ,      SUM(decode(beheerstatus,'4', 1, 0)) aantal_status_4
      ,      SUM(decode(beheerstatus,'5', 1, 0)) aantal_status_5
      FROM vgc_tnt_gn_codes_tree
    ;
    --
    r_gvt c_gvt%ROWTYPE;
  --
  BEGIN
    --
    -- bijwerken voorkeuren
    --
    /*FOR r_gvs_voorkeur in c_gvs_voorkeur
    LOOP
      UPDATE vgc_v_gn_vertaling_traces
      SET    voorkeur = 'J'
      WHERE  gn_code = r_gvs_voorkeur.gn_code
      AND    certificaattype = r_gvs_voorkeur.certificaattype
      AND    status = 'ACTIVE'
      AND    rownum = 1
      ;
    END LOOP;
    COMMIT;
    OPEN c_gvs;
    FETCH c_gvs INTO r_gvs;
    CLOSE c_gvs;*/
    --
    vgc_blg.write_log('Aantal ongewijzigde rijen: ' || r_gvt.aantal_status_1, v_objectnaam, 'N', 1);
    vgc_blg.write_log('Aantal nieuwe rijen: ' || r_gvt.aantal_status_2, v_objectnaam, 'N', 1);
    vgc_blg.write_log('Aantal gewijzigde rijen zonder species: ' || r_gvt.aantal_status_3, v_objectnaam, 'N', 1);
    vgc_blg.write_log('Aantal gewijzigde rijen met species: ' || r_gvt.aantal_status_4, v_objectnaam, 'N', 1);
    vgc_blg.write_log('Aantal gewijzigde rijen op DELETED: ' || r_gvt.aantal_status_5, v_objectnaam, 'N', 1);
    --
    -- verifieeren van wijzigingen
    --
  --  UPDATE vgc_gn_codes_tree_tnt
  --  SET beheerstatus = '1'
  --  WHERE beheerstatus != '1'
  --  ;
  --  COMMIT;
  EXCEPTION
    WHEN OTHERS
    THEN
      vgc_blg.write_log('Fout bij resumeren: ' || SQLERRM, v_objectnaam, 'J', 5);
      RAISE;
  END resumeer;
  --
BEGIN
  --
  trace(v_objectnaam);
  vgc_blg.write_log('start', v_objectnaam, 'N', 1);
  -- Aanmaken lock zodat VGC0501NT niet synchroon kan draaien
  OPEN c_lock;
  CLOSE c_lock;
  -- bewaren oude data
  execute immediate ('TRUNCATE TABLE VGC_OWNER.VGC_TNT_GN_CODES_TREE_SAVE' );
  execute immediate ('INSERT INTO VGC_OWNER.VGC_TNT_GN_CODES_TREE_SAVE SELECT * FROM VGC_OWNER.VGC_TNT_GN_CODES_TREE' );
  --
  commit;
  -- initialiseren request
  r_rqt.request_id             := NULL;
  r_rqt.webservice_url         := vgc$algemeen.get_appl_register ('TNT_GN_CODES_WEBSERVICE');
  r_rqt.bestemd_voor           := 'TNT';
  r_rqt.webservice_logische_naam := 'VGC0501NT';
  if p_type = 'LNV'
  then
    sync(k_nonanimalproducts);
  elsif p_type = 'LPJ'
  then
    sync(k_animals);
  elsif p_type = 'NPJ'
  then
    sync(k_animalproducts);
  else
    sync(k_fytoproducts);
  end if;

  IF v_laatste_sync IS NULL
  THEN
    INSERT INTO vgc_applicatie_registers arr
           (variabele         , waarde)
    VALUES (k_laatste_sync_var, v_server_side_date);
  ELSE
    UPDATE vgc_applicatie_registers arr
       SET arr.waarde = v_server_side_date
     WHERE arr.variabele = k_laatste_sync_var;
  END IF;
  --
  COMMIT;
  resumeer;
  vgc_blg.write_log('einde', v_objectnaam, 'N', 1);
  --
EXCEPTION
  WHEN resource_busy
  THEN
    ROLLBACK;
    RAISE;
  WHEN OTHERS
  THEN
    IF c_lock%ISOPEN
    THEN
      CLOSE c_lock;
    END IF;
    vgc_blg.write_log('Exception: '|| SQLERRM, v_objectnaam, 'N', 1);
    ROLLBACK;
    qms$errors.unhandled_exception(v_objectnaam);
END VGC0501NT;
/* Indienen Besluit VGC (submitDecision) */
PROCEDURE VGC0503NT
 (P_GGS_NUMMER IN VGC_PARTIJEN.GGS_NUMMER%TYPE
 ,P_REQUEST_ID IN VGC_REQUESTS.REQUEST_ID%TYPE := null
 )
 IS
 PRAGMA AUTONOMOUS_TRANSACTION;
v_objectnaam            vgc_batchlog.proces%TYPE                  := g_package_name || '.VGC0503NT#01';
/*********************************************************************
Wijzigingshistorie
doel:
Indienen besluite VGC-CLIENT bij TRACES-NT (SUBMIT DECISION)

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
 1      28-02-2020 GLR     creatie
*********************************************************************/
-- haalt een reeds bestaande request op aan de hand van de input-parameter request_id
  CURSOR c_rqt
  IS
    SELECT rqt.*
    FROM   vgc_requests rqt
    WHERE  rqt.request_id = p_request_id
  ;
--
  CURSOR c_prim_doc (b_ptj_id in vgc_partijen.id%TYPE)
  IS
    SELECT dct.id
    FROM   vgc_v_veterin_documenten dct
    WHERE  dct.ptj_id = b_ptj_id
    ORDER BY creation_date ASC
  ;
--  haalt HTD-token op
  CURSOR c_token
  IS
    SELECT resultaat
    FROM  vgc_requests
    WHERE ggs_nummer = p_ggs_nummer
    AND   webservice_logische_naam  IN ('VGC0505NT','VGC0504NT')
    ORDER BY datum DESC
  ;
-- bepaalt of er sprake is van een niet erkend land
  CURSOR c_wgg_country
  IS
    SELECT 1
    FROM vgc_v_weigeringen wgg
    ,    vgc_v_weigeringredenen wrn
    ,    vgc_v_beslissingen bsg
    ,    vgc_v_partijen ptj
    WHERE ptj.ggs_nummer = p_ggs_nummer
    AND   bsg.ptj_id = PTJ.ID
    AND   bsg.definitief_ind = 'J'
    AND   wgg.bsg_id = bsg.id
    AND   wrn.id = wgg.wrn_id
    AND   wrn.code IN ('PLD', 'LLD')
    ORDER BY bsg.creation_date DESC
  ;
-- bepaalt of er sprake is van een niet erkende inrichting
  CURSOR c_wgg_establishment
  IS
    SELECT 1
    FROM vgc_v_weigeringen wgg
    ,    vgc_v_weigeringredenen wrn
    ,    vgc_v_beslissingen bsg
    ,    vgc_v_partijen ptj
    WHERE ptj.ggs_nummer = p_ggs_nummer
    AND   bsg.ptj_id = PTJ.ID
    AND   bsg.definitief_ind = 'J'
    AND   wgg.bsg_id = bsg.id
    AND   wrn.id = wgg.wrn_id
    AND   wrn.code = 'PIG'
    ORDER BY bsg.creation_date DESC
  ;
-- haalt het id op van de partij*/
  CURSOR c_ptj
  IS
    SELECT ptj.id
    ,      rle.aangevernummer
    ,      ptj.aangiftejaar
    ,      ptj.aangiftevolgnummer
    ,      decode(ptj.ptj_type,'NPJ','P','LPJ','A','D') cim_class
    ,      att.erkenningsnummer
    ,      ptj.traces_certificaat_id
    FROM   vgc_v_partijen ptj
    ,      vgc_v_relaties rle
    ,      vgc_v_erkenningen att
    WHERE  ptj.ggs_nummer = p_ggs_nummer
    AND    ptj.rle_id = rle.id
    AND    att.ptj_id(+) = ptj.id
  ;
-- haal het aantal containers op
  CURSOR c_ctr(cp_ptj_id vgc_partijen.id%TYPE)
  IS
    SELECT COUNT(ctr.nummer)
    FROM   vgc_v_containers ctr
    ,      vgc_v_colli clo
    WHERE  ctr.clo_id = clo.id
    AND    clo.ptj_id = cp_ptj_id
    AND    ctr.vervangend_zegelnummer IS NOT NULL
    GROUP BY ctr.nummer
  ;
-- haal de minmimale datumtijd monstername op indien er monster zijn genomen
  CURSOR c_lmr(cp_ptj_id vgc_partijen.id%TYPE)
  IS
    SELECT MIN(datumtijd_monstername)
    FROM   vgc_lab_monsters lmr
    WHERE  cte_ptj_id = cp_ptj_id
  ;
-- haal labmonsterreden van de minmimale datumtijd monstername
  CURSOR c_lmn(cp_ptj_id vgc_partijen.id%TYPE, cp_datumtijd vgc_lab_monsters.datumtijd_monstername%TYPE)
  IS
    SELECT code
    FROM   vgc_lab_monsters lmr
    ,      vgc_lab_monster_redenen lmn
    WHERE  cte_ptj_id = cp_ptj_id
    AND    lmr.lmn_id = lmn.id
    AND    datumtijd_monstername = cp_datumtijd
  ;
--
  CURSOR c_toe4
  IS
    SELECT ','||xmlagg(xmlelement(a,oe_code,',').extract('//text()')) vier_pos
    FROM   vgc_tnt_oe_codes
    WHERE  LENGTH(oe_code) = 4
  ;
--
  CURSOR c_toe3
  IS
    SELECT ','||xmlagg(xmlelement(a,oe_code,',').extract('//text()')) drie_pos
    FROM   vgc_tnt_oe_codes
    WHERE  LENGTH(oe_code) = 3
  ;
--
--
  v_vier_pos                     VARCHAR2(250 CHAR) := NULL;
  v_drie_pos                     VARCHAR2(250 CHAR) := NULL;
  -- logische webservicenaam
  -- Record structuur voor afhandeling HTTP requests
  r_rqt                          vgc_requests%ROWTYPE;
  -- berichtvariabelen
  v_htd_token_ref                VARCHAR2(4000 CHAR);
  v_non_approved_country_ind     NUMBER := 0;
  v_non_approved_establishme_ind NUMBER := 0;
  v_aantal_containers            NUMBER := 0;
  v_ptj_id                       vgc_partijen.id%TYPE;
  v_min_datumtijd_monstername    vgc_lab_monsters.datumtijd_monstername%TYPE;
  v_lmn_code                     vgc_lab_monster_redenen.code%TYPE;
  -- variabelen en cursoren voor uitlezen gegevens originEstablishments
  v_erkenningsnummer             vgc_erkenningen.erkenningsnummer%TYPE;
  v_gn_code                      vgc_vp_producten.gn_code%TYPE;
  v_complement_id                vgc_v_gn_vertaling_traces.gn_code_comp_id%TYPE;
  v_species_id                   vgc_v_gn_vertaling_traces.species_id%TYPE;
  v_primair_doc_id               vgc_vp_documenten.id%TYPE;
  v_aangevernummer             vgc_vp_partijen.aangevernummer%TYPE;
  v_aangiftejaar               vgc_vp_partijen.aangiftejaar%TYPE;
  v_aangifte_volgnummer        vgc_vp_partijen.aangifte_volgnummer%TYPE;
  v_cim_class                  varchar2(1);
  v_request_id                 NUMBER;
  v_resultaat                  BOOLEAN;
  v_ws_naam                    VARCHAR2(100 CHAR) := 'VGC0503NT';
  v_chednummer                 VARCHAR2(50 CHAR);
  v_pdf_jn                     VARCHAR2(1 CHAR) := 'J';
  v_operation_username         VARCHAR2(100 CHAR) := vgc$algemeen.get_appl_register ('TNT_WS_OPERATION_USR');
  v_operation_password         VARCHAR2(100 CHAR) := vgc$algemeen.get_appl_register ('TNT_WS_OPERATION_PWD');
  v_services_username          VARCHAR2(100 CHAR) := vgc$algemeen.get_appl_register ('TNT_WS_SERVICES_USR');
  v_services_password          VARCHAR2(100 CHAR) := vgc$algemeen.get_appl_register ('TNT_WS_SERVICES_PWD');

--
-- Stel het bericht op voor aanroep
--
  PROCEDURE maak_bericht
  IS
    CURSOR c_xml
    IS
      SELECT c_encoding || xmlelement("soap:Envelope"
             , xmlattributes ( 'http://schemas.xmlsoap.org/soap/envelope/' AS "xmlns:soap"
                             , 'http://www.w3.org/2001/XMLSchema-instance'  AS "xmlns:xsi"
                             , 'urn:axisgen.b2b.traces.sanco.cec.eu'  AS "xmlns:urn")
      ,        xmlelement("soap:Header")
      ,         xmlelement("soap:Body"
      ,          xmlelement("urn:submitDecision"
      ,            xmlelement("in0"
      ,              xmlelement("operationUserCredentials"
      ,                xmlelement("userName", v_operation_username)
      ,                xmlelement("userPassword", v_operation_password)
                     )
      ,              xmlelement("servicesUserCredentials"
      ,                xmlelement("userName", v_services_username)
      ,                xmlelement("userPassword", v_services_password)
                     )
      ,              xmlelement("certificateStatus", CASE WHEN bte.code = 'TLG' THEN 'VALID' ELSE 'REJECTED' END)
      ,            CASE WHEN ptj.ptj_type = 'LPJ'
                   THEN
                     xmlelement("CHEDAnimalsConsignmentUpdtData"
      ,                vgc_xml.element('countryOfOriginCode', lrg.lnd_code)
      ,                xmlelement("veterinaryDocuments"
      ,                  xmlelement("issueDate", xmlattributes(decode(vdt.datum_afgifte, NULL,'true','false') "xsi:nil"), get_ws_date(NULL,vdt.datum_afgifte,  'yymmdd'))
      ,                  vgc_xml.element('number', vdt.nummer||'.')
                       )
                     )
                   WHEN ptj.ptj_type = 'NPJ'
                   THEN
                     xmlelement("CHEDAnimalProdsConsignUpdtData"
      ,                vgc_xml.element('countryOfOriginCode', lrg.lnd_code)
      ,                xmlelement("veterinaryDocuments"
      ,                  xmlelement("issueDate", xmlattributes(decode(vdt.datum_afgifte, NULL,'true','false') "xsi:nil"), get_ws_date(NULL,vdt.datum_afgifte,  'yymmdd'))
      ,                  vgc_xml.element('number', vdt.nummer||'.')
                          -- Indien een of meerdere erkenningsnummers zijn opgegeven
      ,                  CASE WHEN att.erkenningsnummer IS NOT NULL
                              AND upper(att.erkenningsnummer) NOT IN ('NVT','ONBEKEND')
                         THEN
                           (SELECT xmlagg(
                                     xmlelement("originEstablishments"
      ,                                xmlelement("activity"
      ,                                  vgc_xml.element('referenceDataCode', get_tnt_activity_code(v_gn_code, 'OE', 'P', TRIM(toe.activity_code)))
                                     )
      ,                                xmlelement("business"
      ,                                  vgc_xml.element('approvalNumber', toe.approvalnumber)
      ,                                  vgc_xml.element('countryCode', toe.lnd_code)
                                      )
                                     )
                                   )
                            FROM vgc_tt_oe toe)
                         END CASE
                       )
                     )
                   ELSE
                     xmlelement("CHEDNonAnimalProdsConsignUpdtData"
      ,                vgc_xml.element('countryOfOriginCode', lrg.lnd_code)
      ,                xmlelement("veterinaryDocuments"
      ,                  xmlelement("issueDate", xmlattributes(decode(vdt.datum_afgifte, NULL,'true','false') "xsi:nil"), get_ws_date(NULL,vdt.datum_afgifte,  'yymmdd'))
      ,                  vgc_xml.element('number', vdt.nummer||'.')
                          -- Indien een of meerdere erkenningsnummers zijn opgegeven
      ,                  CASE WHEN att.erkenningsnummer IS NOT NULL
                              AND upper(att.erkenningsnummer) NOT IN ('NVT','ONBEKEND')
                         THEN
                           (SELECT xmlagg(
                                     xmlelement("originEstablishments"
      ,                                xmlelement("activity"
      ,                                  vgc_xml.element('referenceDataCode', get_tnt_activity_code(v_gn_code, 'OE', 'P', TRIM(toe.activity_code)))
                                     )
      ,                                xmlelement("business"
      ,                                  vgc_xml.element('approvalNumber', toe.approvalnumber)
      ,                                  vgc_xml.element('countryCode', toe.lnd_code)
                                      )
                                     )
                                   )
                            FROM vgc_tt_oe toe)
                         END CASE
                       )
                     )
                   END CASE
       ,           CASE WHEN ptj.ptj_type = 'LPJ' -- levende partij CHEDA
                   THEN
                     xmlelement("CHEDAnimalsDecision"
       ,               xmlelement("certificateIdentification"
       ,                 xmlelement("referenceNumber" , ptj.traces_certificaat_id)
       ,                 xmlelement("type" , 'CHEDA')
                       )
       ,               xmlelement("localID", ptj.ggs_nummer)
       ,               xmlelement("signature"
       ,                 xmlelement("dateOfDeclaration" , to_char(SYSDATE, 'yyyy-mm-dd"T"hh24:mi:ss'))
       ,                  xmlelement("signatory"
       ,                    xmlelement("userDetail"
       ,                      xmlelement("lastName", xmlattributes(decode(mdr.naam, NULL,'true','false') "xsi:nil"), mdr.voornaam || ' '||mdr.naam)
                           )
                         )
                       )
       ,               CASE WHEN (vbg.code = 'IVR' AND  ptj.soort_import = 'DTF' AND bte.code = 'TLG' AND (bsg.artikel_8_ind IS NULL OR bsg.artikel_8_ind = 'N'))
                              OR (vbg.code = 'WIR' AND  ptj.soort_import = 'TKR' AND bte.code = 'TLG')
                       THEN
                         xmlelement("acceptance"
       ,                   xmlelement("forDefinitiveImport"
       ,               CASE WHEN gbl.code in ('SLT','QTE','EIG')
                       THEN
                             xmlelement("controlledDestination", get_relatie_element('AF', ptj.af_naam, ptj.af_land, ptj.af_plaats, ptj.af_postcode, ptj.af_straat_postbus, ptj.af_huisnummer, ptj.af_huisnummertoevoeging, get_tnt_activity_code(v_gn_code, 'AF', 'L'),ptj.af_id_type,nvl(ptj.af_id,ptj.af_traces_id)))

                       END
       ,               CASE WHEN gbl.code in ('SLT','QTE','EIG')
                       THEN
                             xmlelement("controlledDestinationActivity", xmlattributes(decode(get_tnt_destination(gbl.code, 'LGL'), NULL , 'true', 'false') "xsi:nil"), get_tnt_destination(gbl.code, 'LGL'))

                       END
                           )
                         )
                       WHEN vbg.code = 'IVR' AND  ptj.soort_import = 'DTF' AND bte.code = 'TLG' AND bsg.artikel_8_ind = 'J'
                       THEN
                         xmlelement("acceptance"
       ,                   xmlelement("ifChannelled"
       ,                     xmlelement("channelingProcedure", 'ARTICLE_8_PROCEDURE')
       ,                     xmlelement("controlledDestination", get_relatie_element('AF', ptj.af_naam, ptj.af_land, ptj.af_plaats, ptj.af_postcode, ptj.af_straat_postbus, ptj.af_huisnummer, ptj.af_huisnummertoevoeging, get_tnt_activity_code(v_gn_code, 'AF', 'L'),ptj.af_id_type,nvl(ptj.af_id,ptj.af_traces_id))) /*#12*/
                           )
                         )
                       WHEN vbg.code IN ('IVR', 'WIR')  AND ptj.soort_import = 'TLK' AND bte.code = 'TLG'
                       THEN
                         xmlelement("acceptance"
       ,                   xmlelement("forTemporaryAdmission"
       ,                     xmlelement("controlledDestination", get_relatie_element('AF', ptj.af_naam, ptj.af_land, ptj.af_plaats, ptj.af_postcode, ptj.af_straat_postbus, ptj.af_huisnummer, ptj.af_huisnummertoevoeging, get_tnt_activity_code(v_gn_code, 'AF', 'L'),ptj.af_id_type,nvl(ptj.af_id,ptj.af_traces_id))) /*#12*/
       ,                     xmlelement("deadline", xmlattributes(decode(bsg.uiterste_datum, NULL,'true','false') "xsi:nil"), get_ws_date(NULL, bsg.uiterste_datum, 'yymmdd'))
                           )
                         )
                       WHEN vbg.code = 'DVR' AND bte.code = 'TLG'
                       THEN
                        xmlelement("acceptance"
       ,                   xmlelement("forTransitProcedure", decode(bce.us_army_ind,'J','MILITARY_FACILITY',NULL))
                         )
                       ELSE
                         xmlelement("acceptance" ,xmlattributes('true' "xsi:nil"))
                       END
       ,               xmlelement("checklist"
       ,                 xmlelement("documentaryCheck"
       ,                   xmlelement("additionalGuarantee"
       ,                     xmlelement("laboratoryTestId", xmlattributes('true' "xsi:nil"))
       ,                     xmlelement("result", xmlattributes(decode(get_tnt_test_result_bin(cte.oordeel_d_garanties), NULL , 'true', 'false') "xsi:nil"), get_tnt_test_result_bin(cte.oordeel_d_garanties))
                           )
       ,                   xmlelement("euStandard", xmlattributes(decode(get_tnt_test_result_bin(cte.oordeel_d_eu), NULL , 'true', 'false') "xsi:nil"), get_tnt_test_result_bin(cte.oordeel_d_eu))
       ,                   xmlelement("nationalRequirements", xmlattributes(decode(get_tnt_test_result_bin(cte.oordeel_d_vereisten), NULL , 'true', 'false') "xsi:nil"), get_tnt_test_result_bin(cte.oordeel_d_vereisten))
                        )
       ,                 case when get_tnt_test_result_bin(cte.oordeel_o, 'O') is null
                         then
                           null
                         else
                           ( select xmlelement("identityCheck"
                ,                   xmlelement("result", xmlattributes(decode(get_tnt_test_result_bin(cte.oordeel_o, 'O'), NULL , 'true', 'false') "xsi:nil"), get_tnt_test_result_bin(cte.oordeel_o, 'O'))
                ,                   xmlelement("type", xmlattributes(decode(get_tnt_type_onderzoek(cte.type_o), NULL , 'true', 'false') "xsi:nil"),   get_tnt_type_onderzoek(cte.type_o))
                                    )
                             from dual )
                         end
       ,                 xmlelement("physicalCheck"
       ,                   xmlelement("numberAnimalsChecked", xmlattributes(decode(cte.aantal_gecontroleerde_dieren, NULL , 'true', 'false') "xsi:nil"), cte.aantal_gecontroleerde_dieren)
       ,                   xmlelement("result", xmlattributes(decode(get_tnt_test_result_bin(cte.oordeel_m), NULL , 'true', 'false') "xsi:nil"), get_tnt_test_result_bin(cte.oordeel_m))
                         )
       ,                 xmlelement("welfareCheckAtArrival", get_tnt_test_result_ter(cte.oordeel_w))
                       )
       ,               xmlelement("customsDocumentReference", ptj.ggs_nummer)
       ,               xmlelement("impactOfTransportOnAnimals"
       ,                 xmlelement("numberBirthsOrAbortions", xmlattributes(decode(cte.aantal_geboorten_abortussen, NULL , 'true', 'false') "xsi:nil"), cte.aantal_geboorten_abortussen)
       ,                 xmlelement("numberDeadAnimals", xmlattributes(decode(cte.aantal_dode_dieren, NULL , 'true', 'false') "xsi:nil"), cte.aantal_dode_dieren)
       ,                 xmlelement("numberDeadAnimalsUnit", 'NUMBER')
       ,                 xmlelement("numberUnfitAnimals", xmlattributes(decode(cte.aantal_notransport , NULL , 'true', 'false') "xsi:nil"), cte.aantal_notransport)
       ,                 xmlelement("numberUnfitAnimalsUnit", 'NUMBER')
                       )
       ,               CASE WHEN cte.lab_oordeel = 'NUD'
                       THEN
                         NULL
                       WHEN cte.lab_oordeel = 'TCN'
                       THEN
                         (SELECT xmlelement("laboratoryTests"
                          ,        xmlelement("date", to_char(v_min_datumtijd_monstername, 'yyyy-mm-dd"T"hh24:mi:ss'))
                          ,        xmlagg (xmlelement("laboratoryTest"
                          ,                xmlelement("conclusionAuthority", get_tnt_labtest_result(cte.lab_oordeel,'M'))
                          ,                  xmlelement("extendedInformation"
                          ,                    xmlelement("conclusionLaboratory", get_tnt_labtest_result(cte.lab_oordeel,'L'))
                          ,                    xmlelement("laboratoryTestIdentification"
                          ,                      xmlelement("laboratoryTestLocalID",xmlattributes(decode(mon_id, NULL , 'true', 'false') "xsi:nil"),  mon_id)
                          ,                      xmlelement("laboratoryTestReferenceNumber",xmlattributes(decode(dossiernummer, NULL , 'true', 'false') "xsi:nil"),  dossiernummer)
                                              )
                          ,                    xmlelement("sampleDate", xmlattributes(decode(datumtijd_monstername, NULL , 'true', 'false') "xsi:nil"), to_char(datumtijd_monstername, 'yyyy-mm-dd"T"hh24:mi:ss'))
                                            )
                          ,                xmlelement("laboratoryTestMoleculeTracesId", xmlattributes(decode(traces_id, NULL , 'true', 'false') "xsi:nil"), traces_id)
                                                   )
                                          )
                          ,               xmlelement("motivation", get_tnt_test_reason (v_lmn_code, reden_monstername))
                                          )
                          FROM (SELECT DISTINCT cte2.lab_oordeel
                                ,      lmr.datumtijd_monstername
                                ,      ozk.traces_id
                                ,      mon.id mon_id
                                ,      lmr.dossiernummer
                                FROM   vgc_controles cte2
                                ,      vgc_lab_monsters lmr
                                ,      vgc_monsteronderzoeken mon
                                ,      vgc_onderzoeken ozk
                                WHERE  cte2.ptj_id =  v_ptj_id
                                AND    cte2.ptj_id =  lmr.cte_ptj_id
                                AND    mon.lmr_id  = lmr.id
                                AND    mon.ozk_id  = ozk.id
                                AND    ozk.traces_id IS NOT NULL
                               )
                         )
                       ELSE
                         (SELECT xmlelement("laboratoryTests"
                          ,        xmlelement("date", to_char(v_min_datumtijd_monstername, 'yyyy-mm-dd"T"hh24:mi:ss'))
                          ,        xmlagg (xmlelement("laboratoryTest"
                          ,                xmlelement("conclusionAuthority", CASE WHEN bte.code = 'TLG' THEN 'SATISFACTORY' WHEN bte.code IN ('VWG', 'DWG') THEN 'NOT_SATISFACTORY' END)
                          ,                  xmlelement("extendedInformation"
                          ,                    xmlelement("conclusionLaboratory", get_tnt_labtest_result(cte.lab_oordeel,'L'))
                          ,                    xmlelement("laboratoryTestIdentification"
                          ,                      xmlelement("laboratoryTestLocalID",xmlattributes(decode(mon_id, NULL , 'true', 'false') "xsi:nil"),  mon_id)
                          ,                      xmlelement("laboratoryTestReferenceNumber",xmlattributes(decode(dossiernummer, NULL , 'true', 'false') "xsi:nil"),  dossiernummer)
                                              )
                          ,                    xmlelement("sampleDate", xmlattributes(decode(datumtijd_monstername, NULL , 'true', 'false') "xsi:nil"), to_char(datumtijd_monstername, 'yyyy-mm-dd"T"hh24:mi:ss'))
                                            )
                          ,                xmlelement("laboratoryTestMoleculeTracesId", xmlattributes(decode(traces_id, NULL , 'true', 'false') "xsi:nil"), traces_id)
                                                   )
                                          )
                          ,               xmlelement("motivation", get_tnt_test_reason (v_lmn_code, reden_monstername))
                                          )
                          FROM (SELECT DISTINCT cte2.lab_oordeel
                                ,      lmr.datumtijd_monstername
                                ,      ozk.traces_id
                                ,      mon.id mon_id
                                ,      lmr.dossiernummer
                                FROM   vgc_controles cte2
                                ,      vgc_lab_monsters lmr
                                ,      vgc_monsteronderzoeken mon
                                ,      vgc_onderzoeken ozk
                                WHERE cte2.ptj_id =  v_ptj_id
                                AND   cte2.ptj_id =  lmr.cte_ptj_id
                                AND   mon.lmr_id  = lmr.id
                                AND   mon.ozk_id  = ozk.id
                                AND   ozk.traces_id IS NOT NULL
                               )
                         )
                       END CASE
       ,               CASE WHEN bte.code IN ('VWG', 'DWG')
                       THEN
                         xmlelement("refusal"
       ,                   xmlelement("notAcceptable"
       ,                     xmlelement("controlledDestination", get_relatie_element('AF', ptj.af_naam, ptj.af_land, ptj.af_plaats, ptj.af_postcode, ptj.af_straat_postbus, ptj.af_huisnummer, ptj.af_huisnummertoevoeging, get_tnt_activity_code(v_gn_code, 'AF', 'L'),ptj.af_id_type,nvl(ptj.af_id,ptj.af_traces_id))) /*#12*/
         ,                   (SELECT xmlagg(xmlelement("notAcceptableActions", xmlattributes(decode(wbe.omschrijving_traces, NULL , 'true', 'false') "xsi:nil"),  wbe.omschrijving_traces))
                             FROM vgc_v_weigerbestemming_types wbe
                             WHERE wbe.id = bsg.wbe_id
                            )
--        ,                    xmlelement("notAcceptableDate", to_char(bsg.datumtijd, 'yyyy-mm-dd"T"hh24:mi:ss'))
        ,                    xmlelement("ExpiryDate", to_char(bsg.uiterste_datum, 'yyyy-mm-dd"T"hh24:mi:ss'))
                          )
       ,                   xmlelement("reasonForRefusal"
       ,                     xmlelement("nonApprovedCountryCode",  xmlattributes(decode(v_non_approved_country_ind , 0 , 'true', 'false') "xsi:nil"), CASE WHEN v_non_approved_country_ind = 1 THEN lrg.lnd_code ELSE NULL END)  --???
       ,                       (SELECT xmlagg(xmlelement("reasons", get_tnt_refusal_reason(wrn.code, 'LWN')))
                                FROM   vgc_v_weigeringen wgg
                                ,      vgc_v_weigeringredenen wrn
                                WHERE  wgg.bsg_id = bsg.id
                                AND    wgg.wrn_id = wrn.id
                               )
                           )
                         )
                       ELSE
                         xmlelement("refusal", xmlattributes('true' "xsi:nil"))
                       END CASE
      ,                CASE WHEN nvl(v_aantal_containers,0) > 0
                       THEN
                         ( SELECT xmlagg(
                                    xmlelement("sealContainer"
                           ,          xmlelement("containerNumber",xmlattributes(decode(nummer, NULL,'true','false') "xsi:nil"),  nummer)
                           ,          xmlelement("sealNumber", xmlattributes(decode(zegelnummer, NULL,'true','false') "xsi:nil"), substr(zegelnummer,1,32))
                           ,          xmlelement("resealedSealNumber", xmlattributes(decode(vervangend_zegelnummer, NULL,'true','false') "xsi:nil"), substr(vervangend_zegelnummer,1,32))
                                    )
                                  )
                           FROM( SELECT DISTINCT replace(ctn.nummer,'-','') nummer
                                 ,      ctn.zegelnummer
                                 ,      ctn.vervangend_zegelnummer
                                 FROM   vgc_v_containers ctn
                                 ,      vgc_v_colli cli
                                 WHERE  ctn.clo_id = cli.id
                                 AND    cli.ptj_id = v_ptj_id
                                 AND    ctn.vervangend_zegelnummer IS NOT NULL
                               )
                         )
                       ELSE
                         xmlelement("sealContainer"
       ,                   xmlelement("resealedSealNumber", xmlattributes(decode(bsg.vervangend_zegelnummer , NULL , 'true', 'false') "xsi:nil"), bsg.vervangend_zegelnummer)
                                   )    
                    END
                     )
                   WHEN ptj.ptj_type = 'NPJ' -- producten CHEDP
                   THEN
                     xmlelement("CHEDAnimalProductsDecision"
       ,               xmlelement("certificateIdentification"
       ,                 xmlelement("referenceNumber" , ptj.traces_certificaat_id)
       ,                 xmlelement("type" , 'CHEDP')
                       )
       ,               xmlelement("localID", ptj.ggs_nummer)
       ,               xmlelement("signature"
       ,                 xmlelement("dateOfDeclaration" , to_char(SYSDATE, 'yyyy-mm-dd"T"hh24:mi:ss'))
       ,                  xmlelement("signatory"
       ,                    xmlelement("userDetail"
       ,                      xmlelement("lastName", xmlattributes(decode(mdr.naam, NULL,'true','false') "xsi:nil"), mdr.voornaam || ' '||mdr.naam)
                           )
                         )
                       )
       ,               CASE WHEN vbg.code = 'IVR' AND bte.code = 'TLG' AND (bsg.artikel_8_ind IS NULL OR bsg.artikel_8_ind = 'N')
                       THEN
                         xmlelement("acceptance"
       ,                    xmlelement("forInternalMarket"
       ,                      xmlelement("freeCirculationUsage", xmlattributes(decode(get_tnt_destination_2(gbl.code, 'NGL'), NULL , 'true', 'false') "xsi:nil"), get_tnt_destination_2(gbl.code, 'NGL'))
                            )
                        )
                       WHEN (vbg.code = 'IVR' AND bsg.artikel_8_ind = 'J' AND bte.code = 'TLG') OR (vbg.code = 'WIR' AND bte.code = 'TLG')
                       THEN
                         xmlelement("acceptance"
       ,                   xmlelement("ifChannelled"
       ,                     xmlelement("channelingProcedure", CASE WHEN vbg.code = 'IVR' AND bsg.artikel_8_ind = 'J' /*#2*/ THEN 'ARTICLE_8_PROCEDURE' ELSE 'REIMPORT_OF_EU_PRODUCTS' END)
       ,                     xmlelement("controlledDestination", get_relatie_element('AF', ptj.af_naam, ptj.af_land, ptj.af_plaats, ptj.af_postcode, ptj.af_straat_postbus, ptj.af_huisnummer, ptj.af_huisnummertoevoeging, get_tnt_activity_code(v_gn_code, 'AF', 'P'),ptj.af_id_type,nvl(ptj.af_id,ptj.af_traces_id))) /*#12*/
                           )
                         )
                       WHEN vbg.code = 'OPS' AND bte.code = 'TLG'
                       THEN
                         xmlelement("acceptance"
       ,                   xmlelement("forSpecificWarehouseProcedure"
                           -- Indien een of meerdere erkenningsnummers zijn opgegeven
       ,                   CASE WHEN ptj.registratienummer IS NOT NULL
                           THEN
                             xmlelement("controlledDestination"
       ,                       xmlelement("activity"
       ,                         vgc_xml.element('referenceDataCode', get_tnt_activity_code(v_gn_code, 'AF', 'P')))
       ,                       xmlelement("business"
       ,                         vgc_xml.element('approvalNumber', ptj.registratienummer)
       ,                         vgc_xml.element('countryCode', ptj.af_land)
                               )
                             )
                           ELSE
                             xmlelement("controlledDestination", get_relatie_element('AF', ptj.af_naam, ptj.af_land, ptj.af_plaats, ptj.af_postcode, ptj.af_straat_postbus, ptj.af_huisnummer, ptj.af_huisnummertoevoeging, get_tnt_activity_code(v_gn_code, 'AF', 'P'),ptj.af_id_type,nvl(ptj.af_id,ptj.af_traces_id)) /*#12*/
                             )
                           END CASE
       ,                     xmlelement("destinationType", xmlattributes(decode(get_tnt_destination_type(bsg.opslag), NULL , 'true', 'false') "xsi:nil"), get_tnt_destination_type(bsg.opslag))
                           )
                         )
                       WHEN vbg.code = 'DVR' AND bte.code = 'TLG'
                       THEN
                         xmlelement("acceptance"
       ,                   xmlelement("forTransitProcedure", decode(bce.us_army_ind,'J','MILITARY_FACILITY',NULL))
                         )
                       ELSE
                         xmlelement("acceptance" ,xmlattributes('true' "xsi:nil"))
                       END CASE
       ,               xmlelement("checklist"
       ,                 xmlelement("documentaryCheck", xmlattributes(decode(get_tnt_test_result_bin(cte.oordeel_d), NULL , 'true', 'false') "xsi:nil"), get_tnt_test_result_bin(cte.oordeel_d))
       ,                 case when get_tnt_test_result_bin(cte.oordeel_o, 'O') is null
                         then
                           null
                         else
                           ( select xmlelement("identityCheck"
                ,                   xmlelement("result", xmlattributes(decode(get_tnt_test_result_bin(cte.oordeel_o, 'O'), NULL , 'true', 'false') "xsi:nil"), get_tnt_test_result_bin(cte.oordeel_o, 'O'))
                ,                   xmlelement("type", xmlattributes(decode(get_tnt_type_onderzoek(cte.type_o), NULL , 'true', 'false') "xsi:nil"),   get_tnt_type_onderzoek(cte.type_o))
                                    )
                             from dual )
                         end
       ,                 xmlelement("physicalCheck"
       ,                   xmlelement("notDoneReason", xmlattributes(decode(get_tnt_test_result_ter(cte.oordeel_m), 'DEROGATION_OR_NOTDONE' , 'false', 'true') "xsi:nil")
       ,                     CASE WHEN get_tnt_test_result_ter(cte.oordeel_m) = 'DEROGATION_OR_NOTDONE'
                             THEN
                               CASE WHEN vbg.code = 'IVR' AND cte.m_verplicht_ind = 'N'
                               THEN
                                 'REDUCED_CHECKS'
                               ELSE
                                 'OTHER'
                               END                      
                             ELSE
                               NULL
                             END
                           )
        ,                  xmlelement("result",  get_tnt_test_result_ter(cte.oordeel_m))                     
                         )
                       )
        ,              xmlelement("customsDocumentReference", ptj.ggs_nummer)
        ,              CASE WHEN cte.lab_oordeel = 'NUD'
                       THEN
                         NULL
                       WHEN cte.lab_oordeel = 'TCN'
                       THEN
                         (SELECT xmlelement("laboratoryTests"
                          ,        xmlelement("date", to_char(v_min_datumtijd_monstername, 'yyyy-mm-dd"T"hh24:mi:ss'))
                          ,        xmlagg (xmlelement("laboratoryTest"
                          ,                xmlelement("conclusionAuthority", get_tnt_labtest_result(cte.lab_oordeel,'M'))
                          ,                  xmlelement("extendedInformation"
                          ,                    xmlelement("conclusionLaboratory", get_tnt_labtest_result(cte.lab_oordeel,'L'))
                          ,                    xmlelement("laboratoryTestIdentification"
                          ,                      xmlelement("laboratoryTestLocalID",xmlattributes(decode(mon_id, NULL , 'true', 'false') "xsi:nil"),  mon_id)
                          ,                      xmlelement("laboratoryTestReferenceNumber",xmlattributes(decode(dossiernummer, NULL , 'true', 'false') "xsi:nil"),  dossiernummer)
                                               )
                          ,                    xmlelement("sampleDate", xmlattributes(decode(datumtijd_monstername, NULL , 'true', 'false') "xsi:nil"), to_char(datumtijd_monstername, 'yyyy-mm-dd"T"hh24:mi:ss'))
                                             )
                          ,                xmlelement("laboratoryTestMoleculeTracesId", xmlattributes(decode(traces_id, NULL , 'true', 'false') "xsi:nil"), traces_id)
                                           )
                                          )
                          ,               xmlelement("motivation", get_tnt_test_reason (v_lmn_code, reden_monstername))
                                 )
                          FROM (SELECT DISTINCT cte2.lab_oordeel
                                ,      lmr.datumtijd_monstername
                                ,      ozk.traces_id
                                ,      mon.id mon_id
                                ,      lmr.dossiernummer
                                FROM   vgc_controles cte2
                                ,      vgc_lab_monsters lmr
                                ,      vgc_monsteronderzoeken mon
                                ,      vgc_onderzoeken ozk
                                WHERE  cte2.ptj_id =  v_ptj_id
                                AND    cte2.ptj_id =  lmr.cte_ptj_id
                                AND    mon.lmr_id  = lmr.id
                                AND    mon.ozk_id  = ozk.id
                                AND    ozk.traces_id IS NOT NULL
                               )
                         )
                       ELSE
                         (SELECT xmlelement("laboratoryTests"
                          ,        xmlelement("date", to_char(v_min_datumtijd_monstername, 'yyyy-mm-dd"T"hh24:mi:ss'))
                          ,        xmlagg (xmlelement("laboratoryTest"
                          ,                xmlelement("conclusionAuthority", CASE WHEN bte.code = 'TLG' THEN 'SATISFACTORY' WHEN bte.code IN ('VWG', 'DWG') THEN 'NOT_SATISFACTORY' END)
                          ,                  xmlelement("extendedInformation"
                          ,                    xmlelement("conclusionLaboratory", get_tnt_labtest_result(cte.lab_oordeel,'L'))
                          ,                    xmlelement("laboratoryTestIdentification"
                          ,                      xmlelement("laboratoryTestLocalID",xmlattributes(decode(mon_id, NULL , 'true', 'false') "xsi:nil"),  mon_id)
                          ,                      xmlelement("laboratoryTestReferenceNumber",xmlattributes(decode(dossiernummer, NULL , 'true', 'false') "xsi:nil"),  dossiernummer)
                                               )
                          ,                    xmlelement("sampleDate", xmlattributes(decode(datumtijd_monstername, NULL , 'true', 'false') "xsi:nil"), to_char(datumtijd_monstername, 'yyyy-mm-dd"T"hh24:mi:ss'))
                                             )
                          ,                xmlelement("laboratoryTestMoleculeTracesId", xmlattributes(decode(traces_id, NULL , 'true', 'false') "xsi:nil"), traces_id)
                                           )
                                          )
                          ,               xmlelement("motivation", get_tnt_test_reason (v_lmn_code, reden_monstername))
                                 )
                          FROM (SELECT DISTINCT cte2.lab_oordeel
                                ,      lmr.datumtijd_monstername
                                ,      ozk.traces_id
                                ,      mon.id mon_id
                                ,      lmr.dossiernummer
                                FROM   vgc_controles cte2
                                ,      vgc_lab_monsters lmr
                                ,      vgc_monsteronderzoeken mon
                                ,      vgc_onderzoeken ozk
                                WHERE cte2.ptj_id =  v_ptj_id
                                AND   cte2.ptj_id =  lmr.cte_ptj_id
                                AND   mon.lmr_id  = lmr.id
                                AND   mon.ozk_id  = ozk.id
                                AND   ozk.traces_id IS NOT NULL
                               )
                         )
                       END CASE
        ,              CASE WHEN bte.code IN ('VWG', 'DWG')
                       THEN
                         xmlelement("refusal"
        ,                  xmlelement("notAcceptable"
        ,                    xmlelement("controlledDestination",get_relatie_element('AF', ptj.af_naam, ptj.af_land, ptj.af_plaats, ptj.af_postcode, ptj.af_straat_postbus, ptj.af_huisnummer, ptj.af_huisnummertoevoeging, get_tnt_activity_code(v_gn_code, 'AF', 'P'),ptj.af_id_type,nvl(ptj.af_id,ptj.af_traces_id)))
        ,                   (SELECT xmlagg(xmlelement("notAcceptableActions", xmlattributes(decode(wbe.omschrijving_traces, NULL , 'true', 'false') "xsi:nil"),  wbe.omschrijving_traces))
                             FROM vgc_v_weigerbestemming_types wbe
                             WHERE wbe.id = bsg.wbe_id
                            )
        ,                    xmlelement("notAcceptableDate", to_char(bsg.datumtijd, 'yyyy-mm-dd"T"hh24:mi:ss'))
        ,                    xmlelement("ExpiryDate", to_char(bsg.uiterste_datum, 'yyyy-mm-dd"T"hh24:mi:ss'))
                          )
        ,                  xmlelement("reasonForRefusal"
        ,                    xmlelement("nonApprovedCountryCode",  xmlattributes(decode(v_non_approved_country_ind , 0 , 'true', 'false') "xsi:nil"), CASE WHEN v_non_approved_country_ind = 1 THEN lrg.lnd_code ELSE NULL  END)
        ,                    xmlelement("nonApprovedEstablishment",  xmlattributes(decode(v_non_approved_establishme_ind , 0 , 'true', 'false') "xsi:nil"), CASE WHEN v_non_approved_establishme_ind = 1 THEN lrg.lnd_code ELSE NULL  END)
        ,                   (SELECT xmlagg(xmlelement("reasons", get_tnt_refusal_reason(wrn.code, 'NWN')))
                             FROM vgc_v_weigeringen wgg
                             ,    vgc_v_weigeringredenen wrn
                             WHERE wgg.bsg_id = bsg.id
                             AND   wgg.wrn_id = wrn.id
                            )
                           )
                         )
                       ELSE
                         xmlelement("refusal", xmlattributes('true' "xsi:nil"))
                       END CASE
      ,                CASE WHEN nvl(v_aantal_containers,0) > 0
                       THEN
                         ( SELECT xmlagg(
                                    xmlelement("sealContainer"
                           ,          xmlelement("containerNumber",xmlattributes(decode(nummer, NULL,'true','false') "xsi:nil"),  nummer)
                           ,          xmlelement("sealNumber", xmlattributes(decode(zegelnummer, NULL,'true','false') "xsi:nil"), substr(zegelnummer,1,32))
                           ,          xmlelement("resealedSealNumber", xmlattributes(decode(vervangend_zegelnummer, NULL,'true','false') "xsi:nil"), substr(vervangend_zegelnummer,1,32))
                                    )
                                  )
                           FROM( SELECT DISTINCT replace(ctn.nummer,'-','') nummer
                                 ,      ctn.zegelnummer
                                 ,      ctn.vervangend_zegelnummer
                                 FROM   vgc_v_containers ctn
                                 ,      vgc_v_colli cli
                                 WHERE  ctn.clo_id = cli.id
                                 AND    cli.ptj_id = v_ptj_id
                                 AND    ctn.vervangend_zegelnummer IS NOT NULL
                               )
                         )
--                       ELSE
--                         xmlelement("sealContainer"
--       ,                   xmlelement("resealedSealNumber", xmlattributes(decode(bsg.vervangend_zegelnummer , NULL , 'true', 'false') "xsi:nil"), bsg.vervangend_zegelnummer)
--                                   )
                       END
                     )
                   ELSE -- producten CHEDD (nonAnimalProduct)
                     xmlelement("CHEDNonAnimalProductsDecision"
       ,               xmlelement("certificateIdentification"
       ,                 xmlelement("referenceNumber" , ptj.traces_certificaat_id)
       ,                 xmlelement("type" , 'CHEDD')
                       )
       ,               xmlelement("localID", ptj.ggs_nummer)
       ,               xmlelement("signature"
       ,                 xmlelement("dateOfDeclaration" , to_char(SYSDATE, 'yyyy-mm-dd"T"hh24:mi:ss'))
       ,                  xmlelement("signatory"
       ,                    xmlelement("userDetail"
       ,                      xmlelement("lastName", xmlattributes(decode(mdr.naam, NULL,'true','false') "xsi:nil"), mdr.voornaam || ' '||mdr.naam)
                           )
                         )
                       )
       ,               CASE WHEN vbg.code = 'IVR'
                       THEN
                         xmlelement("acceptance"
       ,                    xmlelement("forInternalMarket"
       ,                      xmlelement("freeCirculationUsage", xmlattributes(decode(get_tnt_destination_2(gbl.code, 'LNV'), NULL , 'true', 'false') "xsi:nil"), get_tnt_destination_2(gbl.code, 'LNV'))
                            )
                        )
                       WHEN vbg.code = 'TRT'
                       THEN
                         xmlelement("acceptance"
      ,                     xmlelement("forTransferTo"
      ,                        xmlelement("TransferToCountryCode",xmlattributes(decode(bcs_lnd.code, NULL,'true','false') "xsi:nil"), bcs_lnd.code)
      ,                        xmlelement("TransferToID",xmlattributes(decode(bcs.animo_code, NULL,'true','false') "xsi:nil"), bcs.animo_code)
                              )
                         )
                       ELSE
                         xmlelement("acceptance" ,xmlattributes('true' "xsi:nil"))
                       END CASE
       ,               xmlelement("checklist"
       ,                 xmlelement("documentaryCheck", xmlattributes(decode(get_tnt_test_result_bin(cte.oordeel_d), NULL , 'true', 'false') "xsi:nil"), get_tnt_test_result_bin(cte.oordeel_d))
       ,                 case when get_tnt_test_result_bin(cte.oordeel_o, 'O') is null
                         then
                           null
                         else
                           ( select xmlelement("identityCheck"
                ,                   xmlelement("result", xmlattributes(decode(get_tnt_test_result_bin(cte.oordeel_o, 'O'), NULL , 'true', 'false') "xsi:nil"), get_tnt_test_result_bin(cte.oordeel_o, 'O'))
                ,                   xmlelement("type", xmlattributes(decode(get_tnt_type_onderzoek(cte.type_o), NULL , 'true', 'false') "xsi:nil"),   get_tnt_type_onderzoek(cte.type_o))
                                    )
                             from dual )
                         end
       ,                 xmlelement("physicalCheck"
        ,                  xmlelement("result",  get_tnt_test_result_ter(cte.oordeel_m))
                         )
                       )
        ,              xmlelement("customsDocumentReference", ptj.ggs_nummer)
        ,              CASE WHEN cte.lab_oordeel = 'NUD'
                       THEN
                         NULL
                       WHEN cte.lab_oordeel = 'TCN'
                       THEN
                         (SELECT xmlelement("laboratoryTests"
                          ,        xmlelement("date", to_char(v_min_datumtijd_monstername, 'yyyy-mm-dd"T"hh24:mi:ss'))
                          ,        xmlagg (xmlelement("laboratoryTest"
                          ,                xmlelement("conclusionAuthority", get_tnt_labtest_result(cte.lab_oordeel,'M'))
                          ,                  xmlelement("extendedInformation"
                          ,                    xmlelement("conclusionLaboratory", get_tnt_labtest_result(cte.lab_oordeel,'L'))
                          ,                    xmlelement("laboratoryTestIdentification"
                          ,                      xmlelement("laboratoryTestLocalID",xmlattributes(decode(mon_id, NULL , 'true', 'false') "xsi:nil"),  mon_id)
                          ,                      xmlelement("laboratoryTestReferenceNumber",xmlattributes(decode(dossiernummer, NULL , 'true', 'false') "xsi:nil"),  dossiernummer)
                                               )
                          ,                    xmlelement("sampleDate", xmlattributes(decode(datumtijd_monstername, NULL , 'true', 'false') "xsi:nil"), to_char(datumtijd_monstername, 'yyyy-mm-dd"T"hh24:mi:ss'))
                                             )
                          ,                xmlelement("laboratoryTestMoleculeTracesId", xmlattributes(decode(traces_id, NULL , 'true', 'false') "xsi:nil"), traces_id)
                                           )
                                          )
                          ,               xmlelement("motivation", get_tnt_test_reason (v_lmn_code, reden_monstername))
                                 )
                          FROM (SELECT DISTINCT cte2.lab_oordeel
                                ,      lmr.datumtijd_monstername
                                ,      ozk.traces_id
                                ,      mon.id mon_id
                                ,      lmr.dossiernummer
                                FROM   vgc_controles cte2
                                ,      vgc_lab_monsters lmr
                                ,      vgc_monsteronderzoeken mon
                                ,      vgc_onderzoeken ozk
                                WHERE  cte2.ptj_id =  v_ptj_id
                                AND    cte2.ptj_id =  lmr.cte_ptj_id
                                AND    mon.lmr_id  = lmr.id
                                AND    mon.ozk_id  = ozk.id
                                AND    ozk.traces_id IS NOT NULL
                               )
                         )
                       ELSE
                         (SELECT xmlelement("laboratoryTests"
                          ,        xmlelement("date", to_char(v_min_datumtijd_monstername, 'yyyy-mm-dd"T"hh24:mi:ss'))
                          ,        xmlagg (xmlelement("laboratoryTest"
                          ,                xmlelement("conclusionAuthority", CASE WHEN bte.code = 'TLG' THEN 'SATISFACTORY' WHEN bte.code IN ('VWG', 'DWG') THEN 'NOT_SATISFACTORY' END)
                          ,                  xmlelement("extendedInformation"
                          ,                    xmlelement("conclusionLaboratory", get_tnt_labtest_result(cte.lab_oordeel,'L'))
                          ,                    xmlelement("laboratoryTestIdentification"
                          ,                      xmlelement("laboratoryTestLocalID",xmlattributes(decode(mon_id, NULL , 'true', 'false') "xsi:nil"),  mon_id)
                          ,                      xmlelement("laboratoryTestReferenceNumber",xmlattributes(decode(dossiernummer, NULL , 'true', 'false') "xsi:nil"),  dossiernummer)
                                               )
                          ,                    xmlelement("sampleDate", xmlattributes(decode(datumtijd_monstername, NULL , 'true', 'false') "xsi:nil"), to_char(datumtijd_monstername, 'yyyy-mm-dd"T"hh24:mi:ss'))
                                             )
                          ,                xmlelement("laboratoryTestMoleculeTracesId", xmlattributes(decode(traces_id, NULL , 'true', 'false') "xsi:nil"), traces_id)
                                           )
                                          )
                          ,               xmlelement("motivation", get_tnt_test_reason (v_lmn_code, reden_monstername))
                                 )
                          FROM (SELECT DISTINCT cte2.lab_oordeel
                                ,      lmr.datumtijd_monstername
                                ,      ozk.traces_id
                                ,      mon.id mon_id
                                ,      lmr.dossiernummer
                                FROM   vgc_controles cte2
                                ,      vgc_lab_monsters lmr
                                ,      vgc_monsteronderzoeken mon
                                ,      vgc_onderzoeken ozk
                                WHERE cte2.ptj_id =  v_ptj_id
                                AND   cte2.ptj_id =  lmr.cte_ptj_id
                                AND   mon.lmr_id  = lmr.id
                                AND   mon.ozk_id  = ozk.id
                                AND   ozk.traces_id IS NOT NULL
                               )
                         )
                       END CASE
        ,              CASE WHEN bte.code IN ('VWG', 'DWG')
                       THEN
                         xmlelement("refusal"
        ,                  xmlelement("notAcceptable"
        ,                    xmlelement("controlledDestination",get_relatie_element('AF', ptj.af_naam, ptj.af_land, ptj.af_plaats, ptj.af_postcode, ptj.af_straat_postbus, ptj.af_huisnummer, ptj.af_huisnummertoevoeging, get_tnt_activity_code(v_gn_code, 'AF', 'V'),ptj.af_id_type,nvl(ptj.af_id,ptj.af_traces_id)))
        ,                   (SELECT xmlagg(xmlelement("notAcceptableActions", xmlattributes(decode(wbe.omschrijving_traces, NULL , 'true', 'false') "xsi:nil"),  wbe.omschrijving_traces))
                             FROM vgc_v_weigerbestemming_types wbe
                             WHERE wbe.id = bsg.wbe_id
                            )
        ,                    xmlelement("notAcceptableDate", to_char(bsg.datumtijd, 'yyyy-mm-dd"T"hh24:mi:ss'))
        ,                    xmlelement("ExpiryDate", to_char(bsg.uiterste_datum, 'yyyy-mm-dd"T"hh24:mi:ss'))
                        )
        ,                  xmlelement("reasonForRefusal"
        ,                    xmlelement("nonApprovedCountryCode",  xmlattributes(decode(v_non_approved_country_ind , 0 , 'true', 'false') "xsi:nil"), CASE WHEN v_non_approved_country_ind = 1 THEN lrg.lnd_code ELSE NULL  END)
        ,                    xmlelement("nonApprovedEstablishment",  xmlattributes(decode(v_non_approved_establishme_ind , 0 , 'true', 'false') "xsi:nil"), CASE WHEN v_non_approved_establishme_ind = 1 THEN lrg.lnd_code ELSE NULL  END)
        ,                   (SELECT xmlagg(xmlelement("reasons", get_tnt_refusal_reason(wrn.code, 'LNV')))
                             FROM vgc_v_weigeringen wgg
                             ,    vgc_v_weigeringredenen wrn
                             WHERE wgg.bsg_id = bsg.id
                             AND   wgg.wrn_id = wrn.id
                            )
                           )
                         )
                       ELSE
                         xmlelement("refusal", xmlattributes('true' "xsi:nil"))
                       END CASE
--        ,              xmlelement("resealedSealNumber", xmlattributes(decode(bsg.vervangend_zegelnummer , NULL , 'true', 'false') "xsi:nil"), bsg.vervangend_zegelnummer)
      ,                CASE WHEN nvl(v_aantal_containers,0) > 0
                       THEN
                         ( SELECT xmlagg(
                                    xmlelement("sealContainer"
                           ,          xmlelement("containerNumber",xmlattributes(decode(nummer, NULL,'true','false') "xsi:nil"),  nummer)
                           ,          xmlelement("sealNumber", xmlattributes(decode(zegelnummer, NULL,'true','false') "xsi:nil"), substr(zegelnummer,1,32))
                           ,          xmlelement("resealedSealNumber", xmlattributes(decode(vervangend_zegelnummer, NULL,'true','false') "xsi:nil"), substr(vervangend_zegelnummer,1,32))
                                    )
                                  )
                           FROM( SELECT DISTINCT replace(ctn.nummer,'-','') nummer
                                 ,      ctn.zegelnummer
                                 ,      ctn.vervangend_zegelnummer
                                 FROM   vgc_v_containers ctn
                                 ,      vgc_v_colli cli
                                 WHERE  ctn.clo_id = cli.id
                                 AND    cli.ptj_id = v_ptj_id
                                 AND    ctn.vervangend_zegelnummer IS NOT NULL
                               )
                         )
--                       ELSE
--                         xmlelement("sealContainer"
--                         ,          xmlelement("containerNumber",xmlattributes('true' "xsi:nil"))
--                         ,          xmlelement("sealNumber", xmlattributes('true' "xsi:nil"))
--                         ,          xmlelement("resealedSealNumber", xmlattributes(decode(bsg.vervangend_zegelnummer, NULL,'true','false') "xsi:nil"), substr(bsg.vervangend_zegelnummer,1,32))
--        ,              xmlelement("resealedSealNumber", xmlattributes(decode(bsg.vervangend_zegelnummer , NULL , 'true', 'false') "xsi:nil"), bsg.vervangend_zegelnummer)
--                                    )
                       END
                     )
                   END CASE
        ,          xmlelement("htdConfirmationToken", v_htd_token_ref)
                 )
               )
             )
            ).getClobval()
        FROM  vgc_partijen ptj
        ,     vgc_v_keurpunten bce
        ,     vgc_v_keurpunten bcs
        ,     vgc_v_gebruiksdoelen gbl
        ,     vgc_v_beslissingen bsg
        ,     vgc_v_beslissingtypes bte
        ,     vgc_v_veterin_bestemmingen vbg
        ,     vgc_v_controles cte
        ,     vgc_v_weigerbestemming_types wbe
        ,     vgc_v_landrol_oorsprong lrg
        ,     vgc_v_veterin_documenten vdt
        ,     vgc_erkenningen att
        ,     vgc_v_medewerkers mdr
        ,     vgc_v_landen bcs_lnd
        WHERE ptj.ggs_nummer = p_ggs_nummer
        AND   lrg.ptj_id (+) = ptj.id                -- land van oorsprong
        AND   vdt.ptj_id  = ptj.id                   -- veterinaire document
        AND   vdt.id = v_primair_doc_id              -- veterinaire document
        AND   bce.id (+) = ptj.kpt_id_doorv_overl_bip -- bip_code_exit
        AND   bcs.id (+) = ptj.kpt_id_aangeb_sip      -- sip_code_aangeb
        AND   bcs_lnd.id (+) = bcs.lnd_id
        AND   att.ptj_id (+) = ptj.id                -- erkenningsnummer
        AND   bsg.ptj_id (+) = ptj.id                -- beslissing
        AND   bsg.definitief_ind (+) = 'J'           -- beslissing
        AND   bsg.mdr_id = mdr.id (+)
        AND   bte.id (+) = bsg.bse_id                -- beslissingstype
        AND   gbl.id (+) = bsg.gbl_id                -- gebruiksdoel
        AND   vbg.id (+) = bsg.vbg_id                -- veterinaire bestemming
        AND   cte.ptj_id (+) = ptj.id                -- controles
        AND   wbe.id (+) = bsg.wbe_id                -- weigeringbestemming
        ORDER BY bsg.creation_date DESC
      ;

  --

  BEGIN
    OPEN c_xml;
    FETCH c_xml INTO  r_rqt.webservice_bericht;
    CLOSE c_xml;
    escape_xml (r_rqt.webservice_bericht);
  EXCEPTION
    WHEN OTHERS THEN
      IF c_xml%ISOPEN THEN
        CLOSE c_xml;
      END IF;

      RAISE;

  END maak_bericht;

  --

BEGIN
  trace(v_objectnaam);
  vgc_blg.write_log('start' , v_objectnaam, 'J', 5);
  vgc_blg.write_log('P_GGS_NUMMER:'||p_ggs_nummer , v_objectnaam, 'J', 5);
  vgc_blg.write_log('P_REQUEST_ID:'||p_request_id , v_objectnaam, 'J', 5);
  --
  IF p_request_id IS NOT NULL
  THEN
    OPEN c_rqt;
    FETCH c_rqt INTO r_rqt;
    CLOSE c_rqt;
    --
    --check_bestaande_rqt (r_rqt);
  ELSE
    r_rqt.request_id := NULL;
  END IF;
  --
  -- initialiseren request
  --
  r_rqt.webservice_url         := vgc$algemeen.get_appl_register ('TRACES_CERTIFICATE_WS_URL');
  r_rqt.bestemd_voor           := NULL;
  r_rqt.webservice_logische_naam := 'VGC0503NT';
  r_rqt.ggs_nummer             :=  p_ggs_nummer;
  -- ophalen htd-token VGC0502U
  OPEN c_token;
  FETCH c_token INTO v_htd_token_ref;
  CLOSE c_token;
  --
  -- ophalen htd-token VGC0505NT
  OPEN c_token;
  FETCH c_token INTO v_htd_token_ref;
  CLOSE c_token;
  --
  vgc_blg.write_log('token '|| v_htd_token_ref , v_objectnaam, 'J', 5);
  IF v_htd_token_ref IS NOT NULL
  THEN
    -- bepaal of er sprake is van een niet erkend land
    OPEN c_wgg_country;
    FETCH c_wgg_country INTO v_non_approved_country_ind;
    CLOSE c_wgg_country;
    -- bepaal of er sprake is van een niet erkende inrichting
    OPEN c_wgg_establishment;
    FETCH c_wgg_establishment INTO v_non_approved_establishme_ind;
    CLOSE c_wgg_establishment;
    -- ophalen enkele partijgegevens
    OPEN c_ptj;
    FETCH c_ptj INTO v_ptj_id, v_aangevernummer, v_aangiftejaar, v_aangifte_volgnummer, v_cim_class, v_erkenningsnummer, v_chednummer;
    CLOSE c_ptj;
    --
    -- originEstablishments
    --
    -- haal de aanvullende/juiste productgegevens op
    get_tnt_commodity_ids('VGC', v_ptj_id, v_gn_code);
  vgc_blg.write_log('na commodities' , v_objectnaam, 'J', 5);
    --ophalen primair veterinair document*/
    OPEN c_prim_doc(v_ptj_id);
    FETCH c_prim_doc INTO v_primair_doc_id;
    CLOSE c_prim_doc;
    --
    v_erkenningsnummer := TRIM(v_erkenningsnummer);
    OPEN  c_toe4;
    FETCH c_toe4 INTO v_vier_pos;
    CLOSE c_toe4;
    OPEN  c_toe3;
    FETCH c_toe3 INTO v_drie_pos;
    CLOSE c_toe3;
    --
    IF v_erkenningsnummer IS NOT NULL
    AND upper(v_erkenningsnummer) NOT IN ('NVT','ONBEKEND')
    THEN
      --> Nieuwe opzet erkenningen
      FOR r_erk IN ( SELECT e.*,l.code
                     FROM   vgc_erkenningen e
                     ,      vgc_v_landen l
                     WHERE  e.ptj_id = v_ptj_id
                     AND    l.id  (+)= NVL(e.lnd_id,-1) )
      LOOP
          INSERT INTO vgc_tt_oe
           ( activity_code
           , approvalnumber
           , lnd_code)
          VALUES
           ( r_erk.activiteit
           , r_erk.erkenningsnummer
           , r_erk.code);

      END LOOP;

    END IF;
  vgc_blg.write_log('na erkenningen' , v_objectnaam, 'J', 5);

    -- haal het aantal containers op
    OPEN c_ctr(v_ptj_id);
    FETCH c_ctr INTO v_aantal_containers;
    CLOSE c_ctr;
    -- haal de min datumtijd monstername (indien deze genomen zijn)
    OPEN c_lmr(v_ptj_id);
    FETCH c_lmr INTO v_min_datumtijd_monstername;
    CLOSE c_lmr;
    --
    OPEN c_lmn(v_ptj_id,v_min_datumtijd_monstername );
    FETCH c_lmn INTO v_lmn_code;
    CLOSE c_lmn;
  vgc_blg.write_log('voor maak bericht' , v_objectnaam, 'J', 5);
    -- opstellen bericht
    maak_bericht;
  vgc_blg.write_log('na maak bericht' , v_objectnaam, 'J', 5);
    -- aanroepen webservice
    vgc_ws_cms.vgc_cms_out
      (p_aangevernummer => v_aangevernummer
      ,p_aangiftejaar => v_aangiftejaar
      ,p_aangifte_volgnummer => v_aangifte_volgnummer
      ,p_ggs_nummer => p_ggs_nummer
      ,p_classificatie => v_cim_class
      ,p_pdf => v_pdf_jn
      ,p_actiecode => 'U'
      ,p_chednummer => v_chednummer
      ,p_redencode => null
      ,p_redenafkeuring => null
      ,p_ws_naam => 'VGC0503NT'
      ,p_xml => r_rqt.webservice_bericht
      ,p_request_id => v_request_id
      ,p_resultaat => v_resultaat
      );
    --
    -- verwerking webservice antwoord
    --
  vgc_blg.write_log('na webservice' , v_objectnaam, 'J', 5);
    verwerk_traces_antwoord
      ( p_ws_naam        => v_ws_naam
      , p_request_id     => v_request_id
      , p_ptj_id         => v_ptj_id
      , p_pdf_jn         => v_pdf_jn
      , p_resultaat      => v_resultaat
      , p_error_handling => 'N');
  END IF;
   --
  vgc_blg.write_log('eind' , v_objectnaam, 'N', 1);
  --
EXCEPTION
  WHEN OTHERS
  THEN
    vgc_blg.write_log('Exception: ' || SQLERRM, v_objectnaam, 'N', 1);
    qms$errors.unhandled_exception(v_objectnaam);

END VGC0503NT;
/* Indienen Zending VP (submitConsignmentVP) */

PROCEDURE VGC0504NT
 (P_VPJ_ID IN VGC_VP_PARTIJEN.ID%TYPE
 ,P_REQUEST_ID IN OUT VGC_REQUESTS.REQUEST_ID%TYPE
 ,P_ERROR_HANDLING IN VARCHAR2 := 'J'
 )
IS
  v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.VGC0504NT#01';
/*********************************************************************
Wijzigingshistorie
doel:
Indienen zending VGC-CLIENT bij TRACES-EU (SUBMIT CONSIGNMENT) uit VP

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
 1      27-02-2020 GLR     creatie
*********************************************************************/

--  haalt hoofd veterin doc op
  CURSOR c_vmt
  IS
    SELECT vmt.id
    ,      vmt.nummer
    FROM   vgc_v_vp_documenten vmt
    WHERE  vmt.vpj_id = p_vpj_id
    ORDER BY creation_date ASC
  ;

-- haalt de gesommeerde productgegevens op van de partij
  CURSOR c_vpt
  IS
    SELECT verpakkingsvorm
    ,      collo_aantal
    ,      gewicht_netto
    ,      gewicht_bruto
    ,      gn_code
    ,      traces_complement_id
    ,      traces_species_id
    ,      aantal
    FROM   vgc_v_vp_producten vpt
    WHERE  vpt.vpj_id = p_vpj_id
  ;

-- haalt de unieke sleutel van de vpj op zodat hier later aan
-- gerefereerd kan worden in de VGC0505U + erkenningsnummer en land van oorsprong om multiple oe's te herleiden
  CURSOR c_vpj
  IS
    SELECT vpj.aangevernummer
    ,      vpj.aangifte_volgnummer
    ,      vpj.aangiftejaar
    ,      vpj.classificatie
    ,      vat.erkenningsnummer
    ,      vpj.landcode_oorsprong
    ,      decode(vpj.classificatie,'PRD','P','LEV','A','D') cim_class
    FROM   vgc_v_vp_partijen vpj
    ,      vgc_v_vp_producten vpt
--    ,      vgc_v_vp_documenten vmt
    ,      vgc_v_vp_erkenningen vat
    WHERE  vpj.id = p_vpj_id
    AND    vpt.vpj_id = vpj.id
--    AND    vmt.vpt_id = vpt.id
    AND    vat.vpj_id(+) = vpj.id
  ;

-- haalt de traces_id en traces_activity_code opvan de ' AL' rol op
   CURSOR c_al_codes(p_vpj_aangevernummer vgc_v_vp_partijen.aangevernummer%TYPE)
   IS
     SELECT traces_id
     ,      traces_activity_code
     FROM   vgc_v_relaties
     WHERE  aangevernummer = p_vpj_aangevernummer
   ;

--
  CURSOR c_ptj(b_vpj_id vgc_v_vp_partijen.id%TYPE)
  IS
    SELECT ptj.traces_certificaat_id
    ,      ptj.ggs_nummer
    ,      ptj.aangiftejaar
    ,      ptj.id
    FROM   vgc_v_partijen    ptj
    ,      vgc_v_relaties    rle
    ,      vgc_v_vp_partijen vpj
    WHERE  ptj.rle_id = rle.id
    AND    rle.aangevernummer     = vpj.aangevernummer
    AND    ptj.aangiftejaar       = vpj.aangiftejaar
    AND    ptj.aangiftevolgnummer = vpj.aangifte_volgnummer
    AND    vpj.id                 = b_vpj_id
  ;
--
  CURSOR c_toe4
  IS
    SELECT ','||xmlagg(xmlelement(a,oe_code,',').extract('//text()')) vier_pos
    FROM   vgc_tnt_oe_codes
    WHERE  LENGTH(oe_code) = 4
  ;
--
  CURSOR c_toe3
  IS
    SELECT ','||xmlagg(xmlelement(a,oe_code,',').extract('//text()')) drie_pos
    FROM   vgc_tnt_oe_codes
    WHERE  LENGTH(oe_code) = 3
  ;
-- variabelen om de webservice response op te stellen, uit te lezen en te verwerken
  r_rqt                        vgc_requests%ROWTYPE;
-- berichtvariabelen
  v_aantal                     NUMBER := 0;
  v_collo_aantal               NUMBER := 0;
  v_netto_gewicht              NUMBER := 0;
  v_bruto_gewicht              NUMBER := 0;
  v_traces_certificaat_id      VARCHAR2(30 CHAR) := NULL;
  v_ggs_nummer                 VARCHAR2(10 CHAR);
  v_primair_doc_id             vgc_vp_documenten.id%TYPE;
  v_primair_doc_nummer         vgc_vp_documenten.nummer%TYPE;
  v_aangevernummer             vgc_vp_partijen.aangevernummer%TYPE;
  v_aangiftejaar               vgc_vp_partijen.aangiftejaar%TYPE;
  v_aangifte_volgnummer        vgc_vp_partijen.aangifte_volgnummer%TYPE;
  v_local_refnr                VARCHAR2(100 CHAR);
  v_hoofdverpakkingsvorm       VARCHAR2(20 CHAR);
  v_gn_code                    vgc_vp_producten.gn_code%TYPE;
  v_complement_id              vgc_v_gn_vertaling_traces.gn_code_comp_id%TYPE;
  v_species_id                 vgc_v_gn_vertaling_traces.species_id%TYPE;
  v_div_verpakkingsvormen      BOOLEAN := FALSE;
  v_verpakkingsvorm_vorig      VARCHAR2(20 CHAR) := NULL;
  v_al_activity_code           VARCHAR2(40 CHAR);
  v_al_traces_id               VARCHAR2(35 CHAR);
  v_erkenningsnummer           VARCHAR2(70 CHAR);
  v_landcode_oorsprong         VARCHAR2(10 CHAR);
  v_ptj_id                     vgc_partijen.id%TYPE;
  v_ws_naam                    VARCHAR2(100 CHAR) := 'VGC0504NT';
  e_ws_error                   EXCEPTION;
  v_ptj_type                   VARCHAR2(3 CHAR);
  e_specific_operation_error   EXCEPTION;
  e_general_operation_error    EXCEPTION;
  v_request_id                 NUMBER;
  v_resultaat                  BOOLEAN;
  v_chednummer                 VARCHAR2(50 CHAR);
  v_actiecode                  VARCHAR2(1 CHAR) := '1';
  v_pdf_jn                     VARCHAR2 (1 CHAR) := 'N';
  v_dummy                      VARCHAR2(1 CHAR);
  v_vier_pos                   VARCHAR2(250 CHAR) := NULL;
  v_drie_pos                   VARCHAR2(250 CHAR) := NULL;
  v_operation_username         VARCHAR2(100 CHAR) := vgc$algemeen.get_appl_register ('TNT_WS_OPERATION_USR');
  v_operation_password         VARCHAR2(100 CHAR) := vgc$algemeen.get_appl_register ('TNT_WS_OPERATION_PWD');
  v_services_username          VARCHAR2(100 CHAR) := vgc$algemeen.get_appl_register ('TNT_WS_SERVICES_USR');
  v_services_password          VARCHAR2(100 CHAR) := vgc$algemeen.get_appl_register ('TNT_WS_SERVICES_PWD');

--
-- Stel bericht op voor aanroep
--
  PROCEDURE maak_bericht(i_vp_ptj_id IN vgc_vp_partijen.id%TYPE)
  IS
    CURSOR c_xml
    IS
      SELECT c_encoding ||
             xmlelement("soap:Envelope"
      ,        xmlattributes ( 'http://schemas.xmlsoap.org/soap/envelope/' AS "xmlns:soap"
                             , 'http://www.w3.org/2001/XMLSchema-instance'  AS "xmlns:xsi"
                             , 'urn:axisgen.b2b.traces.sanco.cec.eu'  AS "xmlns:urn")
      ,        xmlelement("soap:Header")
      ,        xmlelement("soap:Body"
      ,          xmlelement("urn:submitConsignment"
      ,            xmlelement("in0"
      ,              xmlelement("VersionMIG", vpj.versienr_mig_in)
      ,              xmlelement("operationUserCredentials"
      ,                xmlelement("userName", v_operation_username)
      ,                xmlelement("userPassword", v_operation_password)
                     )
      ,              xmlelement("servicesUserCredentials"
      ,                xmlelement("userName", v_services_username)
      ,                xmlelement("userPassword", v_services_password)
                     )
      ,              CASE WHEN vpj.classificatie IN ('LEV', 'LVD')
                     THEN
                       xmlelement("CHEDAnimalsConsignment"
      ,                  CASE WHEN v_traces_certificaat_id IS NOT NULL
                         THEN
                           xmlelement("certificateIdentification" ,
                             xmlelement("referenceNumber" , v_traces_certificaat_id)
      ,                      xmlelement("type" , 'CHEDA')
                           )
                         ELSE
                           NULL
                         END
      ,                  ( select xmlagg(col)
                           from ( select (xmlelement("commodity"
                                                   ,xmlelement("commodityCode",vpt1.gn_code)
                                                   )) col
                                  from   vgc_v_vgc0504nt_vpt vpt1
                                  where  vpt1.vpj_id = i_vp_ptj_id
                                  group  by vpt1.gn_code --,vpt.traces_complement_id
                         ))
      ,                  xmlelement("signatory"
      ,                    xmlelement("dateOfDeclaration" , xmlattributes(decode(vpj.datum_ondertekening, NULL,'true','false') "xsi:nil"), get_ws_date(NULL, vpj.creation_date, 'yymmdd'))
      ,                    xmlelement("signatory"
      ,                       xmlelement("userDetail"
      ,                         xmlelement("lastName", xmlattributes(decode(vpj.ondertekenaarnaam, NULL,'true','false') "xsi:nil"), vpj.ondertekenaarnaam)
                              )
                           )
                         )
      ,                  xmlelement("animalsCertificatedAs"
      ,                     xmlelement("referenceDataCode", xmlattributes(decode(get_tnt_destination(vpj.gebruiksdoel,'LGL'), NULL,'true','false') "xsi:nil"),get_tnt_destination(vpj.gebruiksdoel,'LGL'))
                         )
      ,                  xmlelement("competentAuthority"
      ,                    xmlelement("code", xmlattributes(decode(vpj.bip_code_aanbod, NULL,'true','false') "xsi:nil"),vpj.bip_code_aanbod)
                         )
      ,                  xmlelement("consignor", get_relatie_element('DP', vpj.dp_naam, vpj.dp_land, vpj.dp_plaats, vpj.dp_postcode, vpj.dp_straat_postbus, vpj.dp_huisnummer, vpj.dp_huisnummertoevoeging, get_tnt_activity_code(v_gn_code, 'DP', 'V'),vpj.dp_id_type,nvl(vpj.dp_id,vpj.dp_traces_id)))--null)) --
      ,                  xmlelement("countryOfOriginCode", xmlattributes(decode(vpj.landcode_oorsprong, NULL,'true','false') "xsi:nil"),vpj.landcode_oorsprong)
      ,                  CASE WHEN to_date(vpj.aankomstdatum,'yymmddhh24mi') < sysdate
                         THEN
                           xmlelement("departureDate", xmlattributes(decode(sysdate + 1/48, NULL,'true','false') "xsi:nil"),get_ws_date(NULL, sysdate + 1/48, 'yymmddHH24MI'))
                         ELSE
                           xmlelement("departureDate", xmlattributes(decode(vpj.aankomstdatum, NULL,'true','false') "xsi:nil"),get_ws_date(NULL,to_date(vpj.aankomstdatum,'yymmddhh24mi') + 1/48, 'yymmddHH24MI'))
                         END
      ,                  xmlelement("estimatedArrivalAtBIP",  xmlattributes(decode(vpj.aankomstdatum, NULL,'true','false') "xsi:nil"),get_ws_date(vpj.aankomstdatum,NULL, 'yymmddHH24MI'))
      ,                  xmlelement("estimatedJourneyTime", 1)
      ,                  xmlelement("importer", get_relatie_element('IM',  vpj.im_naam, vpj.im_land, vpj.im_plaats, vpj.im_postcode, vpj.im_straat_postbus, vpj.im_huisnummer, vpj.im_huisnummertoevoeging, get_tnt_activity_code(v_gn_code, 'IM', 'V'),vpj.im_id_type,nvl(vpj.im_id,vpj.im_traces_id)))--null))--
      ,                  xmlelement("localReferenceNumber", CASE WHEN v_ggs_nummer IS NULL THEN v_local_refnr ELSE v_ggs_nummer END)
      ,                CASE WHEN vpj.versienr_mig_in > 5
                       THEN
                         ( SELECT xmlagg(xmlelement("meansOfTransport"
      ,                             xmlelement("document", xmlattributes(decode(vpj.vrachtbriefnummer, NULL,'true','false') "xsi:nil"),substr(vpj.vrachtbriefnummer,1,32))
      ,                             xmlelement("identification", xmlattributes(decode(identificatie, NULL,'true','false') "xsi:nil"), identificatie)
      ,                             xmlelement("type", xmlattributes(decode(vervoer, NULL,'true','false') "xsi:nil"), CASE WHEN kpt.luchthaven_ind = 'J' THEN 'PLANE' ELSE vervoer END)                               ))
                         FROM( SELECT DECODE(vpj.landcode_verzend,'GB','ROAD',cfe.rv_abbreviation) vervoer
                               ,      tpt.identificatie
                               FROM   vgc_v_vp_transporten tpt
                             --  ,      vgc_v_vp_partijen vpj2
                               ,      cg_ref_codes cfe
                               WHERE  tpt.vpj_id = i_vp_ptj_id
                            --   AND    vpj2.id = tpt.vpj_id
                               AND    cfe.rv_domain = 'SOORT VERVOER'
                               AND    cfe.rv_low_value = tpt.soort_transport
                               AND    tpt.voor_grens_ind = 'J')
                         )
                       ELSE
                         xmlelement("meansOfTransport"
      ,                    xmlelement("document", xmlattributes(decode(vpj.vrachtbriefnummer, NULL,'true','false') "xsi:nil"),substr(vpj.vrachtbriefnummer,1,32))
      ,                    xmlelement("identification", xmlattributes(decode(vpj.vaartuig_vluchtnummer, NULL,'true','false') "xsi:nil"), vpj.vaartuig_vluchtnummer)
      ,                    xmlelement("type", CASE WHEN vpj.LANDCODE_VERZEND = 'GB' THEN 'ROAD' ELSE  CASE WHEN kpt.luchthaven_ind = 'J' THEN 'PLANE' ELSE 'SHIP' END END)
                         )
                       END
      ,                CASE WHEN vpj.versienr_mig_in > 5
                       THEN
                         ( SELECT xmlagg(xmlelement("meansOfTransportAfterBIP"
      ,                             xmlelement("document", xmlattributes(decode(nvl(v_ggs_nummer,vpj.id), NULL,'true','false') "xsi:nil"), nvl(v_ggs_nummer,vpj.id))
      ,                             xmlelement("identification", xmlattributes(decode(identificatie, NULL,'true','false') "xsi:nil"), identificatie)
      ,                             xmlelement("type", xmlattributes(decode(vervoer, NULL,'true','false') "xsi:nil"), vervoer)                               ))
                         FROM( SELECT cfe.rv_abbreviation vervoer
                               ,      tpt.identificatie
                               FROM   vgc_v_vp_transporten tpt
                               ,      cg_ref_codes cfe
                               WHERE  tpt.vpj_id = i_vp_ptj_id
                               AND    cfe.rv_domain = 'SOORT VERVOER'
                               AND    cfe.rv_low_value = tpt.soort_transport
                               AND    tpt.voor_grens_ind = 'N')
                         )
                       ELSE
                           (SELECT xmlagg(xmlelement("meansOfTransportAfterBIP"                                   --herhalende groep
      ,                      xmlelement("document", xmlattributes(decode(nvl(v_ggs_nummer,vpj.id), NULL,'true','false') "xsi:nil"), nvl(v_ggs_nummer,vpj.id))
      ,                      xmlelement("identification", xmlattributes(decode(identificatie, NULL,'true','false') "xsi:nil"),vpj.transport_identificatie)
      ,                      xmlelement("type", get_tnt_transport_type(soort_transport))
                                            )
                                           )
                            FROM (SELECT DISTINCT vtr.identificatie
                                  ,      vtr.SOORT_TRANSPORT
                                  FROM   vgc_v_vp_transporten vtr
                                  WHERE  vtr.vpj_id = i_vp_ptj_id
                                  AND    vtr.voor_grens_ind = 'N'
                                 )
                           )
                        END
      ,                  xmlelement("numberOfAnimals" , xmlattributes(decode(v_aantal, NULL,'true','false') "xsi:nil"),  v_aantal)
      ,                  xmlelement("numberOfAnimalsUnit", 'UNIT')
      ,                  xmlelement("numberOfPackages",  xmlattributes(decode(v_collo_aantal, NULL,'true','false') "xsi:nil"),  v_collo_aantal)
      ,                  xmlelement("productGrossWeight", xmlattributes(decode(v_bruto_gewicht, NULL,'true','false') "xsi:nil"), LTRIM(TO_CHAR(v_bruto_gewicht,'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))
      ,                  xmlelement("placeOfDestination", get_relatie_element('AF', vpj.af_naam, vpj.af_land, vpj.af_plaats, vpj.af_postcode, vpj.af_straat_postbus, vpj.af_huisnummer, vpj.af_huisnummertoevoeging, get_tnt_activity_code(v_gn_code, 'AF', 'L'),vpj.af_id_type,nvl(vpj.af_id,vpj.af_traces_id)))
      ,                  CASE WHEN upper(vpj.bestemming) = 'IVR'
                         THEN
                           xmlelement("purpose"
      ,                      xmlelement("forImportOrAdmission"
      ,                        xmlelement("exitBip"
      ,                          xmlelement("code", xmlattributes(decode(vpj.bip_code_exit, NULL,'true','false') "xsi:nil"),substr(rpad(vpj.bip_code_exit,7),1,7))
                               )
      ,                        xmlelement("exitDate", xmlattributes(decode(vpj.uitslagdatum, NULL,'true','false') "xsi:nil"), get_ws_date(vpj.uitslagdatum, NULL, 'yymmddHH24MI'))
      ,                        xmlelement("measure", xmlattributes(decode(get_tnt_measure(vpj.aanvullende_best), NULL,'true','false') "xsi:nil"), get_tnt_measure(vpj.aanvullende_best))
                             )
                           )
                         WHEN vpj.bestemming = 'WIR'
                         THEN
                           xmlelement("purpose"
      ,                      xmlelement("forReImport")
                           )
                         WHEN upper(vpj.bestemming) = 'DVR'
                         THEN
                           xmlelement("purpose"
      ,                       xmlelement("forTransit"
      ,                         xmlelement("destinationThirdCountryCode",xmlattributes(decode(vpj.landcode_bestemming, NULL,'true','false') "xsi:nil"), vpj.landcode_bestemming)
      ,                         xmlelement("exitBip"
      ,                           xmlelement("code",xmlattributes(decode(vpj.bip_code_exit, NULL,'true','false') "xsi:nil"),decode(kpt2.us_army_ind,'J',kpt2.naam, decode(vpj.bip_code_exit,'FRCQF1',kpt2.naam,vpj.bip_code_exit)))
      ,                           xmlelement("type",xmlattributes(decode(kpt2.us_army_ind, 'N','true','false') "xsi:nil"), decode(kpt2.us_army_ind,'J','MILITARY_FACILITY',NULL))
                                )
                              )
                           )
                         ELSE
                           xmlelement("purpose", xmlattributes('true' "xsi:nil"))
                         END CASE
      ,                  xmlelement("regionOfOriginCode", xmlattributes(decode(vpj.regiocode, NULL,'true','false') "xsi:nil"),  vpj.regiocode)
      ,                  xmlelement("responsibleForConsignment", get_relatie_element('AL', vpj.al_naam, vpj.al_land, vpj.al_plaats, vpj.al_postcode, vpj.al_straat_postbus, vpj.al_huisnummer, vpj.al_huisnummertoevoeging, v_al_activity_code,null,rle_al.traces_id))
      ,                  xmlelement("responsibleForJourneyTransport", xmlattributes(decode(vpj.tr_naam, NULL,'true','false') "xsi:nil"), substr(vpj.tr_naam,1,32))
      ,                  (SELECT xmlagg(xmlelement("sealContainer"                                   --herhalende groep
                                          , xmlelement("containerNumber", xmlattributes(decode(nummer, NULL,'true','false') "xsi:nil"),nummer)
                                          , xmlelement("sealNumber", xmlattributes(decode(zegelnummer, NULL,'true','false') "xsi:nil"),substr(zegelnummer,1,32))
                                          )
                                         )
                          FROM (SELECT DISTINCT replace(ctn.nummer,'-','') nummer
                                ,      ctn.zegelnummer
                                FROM   vgc_v_vp_containers ctn
                                ,      vgc_v_vp_producten pdt
                                WHERE  ctn.vpt_id = pdt.id
                                AND    pdt.vpj_id = i_vp_ptj_id
                               )
                         )
      ,                  (SELECT xmlagg (xmlelement("transitMemberStateCode", xmlattributes(decode(land_code, NULL,'true','false') "xsi:nil"), land_code))                 --herhalende groep
                          FROM vgc_v_vp_route_landen
                          WHERE vpj_id = i_vp_ptj_id
                         )
      ,                  xmlelement("identificationOfAnimals"
                                   ,(select xmlagg(xmlelement("identificationParameterSet"
                                                             ,case when vpt2.gn_code is not null then xmlelement("identificationParameter",xmlelement("key",'commodityCode'),xmlelement("data",vpt2.gn_code)) else null end
                                                             ,case when vpt2.sum_gewicht_bruto is not null then xmlelement("identificationParameter",xmlelement("key",'grossweight'),xmlelement("data",LTRIM(TO_CHAR(vpt2.sum_gewicht_bruto,'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))) else null end
                                                             ,case when vpt2.verpakkingsvorm is not null then xmlelement("identificationParameter",xmlelement("key",'type_package'),xmlelement("data",get_tnt_type_of_packages(v_hoofdverpakkingsvorm))) else null end
                                                             ,case when vpt2.product_type is not null then xmlelement("identificationParameter",xmlelement("key",'producttype'),xmlelement("data",vpt2.product_type)) else null end
                                                             ,case when vpt2.species is not null then xmlelement("identificationParameter",xmlelement("key",'species'),xmlelement("data",vpt2.species)) else null end
                                                  --         ,case when vpt.traces_complement_id is not null then xmlelement("identificationParameter",xmlelement("key",'complement'),xmlelement("data",vpt.traces_complement_id)) else null end
                                                  --         ,case when vpt.traces_species_id is not null then xmlelement("identificationParameter",xmlelement("key",'species'),xmlelement("data",vpt.traces_species_id)) else null end
                                                             ,case when vpt2.sum_collo_aantal is not null then xmlelement("identificationParameter",xmlelement("key",'number_package'),xmlelement("data",vpt2.sum_collo_aantal)) else null end
                                                             ,case when vpt2.sum_aantal is not null then xmlelement("identificationParameter",xmlelement("key",'number_animal'),xmlelement("data",vpt2.sum_aantal)) else null end
                                                             ,case when vpt2.eng_erkenningsnummer is not null then
                                                               xmlelement("identificationOfEstablishments"
                                                                  ,(select xmlagg(xmlelement("identificationParameterSet"
                                                                   ,case when vng.eng_erkenningsnummer is not null then xmlelement("identificationParameter",xmlelement("key",'approvalNumber'),xmlelement("data",vng.eng_erkenningsnummer)) else null end
                                                                   ,case when vng.eng_activiteit is not null then xmlelement("identificationParameter",xmlelement("key",'activity'),xmlelement("data",vng.eng_activiteit)) else null end
                                                                   ,case when vng.eng_land_code is not null then xmlelement("identificationParameter",xmlelement("key",'countryCode'),xmlelement("data",vng.eng_land_code)) else null end
                                                                   ,case when vng.eng_postcode is not null then xmlelement("identificationParameter",xmlelement("key",'postalCode'),xmlelement("data",vng.eng_postcode)) else null end
                                                               ))
                                                                   from   vgc_v_vgc0504nt_vng vng
                                                                   where  vng.vpt_id = vpt2.id
                                                                )
                                                                )
                                                              else
                                                                xmlelement("identificationOfEstablishments"
                                                                  ,(select xmlagg(xmlelement("identificationParameterSet"
                                                                       ,case when vng.eng_erkenningsnummer is not null then xmlelement("identificationParameter",xmlelement("key",'approvalNumber'),xmlelement("data",vng.eng_erkenningsnummer)) else null end
                                                                       ,case when vng.eng_activiteit is not null then xmlelement("identificationParameter",xmlelement("key",'activity'),xmlelement("data",vng.eng_activiteit)) else null end
                                                                       ,case when vng.eng_land_code is not null then xmlelement("identificationParameter",xmlelement("key",'countryCode'),xmlelement("data",vng.eng_land_code)) else null end
                                                                       ,case when vng.eng_postcode is not null then xmlelement("identificationParameter",xmlelement("key",'postalCode'),xmlelement("data",vng.eng_postcode)) else null end
                                                                                               ))
                                                                     from   vgc_v_vgc0504nt_vng vng
                                                                     where  vng.vpj_id = vpj.id
                                                                    )
                                                                   )
                                                              end
                                                   --           ,case when vpt.batchnummer is not null then xmlelement("identificationParameter",xmlelement("key",'batchNumber'),xmlelement("data",vpt.batchnummer)) else null end
                                                              ,case when vpt2.paspoortnummer is not null then xmlelement("identificationParameter",xmlelement("key",'passportNumber'),xmlelement("data",vpt2.paspoortnummer)) else null end
                                                              ,case when vpt2.id_nummer is not null then xmlelement("identificationParameter",xmlelement("key",'idNumber'),xmlelement("data",vpt2.id_nummer)) else null end
                                                               ))
                                     from   vgc_v_vgc0504nt_vpt vpt2
                                     where  vpt2.vpj_id = vpj.id
                                    )
                                   )
      ,                xmlelement("veterinaryDocuments"
      ,                  xmlelement("issueDate", xmlattributes(decode(vmt.document_afgiftedatum, NULL,'true','false') "xsi:nil"), '20'||substr(vmt.document_afgiftedatum,1,2)||'-'||substr(vmt.document_afgiftedatum,3,2)||'-'||substr(vmt.document_afgiftedatum,5,2)||'T00:00:00')
      ,                  xmlelement("type", xmlattributes(decode('636', NULL,'true','false') "xsi:nil"), '636')
      ,                  xmlelement("countrycode",  xmlattributes(decode(vpj.landcode_oorsprong, NULL,'true','false') "xsi:nil"),vpj.landcode_oorsprong)
      ,                  xmlelement("number", xmlattributes(decode(vmt.nummer, NULL,'true','false') "xsi:nil"), vmt.nummer)
                       )
                       )
                     WHEN vpj.classificatie = 'PRD'
                     THEN
                       xmlelement("CHEDAnimalProductsConsignment"
      ,                  CASE WHEN v_traces_certificaat_id IS NOT NULL
                         THEN
                           xmlelement("certificateIdentification"
      ,                      xmlelement("referenceNumber" , v_traces_certificaat_id)
      ,                      xmlelement("type" , 'CHEDP')
                           )
                         ELSE
                           NULL
                         END
      ,                  ( select xmlagg(col)
                           from ( select (xmlelement("commodity"
                                                   ,xmlelement("commodityCode",vpt1.gn_code)
  --                                                 ,xmlelement("commodityCodeComplTracesId",vpt.traces_complement_id)
  --                                                 ,( select xmlagg(xmlelement("commodityCodeSpeciesTracesId",vpt2.traces_species_id))
  --                                                    from   vgc_v_vgc0504u_vpt vpt2
  --                                                    where  vpt2.vpj_id               = i_vp_ptj_id
  --                                                    and    vpt2.gn_code              = vpt.gn_code
  --                                                    and    vpt2.traces_complement_id = vpt.traces_complement_id
  --                                                    and    vpt2.traces_species_id    is not null
  --                                                  )
                                                  ,xmlelement("subtotalNetWeight",LTRIM(TO_CHAR(sum(sum_gewicht_netto),'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))
                                                   )) col
                                  from   vgc_v_vgc0504nt_vpt vpt1
                                  where  vpt1.vpj_id = i_vp_ptj_id
                                  group  by vpt1.gn_code --,vpt.traces_complement_id
                         ))
      ,                  xmlelement("signatory"
      ,                    xmlelement("dateOfDeclaration" , xmlattributes(decode(vpj.datum_ondertekening, NULL,'true','false') "xsi:nil"), get_ws_date(NULL, vpj.creation_date,'yymmdd'))
      ,                    xmlelement("signatory"
      ,                      xmlelement("userDetail"
      ,                        xmlelement("lastName", xmlattributes(decode(vpj.ondertekenaarnaam, NULL,'true','false') "xsi:nil"), vpj.ondertekenaarnaam)
                             )
                           )
                         )
      ,                  xmlelement("animalsCertificatedAs"
      ,                     xmlelement("referenceDataCode", xmlattributes(decode(get_tnt_destination(vpj.gebruiksdoel,'NGL'), NULL,'true','false') "xsi:nil"),get_tnt_destination(vpj.gebruiksdoel,'NGL'))
                         )
      ,                  xmlelement("competentAuthority"
      ,                    xmlelement("code", xmlattributes(decode(vpj.bip_code_aanbod, NULL,'true','false') "xsi:nil"),vpj.bip_code_aanbod)
                         )
      ,                  xmlelement("conformToEuRequirements", xmlattributes(decode(vpj.eu_waardig, NULL,'true','false') "xsi:nil"), CASE WHEN vpj.eu_waardig = 'J'THEN 'true' WHEN vpj.eu_waardig IS NULL THEN NULL WHEN vpj.eu_waardig = 'N' THEN 'false' END )
      ,                  xmlelement("consignor", get_relatie_element('DP', vpj.dp_naam, vpj.dp_land, vpj.dp_plaats, vpj.dp_postcode, vpj.dp_straat_postbus, vpj.dp_huisnummer, vpj.dp_huisnummertoevoeging, get_tnt_activity_code(v_gn_code, 'DP', 'P'),vpj.dp_id_type,nvl(vpj.dp_id,vpj.dp_traces_id)))
      ,                  xmlelement("countryFromWhereConsignedCode",  xmlattributes(decode(vpj.landcode_verzend, NULL,'true','false') "xsi:nil"), vpj.landcode_verzend)
      ,                  xmlelement("countryOfOriginCode",  xmlattributes(decode(vpj.landcode_oorsprong, NULL,'true','false') "xsi:nil"),vpj.landcode_oorsprong)
      ,                  xmlelement("deliveryAddress", get_relatie_element('AF', vpj.af_naam, vpj.af_land, vpj.af_plaats, vpj.af_postcode, vpj.af_straat_postbus, vpj.af_huisnummer, vpj.af_huisnummertoevoeging, CASE WHEN vpj.bestemming = 'OPS' AND vpj.soort_opslag = 'VZT' THEN 'warehouse' WHEN (vpj.bestemming = 'DVR' and nvl(kpt2.us_army_ind,'N') = 'N') THEN NULL ELSE get_tnt_activity_code(v_gn_code, 'AF', 'P') END,vpj.af_id_type,nvl(vpj.af_id,vpj.af_traces_id))) /*#16*/
      ,                  CASE WHEN to_date(vpj.aankomstdatum,'yymmddhh24mi') < sysdate
                         THEN
                           xmlelement("departureDate", xmlattributes(decode(sysdate + 1/48, NULL,'true','false') "xsi:nil"),get_ws_date(NULL, sysdate + 1/48, 'yymmddHH24MI'))
                         ELSE
                           xmlelement("departureDate", xmlattributes(decode(vpj.aankomstdatum, NULL,'true','false') "xsi:nil"),get_ws_date(NULL,to_date(vpj.aankomstdatum,'yymmddhh24mi') + 1/48, 'yymmddHH24MI'))
                         END
      ,                  xmlelement("estimatedArrivalAtBIP", xmlattributes(decode(vpj.aankomstdatum, NULL,'true','false') "xsi:nil"),get_ws_date(vpj.aankomstdatum, NULL,'yymmddHH24MI'))
      ,                  xmlelement("importer", get_relatie_element('IM',  vpj.im_naam, vpj.im_land, vpj.im_plaats, vpj.im_postcode, vpj.im_straat_postbus, vpj.im_huisnummer, vpj.im_huisnummertoevoeging, CASE WHEN (vpj.bestemming = 'DVR' and nvl(kpt2.us_army_ind,'N') = 'N') THEN NULL ELSE get_tnt_activity_code(v_gn_code, 'IM', 'P') END,vpj.im_id_type,nvl(vpj.im_id,vpj.im_traces_id))) /*#16*/
      ,                  xmlelement("localReferenceNumber", CASE WHEN v_ggs_nummer IS NULL THEN v_local_refnr ELSE v_ggs_nummer END)
      ,                CASE WHEN vpj.versienr_mig_in > 5
                       THEN
                         ( SELECT xmlagg(xmlelement("meansOfTransport"
      ,                             xmlelement("document", xmlattributes(decode(vpj.vrachtbriefnummer, NULL,'true','false') "xsi:nil"),substr(vpj.vrachtbriefnummer,1,32))
      ,                             xmlelement("identification", xmlattributes(decode(identificatie, NULL,'true','false') "xsi:nil"), identificatie)
      ,                             xmlelement("type", xmlattributes(decode(vervoer, NULL,'true','false') "xsi:nil"), CASE WHEN kpt.luchthaven_ind = 'J' THEN 'PLANE' ELSE vervoer END)                               ))
                         FROM( SELECT DECODE(vpj.landcode_verzend,'GB','ROAD',cfe.rv_abbreviation) vervoer
                               ,      tpt.identificatie
                               FROM   vgc_v_vp_transporten tpt
                             --  ,      vgc_v_vp_partijen vpj2
                               ,      cg_ref_codes cfe
                               WHERE  tpt.vpj_id = i_vp_ptj_id
                            --   AND    vpj2.id = tpt.vpj_id
                               AND    cfe.rv_domain = 'SOORT VERVOER'
                               AND    cfe.rv_low_value = tpt.soort_transport
                               AND    tpt.voor_grens_ind = 'J')
                         )
                       ELSE
                         xmlelement("meansOfTransport"
      ,                    xmlelement("document", xmlattributes(decode(vpj.vrachtbriefnummer, NULL,'true','false') "xsi:nil"),substr(vpj.vrachtbriefnummer,1,32))
      ,                    xmlelement("identification", xmlattributes(decode(vpj.vaartuig_vluchtnummer, NULL,'true','false') "xsi:nil"), vpj.vaartuig_vluchtnummer)
      ,                    xmlelement("type", CASE WHEN vpj.landcode_verzend = 'GB' THEN 'ROAD' ELSE  CASE WHEN kpt.luchthaven_ind = 'J' THEN 'PLANE' ELSE 'SHIP' END END)
                         )
                       END
      ,                CASE WHEN vpj.versienr_mig_in > 5 --AND vpj.bestemming IN ('OPS', 'DVR')
                       THEN
                         ( SELECT xmlagg(xmlelement("meansOfTransportAfterBIP"
      ,                             xmlelement("document", xmlattributes(decode(nvl(v_ggs_nummer,vpj.id), NULL,'true','false') "xsi:nil"), nvl(v_ggs_nummer,vpj.id))
      ,                             xmlelement("identification", xmlattributes(decode(identificatie, NULL,'true','false') "xsi:nil"), identificatie)
      ,                             xmlelement("type", xmlattributes(decode(vervoer, NULL,'true','false') "xsi:nil"), vervoer)                               ))
                         FROM( SELECT cfe.rv_abbreviation vervoer
                               ,      tpt.identificatie
                               FROM   vgc_v_vp_transporten tpt
                               ,      cg_ref_codes cfe
                               WHERE  tpt.vpj_id = i_vp_ptj_id
                               AND    cfe.rv_domain = 'SOORT VERVOER'
                               AND    cfe.rv_low_value = tpt.soort_transport
                               AND    tpt.voor_grens_ind = 'N')
                         )
                       WHEN vpj.bestemming IN ('OPS', 'DVR') AND vpj.versienr_mig_in < 6
                       THEN
                           (SELECT xmlagg(xmlelement("meansOfTransportAfterBIP"                                   --herhalende groep
      ,                      xmlelement("document", xmlattributes(decode(nvl(v_ggs_nummer,vpj.id), NULL,'true','false') "xsi:nil"), nvl(v_ggs_nummer,vpj.id))
      ,                      xmlelement("identification", xmlattributes(decode(identificatie, NULL,'true','false') "xsi:nil"),vpj.transport_identificatie)
      ,                      xmlelement("type", get_tnt_transport_type(soort_transport))
                                            )
                                           )
                            FROM (SELECT DISTINCT vtr.identificatie
                                  ,      vtr.SOORT_TRANSPORT
                                  FROM   vgc_v_vp_transporten vtr
                                  WHERE  vtr.vpj_id = i_vp_ptj_id
                                  AND    vtr.voor_grens_ind = 'N'
                                 )
                           )
                        ELSE
                         NULL
                       END
      ,                  xmlelement("numberPackages",  xmlattributes(decode(v_collo_aantal, NULL,'true','false') "xsi:nil"),  v_collo_aantal)
      ,                  xmlelement("productGrossWeight", xmlattributes(decode(v_bruto_gewicht, NULL,'true','false') "xsi:nil"), LTRIM(TO_CHAR(v_bruto_gewicht,'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))
      ,                  xmlelement("productNetWeight", xmlattributes(decode(v_netto_gewicht, NULL,'true','false') "xsi:nil"), LTRIM(TO_CHAR(v_netto_gewicht,'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))
      ,                  xmlelement("productTemperature",  xmlattributes(decode(get_tnt_product_temperature(vpj.conserveringsmethode), NULL,'true','false') "xsi:nil"),get_tnt_product_temperature(vpj.conserveringsmethode))
      ,                  CASE WHEN vpj.bestemming = 'IVR'
                         THEN
                           xmlelement("purpose"
      ,                      xmlelement("forInternalMarket"
      ,                        xmlelement("destination",  xmlattributes(decode(get_tnt_destination(vpj.gebruiksdoel,'NGL'), NULL,'true','false') "xsi:nil"), get_tnt_destination(vpj.gebruiksdoel,'NGL'))
                             )
                           )
                         WHEN vpj.bestemming = 'OPS'
                         THEN
                           xmlelement("purpose"
      ,                      xmlelement("forNonConformingConsignment"
      ,                        xmlelement("destination", xmlattributes(decode(get_tnt_destination_type(vpj.soort_opslag), NULL,'true','false') "xsi:nil"), get_tnt_destination_type(vpj.soort_opslag))
      ,                        xmlelement("name", xmlattributes(decode(vpj.naam_vaartuig, NULL,'true','false') "xsi:nil"),vpj.naam_vaartuig)
      ,                        xmlelement("port", xmlattributes(decode(vpj.naam_haven, NULL,'true','false') "xsi:nil"),vpj.naam_haven)
      ,                        xmlelement("registerNumber", xmlattributes(decode(vpj.registratie_opslag, NULL,'true','false') "xsi:nil"), vpj.registratie_opslag)
                             )
                           )
                         WHEN vpj.bestemming = 'WIR'
                         THEN
                           xmlelement("purpose"
      ,                      xmlelement("forReImport")
                           )
                         WHEN vpj.bestemming = 'DVR'
                         THEN
                           xmlelement("purpose"
      ,                      xmlelement("forTransit"
      ,                        xmlelement("destinationThirdCountryCode",  xmlattributes(decode(vpj.landcode_bestemming, NULL,'true','false') "xsi:nil"),vpj.landcode_bestemming)
      ,                        xmlelement("exitBip"
      ,                           xmlelement("code",xmlattributes(decode(vpj.bip_code_exit, NULL,'true','false') "xsi:nil"),decode(kpt2.us_army_ind,'J',kpt2.naam, decode(vpj.bip_code_exit,'FRCQF1',kpt2.naam,vpj.bip_code_exit)))
      ,                           xmlelement("type",xmlattributes(decode(kpt2.us_army_ind, 'N','true','false') "xsi:nil"), decode(kpt2.us_army_ind,'J','MILITARY_FACILITY',NULL))
                               )
                             )
                           )
                         ELSE
                           xmlelement("purpose", xmlattributes('true' "xsi:nil"))
                         END
      ,                  xmlelement("responsibleForConsignment", get_relatie_element('AL', vpj.al_naam, vpj.al_land, vpj.al_plaats, vpj.al_postcode, vpj.al_straat_postbus, vpj.al_huisnummer, vpj.al_huisnummertoevoeging, v_al_activity_code,null,rle_al.traces_id))
      ,                  (SELECT xmlagg(xmlelement("sealContainer"                                   --herhalende groep
                          ,               xmlelement("containerNumber", xmlattributes(decode(nummer, NULL,'true','false') "xsi:nil"),nummer)
                          ,               xmlelement("sealNumber", xmlattributes(decode(zegelnummer, NULL,'true','false') "xsi:nil"),substr(zegelnummer,1,32) )
                                        )
                                       )
                          FROM (SELECT DISTINCT replace(ctn.nummer,'-','') nummer
                                ,      ctn.zegelnummer
                                FROM   vgc_v_vp_containers ctn
                                ,      vgc_v_vp_producten pdt
                                WHERE ctn.vpt_id = pdt.id
                                AND pdt.vpj_id = i_vp_ptj_id
                               )
                         )
      ,                  xmlelement("typeOfPackages"
      ,                    xmlelement("referenceDataCode", get_tnt_type_of_packages(v_hoofdverpakkingsvorm))
                         )
      ,                  xmlelement("identificationOfAnimals"
                                   ,(select xmlagg(xmlelement("identificationParameterSet"
                                                             ,case when vpt2.gn_code is not null then xmlelement("identificationParameter",xmlelement("key",'commodityCode'),xmlelement("data",vpt2.gn_code)) else null end
                                            --               ,case when vpt.traces_complement_id is not null then xmlelement("identificationParameter",xmlelement("key",'complement'),xmlelement("data",vpt.traces_complement_id)) else null end
                                                             ,case when vpt2.sum_gewicht_bruto is not null then xmlelement("identificationParameter",xmlelement("key",'grossweight'),xmlelement("data",LTRIM(TO_CHAR(vpt2.sum_gewicht_bruto,'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))) else null end
                                                             ,case when vpt2.sum_gewicht_netto is not null  and vpt.gn_code != '05111000' then xmlelement("identificationParameter",xmlelement("key",'netweight'),xmlelement("data",LTRIM(TO_CHAR(vpt2.sum_gewicht_netto,'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))) else null end
                                                             ,case when vpt2.product_type is not null then xmlelement("identificationParameter",xmlelement("key",'producttype'),xmlelement("data",vpt2.product_type)) else null end
                                                             ,case when vpt2.species is not null then xmlelement("identificationParameter",xmlelement("key",'species'),xmlelement("data",vpt2.species)) else null end
                                            --               ,case when vpt.traces_species_id is not null then xmlelement("identificationParameter",xmlelement("key",'species'),xmlelement("data",vpt.traces_species_id)) else null end
                                                             ,case when vpt2.sum_collo_aantal is not null then xmlelement("identificationParameter",xmlelement("key",'number_package'),xmlelement("data",vpt2.sum_collo_aantal)) else null end
                                                             ,case when vpt2.sum_aantal is not null and vpt2.hoeveelheid_ind != 'N' then xmlelement("identificationParameter",xmlelement("key",'number_animal'),xmlelement("data",vpt2.sum_aantal)) else null end
                                                             ,case when vpt2.verpakkingsvorm is not null then xmlelement("identificationParameter",xmlelement("key",'type_package'),xmlelement("data",get_tnt_type_of_packages(v_hoofdverpakkingsvorm))) else null end
                                                             ,case when vpt2.eng_erkenningsnummer is not null then
                                                               xmlelement("identificationOfEstablishments"
                                                                  ,(select xmlagg(xmlelement("identificationParameterSet"
                                                                   ,case when vng.eng_erkenningsnummer is not null then xmlelement("identificationParameter",xmlelement("key",'approvalNumber'),xmlelement("data",vng.eng_erkenningsnummer)) else null end
                                                                   ,case when vng.eng_activiteit is not null then xmlelement("identificationParameter",xmlelement("key",'activity'),xmlelement("data",vng.eng_activiteit)) else null end
                                                                   ,case when vng.eng_land_code is not null then xmlelement("identificationParameter",xmlelement("key",'countryCode'),xmlelement("data",vng.eng_land_code)) else null end
                                                                   ,case when vng.eng_postcode is not null then xmlelement("identificationParameter",xmlelement("key",'postalCode'),xmlelement("data",vng.eng_postcode)) else null end
                                                               ))
                                                                   from   vgc_v_vgc0504nt_vng vng
                                                                   where  vng.vpt_id = vpt2.id
                                                                )
                                                                )
                                                              else
                                                                xmlelement("identificationOfEstablishments"
                                                                  ,(select xmlagg(xmlelement("identificationParameterSet"
                                                                       ,case when vng.eng_erkenningsnummer is not null then xmlelement("identificationParameter",xmlelement("key",'approvalNumber'),xmlelement("data",vng.eng_erkenningsnummer)) else null end
                                                                       ,case when vng.eng_activiteit is not null then xmlelement("identificationParameter",xmlelement("key",'activity'),xmlelement("data",vng.eng_activiteit)) else null end
                                                                       ,case when vng.eng_land_code is not null then xmlelement("identificationParameter",xmlelement("key",'countryCode'),xmlelement("data",vng.eng_land_code)) else null end
                                                                       ,case when vng.eng_postcode is not null then xmlelement("identificationParameter",xmlelement("key",'postalCode'),xmlelement("data",vng.eng_postcode)) else null end
                                                                                               ))
                                                                     from   vgc_v_vgc0504nt_vng vng
                                                                     where  vng.vpj_id = vpj.id
                                                                    )
                                                                   )
                                                              end
                                                              ,case when vpt2.batchnummer is not null then xmlelement("identificationParameter",xmlelement("key",'batchNumber'),xmlelement("data",vpt2.batchnummer)) else null end
                                                              ,case when vpt2.consumentenverpakking is not null then xmlelement("identificationParameter",xmlelement("key",'finalConsumer'),xmlelement("data",vpt2.consumentenverpakking)) else null end
                                                                ))
                                     from   vgc_v_vgc0504nt_vpt vpt2
                                     where  vpt2.vpj_id = vpj.id
                                    )
                                  )
      ,                xmlelement("veterinaryDocuments"
      ,                  xmlelement("issueDate", xmlattributes(decode(vmt.document_afgiftedatum, NULL,'true','false') "xsi:nil"), '20'||substr(vmt.document_afgiftedatum,1,2)||'-'||substr(vmt.document_afgiftedatum,3,2)||'-'||substr(vmt.document_afgiftedatum,5,2)||'T00:00:00')
      ,                  xmlelement("type", xmlattributes(decode('636', NULL,'true','false') "xsi:nil"), '636')
      ,                  xmlelement("countrycode",  xmlattributes(decode(vpj.landcode_oorsprong, NULL,'true','false') "xsi:nil"),vpj.landcode_oorsprong)
      ,                  xmlelement("number", xmlattributes(decode(vmt.nummer, NULL,'true','false') "xsi:nil"), vmt.nummer)
                         )
                     )
                     ELSE
                       xmlelement("CHEDNonAnimalProductsConsignment"
      ,                  CASE WHEN v_traces_certificaat_id IS NOT NULL
                         THEN
                           xmlelement("certificateIdentification"
      ,                      xmlelement("referenceNumber" , v_traces_certificaat_id)
      ,                      xmlelement("type" , 'CHEDD')
                           )
                         ELSE
                           NULL
                         END
      ,                  ( select xmlagg(col)
                           from ( select (xmlelement("commodity"
                                                   ,xmlelement("commodityCode",vpt.gn_code)
                                                   ,xmlelement("subtotalNetWeight",SUM(sum_gewicht_netto))
                                                   )) col
                                  from   vgc_v_vgc0504nt_vpt vpt
                                  where  vpt.vpj_id = i_vp_ptj_id
                                  group  by vpt.gn_code--,vpt.traces_complement_id
                         ))
      ,                  xmlelement("signatory"
      ,                    xmlelement("dateOfDeclaration" , xmlattributes(decode(vpj.datum_ondertekening, NULL,'true','false') "xsi:nil"), get_ws_date(NULL, vpj.creation_date,'yymmdd'))
      ,                    xmlelement("signatory"
      ,                      xmlelement("userDetail"
      ,                        xmlelement("lastName", xmlattributes(decode(vpj.ondertekenaarnaam, NULL,'true','false') "xsi:nil"), vpj.ondertekenaarnaam)
                             )
                           )
                         )
      ,                  xmlelement("competentAuthority"
      ,                    xmlelement("code", xmlattributes(decode(vpj.bip_code_aanbod, NULL,'true','false') "xsi:nil"),vpj.bip_code_aanbod)
                         )
      ,                  xmlelement("animalsCertificatedAs"
      ,                    xmlelement("referenceDataCode", xmlattributes(decode(get_tnt_destination(vpj.gebruiksdoel,'LNV'), NULL,'true','false') "xsi:nil"),get_tnt_destination(vpj.gebruiksdoel,'LNV'))
                         )
      ,                  xmlelement("conformToEuRequirements", xmlattributes(decode(vpj.eu_waardig, NULL,'true','false') "xsi:nil"), CASE WHEN vpj.eu_waardig = 'J'THEN 'true' WHEN vpj.eu_waardig IS NULL THEN NULL WHEN vpj.eu_waardig = 'N' THEN 'false' END )
      ,                  xmlelement("consignor", get_relatie_element('DP', vpj.dp_naam, vpj.dp_land, vpj.dp_plaats, vpj.dp_postcode, vpj.dp_straat_postbus, vpj.dp_huisnummer, vpj.dp_huisnummertoevoeging, get_tnt_activity_code(v_gn_code, 'DP', 'P'),vpj.dp_id_type,nvl(vpj.dp_id,vpj.dp_traces_id)))
      ,                  xmlelement("countryFromWhereConsignedCode",  xmlattributes(decode(vpj.landcode_verzend, NULL,'true','false') "xsi:nil"), vpj.landcode_verzend)
      ,                  xmlelement("countryOfOriginCode",  xmlattributes(decode(vpj.landcode_oorsprong, NULL,'true','false') "xsi:nil"),vpj.landcode_oorsprong)
      ,                  xmlelement("deliveryAddress", get_relatie_element('AF', vpj.af_naam, vpj.af_land, vpj.af_plaats, vpj.af_postcode, vpj.af_straat_postbus, vpj.af_huisnummer, vpj.af_huisnummertoevoeging, CASE WHEN vpj.bestemming = 'OPS' AND vpj.soort_opslag = 'VZT' THEN 'warehouse' WHEN (vpj.bestemming = 'DVR' and nvl(kpt2.us_army_ind,'N') = 'N') THEN NULL ELSE get_tnt_activity_code(v_gn_code, 'AF', 'P') END,vpj.af_id_type,nvl(vpj.af_id,vpj.af_traces_id))) /*#16*/
      ,                  xmlelement("estimatedArrivalAtBIP", xmlattributes(decode(vpj.aankomstdatum, NULL,'true','false') "xsi:nil"),get_ws_date(vpj.aankomstdatum, NULL,'yymmddHH24MI'))
      ,                  xmlelement("importer", get_relatie_element('IM',  vpj.im_naam, vpj.im_land, vpj.im_plaats, vpj.im_postcode, vpj.im_straat_postbus, vpj.im_huisnummer, vpj.im_huisnummertoevoeging, CASE WHEN (vpj.bestemming = 'DVR' and nvl(kpt2.us_army_ind,'N') = 'N') THEN NULL ELSE get_tnt_activity_code(v_gn_code, 'IM', 'P') END,vpj.im_id_type,nvl(vpj.im_id,vpj.im_traces_id))) /*#16*/
      ,                  xmlelement("localReferenceNumber", CASE WHEN v_ggs_nummer IS NULL THEN v_local_refnr ELSE v_ggs_nummer END)
      ,                CASE WHEN vpj.versienr_mig_in > 5
                       THEN
                         ( SELECT xmlagg(xmlelement("meansOfTransport"
      ,                             xmlelement("document", xmlattributes(decode(vpj.vrachtbriefnummer, NULL,'true','false') "xsi:nil"),substr(vpj.vrachtbriefnummer,1,32))
      ,                             xmlelement("identification", xmlattributes(decode(identificatie, NULL,'true','false') "xsi:nil"), identificatie)
      ,                             xmlelement("type", xmlattributes(decode(vervoer, NULL,'true','false') "xsi:nil"), CASE WHEN kpt.luchthaven_ind = 'J' THEN 'PLANE' ELSE vervoer END)                               ))
                         FROM( SELECT DECODE(vpj.landcode_verzend,'GB','ROAD',cfe.rv_abbreviation) vervoer
                               ,      tpt.identificatie
                               FROM   vgc_v_vp_transporten tpt
                             --  ,      vgc_v_vp_partijen vpj2
                               ,      cg_ref_codes cfe
                               WHERE  tpt.vpj_id = i_vp_ptj_id
                            --   AND    vpj2.id = tpt.vpj_id
                               AND    cfe.rv_domain = 'SOORT VERVOER'
                               AND    cfe.rv_low_value = tpt.soort_transport
                               AND    tpt.voor_grens_ind = 'J')
                         )
                       ELSE
                         xmlelement("meansOfTransport"
      ,                    xmlelement("document", xmlattributes(decode(vpj.vrachtbriefnummer, NULL,'true','false') "xsi:nil"),substr(vpj.vrachtbriefnummer,1,32))
      ,                    xmlelement("identification", xmlattributes(decode(vpj.vaartuig_vluchtnummer, NULL,'true','false') "xsi:nil"), vpj.vaartuig_vluchtnummer)
      ,                    xmlelement("type", CASE WHEN vpj.LANDCODE_VERZEND = 'GB' THEN 'ROAD' ELSE  CASE WHEN kpt.luchthaven_ind = 'J' THEN 'PLANE' ELSE 'SHIP' END END)
                         )
                       END
      ,                CASE WHEN vpj.bestemming IN ('OPS', 'DVR') AND vpj.versienr_mig_in > 5
                       THEN
                         ( SELECT xmlagg(xmlelement("meansOfTransportAfterBIP"
      ,                             xmlelement("document", xmlattributes(decode(nvl(v_ggs_nummer,vpj.id), NULL,'true','false') "xsi:nil"), nvl(v_ggs_nummer,vpj.id))
      ,                             xmlelement("identification", xmlattributes(decode(identificatie, NULL,'true','false') "xsi:nil"), identificatie)
      ,                             xmlelement("type", xmlattributes(decode(vervoer, NULL,'true','false') "xsi:nil"), vervoer)                               ))
                         FROM( SELECT cfe.rv_abbreviation vervoer
                               ,      tpt.identificatie
                               FROM   vgc_v_vp_transporten tpt
                               ,      cg_ref_codes cfe
                               WHERE  tpt.vpj_id = i_vp_ptj_id
                               AND    cfe.rv_domain = 'SOORT VERVOER'
                               AND    cfe.rv_low_value = tpt.soort_transport
                               AND    tpt.voor_grens_ind = 'N')
                         )
                       WHEN vpj.bestemming IN ('OPS', 'DVR') AND vpj.versienr_mig_in < 6
                       THEN
                           (SELECT xmlagg(xmlelement("meansOfTransportAfterBIP"                                   --herhalende groep
      ,                      xmlelement("document", xmlattributes(decode(nvl(v_ggs_nummer,vpj.id), NULL,'true','false') "xsi:nil"), nvl(v_ggs_nummer,vpj.id))
      ,                      xmlelement("identification", xmlattributes(decode(identificatie, NULL,'true','false') "xsi:nil"),vpj.transport_identificatie)
      ,                      xmlelement("type", get_tnt_transport_type(soort_transport))
                                            )
                                           )
                            FROM (SELECT DISTINCT vtr.identificatie
                                  ,      vtr.SOORT_TRANSPORT
                                  FROM   vgc_v_vp_transporten vtr
                                  WHERE  vtr.vpj_id = i_vp_ptj_id
                                  AND    vtr.voor_grens_ind = 'N'
                                 )
                           )
                        ELSE
                         NULL
                       END
      ,                  xmlelement("numberPackages",  xmlattributes(decode(v_collo_aantal, NULL,'true','false') "xsi:nil"),  v_collo_aantal)
      ,                  xmlelement("productGrossWeight", xmlattributes(decode(v_bruto_gewicht, NULL,'true','false') "xsi:nil"), LTRIM(TO_CHAR(v_bruto_gewicht,'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))
      ,                  xmlelement("productNetWeight", xmlattributes(decode(v_netto_gewicht, NULL,'true','false') "xsi:nil"), LTRIM(TO_CHAR(v_netto_gewicht,'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))
      ,                  CASE WHEN get_tnt_activity_code(v_gn_code, 'AF', 'V') = 'bov_semen'
                         THEN
                           NULL
                         ELSE
                           xmlelement("productTemperature",  xmlattributes(decode(get_tnt_product_temperature(vpj.conserveringsmethode), NULL,'true','false') "xsi:nil"),get_tnt_product_temperature(vpj.conserveringsmethode))
                         END
      ,                  CASE WHEN upper(vpj.bestemming) = 'TRT'
                         THEN
                           xmlelement("purpose"
      ,                       xmlelement("forTransferTo"
      ,                         xmlelement("TransferToCountryCode",xmlattributes(decode(lnd.code, NULL,'true','false') "xsi:nil"), lnd.code)
      ,                         xmlelement("TransferToID",xmlattributes(decode(vpj.sip_code_aanbod, NULL,'true','false') "xsi:nil"), vpj.sip_code_aanbod)
                              )
                           )
                         ELSE
                           xmlelement("purpose", xmlattributes('true' "xsi:nil"))
                         END CASE
      ,                  xmlelement("responsibleForConsignment", get_relatie_element('AL', vpj.al_naam, vpj.al_land, vpj.al_plaats, vpj.al_postcode, vpj.al_straat_postbus, vpj.al_huisnummer, vpj.al_huisnummertoevoeging, v_al_activity_code,null,rle_al.traces_id))
      ,                  (SELECT xmlagg(xmlelement("sealContainer"                                   --herhalende groep
                          ,               xmlelement("containerNumber", xmlattributes(decode(nummer, NULL,'true','false') "xsi:nil"),nummer)
                          ,               xmlelement("sealNumber", xmlattributes(decode(zegelnummer, NULL,'true','false') "xsi:nil"),substr(zegelnummer,1,32) )
                                        )
                                       )
                          FROM (SELECT DISTINCT replace(ctn.nummer,'-','') nummer
                                ,      ctn.zegelnummer
                                FROM   vgc_v_vp_containers ctn
                                ,      vgc_v_vp_producten pdt
                                WHERE ctn.vpt_id = pdt.id
                                AND pdt.vpj_id = i_vp_ptj_id
                               )
                         )
      ,                  xmlelement("typeOfPackages"
      ,                    xmlelement("referenceDataCode", get_tnt_type_of_packages(v_hoofdverpakkingsvorm))
                         )
      ,                  xmlelement("identificationOfAnimals"
                                   ,(select xmlagg(xmlelement("identificationParameterSet"
--                                                             ,case when vpt.traces_complement_id is not null then xmlelement("identificationParameter",xmlelement("key",'complement'),xmlelement("data",vpt.traces_complement_id)) else null end
                                                             ,case when vpt2.sum_gewicht_bruto is not null then xmlelement("identificationParameter",xmlelement("key",'grossweight'),xmlelement("data",LTRIM(TO_CHAR(vpt2.sum_gewicht_bruto,'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))) else null end
                                                             ,case when vpt2.sum_gewicht_netto is not null then xmlelement("identificationParameter",xmlelement("key",'netweight'),xmlelement("data",LTRIM(TO_CHAR(vpt2.sum_gewicht_netto,'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))) else null end
--                                                             ,case when vpt.traces_species_id is not null then xmlelement("identificationParameter",xmlelement("key",'species'),xmlelement("data",vpt.traces_species_id)) else null end
                                                             ,case when vpt2.sum_collo_aantal is not null then xmlelement("identificationParameter",xmlelement("key",'number_package'),xmlelement("data",vpt2.sum_collo_aantal)) else null end
                                                             ,case when vpt2.product_type is not null then xmlelement("identificationParameter",xmlelement("key",'producttype'),xmlelement("data",vpt2.product_type)) else null end
                                                             ,case when vpt2.verpakkingsvorm is not null then xmlelement("identificationParameter",xmlelement("key",'type_package'),xmlelement("data",get_tnt_type_of_packages(v_hoofdverpakkingsvorm))) else null end
                                                                ))
                                     from   vgc_v_vgc0504nt_vpt vpt2
                                     where  vpt2.vpj_id = vpj.id
                                    )
                                  )
    ,                CASE WHEN vmt.document_afgiftedatum > substr(vpj.aankomstdatum,1,6)
                     THEN
                       NULL
                     ELSE
                       xmlelement("veterinaryDocuments"
      ,                  xmlelement("issueDate", xmlattributes(decode(vmt.document_afgiftedatum, NULL,'true','false') "xsi:nil"), '20'||substr(vmt.document_afgiftedatum,1,2)||'-'||substr(vmt.document_afgiftedatum,3,2)||'-'||substr(vmt.document_afgiftedatum,5,2)||'T00:00:00')
      ,                  xmlelement("type", xmlattributes(decode('636', NULL,'true','false') "xsi:nil"), '636')
      ,                  xmlelement("countrycode",  xmlattributes(decode(vpj.landcode_oorsprong, NULL,'true','false') "xsi:nil"),vpj.landcode_oorsprong)
      ,                  xmlelement("number", xmlattributes(decode(vmt.nummer, NULL,'true','false') "xsi:nil"), vmt.nummer)
                       )
                     END
                     )
                   END
      ,              xmlelement("operation", CASE WHEN v_traces_certificaat_id IS NOT NULL THEN 'REPLACE' ELSE 'CREATE' END)
                )
               )
             )
             ).getClobval()
      FROM  vgc_v_vp_partijen vpj
      ,     vgc_v_vp_documenten vmt
      ,     vgc_v_keurpunten kpt
      ,     vgc_v_keurpunten kpt2
      ,     vgc_v_keurpunten kpt3
      ,     vgc_v_relaties rle_al
      ,     vgc_v_vp_erkenningen vat
      ,     vgc_v_vp_producten vpt
      ,     vgc_v_landen lnd
      WHERE vpj.id = i_vp_ptj_id
      AND   vpj.id = vmt.vpj_id
      AND   vpj.id = vpt.vpj_id
      AND   vpj.id = vat.vpj_id (+)
      AND   vmt.id = v_primair_doc_id
      AND   rle_al.aangevernummer (+) = vpj.aangevernummer
      AND   kpt.animo_code (+) = vpj.bip_code_aanbod
      AND   kpt2.animo_code (+) = vpj.bip_code_exit
      AND   kpt3.animo_code (+) = vpj.sip_code_aanbod
      AND   kpt3.lnd_id = lnd.id  (+)
    ;
    --
    BEGIN
      OPEN c_xml;
      FETCH c_xml INTO  r_rqt.webservice_bericht;
      CLOSE c_xml;
      escape_xml (r_rqt.webservice_bericht);
    EXCEPTION
      WHEN OTHERS THEN
        dbms_output.put_line(SQLERRM);
        IF c_xml%ISOPEN THEN
          CLOSE c_xml;
        END IF;
        RAISE;
    END maak_bericht;
  --
BEGIN
  --
  trace(v_objectnaam);
  vgc_blg.write_log('start' , v_objectnaam, 'N', 1);
  -- haal de unieke sleutel van de partij op
  OPEN c_vpj;
  FETCH c_vpj INTO v_aangevernummer
                 , v_aangifte_volgnummer
                 , v_aangiftejaar
                 , v_ptj_type
                 , v_erkenningsnummer
                 , v_landcode_oorsprong
                 , v_ptj_type
  ;
  CLOSE c_vpj;
  v_local_refnr := v_aangevernummer ||'/'||v_aangiftejaar||'/'||v_aangifte_volgnummer;
  -- haal een eventueel certificaat id en ggs_nummer op van de bij de VP_partij corresponderende partij in VGC_PARTIJEN
  OPEN c_ptj(p_vpj_id);
  FETCH c_ptj INTO v_chednummer
                 , v_ggs_nummer
                 , v_aangiftejaar
                 , v_ptj_id
  ;
  CLOSE c_ptj;
  --
  -- initialiseren request
  --
  r_rqt.request_id               := NULL;
  r_rqt.webservice_url           := vgc$algemeen.get_appl_register ('TRACES_CERTIFICATE_WS_URL');
  r_rqt.bestemd_voor             := NULL;
  r_rqt.webservice_logische_naam := 'VGC0504NT';
  r_rqt.aangifte_volgnummer      := v_aangifte_volgnummer;
  r_rqt.aangiftejaar             := v_aangiftejaar;
  r_rqt.aangevernummer           := v_aangevernummer;
  r_rqt.ggs_nummer               := v_ggs_nummer;
  -- haal de traces_id en activity_code op van de aangever
  OPEN c_al_codes(v_aangevernummer);
  FETCH c_al_codes INTO v_al_traces_id, v_al_activity_code;
  CLOSE c_al_codes;
  -- ophalen primair veterinair document
  OPEN c_vmt;
  FETCH c_vmt INTO v_primair_doc_id, v_primair_doc_nummer;
  CLOSE c_vmt;
  --
  -- haal de aanvullende/juiste productgegevens op
  get_tnt_commodity_ids('VP', p_vpj_id, v_gn_code);
  --
  v_erkenningsnummer := TRIM(v_erkenningsnummer);
  OPEN  c_toe4;
  FETCH c_toe4 INTO v_vier_pos;
  CLOSE c_toe4;
  OPEN  c_toe3;
  FETCH c_toe3 INTO v_drie_pos;
  CLOSE c_toe3;
  --
  IF v_erkenningsnummer IS NOT NULL
  AND upper(v_erkenningsnummer) NOT IN ('NVT','ONBEKEND')
  THEN
    --> Nieuwe opzet erkenningen
    FOR r_erk IN ( SELECT e.*,l.code
                   FROM   vgc_erkenningen e
                   ,      vgc_v_landen l
                   WHERE  e.ptj_id = v_ptj_id
                   AND    l.id  (+)= NVL(e.lnd_id,-1) )
    LOOP
        INSERT INTO vgc_tt_oe
         ( activity_code
         , approvalnumber
         , lnd_code)
        VALUES
         ( r_erk.activiteit
         , r_erk.erkenningsnummer
         , r_erk.code);

    END LOOP;

  END IF;
  vgc_blg.write_log('voor product totaalinfo' , v_objectnaam, 'N', 1);
  -- ophalen product totalen informatie
  FOR r_vpt IN c_vpt
  LOOP
    IF nvl(v_verpakkingsvorm_vorig, r_vpt.verpakkingsvorm) <> r_vpt.verpakkingsvorm
    THEN
      v_div_verpakkingsvormen := TRUE;
    END IF;

    v_aantal                :=  v_aantal + r_vpt.aantal;
    v_collo_aantal          :=  v_collo_aantal + r_vpt.collo_aantal;
    v_netto_gewicht         :=  v_netto_gewicht + r_vpt.gewicht_netto;
    v_bruto_gewicht         :=  v_bruto_gewicht + r_vpt.gewicht_bruto;
    v_verpakkingsvorm_vorig := r_vpt.verpakkingsvorm;
  END LOOP;

  IF v_div_verpakkingsvormen
  THEN
    v_hoofdverpakkingsvorm := 'CT';
  ELSE
    v_hoofdverpakkingsvorm := v_verpakkingsvorm_vorig;
  END IF;
  --
  IF nvl(v_chednummer,'*') != '*'
  THEN
    v_actiecode := '1';
  ELSE
    v_actiecode := '1';
  END IF;
  --
  -- opstellen bericht
  -- alleen voor niet-ontheffingen.
  -- een ontheffing heeft een rapport met in de naam NVWA
  --
  if instr(upper(v_primair_doc_nummer),'NVWA') = 0
  then
    maak_bericht(p_vpj_id);
    --
    -- aanroepen webservice
    --
    vgc_ws_cms.vgc_cms_out
      (p_aangevernummer      => v_aangevernummer
      ,p_aangiftejaar        => v_aangiftejaar
      ,p_aangifte_volgnummer => v_aangifte_volgnummer
      ,p_ggs_nummer          => v_ggs_nummer
      ,p_classificatie       => v_ptj_type
      ,p_pdf                 => v_pdf_jn
      ,p_actiecode           => v_actiecode
      ,p_chednummer          => v_chednummer
      ,p_redencode           => null
      ,p_redenafkeuring      => null
      ,p_ws_naam             => 'VGC0504NT'
      ,p_xml                 => r_rqt.webservice_bericht
      ,p_request_id          => v_request_id
      ,p_resultaat           => v_resultaat
      );
    --
    p_request_id := v_request_id;
    --
    if v_resultaat
    then
    -- verwerking webservice antwoord
    --
    verwerk_traces_antwoord
      ( p_ws_naam        => v_ws_naam
      , p_request_id     => v_request_id
      , p_ptj_id         => v_ptj_id
      , p_pdf_jn         => v_pdf_jn
      , p_resultaat      => v_resultaat
      , p_error_handling => p_error_handling);
    --
    end if;
  end if;
  vgc_blg.write_log('eind' , v_objectnaam, 'N', 1);
  --
EXCEPTION
  WHEN e_ws_error THEN
    IF p_error_handling = 'N'
    THEN
      p_request_id := r_rqt.request_id;
    ELSE
      vgc_blg.write_log('Exception: Webservice geeft http-code: ' || r_rqt.webservice_returncode, v_objectnaam, 'N', 1);
      raise_application_error(-20000, 'VGC-00502 #1' || r_rqt.webservice_logische_naam ||': Webservice geeft http-code: ' || r_rqt.webservice_returncode);
    END IF;

  WHEN e_specific_operation_error
  THEN
    IF p_error_handling = 'N'
    THEN
      p_request_id := r_rqt.request_id;
    ELSE
      vgc_blg.write_log('Exception: Aanroep webservice mislukt. Specifieke operatie fout ontvangen van Traces webservice: ' || nvl(r_rqt.operation_result,'specificOperationResult is leeg'), v_objectnaam, 'N', 1);
      raise_application_error(-20000, 'VGC-00502 #1' || r_rqt.webservice_logische_naam ||': ' || r_rqt.operation_result );

    END IF;

  WHEN e_general_operation_error
  THEN
    IF p_error_handling = 'N'
    THEN
      p_request_id := r_rqt.request_id;
    ELSE
      vgc_blg.write_log('Exception: Aanroep webservice mislukt. Generieke operatie fout ontvangen van Traces webservice: ' || r_rqt.operation_result, v_objectnaam, 'N', 1);
      raise_application_error(-20000, 'VGC-00502 #1' || r_rqt.webservice_logische_naam ||': ' || r_rqt.operation_result );

    END IF;

  WHEN OTHERS
  THEN
    vgc_blg.write_log('Exception: ' || SQLERRM, v_objectnaam, 'N', 5);
    qms$errors.unhandled_exception(v_objectnaam);
    RAISE;

END VGC0504NT;

/* Indienen Zending VGC (submitConsignmentVGC) */

PROCEDURE VGC0505NT
 (P_GGS_NUMMER IN VGC_PARTIJEN.GGS_NUMMER%TYPE
 ,P_REQUEST_ID IN OUT VGC_REQUESTS.REQUEST_ID%TYPE
 ,P_ERROR_HANDLING IN VARCHAR2 := 'J'
 )
 IS
 PRAGMA AUTONOMOUS_TRANSACTION;
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.VGC0505NT#01';
v_ptj_id                     vgc_partijen.id%type;
/*********************************************************************
Wijzigingshistorie
doel:
Indienen zending VGC-CLIENT bij TRACES-TNT (SUBMIT CONSIGNMENT)

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
 1      27-02-2020 GLR     creatie
 2      06-03-2020 CMA     W2003 1430
*********************************************************************/

--
  CURSOR c_ptj
  IS
    SELECT ptj.id
    ,      rle.aangevernummer
    ,      ptj.aangiftejaar
    ,      ptj.aangiftevolgnummer
    ,      ptj.ptj_type
    ,      decode(ptj.ptj_type,'NPJ','P','LPJ','A','D') cim_class
    ,      ptj.traces_certificaat_id
    FROM   vgc_v_partijen ptj
    ,      vgc_v_relaties rle
    WHERE  ptj.ggs_nummer = p_ggs_nummer
    AND    ptj.rle_id = rle.id
  ;
--
  r_ptj c_ptj%ROWTYPE;
--
  CURSOR c_prim_doc (b_ptj_id vgc_partijen.id%type)
  IS
    SELECT vdt.id
    ,      vdt.nummer
    FROM vgc_v_veterin_documenten vdt
    WHERE vdt.ptj_id = b_ptj_id
    ORDER BY creation_date ASC
  ;
--
  CURSOR c_prod_detail
  IS
/*    SELECT vvm.code
    ,      cli.aantal
    ,      cli.gewicht_netto
    ,      cli.gewicht_bruto
    ,      cli.aantal_dieren
    ,      cli.GN_CODE
    ,      cli.traces_complement_id
    ,      cli.traces_species_id
    FROM   vgc_v_colli cli
    ,      vgc_v_verpakkingsvormen vvm
    WHERE  cli.ptj_id = v_ptj_id
    AND    cli.clo_id IS NULL
    AND    vvm.id (+) = cli.vvm_id
  ;*/
    SELECT vvm.code
    ,      sum(cli1.aantal)
    ,      sum(cli1.gewicht_netto)
    ,      sum(cli1.gewicht_bruto)
    ,      sum(cli1.aantal_dieren)
    ,      cli.GN_CODE
    ,      cli.traces_complement_id
    ,      cli.traces_species_id
    FROM   vgc_v_colli cli
    ,      vgc_v_colli cli1
    ,      vgc_v_verpakkingsvormen vvm
    WHERE  cli.ptj_id = v_ptj_id
    AND    cli.clo_id IS NULL
    AND cli1.clo_id = cli.id
    AND    vvm.id (+) = cli.vvm_id
    group by vvm.code
    ,   cli.gn_code
    ,   cli.TRACES_COMPLEMENT_ID
    ,   cli.TRACES_SPECIES_ID
;
--
  CURSOR c_toe4
  IS
    SELECT ','||xmlagg(xmlelement(a,oe_code,',').extract('//text()')) vier_pos
    FROM   vgc_tnt_oe_codes
    WHERE  LENGTH(oe_code) = 4
  ;
--
  CURSOR c_toe3
  IS
    SELECT ','||xmlagg(xmlelement(a,oe_code,',').extract('//text()')) drie_pos
    FROM   vgc_tnt_oe_codes
    WHERE  LENGTH(oe_code) = 3
  ;
--
  CURSOR c_vdt (b_nummer vgc_v_veterin_documenten.nummer%TYPE
               ,b_ptj_id vgc_v_veterin_documenten.ptj_id%TYPE)
  IS
    SELECT '1'
    FROM   vgc_v_veterin_documenten
    WHERE  nummer = b_nummer
    AND    ptj_id = b_ptj_id
  ;
--
  CURSOR c_rqt
  IS
    SELECT rqt.*
    FROM   vgc_requests rqt
    WHERE  rqt.request_id = p_request_id
  ;
--
  v_vier_pos                     VARCHAR2(250 CHAR) := NULL;
  v_drie_pos                     VARCHAR2(250 CHAR) := NULL;
  v_erkenningsnummer           VARCHAR2(100 CHAR);
  r_rqt                        vgc_requests%ROWTYPE;
  v_aantal_dieren              NUMBER;
  v_collo_aantal               NUMBER;
  v_netto_gewicht              NUMBER;
  v_bruto_gewicht              NUMBER;
  v_primair_doc_id             vgc_vp_documenten.id%TYPE;
  v_primair_doc_nummer         vgc_vp_documenten.nummer%TYPE;
  v_hoofdverpakkingsvorm       VARCHAR2(20 CHAR);
  v_gn_code                    vgc_vp_producten.gn_code%TYPE;
  v_complement_id              vgc_v_gn_vertaling_traces.species_id%TYPE;
  v_species_id                 vgc_v_gn_vertaling_traces.gn_code_comp_id%TYPE;
  v_certificaat_ref            vgc_partijen.traces_certificaat_id%TYPE;
  v_ws_naam                    VARCHAR2(100 CHAR) := 'VGC0505NT';
  e_ws_error                   EXCEPTION;
  e_specific_operation_error   EXCEPTION;
  e_general_operation_error    EXCEPTION;
  v_request_id                 NUMBER;
  v_resultaat                  BOOLEAN;
  v_actiecode                  VARCHAR2(1 CHAR);
  v_pdf_jn                     VARCHAR2(1 CHAR) := 'N';
  v_operation_username         VARCHAR2(100 CHAR) := vgc$algemeen.get_appl_register ('TNT_WS_OPERATION_USR');
  v_operation_password         VARCHAR2(100 CHAR) := vgc$algemeen.get_appl_register ('TNT_WS_OPERATION_PWD');
  v_services_username          VARCHAR2(100 CHAR) := vgc$algemeen.get_appl_register ('TNT_WS_SERVICES_USR');
  v_services_password          VARCHAR2(100 CHAR) := vgc$algemeen.get_appl_register ('TNT_WS_SERVICES_PWD');
--
--  Stelt bericht op voor aanroep
--
  PROCEDURE maak_bericht(i_ggs_nummer IN vgc_partijen.ggs_nummer%TYPE)
  IS
    CURSOR c_xml
    IS
      SELECT c_encoding ||
             xmlelement("soap:Envelope"
             , xmlattributes ( 'http://schemas.xmlsoap.org/soap/envelope/' AS "xmlns:soap"
                             , 'http://www.w3.org/2001/XMLSchema-instance'  AS "xmlns:xsi"
                             , 'urn:axisgen.b2b.traces.sanco.cec.eu'  AS "xmlns:urn")
      ,      xmlelement("soap:Header")
      ,      xmlelement("soap:Body"
      ,        xmlelement("urn:submitConsignment"
      ,            xmlelement("in0"
      ,              xmlelement("VersionMIG", ptj.versienr_mig_in)
      ,              xmlelement("operationUserCredentials"
      ,                xmlelement("userName", v_operation_username)
      ,                xmlelement("userPassword", v_operation_password)
                     )
      ,              xmlelement("servicesUserCredentials"
      ,                xmlelement("userName", v_services_username)
      ,                xmlelement("userPassword", v_services_password)
                     )
      ,            CASE WHEN ptj.ptj_type = 'LPJ'
                   THEN
                     xmlelement("CHEDAnimalsConsignment"
      ,              CASE WHEN ptj.traces_certificaat_id IS NOT NULL
                     THEN
                       xmlelement("certificateIdentification"
      ,                  xmlelement("referenceNumber" , v_certificaat_ref)
      ,                  xmlelement("type" , 'CHEDA')
                       )
                     ELSE
                       NULL
                     END
      ,                  ( select xmlagg(col)
                           from ( select (xmlelement("commodity"
                                                   ,xmlelement("commodityCode",clo.gn_code)
                                                   )) col
                                  from   vgc_v_vgc0505nt_clo clo
                                  where  clo.ptj_id = v_ptj_id
                                  group  by clo.gn_code
                         ))
      ,                xmlelement("signatory"
      ,                  xmlelement("dateOfDeclaration" , xmlattributes(decode(ptj.datum_ondertekening, NULL,'true','false') "xsi:nil"), get_ws_date(NULL, ptj.creation_date, 'yymmdd'))
      ,                  xmlelement("signatory"
      ,                    xmlelement("userDetail"
      ,                      xmlelement("lastName", xmlattributes(decode(ptj.naam_ondertekenaar, NULL,'true','false') "xsi:nil"), ptj.naam_ondertekenaar)
                           )
                         )
                       )
      ,                xmlelement("animalsCertificatedAs"
      ,                  xmlelement("referenceDataCode", xmlattributes(decode(get_tnt_destination(gbl.code,'LGL'), NULL,'true','false') "xsi:nil"),get_tnt_destination(gbl.code,'LGL'))
                       )
      ,                xmlelement("competentAuthority"
      ,                  xmlelement("code", xmlattributes(decode(bca.animo_code , NULL,'true','false') "xsi:nil"), bca.animo_code )
                       )
      ,                xmlelement("consignor", get_relatie_element('DP', ptj.dp_naam, ptj.dp_land, ptj.dp_plaats, ptj.dp_postcode, ptj.dp_straat_postbus, ptj.dp_huisnummer, ptj.dp_huisnummertoevoeging, get_tnt_activity_code(v_gn_code, 'DP', 'L'),ptj.dp_id_type,nvl(dp_id,ptj.dp_traces_id)))
      ,                xmlelement("countryOfOriginCode", xmlattributes(decode(lon.lnd_code, NULL,'true','false') "xsi:nil"),lon.lnd_code)
      ,                CASE WHEN nvl(bsg.datumtijd, ptj.datum_aankomst) < sysdate
                       THEN
                         xmlelement("departureDate", xmlattributes(decode(sysdate + 1/48, NULL,'true','false') "xsi:nil"),get_ws_date(NULL, sysdate + 1/48, 'yymmddHH24MI'))
                       ELSE
                         xmlelement("departureDate", xmlattributes(decode(nvl(bsg.datumtijd, ptj.datum_aankomst), NULL,'true','false') "xsi:nil"),get_ws_date(NULL, nvl(bsg.datumtijd, ptj.datum_aankomst) + 1/48, 'yymmddHH24MI'))
                       END
      ,                CASE WHEN nvl(bsg.datumtijd, ptj.datum_aankomst) < ptj.datum_aankomst
                       THEN
                         xmlelement("estimatedArrivalAtBIP", xmlattributes(decode(nvl(bsg.datumtijd, ptj.datum_aankomst), NULL,'true','false') "xsi:nil"),get_ws_date(NULL, nvl(bsg.datumtijd, ptj.datum_aankomst), 'yymmddHH24MI'))
                       ELSE
                         xmlelement("estimatedArrivalAtBIP",  xmlattributes(decode(ptj.datum_aankomst, NULL,'true','false') "xsi:nil"),get_ws_date(NULL, ptj.datum_aankomst, 'yymmddHH24MI'))
                       END
      ,                xmlelement("estimatedJourneyTime", 1)
      ,                xmlelement("importer", get_relatie_element('IM', ptj.im_naam, ptj.im_land, ptj.im_plaats, ptj.im_postcode, ptj.im_straat_postbus, ptj.im_huisnummer, ptj.im_huisnummertoevoeging, get_tnt_activity_code(v_gn_code, 'IM', 'L'),ptj.im_id_type,nvl(im_id,ptj.im_traces_id)))
      ,                xmlelement("localReferenceNumber", ptj.ggs_nummer)
      ,                CASE WHEN ptj.versienr_mig_in > 5
                       THEN
                         ( SELECT xmlagg(xmlelement("meansOfTransport"
      ,                             xmlelement("document", xmlattributes(decode(ptj.vrachtbriefnummer, NULL,'true','false') "xsi:nil"),substr(ptj.vrachtbriefnummer,1,32))
      ,                             xmlelement("identification", xmlattributes(decode(identificatie, NULL,'true','false') "xsi:nil"), identificatie)
      ,                             xmlelement("type", xmlattributes(decode(vervoer, NULL,'true','false') "xsi:nil"), CASE WHEN bca.luchthaven_ind = 'J' THEN 'PLANE' ELSE vervoer END)                               ))
                         FROM( SELECT DECODE(lvg.lnd_code , 'GB', 'ROAD', cfe.rv_abbreviation) vervoer
                               ,      tpt.identificatie
                               FROM   vgc_v_transporten tpt
                               ,      cg_ref_codes cfe
                               WHERE  tpt.ptj_id = v_ptj_id
                               AND    cfe.rv_domain = 'SOORT VERVOER'
                               AND    cfe.rv_low_value = tpt.soort_vervoer
                               AND    tpt.voor_grens_ind = 'J')
                         )
                       ELSE
                         xmlelement("meansOfTransport"
      ,                    xmlelement("document", xmlattributes(decode(ptj.vrachtbriefnummer, NULL,'true','false') "xsi:nil"),substr(ptj.vrachtbriefnummer,1,32))
      ,                    xmlelement("identification", xmlattributes(decode(ptj.vaartuig_vluchtnummer, NULL,'true','false') "xsi:nil"), ptj.vaartuig_vluchtnummer)
      ,                    xmlelement("type", CASE WHEN lvg.lnd_code = 'GB' THEN 'ROAD' ELSE  CASE WHEN bca.luchthaven_ind = 'J' THEN 'PLANE' ELSE 'SHIP' END END)
--      ,                    xmlelement("type", CASE WHEN bca.luchthaven_ind = 'J' THEN 'PLANE' ELSE 'SHIP' END)
                         )
                       END
      ,                CASE WHEN ptj.versienr_mig_in > 5
                       THEN
                         ( SELECT xmlagg(xmlelement("meansOfTransportAfterBIP"
      ,                             xmlelement("document", xmlattributes(decode(ptj.ggs_nummer, NULL,'true','false') "xsi:nil"),ptj.ggs_nummer)
      ,                             xmlelement("identification", xmlattributes(decode(identificatie, NULL,'true','false') "xsi:nil"), identificatie)
      ,                             xmlelement("type", xmlattributes(decode(vervoer, NULL,'true','false') "xsi:nil"), vervoer)                               ))
                         FROM( SELECT cfe.rv_abbreviation vervoer
                               ,      tpt.identificatie
                               FROM   vgc_v_transporten tpt
                               ,      cg_ref_codes cfe
                               WHERE  tpt.ptj_id = v_ptj_id
                               AND    cfe.rv_domain = 'SOORT VERVOER'
                               AND    cfe.rv_low_value = tpt.soort_vervoer
                               AND    tpt.voor_grens_ind = 'N')
                         )
                       ELSE
                         xmlelement("meansOfTransportAfterBIP"
      ,                    xmlelement("document", xmlattributes(decode(ptj.ggs_nummer, NULL,'true','false') "xsi:nil"), ptj.ggs_nummer)
      ,                    xmlelement("identification", xmlattributes(decode(ptj.vervolgtransportid, NULL,'true','false') "xsi:nil"),ptj.vervolgtransportid)
      ,                    xmlelement("type", get_tnt_transport_type(ptj.vervolgtransport))
                         )
                       END
      ,                xmlelement("numberOfAnimals" , xmlattributes(decode(v_aantal_dieren, NULL,'true','false') "xsi:nil"),  v_aantal_dieren)
      ,                xmlelement("numberOfAnimalsUnit", 'UNIT')
      ,                xmlelement("numberOfPackages",  xmlattributes(decode(v_collo_aantal, NULL,'true','false') "xsi:nil"),  v_collo_aantal)
      ,                xmlelement("productGrossWeight", xmlattributes(decode(v_bruto_gewicht, NULL,'true','false') "xsi:nil"), LTRIM(TO_CHAR(v_bruto_gewicht,'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))
      ,                xmlelement("placeOfDestination",get_relatie_element('AF', ptj.af_naam, ptj.af_land, ptj.af_plaats, ptj.af_postcode, ptj.af_straat_postbus, ptj.af_huisnummer, ptj.af_huisnummertoevoeging, get_tnt_activity_code(v_gn_code, 'AF', 'L'),ptj.af_id_type,nvl(af_id,ptj.af_traces_id)))
      ,                CASE WHEN upper(vbg.code) IN ('IVR')
                       THEN
                         xmlelement("purpose"
      ,                    xmlelement("forImportOrAdmission"
      ,                      xmlelement("exitBip"
      ,                        xmlelement("code", xmlattributes(decode(bce.animo_code, NULL,'true','false') "xsi:nil"),substr(rpad(bce.animo_code,7),1,7))
                             )
      ,                      xmlelement("exitDate", xmlattributes(decode(ptj.uitslagdatum, NULL,'true','false') "xsi:nil"), get_ws_date(NULL, ptj.uitslagdatum, 'yymmddHH24MI'))
      ,                      xmlelement("measure", xmlattributes(decode(get_tnt_measure(ptj.soort_import), NULL,'true','false') "xsi:nil"), get_tnt_measure(ptj.soort_import))
                           )
                         )
                       WHEN upper(vbg.code) = 'WIR'
                       THEN
                         xmlelement("purpose"
      ,                    xmlelement("forReImport")
                         )
                       WHEN upper(vbg.code) = 'DVR'
                       THEN
                         xmlelement("purpose"
      ,                    xmlelement("forTransit"
      ,                      xmlelement("destinationThirdCountryCode",xmlattributes(decode(lbg.lnd_code, NULL,'true','false') "xsi:nil"), lbg.lnd_code)
      ,                      xmlelement("exitBip"
      ,                        xmlelement("code",xmlattributes(decode(bce.animo_code, NULL,'true','false') "xsi:nil"), decode(bce.us_army_ind,'J',bce.naam, decode(bce.animo_code,'FRCQF1',bce.naam,bce.animo_code)))
      ,                        xmlelement("type",xmlattributes(decode(bce.us_army_ind, 'N','true','false') "xsi:nil"), decode(bce.us_army_ind,'J','MILITARY_FACILITY',NULL))
                             )
                           )
                         )
                       ELSE
                         xmlelement("purpose", xmlattributes('true' "xsi:nil"))
                       END
      ,                xmlelement("regionOfOriginCode", xmlattributes(decode(lon.rgo_code, NULL,'true','false') "xsi:nil"), lon.rgo_code)
      ,                xmlelement("responsibleForConsignment", get_relatie_element('AL', rle.naam, rle_al_lnd.code, rle.plaats, rle.postcode, rle.straat_postbus, rle.huisnummer, rle.huisnummertoevoeging, rle.traces_activity_code,null,rle.traces_id)) /*#12*/
      ,                xmlelement("responsibleForJourneyTransport", xmlattributes(decode(ptj.tr_naam, NULL,'true','false') "xsi:nil"), substr(ptj.tr_naam,1,32))  V
      ,                ( SELECT xmlagg(
                                  xmlelement("sealContainer"
                         ,          xmlelement("containerNumber",xmlattributes(decode(nummer, NULL,'true','false') "xsi:nil"),  nummer)
                         ,          xmlelement("sealNumber", xmlattributes(decode(zegelnummer, NULL,'true','false') "xsi:nil"), substr(zegelnummer,1,32))
                                  )
                                )
                         FROM( SELECT DISTINCT replace(ctn.nummer,'-','') nummer
                               ,      ctn.zegelnummer
                               FROM   vgc_v_containers ctn
                               ,      vgc_v_colli cli
                               WHERE  ctn.clo_id = cli.id
                               AND    cli.ptj_id = v_ptj_id
                             )
                       )
      ,                ( SELECT xmlagg (xmlelement("transitMemberStateCode", xmlattributes(decode(lnd.code, NULL,'true','false') "xsi:nil"), lnd.code))
                         FROM   vgc_landen lnd
                         ,      vgc_landrollen ldn
                         ,      vgc_landrol_types lre
                         WHERE  ldn.ptj_id = v_ptj_id
                         AND    ldn.lre_id = lre.id
                         AND    lre.code  = 'COR'
                         AND    lnd.id = ldn.lnd_id
                       )
      ,              xmlelement("transporter", get_relatie_element('TR', substr(ptj.tr_naam,1,32), ptj.tr_land, ptj.tr_plaats, ptj.tr_postcode, ptj.tr_straat_postbus, ptj.tr_huisnummer, ptj.tr_huisnummertoevoeging, get_tnt_activity_code(v_gn_code, 'TR', 'L'),ptj.tr_id_type,nvl(tr_id,ptj.tr_traces_id)))
      ,                  xmlelement("identificationOfAnimals"
                                   ,(select xmlagg(xmlelement("identificationParameterSet"
                                                             ,case when clo.gn_code is not null then xmlelement("identificationParameter",xmlelement("key",'commodityCode'),xmlelement("data",clo.gn_code)) else null end
                                                             ,case when clo.sum_gewicht_bruto is not null then xmlelement("identificationParameter",xmlelement("key",'grossweight'),xmlelement("data",LTRIM(TO_CHAR(clo.sum_gewicht_bruto,'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))) else null end
                                                             ,case when clo.verpakkingsvorm is not null then xmlelement("identificationParameter",xmlelement("key",'type_package'),xmlelement("data",get_tnt_type_of_packages(clo.verpakkingsvorm))) else null end
                                                             ,case when clo.traces_complement_id is not null then xmlelement("identificationParameter",xmlelement("key",'complement'),xmlelement("data",clo.traces_complement_id)) else null end
                                                             ,case when clo.traces_species_id is not null then xmlelement("identificationParameter",xmlelement("key",'species'),xmlelement("data",clo.traces_species_id)) else null end
                                                             ,case when clo.product_type is not null then xmlelement("identificationParameter",xmlelement("key",'producttype'),xmlelement("data",clo.product_type)) 
                                                              else 
                                                                (select xmlagg(xmlelement("identificationParameter",xmlelement("key",'producttype'),xmlelement("data",cpt.producttype_uppercase))) 
                                                                            from  vgc_v_vgc0505nt_cpt cpt
                                                                            ,     vgc_v_colli clo2
                                                                           where  clo2.id = cpt.clo_id
                                                                           and    clo2.ptj_id = v_ptj_id
                                                                )
                                                              end            
                                                             ,case when clo.species is not null then xmlelement("identificationParameter",xmlelement("key",'species'),xmlelement("data",clo.species))
                                                              else 
                                                                (select xmlagg(xmlelement("identificationParameter",xmlelement("key",'species'),xmlelement("data",css.species_uppercase))) 
                                                                            from   vgc_v_vgc0505nt_css css
                                                                            ,     vgc_v_colli clo2
                                                                            where  clo2.id = css.clo_id
                                                                            and    clo2.ptj_id = v_ptj_id
                                                                )
                                                              end            
                                                             ,case when clo.sum_aantal is not null then xmlelement("identificationParameter",xmlelement("key",'number_package'),xmlelement("data",clo.sum_aantal)) else null end
                                                             ,case when clo.sum_aantal_dieren is not null then xmlelement("identificationParameter",xmlelement("key",'number_animal'),xmlelement("data",clo.sum_aantal_dieren)) else null end
                                                             ,case when clo.eng_erkenningsnummer is not null then
                                                                xmlelement("identificationOfEstablishments"
                                                                         ,(select xmlagg(xmlelement("identificationParameterSet"
                                                                                                   ,case when eng.erkenningsnummer is not null then xmlelement("identificationParameter",xmlelement("key",'approvalNumber'),xmlelement("data",eng.erkenningsnummer)) else null end
                                                                                                   ,case when eng.activiteit is not null then xmlelement("identificationParameter",xmlelement("key",'activity'),xmlelement("data",eng.activiteit)) else null end
                                                                                                   ,case when eng.land_code is not null then xmlelement("identificationParameter",xmlelement("key",'countryCode'),xmlelement("data",eng.land_code)) else null end
                                                                                                   ,case when eng.postcode is not null then xmlelement("identificationParameter",xmlelement("key",'postalCode'),xmlelement("data",eng.postcode)) else null end
                                                                                                     ))
                                                                           from   vgc_v_vgc0505nt_eng eng
                                                                            ,     vgc_v_colli clo2
                                                                           where  clo2.id = eng.clo_id
                                                                           and    clo2.ptj_id = v_ptj_id
                                                                          )
                                                                         )
                                                              else
                                                                xmlelement("identificationOfEstablishments"
                                                                         ,(select xmlagg(xmlelement("identificationParameterSet"
                                                                                                   ,case when eng.erkenningsnummer is not null then xmlelement("identificationParameter",xmlelement("key",'approvalNumber'),xmlelement("data",eng.erkenningsnummer)) else null end
                                                                                                   ,case when eng.activiteit is not null then xmlelement("identificationParameter",xmlelement("key",'activity'),xmlelement("data",eng.activiteit)) else null end
                                                                                                   ,case when eng.land_code is not null then xmlelement("identificationParameter",xmlelement("key",'countryCode'),xmlelement("data",eng.land_code)) else null end
                                                                                                   ,case when eng.postcode is not null then xmlelement("identificationParameter",xmlelement("key",'postalCode'),xmlelement("data",eng.postcode)) else null end
                                                                                                     ))
                                                                           from   vgc_v_vgc0505nt_eng eng
                                                                           ,     vgc_v_colli clo2
                                                                           where  clo2.id = eng.clo_id
                                                                           and    clo2.ptj_id = v_ptj_id
                                                                          )
                                                                         )
                                                              end
                                             --                 ,case when clo.batchnummer is not null then xmlelement("identificationParameter",xmlelement("key",'batchNumber'),xmlelement("data",clo.batchnummer)) else null end
                                                              ,case when clo.paspoortnummer is not null then xmlelement("identificationParameter",xmlelement("key",'passportNumber'),xmlelement("data",clo.paspoortnummer)) else null end
                                                              ,case when clo.id_nummer is not null then xmlelement("identificationParameter",xmlelement("key",'idNumber'),xmlelement("data",clo.id_nummer)) else null end
                                                              ))
                                     from   vgc_v_vgc0505nt_clo clo
                                     where  clo.ptj_id = ptj.id
                                    )
                                   )
      ,                xmlelement("veterinaryDocuments"
      ,                  xmlelement("issueDate", xmlattributes(decode(dct.datum_afgifte, NULL,'true','false') "xsi:nil"), get_ws_date(NULL, dct.datum_afgifte, 'yymmddHH24MI'))
      ,                    xmlelement("type", xmlattributes(decode('636', NULL,'true','false') "xsi:nil"), '636')
      ,                    xmlelement("countrycode", xmlattributes(decode(lon.lnd_code, NULL,'true','false') "xsi:nil"), lon.lnd_code)
      ,                    xmlelement("number", xmlattributes(decode(dct.nummer, NULL,'true','false') "xsi:nil"), dct.nummer)
                       )
                     )
                   WHEN ptj.ptj_type = 'NPJ'
                   THEN
                     xmlelement("CHEDAnimalProductsConsignment"
      ,                CASE WHEN ptj.traces_certificaat_id IS NOT NULL
                       THEN
                         xmlelement("certificateIdentification"
      ,                    xmlelement("referenceNumber" , v_certificaat_ref)
      ,                    xmlelement("type" , 'CHEDP')
                         )
                       ELSE
                         NULL
                       END
     ,                  ( select xmlagg(col)
                           from ( select (xmlelement("commodity"
                                                   ,xmlelement("commodityCode",clo.gn_code)
                                                   ,xmlelement("subtotalNetWeight",LTRIM(TO_CHAR(sum(clo.sum_gewicht_netto),'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))
                                                   )) col
                                  from   vgc_v_vgc0505nt_clo clo
                                  where  clo.ptj_id = v_ptj_id
                                  group  by clo.gn_code
                         ))
      ,                xmlelement("signatory"
      ,                  xmlelement("dateOfDeclaration" , xmlattributes(decode(ptj.datum_ondertekening, NULL,'true','false') "xsi:nil"), get_ws_date(NULL, ptj.creation_date, 'yymmdd'))
      ,                  xmlelement("signatory"
      ,                    xmlelement("userDetail"
      ,                      xmlelement("lastName", xmlattributes(decode(ptj.naam_ondertekenaar, NULL,'true','false') "xsi:nil"), ptj.naam_ondertekenaar)
                           )
                         )
                       )
      ,                xmlelement("animalsCertificatedAs"
      ,                  xmlelement("referenceDataCode", xmlattributes(decode(get_tnt_destination(gbl.code,'NGL'), NULL,'true','false') "xsi:nil"),get_tnt_destination(gbl.code,'NGL'))
                       )
      ,                xmlelement("competentAuthority"
      ,                  xmlelement("code", xmlattributes(decode(bca.animo_code, NULL,'true','false') "xsi:nil"),bca.animo_code)
                       )
      ,                xmlelement("conformToEuRequirements", xmlattributes(decode(ptj.eu_waardig_ind, NULL,'true','false') "xsi:nil"), CASE WHEN ptj.eu_waardig_ind = 'J'THEN 'true' WHEN ptj.eu_waardig_ind IS NULL THEN NULL WHEN PTJ.eu_waardig_ind= 'N' THEN 'false' END )
      ,                xmlelement("consignor", get_relatie_element('DP', ptj.dp_naam, ptj.dp_land, ptj.dp_plaats, ptj.dp_postcode, ptj.dp_straat_postbus, ptj.dp_huisnummer, ptj.dp_huisnummertoevoeging, get_tnt_activity_code(v_gn_code, 'DP', 'P'),ptj.dp_id_type,nvl(dp_id,ptj.dp_traces_id)))
      ,                xmlelement("countryFromWhereConsignedCode",  xmlattributes(decode(lvg.lnd_code, NULL,'true','false') "xsi:nil"), lvg.lnd_code)
      ,                xmlelement("countryOfOriginCode",  xmlattributes(decode(lon.lnd_code, NULL,'true','false') "xsi:nil"),lon.lnd_code)
      ,                xmlelement("deliveryAddress", get_relatie_element('AF', ptj.af_naam, ptj.af_land, ptj.af_plaats, ptj.af_postcode, ptj.af_straat_postbus, ptj.af_huisnummer, ptj.af_huisnummertoevoeging, CASE WHEN vbg.code = 'OPS' AND ptj.opslag = 'VZT' THEN 'warehouse' WHEN (vbg.code = 'DVR' and nvl(bce.us_army_ind,'N') = 'N') THEN NULL ELSE get_tnt_activity_code(v_gn_code, 'AF', 'P') END,ptj.af_id_type,nvl(af_id,ptj.af_traces_id)))--
      ,                CASE WHEN nvl(bsg.datumtijd, ptj.datum_aankomst) < sysdate
                       THEN
                         xmlelement("departureDate", xmlattributes(decode(sysdate + 1/48, NULL,'true','false') "xsi:nil"),get_ws_date(NULL, sysdate + 1/48, 'yymmddHH24MI'))
                       ELSE
                         xmlelement("departureDate", xmlattributes(decode(nvl(bsg.datumtijd, ptj.datum_aankomst), NULL,'true','false') "xsi:nil"),get_ws_date(NULL, nvl(bsg.datumtijd, ptj.datum_aankomst) + 1/48, 'yymmddHH24MI'))
                       END
      ,                CASE WHEN nvl(bsg.datumtijd, ptj.datum_aankomst) < ptj.datum_aankomst
                       THEN
                         xmlelement("estimatedArrivalAtBIP", xmlattributes(decode(nvl(bsg.datumtijd, ptj.datum_aankomst), NULL,'true','false') "xsi:nil"),get_ws_date(NULL, nvl(bsg.datumtijd, ptj.datum_aankomst), 'yymmddHH24MI'))
                       ELSE
                         xmlelement("estimatedArrivalAtBIP",  xmlattributes(decode(ptj.datum_aankomst, NULL,'true','false') "xsi:nil"),get_ws_date(NULL, ptj.datum_aankomst, 'yymmddHH24MI'))
                       END
      ,                xmlelement("importer", get_relatie_element('IM',  ptj.im_naam, ptj.im_land, ptj.im_plaats, ptj.im_postcode, ptj.im_straat_postbus, ptj.im_huisnummer, ptj.im_huisnummertoevoeging, CASE WHEN (vbg.code = 'DVR' and nvl(bce.us_army_ind,'N') = 'N') THEN NULL ELSE get_tnt_activity_code(v_gn_code, 'IM', 'P') END,ptj.im_id_type,nvl(im_id,ptj.im_traces_id)))--
      ,                xmlelement("localReferenceNumber", ptj.ggs_nummer)
      ,                CASE WHEN ptj.versienr_mig_in > 5
                       THEN
                         ( SELECT xmlagg(xmlelement("meansOfTransport"
      ,                             xmlelement("document", xmlattributes(decode(ptj.vrachtbriefnummer, NULL,'true','false') "xsi:nil"),substr(ptj.vrachtbriefnummer,1,32))
      ,                             xmlelement("identification", xmlattributes(decode(identificatie, NULL,'true','false') "xsi:nil"), identificatie)
      ,                             xmlelement("type", xmlattributes(decode(vervoer, NULL,'true','false') "xsi:nil"), CASE WHEN bca.luchthaven_ind = 'J' THEN 'PLANE' ELSE vervoer END)                               ))
                         FROM( SELECT DECODE(lvg.lnd_code , 'GB', 'ROAD', cfe.rv_abbreviation) vervoer
                               ,      tpt.identificatie
                               FROM   vgc_v_transporten tpt
                               ,      cg_ref_codes cfe
                               WHERE  tpt.ptj_id = v_ptj_id
                               AND    cfe.rv_domain = 'SOORT VERVOER'
                               AND    cfe.rv_low_value = tpt.soort_vervoer
                               AND    tpt.voor_grens_ind = 'J')
                         )
                       ELSE
                         xmlelement("meansOfTransport"
      ,                    xmlelement("document", xmlattributes(decode(ptj.vrachtbriefnummer, NULL,'true','false') "xsi:nil"),substr(ptj.vrachtbriefnummer,1,32))
      ,                    xmlelement("identification", xmlattributes(decode(ptj.vaartuig_vluchtnummer, NULL,'true','false') "xsi:nil"), ptj.vaartuig_vluchtnummer)
      ,                    xmlelement("type", CASE WHEN lvg.lnd_code = 'GB' THEN 'ROAD' ELSE  CASE WHEN bca.luchthaven_ind = 'J' THEN 'PLANE' ELSE 'SHIP' END END)
--      ,                    xmlelement("type", CASE WHEN bca.luchthaven_ind = 'J' THEN 'PLANE' ELSE 'SHIP' END)
                         )
                       END
      ,                CASE WHEN ptj.versienr_mig_in > 5 --AND vbg.code IN ('OPS', 'DVR')
                       THEN
                         ( SELECT xmlagg(xmlelement("meansOfTransportAfterBIP"
      ,                             xmlelement("document", xmlattributes(decode(ptj.ggs_nummer, NULL,'true','false') "xsi:nil"),ptj.ggs_nummer)
      ,                             xmlelement("identification", xmlattributes(decode(identificatie, NULL,'true','false') "xsi:nil"), identificatie)
      ,                             xmlelement("type", xmlattributes(decode(vervoer, NULL,'true','false') "xsi:nil"), vervoer)                               ))
                         FROM( SELECT cfe.rv_abbreviation vervoer
                               ,      tpt.identificatie
                               FROM   vgc_v_transporten tpt
                               ,      cg_ref_codes cfe
                               WHERE  tpt.ptj_id = v_ptj_id
                               AND    cfe.rv_domain = 'SOORT VERVOER'
                               AND    cfe.rv_low_value = tpt.soort_vervoer
                               AND    tpt.voor_grens_ind = 'N')
                         )
                       WHEN vbg.code IN ('OPS', 'DVR') AND ptj.versienr_mig_in < 6
                       THEN
                         xmlelement("meansOfTransportAfterBIP"
      ,                    xmlelement("document", ptj.ggs_nummer)
      ,                    xmlelement("identification",'not_registered_in_vgc')
      ,                    xmlelement("type", 'OTHER')
                         )
                       ELSE
                         NULL
                       END
      ,                xmlelement("numberPackages",  xmlattributes(decode(v_collo_aantal, NULL,'true','false') "xsi:nil"),  v_collo_aantal)
      ,                xmlelement("productGrossWeight", xmlattributes(decode(v_bruto_gewicht, NULL,'true','false') "xsi:nil"), LTRIM(TO_CHAR(v_bruto_gewicht,'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))
      ,                xmlelement("productNetWeight",  xmlattributes(decode(v_netto_gewicht, NULL,'true','false') "xsi:nil"),  LTRIM(TO_CHAR(v_netto_gewicht,'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))
      ,                xmlelement("productTemperature",  xmlattributes(decode(get_tnt_product_temperature(cse.code), NULL,'true','false') "xsi:nil"),get_tnt_product_temperature(cse.code))
      ,                CASE WHEN vbg.code = 'IVR'
                       THEN
                         xmlelement("purpose"
      ,                    xmlelement("forInternalMarket"
      ,                      xmlelement("destination",  xmlattributes(decode(get_tnt_destination(gbl.code,'NGL'), NULL,'true','false') "xsi:nil"), get_tnt_destination(gbl.code,'NGL'))
                           )
                         )
                       WHEN vbg.code = 'OPS'
                       THEN
                         xmlelement("purpose"
      ,                    xmlelement("forNonConformingConsignment"
      ,                      xmlelement("destination", xmlattributes(decode(get_tnt_destination_type(ptj.opslag), NULL,'true','false') "xsi:nil"), get_tnt_destination_type(ptj.opslag))
      ,                      xmlelement("name", xmlattributes(decode(ptj.naam_vaartuig, NULL,'true','false') "xsi:nil"),ptj.naam_vaartuig)
      ,                      xmlelement("port", xmlattributes(decode(ptj.naam_haven, NULL,'true','false') "xsi:nil"),ptj.naam_haven)
      ,                      xmlelement("registerNumber", xmlattributes(decode(ptj.registratienummer, NULL,'true','false') "xsi:nil"), ptj.registratienummer)
                           )
                         )
                       WHEN vbg.code = 'WIR'
                       THEN
                         xmlelement("purpose"
      ,                    xmlelement("forReImport")
                         )
                       WHEN vbg.code = 'DVR'
                       THEN
                         xmlelement("purpose"
      ,                    xmlelement("forTransit"
      ,                      xmlelement("destinationThirdCountryCode",  xmlattributes(decode(lbg.lnd_code, NULL,'true','false') "xsi:nil"), lbg.lnd_code)
      ,                      xmlelement("exitBip"
      ,                        xmlelement("code",xmlattributes(decode(bce.animo_code, NULL,'true','false') "xsi:nil"), decode(bce.us_army_ind,'J',bce.naam, decode(bce.animo_code,'FRCQF1',bce.naam,bce.animo_code)))
      ,                        xmlelement("type",xmlattributes(decode(bce.us_army_ind, 'N','true','false') "xsi:nil"), decode(bce.us_army_ind,'J','MILITARY_FACILITY',NULL))
                                 )
                           )
                         )
                       ELSE
                         xmlelement("purpose", xmlattributes('true' "xsi:nil"))
                       END
      ,                xmlelement("responsibleForConsignment", get_relatie_element('AL', rle.naam, rle_al_lnd.code, rle.plaats, rle.postcode, rle.straat_postbus, rle.huisnummer, rle.huisnummertoevoeging, rle.traces_activity_code,null,rle.traces_id)) /*#12*/
      ,                ( SELECT xmlagg(xmlelement("sealContainer"
                         ,               xmlelement("containerNumber",xmlattributes(decode(nummer, NULL,'true','false') "xsi:nil"),  nummer)
                         ,               xmlelement("sealNumber", xmlattributes(decode(zegelnummer, NULL,'true','false') "xsi:nil"), substr(zegelnummer,1,32) /*#11*/)
                                       )
                                )
                         FROM( SELECT DISTINCT replace(ctn.nummer,'-','') nummer
                               ,      ctn.zegelnummer
                               FROM   vgc_v_containers ctn
                               ,      vgc_v_colli cli
                               WHERE  ctn.clo_id = cli.id
                               AND    cli.ptj_id = v_ptj_id)
                       )
      ,                  xmlelement("typeOfPackages"
      ,                    xmlelement("referenceDataCode", get_tnt_type_of_packages(v_hoofdverpakkingsvorm))
                                   )
      ,                  xmlelement("identificationOfAnimals"
                                   ,(select xmlagg(xmlelement("identificationParameterSet"
                                                             ,case when clo.gn_code is not null then xmlelement("identificationParameter",xmlelement("key",'commodityCode'),xmlelement("data",clo.gn_code)) else null end
                                                             ,case when clo.traces_complement_id is not null then xmlelement("identificationParameter",xmlelement("key",'complement'),xmlelement("data",clo.traces_complement_id)) else null end
                                                             ,case when clo.sum_gewicht_bruto is not null then xmlelement("identificationParameter",xmlelement("key",'grossweight'),xmlelement("data",LTRIM(TO_CHAR(clo.sum_gewicht_bruto,'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))) else null end
                                                             ,case when clo.sum_gewicht_netto is not null and clo.gn_code != '05111000' then xmlelement("identificationParameter",xmlelement("key",'netweight'),xmlelement("data",LTRIM(TO_CHAR(clo.sum_gewicht_netto,'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))) else null end
                                                             ,case when clo.product_type is not null then xmlelement("identificationParameter",xmlelement("key",'producttype'),xmlelement("data",clo.product_type)) 
                                                              else 
                                                                (select xmlagg(xmlelement("identificationParameter",xmlelement("key",'producttype'),xmlelement("data",cpt.producttype_uppercase))) 
                                                                            from   vgc_v_vgc0505nt_cpt cpt
                                                                            ,      vgc_v_colli clo2
                                                                            where  clo2.id = cpt.clo_id
                                                                            and    clo2.ptj_id = ptj.id
                                                                )
                                                              end            
                                                             ,case when clo.species is not null then xmlelement("identificationParameter",xmlelement("key",'species'),xmlelement("data",clo.species))
                                                              else 
                                                                (select xmlagg(xmlelement("identificationParameter",xmlelement("key",'species'),xmlelement("data",css.species_uppercase))) 
                                                                            from   vgc_v_vgc0505nt_css css
                                                                            ,      vgc_v_colli clo2
                                                                            where  clo2.id = css.clo_id
                                                                            and    clo2.ptj_id = ptj.id
                                                                )
                                                              end            
                                                             ,case when clo.traces_species_id is not null then xmlelement("identificationParameter",xmlelement("key",'species'),xmlelement("data",clo.traces_species_id)) else null end
                                                             ,case when clo.sum_aantal is not null then xmlelement("identificationParameter",xmlelement("key",'number_package'),xmlelement("data",clo.sum_aantal)) else null end
                                                             ,case when clo.sum_aantal_dieren is not null and clo.hoeveelheid_ind != 'N' then xmlelement("identificationParameter",xmlelement("key",'number_animal'),xmlelement("data",clo.sum_aantal_dieren)) else null end
                                                             ,case when clo.verpakkingsvorm is not null then xmlelement("identificationParameter",xmlelement("key",'type_package'),xmlelement("data",get_tnt_type_of_packages(clo.verpakkingsvorm))) else null end
                                                             ,case when clo.eng_erkenningsnummer is not null then
                                                                xmlelement("identificationOfEstablishments"
                                                                         ,(select xmlagg(xmlelement("identificationParameterSet"
                                                                                                   ,case when eng.erkenningsnummer is not null then xmlelement("identificationParameter",xmlelement("key",'approvalNumber'),xmlelement("data",eng.erkenningsnummer)) else null end
                                                                                                   ,case when eng.activiteit is not null then xmlelement("identificationParameter",xmlelement("key",'activity'),xmlelement("data",eng.activiteit)) else null end
                                                                                                   ,case when eng.land_code is not null then xmlelement("identificationParameter",xmlelement("key",'countryCode'),xmlelement("data",eng.land_code)) else null end
                                                                                                   ,case when eng.postcode is not null then xmlelement("identificationParameter",xmlelement("key",'postalCode'),xmlelement("data",eng.postcode)) else null end
                                                                                                     ))
                                                                           from   vgc_v_vgc0505nt_eng eng
                                                                               ,     vgc_v_colli clo2
                                                                           where  clo2.id = eng.clo_id
                                                                           and    clo2.ptj_id = v_ptj_id
                                                                      )
                                                                         )
                                                              else
                                                                xmlelement("identificationOfEstablishments"
                                                                         ,(select xmlagg(xmlelement("identificationParameterSet"
                                                                                                   ,case when eng.erkenningsnummer is not null then xmlelement("identificationParameter",xmlelement("key",'approvalNumber'),xmlelement("data",eng.erkenningsnummer)) else null end
                                                                                                   ,case when eng.activiteit is not null then xmlelement("identificationParameter",xmlelement("key",'activity'),xmlelement("data",eng.activiteit)) else null end
                                                                                                   ,case when eng.land_code is not null then xmlelement("identificationParameter",xmlelement("key",'countryCode'),xmlelement("data",eng.land_code)) else null end
                                                                                                   ,case when eng.postcode is not null then xmlelement("identificationParameter",xmlelement("key",'postalCode'),xmlelement("data",eng.postcode)) else null end
                                                                                                     ))
                                                                           from   vgc_v_vgc0505nt_eng eng
                                                                           ,     vgc_v_colli clo2
                                                                           where  clo2.id = eng.clo_id
                                                                           and    clo2.ptj_id = v_ptj_id
                                                                          )
                                                                         )
                                                              end
                                                              ,case when clo.batchnummer is not null then xmlelement("identificationParameter",xmlelement("key",'batchNumber'),xmlelement("data",clo.batchnummer)) else null end
                                                              ,case when clo.consumentenverpakking is not null then xmlelement("identificationParameter",xmlelement("key",'finalConsumer'),xmlelement("data",clo.consumentenverpakking)) else null end
                                                               ))
                                     from   vgc_v_vgc0505nt_clo clo
                                     where  clo.ptj_id = ptj.id
                                    )
                                   )
      ,                xmlelement("veterinaryDocuments"
      ,                  xmlelement("issueDate", xmlattributes(decode(dct.datum_afgifte, NULL,'true','false') "xsi:nil"), get_ws_date(NULL,dct.datum_afgifte,  'yymmdd'))
      ,                  xmlelement("type", xmlattributes(decode('636', NULL,'true','false') "xsi:nil"), '636')
      ,                  xmlelement("countrycode", xmlattributes(decode(lon.lnd_code, NULL,'true','false') "xsi:nil"), lon.lnd_code)
      ,                  xmlelement("number", xmlattributes(decode(dct.nummer, NULL,'true','false') "xsi:nil"), dct.nummer)
                          -- Indien een of meerdere erkenningsnummers zijn opgegeven
      ,                  CASE WHEN eng.erkenningsnummer IS NOT NULL
                              AND upper(eng.erkenningsnummer) NOT IN ('NVT','ONBEKEND')
                         THEN
                           (SELECT xmlagg(
                                     xmlelement("originEstablishments"
      ,                ( SELECT xmlagg(xmlelement("activity"
,                                  vgc_xml.element('referenceDataCode', get_tnt_activity_code(cli.gn_code, 'OE', 'P', TRIM(toe.activity_code)))

                                       )
                                )
                         FROM   vgc_v_colli cli
                         WHERE  cli.ptj_id = v_ptj_id
                         AND    cli.clo_id IS NULL)
--                       )
      ,                                xmlelement("business"
      ,                                  vgc_xml.element('approvalNumber', toe.approvalnumber)
      ,                                  vgc_xml.element('countryCode', toe.lnd_code)
                                      )
                                     )
                                   )
                            FROM vgc_tt_oe toe)
                         END CASE
                         )
                         --      ,                xmlelement("veterinaryDocuments"
--      ,                  xmlelement("issueDate", xmlattributes(decode(dct.datum_afgifte, NULL,'true','false') "xsi:nil"),  get_ws_date(NULL, dct.datum_afgifte, 'yymmddHH24MI'))
--      ,                    xmlelement("type", xmlattributes(decode('636', NULL,'true','false') "xsi:nil"), '636')
--      ,                    xmlelement("countrycode", xmlattributes(decode(lon.lnd_code, NULL,'true','false') "xsi:nil"), lon.lnd_code)
--      ,                    xmlelement("number", xmlattributes(decode(dct.nummer, NULL,'true','false') "xsi:nil"), dct.nummer)
--                       )
                     )
                   ELSE
                     xmlelement("CHEDNonAnimalProductsConsignment"
      ,                CASE WHEN ptj.traces_certificaat_id IS NOT NULL
                       THEN
                         xmlelement("certificateIdentification"
      ,                    xmlelement("referenceNumber" , v_certificaat_ref)
      ,                    xmlelement("type" , 'CHEDD')
                         )
                       ELSE
                         NULL
                       END
      ,                  ( select xmlagg(col)
                           from ( select (xmlelement("commodity"
                                                   ,xmlelement("commodityCode",clo.gn_code)
                                              --     ,xmlelement("commodityCodeComplTracesId",clo.traces_complement_id)
                                              --     ,( select xmlagg(xmlelement("commodityCodeSpeciesTracesId",clo2.traces_species_id))
                                              --        from   vgc_v_vgc0505u_clo clo2
                                              --        where  clo2.ptj_id               = v_ptj_id
                                              --        and    clo2.gn_code              = clo.gn_code
                                              --        and    clo2.traces_complement_id = clo.traces_complement_id
                                              --        and    clo2.traces_species_id    is not null
                                              --      )
                                                   ,xmlelement("subtotalNetWeight",LTRIM(TO_CHAR(sum(clo.sum_gewicht_netto),'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))
                                                   )) col
                                  from   vgc_v_vgc0505nt_clo clo
                                  where  clo.ptj_id = v_ptj_id
                                  group  by clo.gn_code--,clo.traces_complement_id
                         ))
      ,                xmlelement("signatory"
      ,                  xmlelement("dateOfDeclaration" , xmlattributes(decode(ptj.datum_ondertekening, NULL,'true','false') "xsi:nil"), get_ws_date(NULL, ptj.creation_date, 'yymmdd'))
      ,                  xmlelement("signatory"
      ,                    xmlelement("userDetail"
      ,                      xmlelement("lastName", xmlattributes(decode(ptj.naam_ondertekenaar, NULL,'true','false') "xsi:nil"), ptj.naam_ondertekenaar)
                           )
                         )
                       )
      ,                xmlelement("competentAuthority"
      ,                  xmlelement("code", xmlattributes(decode(bca.animo_code, NULL,'true','false') "xsi:nil"),bca.animo_code)
                       )
      ,                xmlelement("animalsCertificatedAs"
      ,                  xmlelement("referenceDataCode", xmlattributes(decode(get_tnt_destination(gbl.code,'LNV'), NULL,'true','false') "xsi:nil"),get_tnt_destination(gbl.code,'LNV'))
                       )
      ,                xmlelement("conformToEuRequirements", xmlattributes(decode(ptj.eu_waardig_ind, NULL,'true','false') "xsi:nil"), CASE WHEN ptj.eu_waardig_ind = 'J'THEN 'true' WHEN ptj.eu_waardig_ind IS NULL THEN NULL WHEN PTJ.eu_waardig_ind= 'N' THEN 'false' END )
      ,                xmlelement("consignor", get_relatie_element('DP', ptj.dp_naam, ptj.dp_land, ptj.dp_plaats, ptj.dp_postcode, ptj.dp_straat_postbus, ptj.dp_huisnummer, ptj.dp_huisnummertoevoeging, get_tnt_activity_code(v_gn_code, 'DP', 'P'),ptj.dp_id_type,nvl(ptj.dp_id,ptj.dp_traces_id)))--
      ,                xmlelement("countryFromWhereConsignedCode",  xmlattributes(decode(lvg.lnd_code, NULL,'true','false') "xsi:nil"), lvg.lnd_code)
      ,                xmlelement("countryOfOriginCode",  xmlattributes(decode(lon.lnd_code, NULL,'true','false') "xsi:nil"),lon.lnd_code)
      ,                xmlelement("deliveryAddress", get_relatie_element('AF', ptj.af_naam, ptj.af_land, ptj.af_plaats, ptj.af_postcode, ptj.af_straat_postbus, ptj.af_huisnummer, ptj.af_huisnummertoevoeging, CASE WHEN vbg.code = 'OPS' AND ptj.opslag = 'VZT' THEN 'warehouse' WHEN (vbg.code = 'DVR' and nvl(bce.us_army_ind,'N') = 'N') THEN NULL ELSE get_tnt_activity_code(v_gn_code, 'AF', 'P') END,ptj.af_id_type,nvl(ptj.af_id,ptj.af_traces_id)))--
      ,                CASE WHEN nvl(bsg.datumtijd, ptj.datum_aankomst) < ptj.datum_aankomst
                       THEN
                         xmlelement("estimatedArrivalAtBIP", xmlattributes(decode(nvl(bsg.datumtijd, ptj.datum_aankomst), NULL,'true','false') "xsi:nil"),get_ws_date(NULL, nvl(bsg.datumtijd, ptj.datum_aankomst), 'yymmddHH24MI'))
                       ELSE
                         xmlelement("estimatedArrivalAtBIP",  xmlattributes(decode(ptj.datum_aankomst, NULL,'true','false') "xsi:nil"),get_ws_date(NULL, ptj.datum_aankomst, 'yymmddHH24MI'))
                       END
      ,                xmlelement("importer", get_relatie_element('IM',  ptj.im_naam, ptj.im_land, ptj.im_plaats, ptj.im_postcode, ptj.im_straat_postbus, ptj.im_huisnummer, ptj.im_huisnummertoevoeging, CASE WHEN (vbg.code = 'DVR' and nvl(bce.us_army_ind,'N') = 'N') THEN NULL ELSE get_tnt_activity_code(v_gn_code, 'IM', 'P') END,ptj.im_id_type,nvl(ptj.im_id,ptj.im_traces_id)))--
      ,                xmlelement("localReferenceNumber", ptj.ggs_nummer)
      ,                CASE WHEN ptj.versienr_mig_in > 5
                       THEN
                         ( SELECT xmlagg(xmlelement("meansOfTransport"
      ,                             xmlelement("document", xmlattributes(decode(ptj.vrachtbriefnummer, NULL,'true','false') "xsi:nil"),substr(ptj.vrachtbriefnummer,1,32))
      ,                             xmlelement("identification", xmlattributes(decode(identificatie, NULL,'true','false') "xsi:nil"), identificatie)
      ,                             xmlelement("type", xmlattributes(decode(vervoer, NULL,'true','false') "xsi:nil"), CASE WHEN bca.luchthaven_ind = 'J' THEN 'PLANE' ELSE vervoer END)                               ))
                         FROM( SELECT DECODE(lvg.lnd_code , 'GB', 'ROAD', cfe.rv_abbreviation) vervoer
                               ,      tpt.identificatie
                               FROM   vgc_v_transporten tpt
                               ,      cg_ref_codes cfe
                               WHERE  tpt.ptj_id = v_ptj_id
                               AND    cfe.rv_domain = 'SOORT VERVOER'
                               AND    cfe.rv_low_value = tpt.soort_vervoer
                               AND    tpt.voor_grens_ind = 'J')
                         )
                       ELSE
                         xmlelement("meansOfTransport"
      ,                    xmlelement("document", xmlattributes(decode(ptj.vrachtbriefnummer, NULL,'true','false') "xsi:nil"),substr(ptj.vrachtbriefnummer,1,32))
      ,                    xmlelement("identification", xmlattributes(decode(ptj.vaartuig_vluchtnummer, NULL,'true','false') "xsi:nil"), ptj.vaartuig_vluchtnummer)
      ,                    xmlelement("type", CASE WHEN lvg.lnd_code = 'GB' THEN 'ROAD' ELSE  CASE WHEN bca.luchthaven_ind = 'J' THEN 'PLANE' ELSE 'SHIP' END END)
                          )
                       END
      ,                CASE WHEN vbg.code IN ('OPS', 'DVR') AND ptj.versienr_mig_in > 5
                       THEN
                         ( SELECT xmlagg(xmlelement("meansOfTransportAfterBIP"
      ,                             xmlelement("document", xmlattributes(decode(ptj.ggs_nummer, NULL,'true','false') "xsi:nil"),ptj.ggs_nummer)
      ,                             xmlelement("identification", xmlattributes(decode(identificatie, NULL,'true','false') "xsi:nil"), identificatie)
      ,                             xmlelement("type", xmlattributes(decode(vervoer, NULL,'true','false') "xsi:nil"), vervoer)                               ))
                         FROM( SELECT cfe.rv_abbreviation vervoer
                               ,      tpt.identificatie
                               FROM   vgc_v_transporten tpt
                               ,      cg_ref_codes cfe
                               WHERE  tpt.ptj_id = v_ptj_id
                               AND    cfe.rv_domain = 'SOORT VERVOER'
                               AND    cfe.rv_low_value = tpt.soort_vervoer
                               AND    tpt.voor_grens_ind = 'N')
                         )
                       WHEN vbg.code IN ('OPS', 'DVR') AND ptj.versienr_mig_in < 6
                       THEN
                         xmlelement("meansOfTransportAfterBIP"
      ,                    xmlelement("document", ptj.ggs_nummer)
      ,                    xmlelement("identification",'not_registered_in_vgc')
      ,                    xmlelement("type", 'OTHER')
                         )
                       ELSE
                         NULL
                       END
      ,                xmlelement("numberPackages",  xmlattributes(decode(v_collo_aantal, NULL,'true','false') "xsi:nil"),  v_collo_aantal)
      ,                xmlelement("productGrossWeight", xmlattributes(decode(v_bruto_gewicht, NULL,'true','false') "xsi:nil"), LTRIM(TO_CHAR(v_bruto_gewicht,'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))
      ,                xmlelement("productNetWeight",  xmlattributes(decode(v_netto_gewicht, NULL,'true','false') "xsi:nil"),  LTRIM(TO_CHAR(v_netto_gewicht,'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))
      ,                CASE WHEN get_tnt_activity_code(v_gn_code, 'AF', 'V') IN ('bov_semen','other')
                       THEN
                         NULL
                       ELSE
                         xmlelement("productTemperature",  xmlattributes(decode(get_tnt_product_temperature(cse.code), NULL,'true','false') "xsi:nil"),get_tnt_product_temperature(cse.code))
                       END
      ,                CASE WHEN vbg.code = 'TRT'
                       THEN
                           xmlelement("purpose"
      ,                       xmlelement("forTransferTo"
      ,                         xmlelement("TransferToCountryCode",xmlattributes(decode(bcs_lnd.code, NULL,'true','false') "xsi:nil"), bcs_lnd.code)
      ,                         xmlelement("TransferToID",xmlattributes(decode(bcs.animo_code, NULL,'true','false') "xsi:nil"), bcs.animo_code)
                              )
                           )
                       ELSE
                         xmlelement("purpose", xmlattributes('true' "xsi:nil"))
                       END CASE
      ,                xmlelement("responsibleForConsignment", get_relatie_element('AL', rle.naam, rle_al_lnd.code, rle.plaats, rle.postcode, rle.straat_postbus, rle.huisnummer, rle.huisnummertoevoeging, rle.traces_activity_code, null,rle.traces_id)) /*#12*/
      ,                ( SELECT xmlagg(xmlelement("sealContainer"
                         ,               xmlelement("containerNumber",xmlattributes(decode(nummer, NULL,'true','false') "xsi:nil"),  nummer)
                         ,               xmlelement("sealNumber", xmlattributes(decode(zegelnummer, NULL,'true','false') "xsi:nil"), substr(zegelnummer,1,32) /*#11*/)
                                       )
                                )
                         FROM( SELECT DISTINCT replace(ctn.nummer,'-','') nummer
                               ,      ctn.zegelnummer
                               FROM   vgc_v_containers ctn
                               ,      vgc_v_colli cli
                               WHERE  ctn.clo_id = cli.id
                               AND    cli.ptj_id = v_ptj_id)
                       )
      ,                  xmlelement("typeOfPackages"
      ,                    xmlelement("referenceDataCode", get_tnt_type_of_packages(v_hoofdverpakkingsvorm))
                                   )
      ,                  xmlelement("identificationOfAnimals"
                                   ,(select xmlagg(xmlelement("identificationParameterSet"
                                                             ,case when clo.gn_code is not null then xmlelement("identificationParameter",xmlelement("key",'commodityCode'),xmlelement("data",clo.gn_code)) else null end
                                       --                      ,case when clo.traces_complement_id is not null then xmlelement("identificationParameter",xmlelement("key",'complement'),xmlelement("data",clo.traces_complement_id)) else null end
                                                             ,case when clo.sum_gewicht_netto is not null then xmlelement("identificationParameter",xmlelement("key",'netweight'),xmlelement("data",LTRIM(TO_CHAR(clo.sum_gewicht_netto,'999999999999999D999','NLS_NUMERIC_CHARACTERS = ''.,''')))) else null end
                                      --                       ,case when clo.traces_species_id is not null then xmlelement("identificationParameter",xmlelement("key",'species'),xmlelement("data",clo.traces_species_id)) else null end
                                                             ,case when clo.sum_aantal is not null then xmlelement("identificationParameter",xmlelement("key",'number_package'),xmlelement("data",clo.sum_aantal)) else null end
                                      --                       ,case when clo.product_type is not null then xmlelement("identificationParameter",xmlelement("key",'producttype'),xmlelement("data",clo.product_type)) else null end
                                                             ,case when clo.verpakkingsvorm is not null then xmlelement("identificationParameter",xmlelement("key",'type_package'),xmlelement("data",get_tnt_type_of_packages(clo.verpakkingsvorm))) else null end
                                                               ))
                                     from   vgc_v_vgc0505nt_clo clo
                                     where  clo.ptj_id = ptj.id
                                    )
                                   )
      ,                CASE WHEN trunc(dct.datum_afgifte) > trunc(ptj.datum_aankomst)
                       THEN
                         NULL
                       ELSE
                         xmlelement("veterinaryDocuments"
      ,                    xmlelement("issueDate", xmlattributes(decode(dct.datum_afgifte, NULL,'true','false') "xsi:nil"),  get_ws_date(NULL, dct.datum_afgifte, 'yymmddHH24MI'))
      ,                      xmlelement("type", xmlattributes(decode('636', NULL,'true','false') "xsi:nil"), '636')
      ,                      xmlelement("countrycode", xmlattributes(decode(lon.lnd_code, NULL,'true','false') "xsi:nil"), lon.lnd_code)
      ,                      xmlelement("number", xmlattributes(decode(dct.nummer, NULL,'true','false') "xsi:nil"), dct.nummer)
                         )
                       END
                     )
                   END
      ,            xmlelement("operation", CASE WHEN ptj.traces_certificaat_id IS NOT NULL THEN 'REPLACE' ELSE 'CREATE' END)
                )
               )
             )
             ).getClobval()
        FROM vgc_partijen ptj
            ,vgc_v_veterin_documenten dct
            ,vgc_v_gebruiksdoelen gbl
            ,vgc_v_keurpunten bca
            ,vgc_v_keurpunten bce
            ,vgc_v_keurpunten bcs
            ,vgc_v_landrol_bestemming lbg
            ,vgc_v_landrol_verzending lvg
            ,vgc_v_landrol_oorsprong  lon
            ,vgc_v_veterin_bestemmingen vbg
            ,vgc_v_conserveringsmethoden cse
            ,vgc_relaties rle
            ,vgc_v_landen rle_al_lnd
            ,vgc_v_landen bcs_lnd
            ,vgc_v_beslissingen bsg
            ,vgc_v_erkenningen eng
        WHERE ptj.ggs_nummer = i_ggs_nummer
        AND   dct.ptj_id  = ptj.id                    -- veterinaire document
        AND   dct.id = v_primair_doc_id               -- veterinaire document
        AND   bca.id (+) = ptj.kpt_id_aangeb_bip      -- bip_code_aanbod
        AND   bcs.id (+) = ptj.kpt_id_aangeb_sip      -- sip_code_aanbod
        AND   bcs.lnd_id  = bcs_lnd.id (+)            -- sip_code_aanbod
        AND   bce.id (+) = ptj.kpt_id_doorv_overl_bip -- bip_code_exit
        AND   gbl.id (+) = CASE WHEN ptj.ptj_type = 'LPJ' THEN ptj.gbl_id_levend
                                WHEN ptj.ptj_type = 'LNV' THEN ptj.gbl_id_levensmiddel ELSE ptj.gbl_id_niet_levend END -- cma, 4/3/20
        AND   vbg.id (+) = ptj.vbg_id -- veterinaire bestemming
        AND   cse.id (+) = ptj.cse_id -- conserveringmethode
        AND   ptj.id  = eng.ptj_id (+) -- erkenningen
        AND   lbg.ptj_id (+) = ptj.id -- land van bestemming
        AND   lvg.ptj_id (+) = ptj.id -- land van verzending
        AND   lon.ptj_id (+) = ptj.id -- land van oorsprong
        AND   rle.id    = ptj.rle_id  -- al land
        AND   rle.lnd_id = rle_al_lnd.id -- al land
        AND   bsg.ptj_id (+)  = ptj.id -- beslissing
        AND   bsg.definitief_ind  (+) = 'J' -- beslissing
    ;

  --

  BEGIN
    vgc_blg.write_log('start maak bericht' , v_objectnaam, 'J', 5);
    OPEN c_xml;
    FETCH c_xml INTO  r_rqt.webservice_bericht; --v_bericht;
    CLOSE c_xml;
    vgc_blg.write_log('escape_xml maak bericht' , v_objectnaam, 'J', 5);
    escape_xml (r_rqt.webservice_bericht);--v_bericht);
    vgc_blg.write_log('einde maak bericht' , v_objectnaam, 'J', 5);
  EXCEPTION
    WHEN OTHERS
    THEN
      IF c_xml%ISOPEN
      THEN
        CLOSE c_xml;
      END IF;

      RAISE;

  END maak_bericht;

--

BEGIN

  trace(v_objectnaam);
  vgc_blg.write_log('start' , v_objectnaam, 'N', 1);
  --
  IF p_request_id IS NOT NULL
  THEN
    OPEN c_rqt;
    FETCH c_rqt INTO r_rqt;
    CLOSE c_rqt;
    --
   -- check_bestaande_rqt (r_rqt);
  ELSE
    r_rqt.request_id := NULL;
  END IF;
  --
  OPEN c_ptj;
  FETCH c_ptj INTO r_ptj;
  CLOSE c_ptj;
  --
  IF nvl(r_ptj.traces_certificaat_id,'*') <> '*'
  THEN
    v_actiecode := '1';
  ELSE
    v_actiecode := '1';
  END IF;
  --
  r_rqt.ggs_nummer             := p_ggs_nummer;
  v_ptj_id                     := r_ptj.id;
  --
  open c_prim_doc(v_ptj_id);
  fetch c_prim_doc into v_primair_doc_id, v_primair_doc_nummer;
  close c_prim_doc;
  --
  v_erkenningsnummer := TRIM(v_erkenningsnummer);
  OPEN  c_toe4;
  FETCH c_toe4 INTO v_vier_pos;
  CLOSE c_toe4;
  OPEN  c_toe3;
  FETCH c_toe3 INTO v_drie_pos;
  CLOSE c_toe3;
  --
  IF v_erkenningsnummer IS NOT NULL
  AND upper(v_erkenningsnummer) NOT IN ('NVT','ONBEKEND')
  THEN
    --> Nieuwe opzet erkenningen
    FOR r_erk IN ( SELECT e.*,l.code
                   FROM   vgc_erkenningen e
                   ,      vgc_v_landen l
                   WHERE  e.ptj_id = v_ptj_id
                   AND    l.id  (+)= NVL(e.lnd_id,-1) )
    LOOP
        INSERT INTO vgc_tt_oe
         ( activity_code
         , approvalnumber
         , lnd_code)
        VALUES
         ( r_erk.activiteit
         , r_erk.erkenningsnummer
         , r_erk.code);

    END LOOP;

  END IF;
  -- ophalen product totalen informatie
  OPEN c_prod_detail;
  FETCH c_prod_detail INTO v_hoofdverpakkingsvorm, v_collo_aantal, v_netto_gewicht, v_bruto_gewicht, v_aantal_dieren, v_gn_code, v_complement_id, v_species_id;
  CLOSE c_prod_detail;

  --
  -- opstellen bericht
  -- alleen voor niet-ontheffingen.
  -- een ontheffing heeft een rapport met in de naam NVWA
  --
  if instr(upper(v_primair_doc_nummer),'NVWA') = 0
  then
    maak_bericht(p_ggs_nummer);
  vgc_blg.write_log('start8' , v_objectnaam, 'N', 1);

    -- aanroepen webservice
    vgc_ws_cms.vgc_cms_out
      (p_aangevernummer => r_ptj.aangevernummer
      ,p_aangiftejaar => r_ptj.aangiftejaar
      ,p_aangifte_volgnummer => r_ptj.aangiftevolgnummer
      ,p_ggs_nummer => p_ggs_nummer
      ,p_classificatie => r_ptj.cim_class
      ,p_pdf => v_pdf_jn
      ,p_actiecode => v_actiecode
      ,p_chednummer => r_ptj.traces_certificaat_id
      ,p_redencode => null
      ,p_redenafkeuring => null
      ,p_ws_naam => 'VGC0505NT'
      ,p_xml => r_rqt.webservice_bericht
      ,p_request_id => v_request_id
      ,p_resultaat => v_resultaat
      );
    --
    -- verwerking webservice antwoord
    --
  vgc_blg.write_log('start9' , v_objectnaam, 'N', 1);
    verwerk_traces_antwoord
      ( p_ws_naam        => v_ws_naam
      , p_request_id     => v_request_id
      , p_ptj_id         => v_ptj_id
      , p_pdf_jn         => v_pdf_jn
      , p_resultaat      => v_resultaat
      , p_error_handling => p_error_handling);
     --
    p_request_id := v_request_id;
  end if;

  vgc_blg.write_log('eind' , v_objectnaam, 'N', 1);
  --
EXCEPTION
  WHEN e_ws_error THEN
    IF p_error_handling = 'N'
    THEN
      p_request_id := r_rqt.request_id;
    ELSE
      vgc_blg.write_log('Exception: Webservice geeft http-code: ' || r_rqt.webservice_returncode, v_objectnaam, 'N', 1);
      raise_application_error(-20000, 'VGC-00502 #1' || r_rqt.webservice_logische_naam ||': Webservice geeft http-code: ' || r_rqt.webservice_returncode);
    END IF;

  WHEN e_specific_operation_error
  THEN
    IF p_error_handling = 'N'
    THEN
      p_request_id := r_rqt.request_id;
    ELSE
      vgc_blg.write_log('Exception: Aanroep webservice mislukt. Specifieke operatie fout ontvangen van Traces webservice: ' || nvl(r_rqt.operation_result,'specificOperationResult is leeg'), v_objectnaam, 'N', 1);
      raise_application_error(-20000, 'VGC-00502 #1' || r_rqt.webservice_logische_naam ||': ' || r_rqt.operation_result );

    END IF;

  WHEN e_general_operation_error
  THEN
    IF p_error_handling = 'N'
    THEN
      p_request_id := r_rqt.request_id;
    ELSE
      vgc_blg.write_log('Exception: Aanroep webservice mislukt. Generieke operatie fout ontvangen van Traces webservice: ' || r_rqt.operation_result, v_objectnaam, 'N', 1);
      raise_application_error(-20000, 'VGC-00502 #1' || r_rqt.webservice_logische_naam ||': ' || r_rqt.operation_result );

    END IF;

  WHEN OTHERS
  THEN
    vgc_blg.write_log('Exception: ' || SQLERRM, v_objectnaam, 'N', 5);
    qms$errors.unhandled_exception(v_objectnaam);
    RAISE;

END VGC0505NT;
/* Indienen Lab Test VGC (submitLaboratoryTests) */

PROCEDURE VGC0506NT
 (P_GGS_NUMMER IN VGC_PARTIJEN.GGS_NUMMER%TYPE
 ,P_REQUEST_ID IN OUT VGC_REQUESTS.REQUEST_ID%TYPE
 ,P_ERROR_HANDLING IN VARCHAR2 := 'J'
 )
 IS
 PRAGMA AUTONOMOUS_TRANSACTION;
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.VGC0506NT#01';
v_ptj_id                     vgc_partijen.id%type;
/*********************************************************************
Wijzigingshistorie
doel:
Indienen laboratorium testen VGC-CLIENT bij TRACES-TNT (SUBMIT LABORATORY TESTS)

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
 1      11-01-2022 GLR     creatie
 *********************************************************************/

--
  CURSOR c_ptj
  IS
    SELECT ptj.id
    ,      rle.aangevernummer
    ,      ptj.aangiftejaar
    ,      ptj.aangiftevolgnummer
    ,      ptj.ptj_type
    ,      decode(ptj.ptj_type,'NPJ','P','LPJ','A','D') cim_class
    ,      ptj.traces_certificaat_id
    FROM   vgc_v_partijen ptj
    ,      vgc_v_relaties rle
    ,      vgc_v_lab_monsters lmr
    WHERE  ptj.ggs_nummer = p_ggs_nummer
    AND    ptj.rle_id = rle.id
    AND    lmr.CTE_PTJ_ID = ptj.id (+)
  ;
--
  r_ptj c_ptj%ROWTYPE;
--
  k_operation                  CONSTANT  VARCHAR2(30 CHAR)                           := 'submitLaboratoryTests';
  v_antwoord                   xmltype;
  v_operators                  xmltype;
  v_ws_naam                    VARCHAR2(100 CHAR) := 'submitLaboratoryTests';
  r_rqt                        vgc_requests%ROWTYPE;
  e_ws_error                   EXCEPTION;
  e_specific_operation_error   EXCEPTION;
  e_general_operation_error    EXCEPTION;
  v_request_id                 NUMBER;
  v_resultaat                  BOOLEAN;
  v_actiecode                  VARCHAR2(1 CHAR);
  v_pdf_jn                     VARCHAR2(1 CHAR) := 'N';
  v_result                     VARCHAR2(200 CHAR);
  l_timestamp_char             VARCHAR2(100 CHAR);
  l_trx_timestamp_char         VARCHAR2(100 CHAR);
  v_username                   VARCHAR2(100 CHAR);
  v_password                   VARCHAR2(100 CHAR);
  l_CreateTimestampString      VARCHAR2(100 CHAR);
  l_ExpireTimestampString      VARCHAR2(100 CHAR);
  v_timestamp                  TIMESTAMP;
  l_nonce_raw                  RAW(100);
  l_nonce_b64                  VARCHAR2(24 CHAR);
  l_password_digest_b64        VARCHAR2(100 CHAR);
  l_offset                     INTEGER := 0;
  v_retrieval_type             VARCHAR2(3 CHAR);
  v_soort                      VARCHAR2(1 CHAR);
  v_tnt_auth                   VARCHAR2(50 CHAR);
--
--  Stelt bericht op voor aanroep
--
  PROCEDURE maak_bericht(i_ggs_nummer IN vgc_partijen.ggs_nummer%TYPE)
  IS
    CURSOR c_xml
    IS
      SELECT c_encoding ||
             xmlelement("soapenv:Envelope"
      ,        xmlattributes ( 'http://schemas.xmlsoap.org/soap/envelope/' AS "xmlns:soapenv"
                             , 'http://ec.europa.eu/sanco/tracesnt/base/v4' AS "xmlns:v4"
                             , 'http://ec.europa.eu/tracesnt/body/v3'AS "xmlns:v3"
                             , 'http://ec.europa.eu/tracesnt/certificate/ched/submission/v01' AS "xmlns:v01"
                             , 'http://ec.europa.eu/tracesnt/certificate/laboratorytest/v1' AS "xmlns:v1"
                             , 'urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:21' AS "xmlns:urn"
                             , 'http://ec.europa.eu/tracesnt/referencedata/laboratorytest/v1' AS "xmlns:v11"
                             , 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'  AS "xmlns:oas")
      ,        xmlelement("soapenv:Header"
      ,          xmlattributes( 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd' AS "xmlns:wsse"
                              , 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'  AS "xmlns:wsu")
      ,          xmlelement("wsse:Security"
      ,            xmlelement("wsse:UsernameToken"
      ,            xmlattributes( 'UsernameToken-A5B8D7123A55CB6A75153751937547586' AS "wsu:Id" )
      ,              xmlelement("wsse:Username", v_username)
      ,              xmlelement("wsse:Password"
      ,                xmlattributes( 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest' AS "Type" )
      ,                l_password_digest_b64)
      ,              xmlelement("wsse:Nonce", l_nonce_b64)
      ,              xmlelement("wsu:Created", l_CreateTimestampString)
                   )
      ,            xmlelement("wsu:Timestamp"
      ,              xmlelement("wsu:Created", l_CreateTimestampString)
      ,              xmlelement("wsu:Expires", l_ExpireTimestampString)
                   )
                 )
      ,          xmlelement("v4:LanguageCode",'nl')
      ,          xmlelement("v3:BodyIdentity"
      ,            xmlelement("AuthorityActivityAccessIdentifier",v_tnt_auth)
                            )
      ,          xmlelement("v4:WebServiceClientId",'vgc-client')
               )
      ,        xmlelement("soapenv:Body"
      ,          xmlelement("v01:SubmitChedLaboratoryTestRequest"
      ,            xmlelement("v01:ChedReferenceNumber", ptj.traces_certificaat_id)
      ,              xmlelement("v01:SPSConsignmentItemLaboratoryTest"
      ,                xmlelement("v1:NatureIdentificationSPSCargo"
      ,                  xmlelement("urn:TypeCode", xmlattributes('General cargo (Commodities)' AS "name"), '12')
                                 )
      ,                (SELECT xmlagg(xmlelement("v1:ProductSPSLaboratoryTest"
      ,                                (SELECT xmlagg(xmlelement("v1:ProductSPSClassification"
      ,                                   xmlelement("urn:SystemID",'CN')
      ,                                   xmlelement("urn:SystemName",'CN Code (Combined Nomenclature)')
      ,                                              xmlelement("urn:ClassCode",gtt.gn_code)
      ,                                            xmlelement("urn:ClassName",gtt.gn_code_meaning)
                                                    ))
                                          FROM vgc_v_tnt_gn_codes_tree gtt
                                          WHERE clo.gn_code LIKE gtt.gn_code||'%'
                                          AND gtt.type = 'E'
                                          AND gtt.soort = v_soort
                                          AND gtt.gn_code = 
                                          ( SELECT max(gtt.gn_code)
                                            FROM vgc_v_tnt_gn_codes_tree gtt
                                            WHERE clo.gn_code LIKE gtt.gn_code||'%'
                                            AND gtt.type = 'E'
                                            AND gtt.soort = v_soort
                                          )
                                        )
      ,                                 xmlelement("v1:SPSLaboratoryTest"
      ,                                   xmlelement("v1:TestDescriptor"
      ,                                     xmlelement("v11:ID", xmlattributes('laboratory_test_internal_id' AS "schemeID") ,ozk.traces_id)
      ,                                     xmlelement("v11:Description")
--     ,                                     xmlelement("v11:CategoryCode")
                                                    )
      ,                                   xmlelement("v1:TestMotivationCode",lmn.traces_omschrijving)
      ,                                   CASE WHEN clo.species IS NOT NULL
                                          THEN
                                            xmlelement("v1:ScientificName",clo.species)
                                          END
      ,                                   xmlelement("v1:InspectorConclusionCode",
                                          CASE WHEN mok.lab_oordeel = 'NUD'
                                          THEN
                                            'SATISFACTORY'
                                          ELSE
                                            get_tnt_labtest_result(mok.mdw_oordeel,'M')
                                          END
                                           )
      ,                                   xmlelement("v1:Analysys"
      ,                                     xmlelement("v1:AnalysisTypeCode", 'INITIAL')
--      ,                                     xmlelement("v1:SamplingDateTime", get_ws_date(NULL, lmr.DATUMTIJD_MONSTERNAME, 'yymmdd'))
      ,                                     xmlelement("v1:SamplingDateTime", get_ws_date(NULL, lmr.DATUMTIJD_MONSTERNAME-(10/1440), 'yymmddHH24MISS'))
      ,                                     xmlelement("v1:SampleBatchNumber", lmr.DossierNUMMER)
      ,                                     xmlelement("v1:NumberOfSamples", to_char(lmr.aantal))
      ,                                     xmlelement("v1:SampleTypeCode", lme.code)
      ,                                     xmlelement("v1:SampleConservationCode", cse.traces_omschrijving)
      ,                                     xmlelement("v1:LaboratorySPSParty"
      ,                                       xmlelement("urn:ID",xmlattributes('laboratory_code' AS "schemeID"), lbm.omschrijving_traces)
      ,                                       xmlelement("urn:Name", lbm.naam)
      ,                                       xmlelement("urn:SpecifiedSPSAddress"
      ,                                         xmlelement("urn:CountryID", 'NL')
                                                       ))
      ,                                     CASE WHEN lmr.ontvangstdatum_lab IS NOT NULL
                                            THEN
                                              xmlelement("v1:LaboratoryReceiptDateTime",get_ws_date(NULL, lmr.ontvangstdatum_lab,'yymmddHH24MISS'))
                                            END
      ,                                     CASE WHEN lmr.datum_uitslag_lab IS NOT NULL
                                            THEN
                                               xmlelement("v1:LaboratoryReportDateTime",get_ws_date(NULL, lmr.datum_uitslag_lab,'yymmddHH24MISS'))
                                            END
      ,                                     xmlelement("v1:LaboratoryTestMethod",get_tnt_labtest_methoden(mok.id,'M'))
      ,                                     xmlelement("v1:LaboratoryResults",get_tnt_labtest_methoden(mok.id,'R'))
      ,                                     CASE WHEN mok.lab_oordeel != 'TCN'
                                            THEN
                                              xmlelement("v1:LaboratoryConclusionCode",get_tnt_labtest_result(mok.lab_oordeel,'L'))
                                            END
      ,                                     xmlelement("v1:AnalysisSPSNote"
      ,                                       xmlelement("urn:Content")
                                                    ))
                                           )
                                                     )
                                                  )
                        FROM  vgc_v_colli clo
                        ,     vgc_v_lab_monsters lmr
                        ,     vgc_v_monsteronderzoeken mok
                        ,     vgc_v_lab_monster_redenen lmn
                        ,     vgc_v_laboratoria lbm
                        ,     vgc_v_conserveringsmethoden cse
                        ,     vgc_v_lab_monster_types lme
                      --  ,     vgc_v_tnt_gn_codes_tree gte
                        ,     vgc_v_onderzoeken ozk
                        WHERE lmr.clo_id = clo.id
                      --  AND   gte.gn_code = clo.gn_code
                      --  AND   gte.soort = v_soort
                        AND   lmr.cte_ptj_id = ptj.id
                        AND   lmr.lmr_id IS NULL
                        AND   mok.lmr_id = lmr.id
                        AND   mok.ozk_id = ozk.id
                        AND   lmr.lmn_id = lmn.id
                        AND   lmr.lbm_id = lbm.id
                        AND   lmr.cse_id = cse.id
                        AND   lmr.lme_id = lme.id (+)
                        AND   ozk.traces_id IS NOT NULL
                        )
                                )
                            )
                         )
                       ).getClobval()
      FROM vgc_v_partijen ptj
      WHERE ptj.ggs_nummer = p_ggs_nummer
    ;
  --
  BEGIN
    vgc_blg.write_log('start maak bericht' , v_objectnaam, 'J', 5);
  -- Ophalen credentials
  IF v_retrieval_type = 'NPJ'
  THEN
    v_username := vgc$algemeen.get_appl_register('TNT_USERNAME_CHEDP');
    v_password := vgc$algemeen.get_appl_register('TNT_PASSWORD_CHEDP');
    v_tnt_auth := vgc$algemeen.get_appl_register('TNT_AUTHORITY_P');
    v_soort    := 'P';
  ELSIF v_retrieval_type = 'LPJ'
  THEN
    v_username := vgc$algemeen.get_appl_register('TNT_USERNAME_CHEDA');
    v_password := vgc$algemeen.get_appl_register('TNT_PASSWORD_CHEDA');
    v_tnt_auth := vgc$algemeen.get_appl_register('TNT_AUTHORITY_L');
    v_soort    := 'L';
  ELSIF v_retrieval_type = 'LNV'
  THEN
    v_username := vgc$algemeen.get_appl_register('TNT_USERNAME_CHEDD');
    v_password := vgc$algemeen.get_appl_register('TNT_PASSWORD_CHEDD');
    v_tnt_auth := vgc$algemeen.get_appl_register('TNT_AUTHORITY_D');
    v_soort    := 'V';
  ELSE
    v_username := vgc$algemeen.get_appl_register('TNT_USERNAME_CHEDPP');
    v_password := vgc$algemeen.get_appl_register('TNT_PASSWORD_CHEDPP');
    v_tnt_auth := vgc$algemeen.get_appl_register('TNT_AUTHORITY_PP');
    v_soort    := 'F';
  END IF;
  --
    v_timestamp := SYSTIMESTAMP;
    l_timestamp_char      := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
    l_trx_timestamp_char  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM');
    l_nonce_raw           := utl_i18n.string_to_raw(dbms_random.string('a',16),'utf8');
    l_nonce_b64           := utl_i18n.raw_to_char(utl_encode.base64_encode(l_nonce_raw),'utf8');
    l_password_digest_b64 := utl_i18n.raw_to_char
                           ( utl_encode.base64_encode
                             ( dbms_crypto.hash
                               ( l_nonce_raw||utl_i18n.string_to_raw(l_timestamp_char||v_password,'utf8')
                               , dbms_crypto.hash_sh1
                               )
                             )
                           , 'utf8'
                           );
  --
    l_CreateTimestampString := TO_CHAR(v_timestamp,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
    v_timestamp :=v_timestamp + 3/1440;
    l_ExpireTimestampString := TO_CHAR(v_timestamp,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
  -- Opstellen bericht
    OPEN c_xml;
    FETCH c_xml INTO  r_rqt.webservice_bericht;
    CLOSE c_xml;
    escape_xml(r_rqt.webservice_bericht);
    --
  EXCEPTION
    WHEN OTHERS
    THEN
      IF c_xml%ISOPEN
      THEN
        CLOSE c_xml;
      END IF;
      RAISE;
  END maak_bericht;
--
-- Verwerkt het binnengekomen resultaat
--
  FUNCTION verwerk RETURN BOOLEAN
  IS
    v_einde             boolean := false;
    l_sysdate           DATE := SYSDATE;
    l_user              VARCHAR2(35 CHAR) := USER;
    --
--    v_generalOperationResult      VARCHAR2(200 CHAR);
--    v_specificOperationResult     VARCHAR2(200 CHAR);
    v_xmlns1                      VARCHAR2(2000 CHAR) :=  'xmlns:ns7="http://ec.europa.eu/tracesnt/directory/operator/v1"'||' xmlns:ns0="http://schemas.xmlsoap.org/soap/envelope/"';
--    v_xmlns2                      VARCHAR2(2000 CHAR) :=  'xmlns:ns7="http://ec.europa.eu/tracesnt/directory/operator/v1"';
--   v_xmlns3                      VARCHAR2(2000 CHAR) :=  'xmlns:ns7="http://ec.europa.eu/tracesnt/directory/operator/v1"'||' xmlns:ns4="http://ec.europa.eu/tracesnt/directory/common/v1"'||
--                                                          ' xmlns:ns5="http://ec.europa.eu/tracesnt/directory/geo/city/v1"';
    v_response                    xmltype;
    v_fault                       xmltype;
--    v_operatorsstr                clob;
    v_faultstr                    clob;
    --
  BEGIN
    vgc_blg.write_log('Start: verwerk', v_objectnaam, 'J', 5);
    -- init variabelen voor verwerken
    v_fault              :=  vgc_xml.extractxml(v_antwoord, '//ns0:Fault', v_xmlns1);
    v_faultstr           :=  vgc_xml.extractxml_str(v_antwoord, '//ns0:Fault/detail/ns7:IllegalFindOperatorException/text()', v_xmlns1);
    --
    IF nvl(length(v_faultstr),0) > 0
    THEN
      v_einde := true;
      v_result := to_char(v_faultstr);
    END IF;
    --
    COMMIT;
    --
    if v_einde
    then
      vgc_blg.write_log('Einde: verwerk', v_objectnaam, 'J', 5);
    else
      vgc_blg.write_log('Einde naar volgende: verwerk', v_objectnaam, 'J', 5);
     end if;
    RETURN v_einde;
  EXCEPTION
    WHEN OTHERS
    THEN
      ROLLBACK;
      RETURN TRUE;
  END verwerk;
--
-- voert synchronisatie uit voor het opgegeven retrieval_type
--
  PROCEDURE sync
  IS

  BEGIN
    vgc_blg.write_log('Start: sync', v_objectnaam, 'J', 5);
    -- initialiseren request
    r_rqt.request_id := NULL;
    r_rqt.status := vgc_ws_requests_nt.kp_in_uitvoering;
    r_rqt.resultaat := k_operation;
    -- opstellen bericht
    maak_bericht(l_offset);
    -- aanroepen webservice
    BEGIN
      vgc_ws_requests_nt.maak_http_request (r_rqt);
    EXCEPTION
      WHEN OTHERS
      THEN
      vgc_blg.write_log('Fout bij synchroniseren: ' || SQLERRM, v_objectnaam, 'J', 5);
    END;
    COMMIT;
    v_request_id := r_rqt.request_id;
    -- indien fout bij aanroepen webservice geef foutmelding en stop verwerking
/*    IF r_rqt.webservice_returncode = 500
    THEN
      v_result := 'Fout bij het aanmelden van een labonderzoek in TNT';
    ELSIF r_rqt.webservice_returncode = 200
    THEN
      v_result := 'OK';
    ELSE
      vgc_blg.write_log('Webservice geeft http-code: ' || r_rqt.webservice_returncode, v_objectnaam, 'J', 5);
      v_result := 'Webservice geeft http-code: ' || r_rqt.webservice_returncode;
      raise_application_error(-20000, 'VGC-00502 #1' || v_ws_naam ||': 3Webservice geeft HTTP-code: ' || r_rqt.webservice_returncode);
    END IF;*/
    --
    select xmltype(r_rqt.webservice_antwoord) into v_antwoord
    from vgc_requests rqt
    where rqt.request_id = r_rqt.request_id;
    -- verwerk response
    vgc_blg.write_log('Eind: sync', v_objectnaam, 'J', 5);

  EXCEPTION
    WHEN OTHERS
    THEN
    v_request_id := r_rqt.request_id;
      vgc_blg.write_log('Fout bij synchroniseren: ' || SQLERRM, v_objectnaam, 'J', 5);
  --    RAISE;

  END sync;


BEGIN

  trace(v_objectnaam);
  vgc_blg.write_log('start' , v_objectnaam, 'N', 1);
  --
  OPEN c_ptj;
  FETCH c_ptj INTO r_ptj;
  CLOSE c_ptj;
  --
  r_rqt.traces_certificaat_id  := r_ptj.traces_certificaat_id;
  r_rqt.aangevernummer         := r_ptj.aangevernummer;
  r_rqt.aangifte_volgnummer    := r_ptj.aangiftevolgnummer;
  r_rqt.aangiftejaar           := r_ptj.aangiftejaar;
  r_rqt.ggs_nummer             := p_ggs_nummer;
  v_ptj_id                     := r_ptj.id;
  v_retrieval_type             := r_ptj.ptj_type;
  -- initialiseren request
  r_rqt.request_id               := NULL;
  r_rqt.webservice_url           := vgc$algemeen.get_appl_register ('TNT_CHED_WEBSERVICE');
  r_rqt.bestemd_voor             := NULL;
  r_rqt.webservice_logische_naam := 'VGC0506NT';
  --
  sync;
  --
  verwerk_tnt_antwoord ('VGC0506NT'
  , p_ggs_nummer
  , r_ptj.id
  ,'J');
  COMMIT;

  vgc_blg.write_log('eind' , v_objectnaam, 'N', 1);
  --
EXCEPTION
  WHEN OTHERS
  THEN
    vgc_blg.write_log('Exception: ' || SQLERRM, v_objectnaam, 'N', 5);
    qms$errors.unhandled_exception(v_objectnaam);
    RAISE;

END VGC0506NT;
--
--
/* Synchroniseer GN-codes */

PROCEDURE VGC0511NT
 (P_GN_CODE IN VGC_COLLI.GN_CODE%TYPE
 ,P_TYPE IN VGC_COLLI.CLO_TYPE%TYPE
  )
 IS
v_objectnaam            vgc_batchlog.proces%TYPE                 := g_package_name || '.VGC0511NT#1';
/*********************************************************************
Wijzigingshistorie
doel:
Synchroniseren van GN-Code details

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  1     31-12-2019 GLR     creatie
*********************************************************************/
  CURSOR c_lock
  IS
    SELECT 1
    FROM   vgc_applicatie_registers arr
    WHERE   arr.variabele = 'TNT_USERNAME'
    FOR UPDATE NOWAIT
  ;
--
  k_animals               CONSTANT VARCHAR2(6 CHAR)                        := 'cheda';
  k_animalproducts        CONSTANT VARCHAR2(6 CHAR)                        := 'chedp';
  k_nonanimalproducts     CONSTANT VARCHAR2(6 CHAR)                        := 'chedd';
  k_fytoproducts          CONSTANT VARCHAR2(6 CHAR)                        := 'chedpp';
--
  l_error_count            NUMBER;
  l_timestamp_char        VARCHAR2(100);
  l_trx_timestamp_char    VARCHAR2(100);
  v_username              VARCHAR2(100);
  v_password              VARCHAR2(100);
  l_CreateTimestampString VARCHAR2(100);
  l_ExpireTimestampString VARCHAR2(100);
  v_timestamp             TIMESTAMP;
  l_nonce_raw             RAW(100);
  l_nonce_b64             VARCHAR2(24);
  l_password_digest_b64   VARCHAR2(100);
--
  k_laatste_sync_var CONSTANT  vgc_applicatie_registers.variabele%TYPE := 'VGC0501U_LAATSTE_SYNC';
  v_laatste_sync               vgc_applicatie_registers.waarde%TYPE    := vgc$algemeen.get_appl_register(k_laatste_sync_var);
  v_server_side_date           vgc_applicatie_registers.waarde%TYPE    := NULL;
  v_antwoord                   xmltype;
  v_ws_naam               VARCHAR2(100 CHAR)                                := 'retrieveReferenceData';
  r_rqt                        vgc_requests%ROWTYPE;
  -- cursor voor lock zodat niet twee synchronisaties tegelijk kunnen runnen
  resource_busy   EXCEPTION;
  PRAGMA EXCEPTION_INIT( resource_busy, -54 );
--
-- Stelt bericht op voor aanroep
--
  PROCEDURE maak_bericht( i_retrieval_type IN VARCHAR2
                        , i_gn_code IN VARCHAR2)
  IS
  --
    CURSOR c_xml
    IS
      SELECT c_encoding ||
             xmlelement("soapenv:Envelope"
      ,        xmlattributes ( 'http://schemas.xmlsoap.org/soap/envelope/' AS "xmlns:soapenv"
                             , 'http://ec.europa.eu/sanco/tracesnt/base/v3'  AS "xmlns:v3"
                             , 'http://ec.europa.eu/tracesnt/body/v3' as "xmlns:v31"
                             , 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'  AS "xmlns:oas"
                             , 'http://ec.europa.eu/tracesnt/certificate/ched/submission/v01' as "xmlns:v01"
                             , 'urn:un:unece:uncefact:data:standard:SPSCertificate:17' as "xmlns:rsm"
                             , 'urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:21' AS "xmlns:ram"
                             , 'urn:un:unece:uncefact:data:standard:UnqualifiedDataType:21' AS "xmlns:udt")
     ,        xmlelement("soapenv:Header"
      ,          xmlattributes( 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd' AS "xmlns:wsse"
                              , 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'  AS "xmlns:wsu")
      ,          xmlelement("wsse:Security"
      ,            xmlelement("wsse:UsernameToken"
      ,            xmlattributes( 'UsernameToken-A5B8D7123A55CB6A75153751937547586' AS "wsu:Id" )
      ,              xmlelement("wsse:Username", v_username)
      ,              xmlelement("wsse:Password"
      ,                xmlattributes( 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest' AS "Type" )
      ,                l_password_digest_b64)
      ,              xmlelement("wsse:Nonce", l_nonce_b64)
      ,              xmlelement("wsu:Created", l_CreateTimestampString)
                   )
      ,            xmlelement("wsu:Timestamp"
      ,              xmlelement("wsu:Created", l_CreateTimestampString)
      ,              xmlelement("wsu:Expires", l_ExpireTimestampString)
                   )
                 )
      ,          xmlelement("v3:LanguageCode",'nl')
      ,          xmlelement("v3:WebServiceClientId",'vgc-client')
               )
      ,        xmlelement("soapenv:Body"
      ,          xmlattributes( 'http://schemas.xmlsoap.org/soap/envelope/' AS "xmlns:soapenv")
      ,          xmlelement("v1:GetClassificationTreeNodeDetailRequest"
      ,            xmlattributes( 'http://ec.europa.eu/tracesnt/referencedata/v1' AS "xmlns:v1")

      ,            xmlelement("v1:TreeID", i_retrieval_type)
      ,            xmlelement("v1:CNCode", i_gn_code)
                 )
               )
             ).getClobval()
      FROM dual
    ;
  --
  BEGIN
  -- Ophalen credentials
  IF i_retrieval_type = 'chedp'
  THEN
    v_username := vgc$algemeen.get_appl_register('TNT_USERNAME_GN_CHEDP');
    v_password := vgc$algemeen.get_appl_register('TNT_PASSWORD_GN_CHEDP');
  ELSIF i_retrieval_type = 'cheda'
  THEN
    v_username := vgc$algemeen.get_appl_register('TNT_USERNAME_GN_CHEDA');
    v_password := vgc$algemeen.get_appl_register('TNT_PASSWORD_GN_CHEDA');
  ELSIF i_retrieval_type = 'chedd'
  THEN
    v_username := vgc$algemeen.get_appl_register('TNT_USERNAME_GN_CHEDD');
    v_password := vgc$algemeen.get_appl_register('TNT_PASSWORD_GN_CHEDD');
  ELSE
    v_username := vgc$algemeen.get_appl_register('TNT_USERNAME_GN_CHEDPP');
    v_password := vgc$algemeen.get_appl_register('TNT_PASSWORD_GN_CHEDPP');
  END IF;
  --
    v_timestamp := SYSTIMESTAMP;
--  l_timestamp_char      := TO_CHAR(v_timestamp,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
--  l_trx_timestamp_char  := TO_CHAR(v_timestamp,'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM');
  l_timestamp_char      := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
  l_trx_timestamp_char  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM');
--  l_timestamp_char      := '2020-01-02T13:01:52.903Z';--TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
--  l_trx_timestamp_char  := '2020-01-02T13:04:52+01:00';--TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM');
    l_nonce_raw           := utl_i18n.string_to_raw(dbms_random.string('a',16),'utf8');
    l_nonce_b64           := utl_i18n.raw_to_char(utl_encode.base64_encode(l_nonce_raw),'utf8');
    l_password_digest_b64 := utl_i18n.raw_to_char
                           ( utl_encode.base64_encode
                             ( dbms_crypto.hash
                               ( l_nonce_raw||utl_i18n.string_to_raw(l_timestamp_char||v_password,'utf8')
                               , dbms_crypto.hash_sh1
                               )
                             )
                           , 'utf8'
                           );
  --
    l_CreateTimestampString := TO_CHAR(v_timestamp,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
    v_timestamp :=v_timestamp + 3/1440;
    l_ExpireTimestampString := TO_CHAR(v_timestamp,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
  -- Opstellen bericht
    OPEN c_xml;
    FETCH c_xml INTO  r_rqt.webservice_bericht;
    CLOSE c_xml;
    escape_xml(r_rqt.webservice_bericht);
    --
  EXCEPTION
    WHEN OTHERS
    THEN
      IF c_xml%ISOPEN
      THEN
        CLOSE c_xml;
      END IF;
      RAISE;
  END maak_bericht;
--
-- Verwerkt het binnengekomen resultaat
--
  FUNCTION verwerk (i_retrieval_type IN VARCHAR2
                   ,i_gn_code IN VARCHAR2)
  RETURN BOOLEAN
  IS
    l_sysdate           DATE := SYSDATE;
    l_user              VARCHAR2(35 CHAR) := USER;
    l_tge_id            NUMBER;
    l_tat_id            NUMBER;
    l_tpt_id            NUMBER;
    l_tse_id            NUMBER;
    l_tgl_id            NUMBER;
    l_ttr_id            NUMBER;
    l_tvm_id            NUMBER;
    -- foutafhandeling
    v_generalOperationResult  VARCHAR2(200 CHAR);
    v_specificOperationResult VARCHAR2(200 CHAR);
    -- tijdelijke variabelen voor verwerken XML
    v_xml_tgl           xmltype;
    v_xml_tat           xmltype;
    v_xml_tpt           xmltype;
    v_xml_tse           xmltype;
    v_xml_ttr           xmltype;
    v_xml_tvm           xmltype;
    v_error             VARCHAR2(400 CHAR);
    v_response          xmltype;
    v_commodities       xmltype;
    v_ns                VARCHAR2(400 CHAR) := 'xmlns:ns8="http://ec.europa.eu/tracesnt/referencedata/classificationtree/v1" xmlns:ns7="http://ec.europa.eu/tracesnt/referencedata/certificatemodel/v1" xmlns:ns9="http://ec.europa.eu/tracesnt/referencedata/nodeattribute/v1" xmlns:ns1="http://ec.europa.eu/tracesnt/referencedata/v1"';
    -- Query voor uitlezen commodities uit response
    CURSOR c_rqt(i_xml xmltype, i_ns VARCHAR2)
    IS
      SELECT extract(VALUE(rqt), '/ns1:Node/ns8:CNCode/text()', i_ns).getStringVal() gn_code
      ,      extract(VALUE(rqt), '/ns1:Node/ns8:Description/text()', i_ns).getStringVal() gn_code_meaning
      ,      extract(VALUE(rqt), '/ns1:Node/ns8:Attribute[contains(@id,''AVAILABLE_CHED_DESCRIPTOR_COLUMNS'')]/ns9:DescriptorColumnValue', i_ns) kolommen
      ,      extract(VALUE(rqt), '/ns1:Node/ns8:Attribute[contains(@id,''PRODUCT_TYPE_POSSIBLE_VALUES'')]/ns9:EnumValue', i_ns) product_types
      ,      extract(VALUE(rqt), '/ns1:Node/ns8:Attribute[contains(@id,''PRODUCT_TEMPERATURE_POSSIBLE_VALUES'')]/ns9:EnumValue', i_ns) temperaturen
      ,      extract(VALUE(rqt), '/ns1:Node/ns8:Attribute[contains(@id,''CHED_CERTIFIED_AS_POSSIBLE_VALUES'')]/ns9:EnumValue', i_ns) gebruiksdoelen
      ,      extract(VALUE
        (rqt), '/ns1:Node/ns8:Attribute[contains(@id,''PACKAGE_TYPE_POSSIBLE_VALUES'')]/ns9:EnumValue', i_ns) verpakkingsvormen
      ,      extract(VALUE(rqt), '/ns1:Node/ns8:Attribute[contains(@id,''TAXON_POSSIBLE_VALUES'')]/ns9:TaxonReference', i_ns) species
      FROM TABLE( xmlsequence(i_xml)) rqt
    ;
    --
    CURSOR c_xml_tpt(i_xml xmltype, i_ns VARCHAR2)
    IS
      SELECT extract(VALUE(rqt), '//ns9:EnumValue/text()', i_ns).getStringVal() product_type
      FROM TABLE( xmlsequence(i_xml)) rqt
    ;
    --
    CURSOR c_xml_tse(i_xml xmltype, i_ns VARCHAR2)
    IS
      SELECT extract(VALUE(rqt), '//ns9:TaxonReference/text()', i_ns).getStringVal() species
      ,      extract(VALUE(rqt), '//ns9:TaxonReference/@taxonId', i_ns).getStringVal() taxon_id
      ,      extract(VALUE(rqt), '//ns9:TaxonReference/@eppoCode', i_ns).getStringVal() eppo_code
      FROM TABLE( xmlsequence(i_xml)) rqt
    ;
    --
    CURSOR c_xml_tat(i_xml xmltype, i_ns VARCHAR2)
    IS
      SELECT extract(VALUE(rqt), '//ns9:DescriptorColumnValue/@id', i_ns).getStringVal() attribuut
      ,      extract(VALUE(rqt), '//ns9:Cardinality/text()', i_ns).getStringVal() optie
      FROM TABLE( xmlsequence(i_xml)) rqt
    ;
    --
    CURSOR c_xml_tgl(i_xml xmltype, i_ns VARCHAR2)
    IS
      SELECT extract(VALUE(rqt), '//ns9:EnumValue/text()', i_ns).getStringVal() gebruiksdoel
      FROM TABLE( xmlsequence(i_xml)) rqt
    ;
    --
    CURSOR c_xml_ttr(i_xml xmltype, i_ns VARCHAR2)
    IS
      SELECT extract(VALUE(rqt), '//ns9:EnumValue/text()', i_ns).getStringVal() temperatuur
      FROM TABLE( xmlsequence(i_xml)) rqt
    ;
    --
    CURSOR c_xml_tvm(i_xml xmltype, i_ns VARCHAR2)
    IS
      SELECT extract(VALUE(rqt), '//ns9:EnumValue/text()', i_ns).getStringVal() verpakkingsvorm
      FROM TABLE( xmlsequence(i_xml)) rqt
    ;
    --
    CURSOR c_tge(i_gn_code vgc_tnt_gn_codes.gn_code%TYPE, i_type vgc_tnt_gn_codes.certificaattype%TYPE)
    IS
      SELECT id
      FROM   vgc_tnt_gn_codes
      WHERE  gn_code = i_gn_code
      AND    certificaattype = i_type
    ;
    --
    CURSOR c_tat(i_attribuut vgc_tnt_gn_codes_attributen.naam%TYPE)
    IS
      SELECT id
      FROM   vgc_tnt_gn_codes_attributen
      WHERE  naam = i_attribuut
    ;
    --
    CURSOR c_tpt(i_product_type vgc_tnt_product_types.product_type%TYPE)
    IS
      SELECT id
      FROM   vgc_tnt_product_types
      WHERE  product_type = i_product_type
    ;
    --
    CURSOR c_tse(i_taxon_id vgc_tnt_species.taxon_id%TYPE)
    IS
      SELECT id
      FROM   vgc_tnt_species
      WHERE  taxon_id = i_taxon_id
    ;
    --
    CURSOR c_tgl(i_gebruiksdoel vgc_tnt_gebruiksdoelen.gebruiksdoel%TYPE)
    IS
      SELECT id
      FROM   vgc_tnt_gebruiksdoelen
      WHERE  gebruiksdoel = i_gebruiksdoel
    ;
    --
    CURSOR c_ttr(i_temperatuur vgc_tnt_temperaturen.temperatuur%TYPE)
    IS
      SELECT id
      FROM   vgc_tnt_temperaturen
      WHERE  temperatuur = i_temperatuur
    ;
    --
    CURSOR c_tvm(i_verpakkingsvorm vgc_tnt_verpakkingsvormen.verpakkingsvorm%TYPE)
    IS
      SELECT id
      FROM   vgc_tnt_verpakkingsvormen
      WHERE  verpakkingsvorm = i_verpakkingsvorm
    ;
    --
  BEGIN
    --dbms_lock.sleep(10);
      -- indien fout bij aanroepen webservice geef foutmelding en stop verwerking
   -- init variabelen voor verwerken
    v_rev_commodditsponse          :=      vgc_xml.extractxml(v_antwoord,'//ns1:GetClassificationTreeNodeDetailResponse', 'xmlns:ns1="http://ec.europa.eu/tracesnt/referencedata/v1"');
    v_commodities       :=      vgc_xml.extractxml(v_response, '//ns1:Node',v_ns);
    -- controleer of server een fout terug heeft gegeven
    v_generalOperationResult := vgc_xml.extractxml_str(v_response, '/retrieveReferenceDataReturn/generalOperationResult/text()',NULL);
    IF v_generalOperationResult IS NOT NULL
    THEN
      COMMIT;
      vgc_blg.write_log('Fout ontvangen: ' || v_generalOperationResult, v_objectnaam, 'J' , 5);
      raise_application_error(-20000, 'VGC-00502 #1' || v_ws_naam ||': Webservice geeft OperationResult: ' || v_generalOperationResult);
    END IF;
    --
    v_specificOperationResult := vgc_xml.extractxml_str(v_response, '/retrieveReferenceDataReturn/specificOperationResult/text()',NULL);
    IF v_specificOperationResult = 'CALLED_OUTSIDE_OPENING_TIME' OR v_specificOperationResult = 'TOO_MANY_INITIAL_LOADS'
    THEN
      COMMIT;
      vgc_blg.write_log('Fout ontvangen: ' || v_specificOperationResult, v_objectnaam, 'J', 5);
      raise_application_error(-20000, 'VGC-00502 #1' || v_ws_naam ||': Webservice geeft OperationResult: ' || v_specificOperationResult);
    END IF;
    -- indien v_server_side_date leeg is deze vullen met waarde uit bericht
    IF v_server_side_date IS NULL
    THEN
      v_server_side_date := vgc_xml.extractxml_str(v_response, '/retrieveReferenceDataReturn/retrievalServerSideDate/text()',NULL);
    END IF;
    --
    -- verwerk commodities
    --
    FOR r_rqt IN c_rqt(v_commodities, v_ns)
    LOOP
      DECLARE
        v_tge vgc_tnt_gn_codes%ROWTYPE;
      BEGIN
        v_xml_tat := r_rqt.kolommen;
        v_xml_tgl := r_rqt.gebruiksdoelen;
        v_xml_tpt := r_rqt.product_types;
        v_xml_tse := r_rqt.species;
        v_xml_ttr := r_rqt.temperaturen;
        v_xml_tvm := r_rqt.verpakkingsvormen;
        v_tge.id               := vgc_tge_seq1.nextval;
        v_tge.gn_code          := r_rqt.gn_code;
        v_tge.gn_code_meaning  := REPLACE(REPLACE(REPLACE(r_rqt.gn_code_meaning,chr(38)||'apos;',''''),chr(38)||'amp;','"'),chr(38)||'quot;','"');
        v_tge.beheerstatus     := '2';
        v_tge.status           := 'ACTIVE';
        v_tge.creation_date    := l_sysdate;
        v_tge.created_by       := l_user;
        v_tge.last_update_date := l_sysdate;
        v_tge.last_updated_by  := l_user;
        --
        IF i_retrieval_type = k_animals
        THEN
          v_tge.certificaattype := 'L';
        ELSIF i_retrieval_type = k_animalproducts
        THEN
          v_tge.certificaattype := 'P';
        ELSIF i_retrieval_type = k_nonanimalproducts
        THEN
          v_tge.certificaattype := 'V';
        ELSE
          v_tge.certificaattype := 'F';
        END IF;
        --
        BEGIN
          INSERT INTO vgc_tnt_gn_codes
          VALUES v_tge;
        EXCEPTION
          WHEN dup_val_on_index
          THEN
           UPDATE vgc_tnt_gn_codes tge
              SET tge.gn_code_meaning  = v_tge.gn_code_meaning
              ,   tge.status           = 'ACTIVE'
              ,   tge.beheerstatus     = '3'
              ,   tge.last_update_date = v_tge.last_update_date
              ,   tge.last_updated_by  = v_tge.last_updated_by
            WHERE tge.gn_code          = v_tge.gn_code
              AND tge.certificaattype  = v_tge.certificaattype
            --  AND tge.gn_code_meaning != v_tge.gn_code_meaning
            ;
          WHEN OTHERS
          THEN
           RAISE;
        END;
        --
        OPEN c_tge (i_gn_code => v_tge.gn_code, i_type => v_tge.certificaattype);
        FETCH c_tge into l_tge_id;
        CLOSE c_tge;
        --
        -- attributen
        --
        FOR r_xml_tat IN c_xml_tat(v_xml_tat, v_ns)
        LOOP
          vgc_blg.write_log('Loop attributen: ' || r_xml_tat.attribuut||'*'||r_xml_tat.optie, v_objectnaam, 'J', 5);

         DECLARE
            v_tat vgc_tnt_gn_codes_attributen%ROWTYPE;
            v_tta vgc_tnt_tge_tat%ROWTYPE;
          BEGIN
            v_tat.id               := vgc_tat_seq1.nextval;
            v_tat.naam             := r_xml_tat.attribuut;
            v_tat.creation_date    := l_sysdate;
            v_tat.created_by       := l_user;
            v_tat.last_update_date := l_sysdate;
            v_tat.last_updated_by  := l_user;
            --
            BEGIN
              INSERT INTO vgc_tnt_gn_codes_attributen
              VALUES v_tat;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_gn_codes_attributen tat
                  SET tat.last_update_date = v_tat.last_update_date
                  ,   tat.last_updated_by  = v_tat.last_updated_by
                WHERE tat.naam    = v_tat.naam
                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
            --
            OPEN c_tat (i_attribuut => v_tat.naam);
            FETCH c_tat into l_tat_id;
            CLOSE c_tat;
            --
            -- koppelen attribuut met gn_code
            --
            IF r_xml_tat.optie LIKE '%MANDATORY%'
            THEN
              v_tta.optie_ind := 'J';
              v_tta.cardinaliteit := 'V';
            ELSE
              v_tta.optie_ind := 'O';
              v_tta.cardinaliteit := 'O';
            END IF;
            --
            IF r_xml_tat.optie LIKE '%MULTIPLE%'
            THEN
              v_tta.meerdere_ind := 'J';
              v_tta.cardinaliteit := v_tta.cardinaliteit ||'M';
            ELSE
              v_tta.meerdere_ind := 'N';
            END IF;
            --
            v_tta.id               := vgc_tta_seq1.nextval;
            v_tta.tge_id           := l_tge_id;
            v_tta.tat_id           := l_tat_id;
            v_tta.status           := 'ACTIVE';
            v_tta.beheerstatus     := '2';
            v_tta.creation_date    := l_sysdate;
            v_tta.created_by       := l_user;
            v_tta.last_update_date := l_sysdate;
            v_tta.last_updated_by  := l_user;
            BEGIN
              INSERT INTO vgc_tnt_tge_tat
              VALUES v_tta;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_tge_tat tta
                  SET tta.status           = 'ACTIVE'
                  ,   tta.beheerstatus     = '3'
                  ,   tta.optie_ind        = v_tta.optie_ind
                  ,   tta.meerdere_ind        = v_tta.meerdere_ind
                  ,   tta.last_update_date = v_tta.last_update_date
                  ,   tta.last_updated_by  = v_tta.last_updated_by
                WHERE tta.tge_id = v_tta.tge_id
                AND   tta.tat_id = v_tta.tat_id
                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
          EXCEPTION
            WHEN OTHERS
            THEN
              RAISE;
          END;
        END LOOP;
        --
        -- producttypes
        --
        FOR r_xml_tpt IN c_xml_tpt(v_xml_tpt, v_ns)
        LOOP
          DECLARE
            v_tpt vgc_tnt_product_types%ROWTYPE;
            v_tgp vgc_tnt_tge_tpt%ROWTYPE;
          BEGIN
            v_tpt.id               := vgc_tpt_seq1.nextval;
            v_tpt.product_type     := r_xml_tpt.product_type;
            v_tpt.beheerstatus     := '2';
            v_tpt.status           := 'ACTIVE';
            v_tpt.creation_date    := l_sysdate;
            v_tpt.created_by       := l_user;
            v_tpt.last_update_date := l_sysdate;
            v_tpt.last_updated_by  := l_user;
            --
            BEGIN
              INSERT INTO vgc_tnt_product_types
              VALUES v_tpt;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_product_types tpt
                  SET tpt.status          = 'ACTIVE'
                  ,   tpt.beheerstatus    = '3'
                  ,   tpt.last_update_date = v_tpt.last_update_date
                  ,   tpt.last_updated_by  = v_tpt.last_updated_by
                WHERE tpt.product_type    = v_tpt.product_type
                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
            --
            OPEN c_tpt (i_product_type => v_tpt.product_type);
            FETCH c_tpt into l_tpt_id;
            CLOSE c_tpt;
            --
            -- koppelen product-type met gn_code
            --
            v_tgp.id               := vgc_tgp_seq1.nextval;
            v_tgp.tge_id           := l_tge_id;
            v_tgp.tpt_id           := l_tpt_id;
            v_tgp.status           := 'ACTIVE';
            v_tgp.beheerstatus     := '2';
            v_tgp.creation_date    := l_sysdate;
            v_tgp.created_by       := l_user;
            v_tgp.last_update_date := l_sysdate;
            v_tgp.last_updated_by  := l_user;
            BEGIN
              INSERT INTO vgc_tnt_tge_tpt
              VALUES v_tgp;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_tge_tpt tgp
                  SET tgp.status          = 'ACTIVE'
                  ,   tgp.beheerstatus    = '3'
                  ,   tgp.last_update_date = v_tgp.last_update_date
                  ,   tgp.last_updated_by  = v_tgp.last_updated_by
                WHERE tgp.tge_id = v_tgp.tge_id
                AND   tgp.tpt_id = v_tgp.tpt_id
                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
          EXCEPTION
            WHEN OTHERS
            THEN
              RAISE;
          END;
        END LOOP;
        --
        -- species
        --
        FOR r_xml_tse IN c_xml_tse(v_xml_tse, v_ns)
        LOOP
          DECLARE
            v_tse vgc_tnt_species%ROWTYPE;
            v_tgs vgc_tnt_tge_tse%ROWTYPE;
          BEGIN
            v_tse.id               := vgc_tse_seq1.nextval;
            v_tse.species          := r_xml_tse.species;
            v_tse.eppo_code        := r_xml_tse.eppo_code;
            v_tse.taxon_id         := r_xml_tse.taxon_id;
            v_tse.beheerstatus     := '2';
            v_tse.status           := 'ACTIVE';
            v_tse.creation_date    := l_sysdate;
            v_tse.created_by       := l_user;
            v_tse.last_update_date := l_sysdate;
            v_tse.last_updated_by  := l_user;
            --
            BEGIN
              INSERT INTO vgc_tnt_species
              VALUES v_tse;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_species tse
                  SET tse.eppo_code        = v_tse.eppo_code
                  ,   tse.species          = v_tse.species
                  ,   tse.status           = 'ACTIVE'
                  ,   tse.beheerstatus     = '3'
                  ,   tse.last_update_date = v_tse.last_update_date
                  ,   tse.last_updated_by  = v_tse.last_updated_by
                WHERE tse.taxon_id         = v_tse.taxon_id

                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
            --
            OPEN c_tse (i_taxon_id => v_tse.taxon_id);
            FETCH c_tse into l_tse_id;
            CLOSE c_tse;
            --
            -- koppelen species met gn_code
            --
            v_tgs.id               := vgc_tgs_seq1.nextval;
            v_tgs.tge_id           := l_tge_id;
            v_tgs.tse_id           := l_tse_id;
            v_tgs.status           := 'ACTIVE';
            v_tgs.beheerstatus     := '2';
            v_tgs.creation_date    := l_sysdate;
            v_tgs.created_by       := l_user;
            v_tgs.last_update_date := l_sysdate;
            v_tgs.last_updated_by  := l_user;
            BEGIN
              INSERT INTO vgc_tnt_tge_tse
              VALUES v_tgs;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_tge_tse tgs
                  SET tgs.status          = 'ACTIVE'
                  ,   tgs.beheerstatus    = '3'
                  ,   tgs.last_update_date = v_tgs.last_update_date
                  ,   tgs.last_updated_by  = v_tgs.last_updated_by
                WHERE tgs.tge_id = v_tgs.tge_id
                AND   tgs.tse_id = v_tgs.tse_id
                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
          EXCEPTION
            WHEN OTHERS
            THEN
              RAISE;
          END;
        END LOOP;
        --
        -- gebruiksdoelen
        --
        FOR r_xml_tgl IN c_xml_tgl(v_xml_tgl, v_ns)
        LOOP
          DECLARE
            v_tgl vgc_tnt_gebruiksdoelen%ROWTYPE;
            v_tgg vgc_tnt_tge_tgl%ROWTYPE;
          BEGIN
            v_tgl.id               := vgc_tgl_seq1.nextval;
            v_tgl.gebruiksdoel     := r_xml_tgl.gebruiksdoel;
            v_tgl.beheerstatus     := '2';
            v_tgl.status           := 'ACTIVE';
            v_tgl.creation_date    := l_sysdate;
            v_tgl.created_by       := l_user;
            v_tgl.last_update_date := l_sysdate;
            v_tgl.last_updated_by  := l_user;
            --
            BEGIN
              INSERT INTO vgc_tnt_gebruiksdoelen
              VALUES v_tgl;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_gebruiksdoelen tgl
                  SET tgl.status          = 'ACTIVE'
                  ,   tgl.beheerstatus    = '3'
                  ,   tgl.last_update_date = v_tgl.last_update_date
                  ,   tgl.last_updated_by  = v_tgl.last_updated_by
                WHERE tgl.gebruiksdoel   = v_tgl.gebruiksdoel
                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
            --
            OPEN c_tgl (i_gebruiksdoel => v_tgl.gebruiksdoel);
            FETCH c_tgl into l_tgl_id;
            CLOSE c_tgl;
            --
            -- koppelen gebruiksdoel met gn_code
            --
            v_tgg.id               := vgc_tgg_seq1.nextval;
            v_tgg.tge_id           := l_tge_id;
            v_tgg.tgl_id           := l_tgl_id;
            v_tgg.status           := 'ACTIVE';
            v_tgg.beheerstatus     := '2';
            v_tgg.creation_date    := l_sysdate;
            v_tgg.created_by       := l_user;
            v_tgg.last_update_date := l_sysdate;
            v_tgg.last_updated_by  := l_user;
            BEGIN
              INSERT INTO vgc_tnt_tge_tgl
              VALUES v_tgg;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_tge_tgl tgg
                  SET tgg.status          = 'ACTIVE'
                  ,   tgg.beheerstatus    = '3'
                  ,   tgg.last_update_date = v_tgg.last_update_date
                  ,   tgg.last_updated_by  = v_tgg.last_updated_by
                WHERE tgg.tge_id = v_tgg.tge_id
                AND   tgg.tgl_id = v_tgg.tgl_id
                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
          EXCEPTION
            WHEN OTHERS
            THEN
              RAISE;
          END;
        END LOOP;
        --
        -- temperaturen
        --
        FOR r_xml_ttr IN c_xml_ttr(v_xml_ttr, v_ns)
        LOOP
          DECLARE
            v_ttr vgc_tnt_temperaturen%ROWTYPE;
            v_tgr vgc_tnt_tge_ttr%ROWTYPE;
          BEGIN
            v_ttr.id               := vgc_ttr_seq1.nextval;
            v_ttr.temperatuur     := r_xml_ttr.temperatuur;
            v_ttr.beheerstatus     := '2';
            v_ttr.status           := 'ACTIVE';
            v_ttr.creation_date    := l_sysdate;
            v_ttr.created_by       := l_user;
            v_ttr.last_update_date := l_sysdate;
            v_ttr.last_updated_by  := l_user;
            --
            BEGIN
              INSERT INTO vgc_tnt_temperaturen
              VALUES v_ttr;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_temperaturen ttr
                  SET ttr.status          = 'ACTIVE'
                  ,   ttr.beheerstatus    = '3'
                  ,   ttr.last_update_date = v_ttr.last_update_date
                  ,   ttr.last_updated_by  = v_ttr.last_updated_by
                WHERE ttr.temperatuur   = v_ttr.temperatuur
                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
            --
            OPEN c_ttr (i_temperatuur => v_ttr.temperatuur);
            FETCH c_ttr into l_ttr_id;
            CLOSE c_ttr;
            --
            -- koppelen species met gn_code
            --
            v_tgr.id               := vgc_tgr_seq1.nextval;
            v_tgr.tge_id           := l_tge_id;
            v_tgr.ttr_id           := l_ttr_id;
            v_tgr.status           := 'ACTIVE';
            v_tgr.beheerstatus     := '2';
            v_tgr.creation_date    := l_sysdate;
            v_tgr.created_by       := l_user;
            v_tgr.last_update_date := l_sysdate;
            v_tgr.last_updated_by  := l_user;
            BEGIN
              INSERT INTO vgc_tnt_tge_ttr
              VALUES v_tgr;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_tge_ttr tgr
                  SET tgr.status          = 'ACTIVE'
                  ,   tgr.beheerstatus    = '3'
                  ,   tgr.last_update_date = v_tgr.last_update_date
                  ,   tgr.last_updated_by  = v_tgr.last_updated_by
                WHERE tgr.tge_id = v_tgr.tge_id
                AND   tgr.ttr_id = v_tgr.ttr_id
                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
          EXCEPTION
            WHEN OTHERS
            THEN
              RAISE;
          END;
        END LOOP;
        --
        -- verpakkingsvormen
        --
        FOR r_xml_tvm IN c_xml_tvm(v_xml_tvm, v_ns)
        LOOP
          DECLARE
            v_tvm vgc_tnt_verpakkingsvormen%ROWTYPE;
            v_tgm vgc_tnt_tge_tvm%ROWTYPE;
          BEGIN
            v_tvm.id               := vgc_tvm_seq1.nextval;
            v_tvm.verpakkingsvorm     := r_xml_tvm.verpakkingsvorm;
            v_tvm.beheerstatus     := '2';
            v_tvm.status           := 'ACTIVE';
            v_tvm.creation_date    := l_sysdate;
            v_tvm.created_by       := l_user;
            v_tvm.last_update_date := l_sysdate;
            v_tvm.last_updated_by  := l_user;
            --
            BEGIN
              INSERT INTO vgc_tnt_verpakkingsvormen
              VALUES v_tvm;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_verpakkingsvormen tvm
                  SET tvm.status          = 'ACTIVE'
                  ,   tvm.beheerstatus    = '3'
                  ,   tvm.last_update_date = v_tvm.last_update_date
                  ,   tvm.last_updated_by  = v_tvm.last_updated_by
                WHERE tvm.verpakkingsvorm   = v_tvm.verpakkingsvorm
                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
            --
            OPEN c_tvm (i_verpakkingsvorm => v_tvm.verpakkingsvorm);
            FETCH c_tvm into l_tvm_id;
            CLOSE c_tvm;
            --
            -- koppelen verpakkingsvorm met gn_code
            --
            v_tgm.id               := vgc_tgm_seq1.nextval;
            v_tgm.tge_id           := l_tge_id;
            v_tgm.tvm_id           := l_tvm_id;
            v_tgm.status           := 'ACTIVE';
            v_tgm.beheerstatus     := '2';
            v_tgm.creation_date    := l_sysdate;
            v_tgm.created_by       := l_user;
            v_tgm.last_update_date := l_sysdate;
            v_tgm.last_updated_by  := l_user;
            BEGIN
              INSERT INTO vgc_tnt_tge_tvm
              VALUES v_tgm;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_tge_tvm tgm
                  SET tgm.status          = 'ACTIVE'
                  ,   tgm.beheerstatus    = '3'
                  ,   tgm.last_update_date = v_tgm.last_update_date
                  ,   tgm.last_updated_by  = v_tgm.last_updated_by
                WHERE tgm.tge_id = v_tgm.tge_id
                AND   tgm.tvm_id = v_tgm.tvm_id
                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
          EXCEPTION
            WHEN OTHERS
            THEN
              RAISE;
          END;
        END LOOP;
      EXCEPTION
        WHEN OTHERS
        THEN
          RAISE;
      END;
    END LOOP;
    --

   -- COMMIT;
    -- return true indien dit de laatste pagina was anders false
   -- IF upper(vgc_xml.extractxml_str(v_response, '/retrieveReferenceDataReturn/isLastPage/text()',NULL)) = 'TRUE'
   -- THEN
   RETURN TRUE;
   -- ELSE
   --   RETURN FALSE;
   -- END IF;
    --
  EXCEPTION
    WHEN OTHERS
    THEN
      IF c_rqt%ISOPEN
      THEN
        CLOSE c_rqt;
      END IF;
      IF c_tpt%ISOPEN
      THEN
        CLOSE c_tpt;
      END IF;
      RAISE;
  END verwerk;
--
-- voert synchronisatie uit voor het opgegeven retrieval_type
--
  PROCEDURE sync (i_retrieval_type IN VARCHAR2, i_gn_code IN VARCHAR2)
  IS
    CURSOR c_tte
    IS
      SELECT gn_code
      ,      type
      ,      soort
      FROM vgc_tnt_gn_codes_tree tte
      WHERE tte.soort = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F')
      AND (tte.gn_code = i_gn_code
      OR i_gn_code IS NULL)
      ORDER BY gn_code
    ;
  --
    v_verwerking_klaar    BOOLEAN         := FALSE;
  --
--
-- tel de wijzigingen en zet alles op geverifieerd (beheerstatus 1)
--
  PROCEDURE resumeer (i_retrieval_type VARCHAR2)
  IS
    CURSOR c_gvt
    IS
      SELECT SUM(decode(beheerstatus,'1', 1, 0)) aantal_status_1
      ,      SUM(decode(beheerstatus,'2', 1, 0)) aantal_status_2
      ,      SUM(decode(beheerstatus,'3', 1, 0)) aantal_status_3
      FROM vgc_tnt_gn_codes
      WHERE certificaattype = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F')
    ;
    --
    r_gvt c_gvt%ROWTYPE;
  --
  BEGIN
  --
    vgc_blg.write_log('Aantal nieuwe rijen: ' || r_gvt.aantal_status_2, v_objectnaam, 'N', 1);
    vgc_blg.write_log('Aantal gewijzigde rijen: ' || r_gvt.aantal_status_3, v_objectnaam, 'N', 1);
    vgc_blg.write_log('Aantal gewijzigde rijen op DELETED: ' || r_gvt.aantal_status_1, v_objectnaam, 'N', 1);
    --
    -- verifieeren van wijzigingen
    --
    UPDATE vgc_tnt_gn_codes
      SET beheerstatus = '1'
    WHERE beheerstatus != '1'
    AND certificaattype = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F')
    ;
    --
    UPDATE vgc_v_tnt_tge_tgl
      SET beheerstatus = '1'
    WHERE beheerstatus != '1'
    AND   tge_id IN (SELECT id FROM vgc_v_tnt_gn_codes WHERE certificaattype = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F'))
    ;
    --
    update vgc_v_tnt_tge_tpt
      SET beheerstatus = '1'
    WHERE beheerstatus != '1'
    AND   tge_id IN (SELECT id FROM vgc_v_tnt_gn_codes WHERE certificaattype = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F'))
    ;
    --
    update vgc_v_tnt_tge_tse
      SET beheerstatus = '1'
    WHERE beheerstatus != '1'
    AND   tge_id IN (SELECT id FROM vgc_v_tnt_gn_codes WHERE certificaattype = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F'))
    ;
    --
    update vgc_v_tnt_tge_ttr
      SET beheerstatus = '1'
    WHERE beheerstatus != '1'
    AND   tge_id IN (SELECT id FROM vgc_v_tnt_gn_codes WHERE certificaattype = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F'))
    ;
    --
    update vgc_v_tnt_tge_tvm
      SET beheerstatus = '1'
    WHERE beheerstatus != '1'
    AND   tge_id IN (SELECT id FROM vgc_v_tnt_gn_codes WHERE certificaattype = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F'))
    ;
  --  COMMIT;
  EXCEPTION
    WHEN OTHERS
    THEN
      vgc_blg.write_log('Fout bij resumeren: ' || SQLERRM, v_objectnaam, 'J', 5);
      RAISE;
  END resumeer;
  --
--
-- tel de wijzigingen en zet alles op geverifieerd (beheerstatus 1)
--
  PROCEDURE init_sync (i_retrieval_type IN VARCHAR2, i_gn_code VARCHAR2)
  IS
  --
  BEGIN
  --
    update vgc_v_tnt_gn_codes
       set status = 'DELETED'
    where certificaattype = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F')
    and   gn_code = i_gn_code
    and   status = 'ACTIVE'
    ;
    --
    update vgc_v_tnt_tge_tgl
       set status = 'DELETED'
    where status = 'ACTIVE'
    and   tge_id in (select id from vgc_v_tnt_gn_codes where certificaattype = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F')
                                                       and   gn_code = i_gn_code)
    ;
    --
    update vgc_v_tnt_tge_tpt
       set status = 'DELETED'
    where status = 'ACTIVE'
    and   tge_id in (select id from vgc_v_tnt_gn_codes where certificaattype = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F')
                                                       and   gn_code = i_gn_code)
    ;
    --
    update vgc_v_tnt_tge_tse
       set status = 'DELETED'
    where status = 'ACTIVE'
    and   tge_id in (select id from vgc_v_tnt_gn_codes where certificaattype = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F')
                                                       and   gn_code = i_gn_code)
    ;
    --
    update vgc_v_tnt_tge_ttr
       set status = 'DELETED'
    where status = 'ACTIVE'
    and   tge_id in (select id from vgc_v_tnt_gn_codes where certificaattype = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F')
                                                       and   gn_code = i_gn_code)
    ;
    --
    update vgc_v_tnt_tge_tvm
       set status = 'DELETED'
    where status = 'ACTIVE'
    and   tge_id in (select id from vgc_v_tnt_gn_codes where certificaattype = decode(i_retrieval_type,'chedp','P','cheda','L','chedd','V','F')
                                                       and   gn_code = i_gn_code)
    ;
  --  COMMIT;
  EXCEPTION
    WHEN OTHERS
    THEN
      vgc_blg.write_log('Fout bij initialiseren van de synchronisatie: ' || SQLERRM, v_objectnaam, 'J', 5);
      RAISE;
  END init_sync;
  --
  BEGIN
  --
    vgc_blg.write_log('Start synchroniseren: ' || i_retrieval_type, v_objectnaam, 'J', 5);
  --
    l_error_count := 0;
    FOR r_tte IN c_tte
    LOOP
      <<restart_retrieval_gn_code>>
      --
      vgc_blg.write_log('Start synchroniseren gn_code : ' || r_tte.gn_code, v_objectnaam, 'J', 5);
     --
      r_rqt.request_id := NULL;
      r_rqt.status := vgc_ws_requests.kp_in_uitvoering;
      r_rqt.resultaat := i_retrieval_type ||' CNCode: '|| r_tte.gn_code;
      -- opstellen bericht
      maak_bericht(i_retrieval_type, r_tte.gn_code);
      -- aanroepen webservice
      BEGIN
        vgc_ws_requests_nt.maak_http_request (r_rqt);
        vgc_ws_requests_nt.log_request(r_rqt);
      EXCEPTION
        WHEN OTHERS
        THEN
          l_error_count := l_error_count + 1;
          vgc_blg.write_log('Fout in sync: ' || l_error_count, v_objectnaam, 'J', 5);
          IF l_error_count < 9
          THEN
            vgc_blg.write_log('Fout in sync: Restart' || l_error_count, v_objectnaam, 'J', 5);
            GOTO restart_retrieval_gn_code;
          ELSE
            vgc_blg.write_log('Fout in sync: Fout' || l_error_count, v_objectnaam, 'J', 5);
            RAISE;
          END IF;
      END;
      --
      vgc_blg.write_log('Uitlezen antwoord', v_objectnaam, 'J', 5);
      --
      IF nvl(r_rqt.webservice_returncode,500) <> 200
      THEN
        vgc_blg.write_log('Foutieven returncode', v_objectnaam, 'J', 5);
        IF dbms_lob.instr(r_rqt.webservice_antwoord,'Node not found',1,1) > 0
        THEN
          UPDATE vgc_tnt_gn_codes_tree
          SET type = 'S'
          WHERE gn_code = r_tte.gn_code
          AND   soort   = r_tte.soort
          ;
          COMMIT;
          vgc_blg.write_log('Tussennode gn_code : ' || r_tte.gn_code, v_objectnaam, 'J', 5);
        ELSE
          vgc_blg.write_log('Webservice geeft http-code: ' || r_rqt.webservice_returncode, v_objectnaam, 'J', 5);
          raise_application_error(-20000, 'VGC-00502 #1' || v_ws_naam ||': Webservice geeft HTTP-code: ' || r_rqt.webservice_returncode);
        END IF;
      ELSE
      -- initialiseren request
        init_sync(i_retrieval_type,r_tte.gn_code);
        v_antwoord := xmltype(r_rqt.webservice_antwoord);
      -- Verwerk indien nodig het gewijzigde wachtwoord
      --check_password_reset(i_response => v_antwoord);
      -- verwerk response
        v_verwerking_klaar := verwerk (i_retrieval_type, r_tte.gn_code);
      END IF;

    END LOOP;
    resumeer(i_retrieval_type);
  EXCEPTION
    WHEN OTHERS
    THEN
      vgc_blg.write_log('Fout bij synchroniseren: ' || SQLERRM, v_objectnaam, 'J', 5);
      RAISE;
  END sync;
BEGIN
  --
  trace(v_objectnaam);
  vgc_blg.write_log('start', v_objectnaam, 'N', 1);
  --
  -- Aanmaken lock zodat VGC0511NT niet synchroon kan draaien
  --
  OPEN c_lock;
  CLOSE c_lock;
  --
  -- initialiseren request
  --
  r_rqt.request_id             := NULL;
  r_rqt.webservice_url         := vgc$algemeen.get_appl_register ('TNT_GN_CODES_WEBSERVICE');
  r_rqt.bestemd_voor           := 'TNT';
  r_rqt.webservice_logische_naam := 'VGC0511NT';
  --
  --Synchroniseer--
  --
  if p_type = 'LNV'
  then
    sync(k_nonanimalproducts, p_gn_code);
  elsif p_type = 'LPJ'
  then
    sync(k_animals, p_gn_code);
  elsif p_type = 'NPJ'
  then
    sync(k_animalproducts, p_gn_code);
  else
    sync(k_fytoproducts, p_gn_code);
  end if;
  vgc_blg.write_log('einde', v_objectnaam, 'N', 1);
  --
  COMMIT;
EXCEPTION
  WHEN resource_busy
  THEN
    ROLLBACK;
    RAISE;
  WHEN OTHERS
  THEN
    IF c_lock%ISOPEN
    THEN
      CLOSE c_lock;
    END IF;
    vgc_blg.write_log('Exception: '|| SQLERRM, v_objectnaam, 'N', 1);
    ROLLBACK;
    qms$errors.unhandled_exception(v_objectnaam);
END VGC0511NT;

PROCEDURE VGC0522NT
 (i_ggs_nummer IN varchar2)
 IS
v_objectnaam vgc_batchlog.proces%TYPE  := g_package_name||'.VGC0522NT#1';
/*********************************************************************
Wijzigingshistorie
doel:
Aanbieden van gereedmedlingen aan CIM

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
   1     28-01-2020 GR     creatie
*********************************************************************/
--
  CURSOR c_ptj( b_ggs_nummer vgc_partijen.ggs_nummer%TYPE)
  IS
    SELECT rqt.webservice_bericht
    ,      decode(cte.m_verplicht_ind,'J','3','2') actiecode
    ,      ptj.aangiftejaar
    ,      ptj.aangiftevolgnummer
    ,      rle.aangevernummer
    ,      nvl(wrn.code,'TLG')  redencode
    ,      nvl(wrn.omschrijving,'Goedgekeurd') redenafkeuring
    ,      ptj.traces_certificaat_id
    FROM   vgc_requests rqt
    ,      vgc_beslissingen bsg
    ,      vgc_controles cte
    ,      vgc_beslissingtypes bse
    ,      vgc_partijen ptj
    ,      vgc_relaties rle
    ,      vgc_weigeringen wgg
    ,      vgc_weigeringredenen wrn
    WHERE  rqt.ggs_nummer = b_ggs_nummer
    AND    rqt.webservice_logische_naam in ('VGC0505U','VGC0503U')
    AND    ptj.ggs_nummer = b_ggs_nummer
    AND    cte.ptj_id = ptj.id
    AND    bsg.ptj_id = ptj.id
    AND    ptj.rle_id = rle.id
    AND    bsg.bse_id = bse_id
    AND    bse.code IN ('DWG','TLG')
    AND    wgg.bsg_id (+) = bsg.id
    AND    wgg.wrn_id  = wrn.id (+)
  ;
  l_resultaat boolean;
  l_request_id number;
BEGIN
  for r_ptj in c_ptj(i_ggs_nummer)
  loop
    vgc_ws_cms.vgc_cms_out
      (p_aangevernummer => r_ptj.aangevernummer
      ,p_aangiftejaar => r_ptj.aangiftejaar
      ,p_aangifte_volgnummer => r_ptj.aangiftevolgnummer
      ,p_ggs_nummer => i_ggs_nummer
      ,p_classificatie => 'D'
      ,p_pdf => 'N'
      ,p_actiecode => r_ptj.actiecode
      ,p_chednummer => r_ptj.traces_certificaat_id
      ,p_redencode => r_ptj.redencode
      ,p_redenafkeuring => r_ptj.redenafkeuring
      ,p_ws_naam => 'VGC0522NT'
      ,p_xml => (r_ptj.webservice_bericht)
      ,p_request_id => l_request_id
      ,p_resultaat => l_resultaat
      );
  end loop;
EXCEPTION
  WHEN OTHERS
  THEN
    vgc_blg.write_log('Exception: ' || SQLERRM, v_objectnaam, 'N', 1);
    ROLLBACK;
END VGC0522NT;
--
/* Ophalen van de organisatiegegevens uit TRACES-NT */

PROCEDURE VGC0701NT
 (P_ERKENNINGSNUMMER IN VARCHAR2
 ,P_ACTIVITEIT IN VARCHAR2
 ,P_LAND_CODE IN VARCHAR2
 ,P_NAAM IN VARCHAR2
 ,P_POSTCODE IN VARCHAR2
 ,P_PLAATS IN VARCHAR2
 )
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.VGC0701NT#1';
/*********************************************************************
Wijzigingshistorie
doel:
Ophalen van de organisatiegegevens uit TRACES-NT

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
   1    01-06-2021 GLR     creatie
*********************************************************************/

--
  k_operation             CONSTANT  VARCHAR2(19 CHAR)                           := 'findOperator';
  v_antwoord              xmltype;
  v_operators             xmltype;
  v_ws_naam               VARCHAR2(100 CHAR) := 'retrieveOperatorData';
  v_result                VARCHAR2(200 CHAR);
  l_timestamp_char        VARCHAR2(100 CHAR);
  l_trx_timestamp_char    VARCHAR2(100 CHAR);
  v_username              VARCHAR2(100 CHAR);
  v_password              VARCHAR2(100 CHAR);
  l_CreateTimestampString VARCHAR2(100 CHAR);
  l_ExpireTimestampString VARCHAR2(100 CHAR);
  v_timestamp             TIMESTAMP;
  l_nonce_raw             RAW(100);
  l_nonce_b64             VARCHAR2(24 CHAR);
  l_password_digest_b64   VARCHAR2(100 CHAR);
  l_offset                INTEGER := 0;



  r_rqt                            vgc_requests%ROWTYPE;
  resource_busy                    EXCEPTION;
  PRAGMA EXCEPTION_INIT( resource_busy, -54 );
--
-- Stelt bericht op voor aanroep
--
  PROCEDURE maak_bericht(l_offset IN INTEGER)
  IS
  --
    CURSOR c_xml
    IS
      SELECT xmlelement("soapenv:Envelope"
      ,        xmlattributes ( 'http://schemas.xmlsoap.org/soap/envelope/' AS "xmlns:soapenv"
                             , 'http://ec.europa.eu/sanco/tracesnt/base/v4' AS "xmlns:v4"
                             , 'http://ec.europa.eu/tracesnt/directory/operator/v1' as "xmlns:v1"
                             , 'http://ec.europa.eu/tracesnt/directory/geo/city/v1' as "xmlns:v11"
                             , 'http://ec.europa.eu/tracesnt/directory/geo/region/v1' as "xmlns:v12"
                             , 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'  AS "xmlns:oas")
      ,        xmlelement("soapenv:Header"
      ,          xmlattributes( 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd' AS "xmlns:wsse"
                              , 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'  AS "xmlns:wsu")
      ,          xmlelement("wsse:Security"
      ,            xmlelement("wsse:UsernameToken"
      ,            xmlattributes( 'UsernameToken-A5B8D7123A55CB6A75153751937547586' AS "wsu:Id" )
      ,              xmlelement("wsse:Username", v_username)
      ,              xmlelement("wsse:Password"
      ,                xmlattributes( 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest' AS "Type" )
      ,                l_password_digest_b64)
      ,              xmlelement("wsse:Nonce", l_nonce_b64)
      ,              xmlelement("wsu:Created", l_CreateTimestampString)
                   )
      ,            xmlelement("wsu:Timestamp"
      ,              xmlelement("wsu:Created", l_CreateTimestampString)
      ,              xmlelement("wsu:Expires", l_ExpireTimestampString)
                   )
                 )
      ,          xmlelement("v4:LanguageCode",'nl')
      ,          xmlelement("v4:WebServiceClientId",'vgc-client')
               )
      ,        xmlelement("soapenv:Body"
      ,          xmlattributes( 'http://schemas.xmlsoap.org/soap/envelope/' AS "xmlns:soapenv")
      ,         xmlelement("v1:FindOperatorRequest"
      ,            xmlattributes( 'http://ec.europa.eu/tracesnt/directory/operator/v1' AS "xmlns:v1"
      ,                           'UPDATE' AS "sortPredicate"
      ,                           'true'  AS "sortAscending"
      ,                           '200'     AS "pageSize"
      ,                           l_offset  AS "offset")
      ,            CASE WHEN p_naam IS NOT null
                   THEN xmlelement("v1:Name"
      ,              xmlattributes ( 'PHRASE' AS "matchMode")
      ,              p_naam )
                   END
      ,            xmlelement("v1:CountryID", upper(p_land_code))
      ,            CASE WHEN p_plaats is not null OR p_postcode is not NULL
                   THEN
                     xmlelement("v1:City"
      ,              CASE WHEN p_plaats is not null
                     THEN
                       xmlelement("v11:Name", upper(p_plaats))
                     END
      ,              CASE WHEN p_postcode is not null
                     THEN
                       xmlelement("v11:PostalCode", upper(p_postcode))
                     END
                            )
                   END
--      ,            CASE WHEN p_erkenningsnummer is not null
--                   THEN
--                     xmlelement("v1:Identifier"
--      ,              xmlelement("v1:ID", p_erkenningsnummer)
--                             )
--                   END
      ,            CASE WHEN p_activiteit is not null OR p_erkenningsnummer is not null
                   THEN
                     xmlelement("v1:Activity"
      ,              CASE WHEN p_erkenningsnummer is not null
                     THEN
                       xmlelement("v1:ID", p_erkenningsnummer)
                     END
      ,              CASE WHEN p_activiteit is null AND p_erkenningsnummer is null
                     THEN
                       xmlelement("v1:Type", 'establishment')
                     ELSE
                       xmlelement("v1:Type", p_activiteit)
                     END
                             )
                   END
              )
                         )
             ).getClobval()
      FROM dual
    ;

  BEGIN
  -- Ophalen credentials
    v_username := vgc$algemeen.get_appl_register('TNT_USERNAME');
    v_password := vgc$algemeen.get_appl_register('TNT_PASSWORD');
  --
    v_timestamp := SYSTIMESTAMP;
    l_timestamp_char      := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
    l_trx_timestamp_char  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM');
    l_nonce_raw           := utl_i18n.string_to_raw(dbms_random.string('a',16),'utf8');
    l_nonce_b64           := utl_i18n.raw_to_char(utl_encode.base64_encode(l_nonce_raw),'utf8');
    l_password_digest_b64 := utl_i18n.raw_to_char
                           ( utl_encode.base64_encode
                             ( dbms_crypto.hash
                               ( l_nonce_raw||utl_i18n.string_to_raw(l_timestamp_char||v_password,'utf8')
                               , dbms_crypto.hash_sh1
                               )
                             )
                           , 'utf8'
                           );
  --
    l_CreateTimestampString := TO_CHAR(v_timestamp,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
    v_timestamp :=v_timestamp + 3/1440;
    l_ExpireTimestampString := TO_CHAR(v_timestamp,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
  -- Opstellen bericht
    OPEN c_xml;
    FETCH c_xml INTO  r_rqt.webservice_bericht;
    CLOSE c_xml;
    escape_xml(r_rqt.webservice_bericht);
    --
  EXCEPTION
    WHEN OTHERS
    THEN
      IF c_xml%ISOPEN
      THEN
        CLOSE c_xml;
      END IF;
      RAISE;
  END maak_bericht;
  --

-- Verwerkt het binnengekomen resultaat
--
  FUNCTION verwerk RETURN BOOLEAN
  IS
    v_einde             boolean := false;
    l_sysdate           DATE := SYSDATE;
    l_user              VARCHAR2(35 CHAR) := USER;
    l_tor_id            NUMBER;
    l_tay_id            NUMBER;
    l_tro_id            NUMBER;
    -- tijdelijke variabelen voor verwerken XML
    v_xml_tro           xmltype;
    v_xml_tay           xmltype;
    --
    v_generalOperationResult      VARCHAR2(200 CHAR);
    v_specificOperationResult     VARCHAR2(200 CHAR);
    v_xmlns1                      VARCHAR2(2000 CHAR) :=  'xmlns:ns7="http://ec.europa.eu/tracesnt/directory/operator/v1"'||' xmlns:ns0="http://schemas.xmlsoap.org/soap/envelope/"';
    v_xmlns2                      VARCHAR2(2000 CHAR) :=  'xmlns:ns7="http://ec.europa.eu/tracesnt/directory/operator/v1"';
    v_xmlns3                      VARCHAR2(2000 CHAR) :=  'xmlns:ns7="http://ec.europa.eu/tracesnt/directory/operator/v1"'||' xmlns:ns4="http://ec.europa.eu/tracesnt/directory/common/v1"'||
                                                          ' xmlns:ns5="http://ec.europa.eu/tracesnt/directory/geo/city/v1"';
    v_response                    xmltype;
    v_fault                       xmltype;
    v_operatorsstr                clob;
    v_faultstr                    clob;
    -- Query voor uitlezen organisaties uit response
    CURSOR c_tln(i_xml xmltype, i_ns varchar2)
    IS
      SELECT extract(VALUE(tln), '/ns7:OperatorIndex/@internalID', i_ns).getStringVal()  tnt_id
      ,      extract(VALUE(tln), '/ns7:OperatorIndex/ns7:Identifier[1]/text()',i_ns).getStringVal()  tnt_nummer
      ,      extract(VALUE(tln), '/ns7:OperatorIndex/ns7:Identifier[1]/@type', i_ns).getStringVal()  tnt_nummer_type
      ,      extract(VALUE(tln), '/ns7:OperatorIndex/ns7:Identifier[2]/text()',i_ns).getStringVal()  tnt_nummer_2
      ,      extract(VALUE(tln), '/ns7:OperatorIndex/ns7:Identifier[2]/@type', i_ns).getStringVal()  tnt_nummer_type_2
      ,      extract(VALUE(tln), '/ns7:OperatorIndex/ns7:Name/text()', i_ns).getStringVal() naam
      ,      extract(VALUE(tln), '/ns7:OperatorIndex/ns7:Activity', i_ns) activiteiten
      ,      extract(VALUE(tln), '/ns7:OperatorIndex/ns7:OperatorAddress[1]/ns7:Address/ns4:Street/text()', i_ns).getStringVal() adres
      ,      extract(VALUE(tln), '/ns7:OperatorIndex/ns7:OperatorAddress[1]/ns7:Address/ns4:City/ns5:PostalCode/text()', i_ns).getStringVal() postcode
      ,      extract(VALUE(tln), '/ns7:OperatorIndex/ns7:OperatorAddress[1]/ns7:Address/ns4:City/ns5:Name/text()', i_ns).getStringVal() plaats
      ,      extract(VALUE(tln), '/ns7:OperatorIndex/ns7:OperatorAddress[1]/ns7:Address/ns4:City/ns5:CountryID/text()', i_ns).getStringVal() landcode
      ,      extract(VALUE(tln), '/ns7:OperatorIndex/ns7:OperatorAddress[1]/ns7:Address/ns4:City', i_ns) regios
      FROM TABLE( xmlsequence(i_xml)) tln
    ;
    --
    CURSOR c_xml_tay(i_xml xmltype, i_ns VARCHAR2)
    IS
      SELECT extract(VALUE(rqt), '//ns7:Activity/@internalID',i_ns).getStringVal()  tnt_id
      ,      extract(VALUE(rqt), '//ns7:Activity/ns7:Identifier/text()',i_ns).getStringVal()  erkenningsnummer
      ,      extract(VALUE(rqt), '//ns7:ActivityType/ns7:Chapter/text()', i_ns).getStringVal() hoofdstuk
      ,      extract(VALUE(rqt), '//ns7:ActivityType/ns7:Section/text()', i_ns).getStringVal() sectie
      ,      extract(VALUE(rqt), '//ns7:ActivityType/ns7:Type/text()', i_ns).getStringVal() type
      ,      extract(VALUE(rqt), '//ns7:Activity/ns7:Status/text()', i_ns).getStringVal()  status
      FROM TABLE( xmlsequence(i_xml)) rqt
    ;
    --
    CURSOR c_xml_tro(i_xml xmltype, i_ns VARCHAR2)
    IS
      SELECT extract(VALUE(rqt), '//ns5:Region[1]/text()', i_ns).getStringVal() regio
      FROM TABLE( xmlsequence(i_xml)) rqt
    ;
   --
    CURSOR c_tor(i_tnt_id vgc_tnt_operators.tnt_id%TYPE)
    IS
      SELECT id
      FROM   vgc_tnt_operators
      WHERE  tnt_id = i_tnt_id
    ;
   --
    CURSOR c_tro(i_naam vgc_tnt_regios.naam%TYPE)
    IS
      SELECT id
      FROM   vgc_tnt_regios
      WHERE  naam = i_naam
    ;
   --
    CURSOR c_tay(i_hoofdstuk vgc_tnt_activiteiten.hoofdstuk%TYPE, i_sectie vgc_tnt_activiteiten.sectie%TYPE, i_type vgc_tnt_activiteiten.type%TYPE )
    IS
      SELECT id
      FROM   vgc_tnt_activiteiten
      WHERE  nvl(hoofdstuk,'$') = nvl(i_hoofdstuk,'$')
        AND  sectie = i_sectie
        AND  type = i_type
    ;
    --
    l_operator_count number := 0;
  BEGIN
    vgc_blg.write_log('Start: verwerk', v_objectnaam, 'J', 5);
    -- init variabelen voor verwerken
    v_fault              :=  vgc_xml.extractxml(v_antwoord, '//ns0:Fault', v_xmlns1);
    v_faultstr           :=  vgc_xml.extractxml_str(v_antwoord, '//ns0:Fault/detail/ns7:IllegalFindOperatorException/text()', v_xmlns1);
    v_response           :=  vgc_xml.extractxml(v_antwoord, '//ns7:FindOperatorResponse', v_xmlns1);
    v_operators          :=  vgc_xml.extractxml(v_response, '//ns7:OperatorIndex',v_xmlns1);
    v_operatorsstr       :=  vgc_xml.extractxml_str(v_response, '//ns7:Status/text()', v_xmlns1);
    l_offset             :=  vgc_xml.extractxml_str(v_response, '//ns7:FindOperatorResponse/@offset', v_xmlns1);
    --
    IF nvl(length(v_faultstr),0) > 0
    THEN
      v_einde := true;
      v_result := to_char(v_faultstr);
    ELSIF nvl(length(v_operatorsstr),0) = 0
    THEN
      v_einde := true;
      IF l_offset = 0
      THEN
        v_result := 'Operator niet gevonden in TNT';
      END IF;
    END IF;
    --
    -- verwerk organisaties
    --
    l_operator_count := 0;
    FOR r_tln IN c_tln(v_operators, v_xmlns3)
    LOOP
      l_operator_count := l_operator_count + 1;
      vgc_blg.write_log('Verwerken: ' || r_tln.tnt_id, v_objectnaam, 'J' , 5);
      DECLARE
        CURSOR c_tpe (b_land_code IN vgc_landen.code%TYPE, b_postcode vgc_tnt_postcodes.postcode%TYPE)
        IS
          SELECT stadsnaam_uppercase
          FROM   vgc_tnt_postcodes tpe
          WHERE  tpe.land_code = b_land_code
          AND    tpe.postcode = b_postcode
        ;

        v_plaats vgc_tnt_operators.plaats%TYPE;
        v_tor vgc_tnt_operators%ROWTYPE;

      BEGIN
                --
        OPEN c_tpe (b_land_code => r_tln.landcode
                   ,b_postcode => r_tln.postcode);
        FETCH c_tpe INTO v_plaats;
        CLOSE c_tpe;
        --
        -- vul rij met waarden
        --
        v_xml_tay              := r_tln.activiteiten;
        v_xml_tro              := r_tln.regios;
        v_tor.id               := vgc_tor_seq1.nextval;
        v_tor.tnt_id           := r_tln.tnt_id;
        v_tor.tnt_nummer       := substr(nvl(r_tln.tnt_nummer,r_tln.tnt_nummer_2),1,100);
        v_tor.tnt_nummer_type  := get_vgc_id_type(nvl(r_tln.tnt_nummer_type,r_tln.tnt_nummer_type_2));
        v_tor.naam             := substr(REPLACE(REPLACE(REPLACE(r_tln.naam,chr(38)||'apos;',''''),chr(38)||'amp;','&'),chr(38)||'quot;','"'),1,200);
        v_tor.adres            := substr(REPLACE(REPLACE(REPLACE(r_tln.adres,chr(38)||'apos;',''''),chr(38)||'amp;','&'),chr(38)||'quot;','"'),1,200);
        v_tor.plaats           := substr(REPLACE(REPLACE(REPLACE(r_tln.plaats,chr(38)||'apos;',''''),chr(38)||'amp;','&'),chr(38)||'quot;','"'),1,200);
        v_tor.postcode         := substr(nvl(r_tln.postcode,v_tor.plaats),1,100);
        v_tor.land_code        := substr(nvl(r_tln.landcode,'XX'),1,3);
        v_tor.naam_vgc         := vertaal_tekst(r_tln.landcode,v_tor.naam);
        v_tor.adres_vgc        := vertaal_tekst(r_tln.landcode,v_tor.adres);
        v_tor.plaats_vgc       := vertaal_tekst(r_tln.landcode,v_tor.plaats);
        v_tor.postcode_vgc     := vertaal_tekst(r_tln.landcode,v_tor.postcode);
        v_tor.herkomst         := 'TNT';
        v_tor.creation_date    := l_sysdate;
        v_tor.created_by       := l_user;
        v_tor.last_update_date := l_sysdate;
        v_tor.last_updated_by  := l_user;
        --
        vgc_blg.write_log('Verwerken: ' || v_tor.naam, v_objectnaam, 'J' , 5);
        --
        BEGIN
          INSERT INTO vgc_tnt_operators VALUES v_tor;

        EXCEPTION
          WHEN dup_val_on_index
          THEN
            UPDATE vgc_tnt_operators  tor
            SET  tor.naam  = v_tor.naam
            ,    tor.adres = v_tor.adres
            ,    tor.postcode = v_tor.postcode
            ,    tor.plaats = v_tor.plaats
            ,    tor.naam_vgc  = v_tor.naam_vgc
            ,    tor.adres_vgc = v_tor.adres_vgc
            ,    tor.postcode_vgc = v_tor.postcode_vgc
            ,    tor.plaats_vgc = v_tor.plaats_vgc
            ,    tor.tnt_nummer = v_tor.tnt_nummer
            ,    tor.tnt_nummer_type = v_tor.tnt_nummer_type
            ,    tor.last_update_date = l_sysdate
            ,    tor.last_updated_by  = l_user
            WHERE tor.tnt_id = v_tor.tnt_id
            ;
          WHEN OTHERS
          THEN
            vgc_blg.write_log('Exception: '|| SQLERRM, v_objectnaam, 'N', 1);
            RAISE;
        END;
        --
        OPEN c_tor (i_tnt_id => v_tor.tnt_id);
        FETCH c_tor into l_tor_id;
        CLOSE c_tor;
        --
        -- eerst ontkoppelen van oude activiteiten
        --
        DELETE FROM vgc_tnt_tor_tay tty
        WHERE tty.tor_id = l_tor_id
        ;
        --
        -- activiteiten
        --
        FOR r_xml_tay IN c_xml_tay(v_xml_tay, v_xmlns3)
        LOOP
          vgc_blg.write_log('Loop activiteiten: ' || r_xml_tay.hoofdstuk||'*'||r_xml_tay.sectie||'*'||r_xml_tay.type, v_objectnaam, 'J', 5);

         DECLARE
            v_tay vgc_tnt_activiteiten%ROWTYPE;
            v_tty vgc_tnt_tor_tay%ROWTYPE;
          BEGIN
            v_tay.id               := vgc_tay_seq1.nextval;
            v_tay.status           := r_xml_tay.status;
            v_tay.hoofdstuk        := r_xml_tay.hoofdstuk;
            v_tay.sectie           := r_xml_tay.sectie;
            v_tay.type             := r_xml_tay.type;
            v_tay.creation_date    := l_sysdate;
            v_tay.created_by       := l_user;
            v_tay.last_update_date := l_sysdate;
            v_tay.last_updated_by  := l_user;
            --
            BEGIN
              INSERT INTO vgc_tnt_activiteiten
              VALUES v_tay;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_activiteiten tay
                  SET tay.status           = v_tay.status
                  ,   tay.last_update_date = v_tay.last_update_date
                  ,   tay.last_updated_by  = v_tay.last_updated_by
                WHERE tay.hoofdstuk = v_tay.hoofdstuk
                  AND tay.sectie = v_tay.sectie
                  AND tay.type    = v_tay.type
                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
            --
            OPEN c_tay (i_hoofdstuk => v_tay.hoofdstuk, i_sectie => v_tay.sectie, i_type => v_tay.type);
            FETCH c_tay into l_tay_id;
            CLOSE c_tay;
            --
            -- koppelen activiteit met operator
            --
            v_tty.id                   := vgc_tty_seq1.nextval;
            v_tty.tor_id               := l_tor_id;
            v_tty.tay_id               := l_tay_id;
            v_tty.tnt_id               := r_xml_tay.tnt_id;
            v_tty.erkenningsnummer     := ltrim(rtrim(REPLACE(REPLACE(REPLACE(r_xml_tay.erkenningsnummer,chr(38)||'apos;',''''),chr(38)||'amp;','&'),chr(38)||'quot;','"')));
            v_tty.erkenningsnummer_vgc := vertaal_tekst(r_tln.landcode,v_tty.erkenningsnummer);
            v_tty.creation_date        := l_sysdate;
            v_tty.created_by           := l_user;
            v_tty.last_update_date     := l_sysdate;
            v_tty.last_updated_by      := l_user;
            BEGIN
              INSERT INTO vgc_tnt_tor_tay
              VALUES v_tty;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_tor_tay tty
                  SET tty.erkenningsnummer     = v_tty.erkenningsnummer
                  ,   tty.erkenningsnummer_vgc = v_tty.erkenningsnummer_vgc
                  ,   tty.tnt_id               = v_tty.tnt_id
                  ,   tty.last_update_date     = v_tty.last_update_date
                  ,   tty.last_updated_by      = v_tty.last_updated_by
                WHERE tty.tor_id = v_tty.tor_id
                AND   tty.tay_id = v_tty.tay_id
                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
          EXCEPTION
            WHEN OTHERS
            THEN
              RAISE;
          END;
        END LOOP;
        --
        -- regios
        --
        FOR r_xml_tro IN c_xml_tro(v_xml_tro, v_xmlns3)
        LOOP
          vgc_blg.write_log('Loop regios: ' || r_xml_tro.regio, v_objectnaam, 'J', 5);
         IF nvl(r_xml_tro.regio,'*') = '*'
         THEN
           exit;
         END IF;

         DECLARE
            v_tro vgc_tnt_regios%ROWTYPE;
            v_tto vgc_tnt_tor_tro%ROWTYPE;
          BEGIN
            v_tro.id               := vgc_tro_seq1.nextval;
            v_tro.naam             := r_xml_tro.regio;
            v_tro.creation_date    := l_sysdate;
            v_tro.created_by       := l_user;
            v_tro.last_update_date := l_sysdate;
            v_tro.last_updated_by  := l_user;
            --
            BEGIN
              INSERT INTO vgc_tnt_regios
              VALUES v_tro;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_regios tro
                  SET tro.last_update_date = v_tro.last_update_date
                  ,   tro.last_updated_by  = v_tro.last_updated_by
                WHERE tro.naam  = v_tro.naam
                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
            --
            OPEN c_tro (i_naam => v_tro.naam);
            FETCH c_tro into l_tro_id;
            CLOSE c_tro;
            --
            -- koppelen regio met operator
            --
            v_tto.id               := vgc_tto_seq1.nextval;
            v_tto.tor_id           := l_tor_id;
            v_tto.tro_id           := l_tro_id;
            v_tto.creation_date    := l_sysdate;
            v_tto.created_by       := l_user;
            v_tto.last_update_date := l_sysdate;
            v_tto.last_updated_by  := l_user;
            BEGIN
              INSERT INTO vgc_tnt_tor_tro
              VALUES v_tto;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_tor_tro tto
                  SET tto.last_update_date = v_tto.last_update_date
                  ,   tto.last_updated_by  = v_tto.last_updated_by
                WHERE tto.tor_id = v_tto.tor_id
                AND   tto.tro_id = v_tto.tro_id
                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
        EXCEPTION
          WHEN OTHERS
          THEN
            RAISE;
        END;
      END LOOP;
      EXCEPTION
        WHEN OTHERS
        THEN
          vgc_blg.write_log('Exception: '|| SQLERRM, v_objectnaam, 'N', 1);
          RAISE;
      END;
      l_offset := l_offset + 1;
    END LOOP;
    --
    COMMIT;
    --
    IF l_operator_count > 150
    THEN
      v_einde := FALSE;
    ELSE
      v_einde := TRUE;
    END IF;  
    --
    if v_einde
    then
      vgc_blg.write_log('Einde: verwerk', v_objectnaam, 'J', 5);
    else
      vgc_blg.write_log('Einde naar volgende: verwerk', v_objectnaam, 'J', 5);
     end if;
    RETURN v_einde;
  EXCEPTION
    WHEN OTHERS
    THEN
      IF c_tln%ISOPEN
      THEN
        CLOSE c_tln;
      END IF;

      ROLLBACK;
      RETURN TRUE;

  END verwerk;

--
-- voert synchronisatie uit voor het opgegeven retrieval_type
--
  PROCEDURE sync
  IS
    v_page_number         NUMBER(9)       := 0;
    v_verwerking_klaar    BOOLEAN         := FALSE;

  BEGIN
    vgc_blg.write_log('Start: sync', v_objectnaam, 'J', 5);
    v_verwerking_klaar := FALSE;
    v_page_number := 0;
    WHILE v_verwerking_klaar = FALSE
    LOOP
      vgc_blg.write_log('IN loop: ' || SQLERRM, v_objectnaam, 'J', 5);
      -- initialiseren request
      r_rqt.request_id := NULL;
      r_rqt.status := vgc_ws_requests_nt.kp_in_uitvoering;
      r_rqt.resultaat := k_operation;
      -- opstellen bericht
      maak_bericht(l_offset);
   --   maak_bericht(v_page_number);
      -- aanroepen webservice
      vgc_ws_requests_nt.maak_http_request (r_rqt);
      COMMIT;
      -- indien fout bij aanroepen webservice geef foutmelding en stop verwerking
      IF r_rqt.webservice_returncode = 500
      THEN
        v_result := 'Fout bij ophalen van operator in TNT';
      ELSIF r_rqt.webservice_returncode = 200
      THEN
        v_result := 'OK';
      ELSE
        vgc_blg.write_log('Webservice geeft http-code: ' || r_rqt.webservice_returncode, v_objectnaam, 'J', 5);
        v_result := 'Webservice geeft http-code: ' || r_rqt.webservice_returncode;
        raise_application_error(-20000, 'VGC-00502 #1' || v_ws_naam ||': 3Webservice geeft HTTP-code: ' || r_rqt.webservice_returncode);
      END IF;
      --
      vgc_blg.write_log('Voor escape_xml', v_objectnaam, 'J', 5);
      --escape_xml(r_rqt.webservice_antwoord);
      --update vgc_requests
      --s--et cim_importaangifte = r_rqt.webservice_antwoord
      --where request_id = r_rqt.request_id;
      --commit;
      vgc_blg.write_log('Voor v_antwoord', v_objectnaam, 'J', 5);
      select xmltype(r_rqt.webservice_antwoord) into v_antwoord
      from vgc_requests rqt
      where rqt.request_id = r_rqt.request_id;
      -- Verwerk indien nodig het gewijzigde wachtwoord
      --check_password_reset(i_response => v_antwoord);
      -- verwerk response
     vgc_blg.write_log('Voor v_verwerking_klaar', v_objectnaam, 'J', 5);
      v_verwerking_klaar := verwerk;
      v_page_number := v_page_number + 1;
    END LOOP;
    vgc_blg.write_log('Eind: sync', v_objectnaam, 'J', 5);

  EXCEPTION
    WHEN OTHERS
    THEN
      vgc_blg.write_log('Fout bij synchroniseren: ' || SQLERRM, v_objectnaam, 'J', 5);
      RAISE;

  END sync;

  --

BEGIN
  --
  --trace(v_objectnaam);
  vgc_blg.write_log('start', v_objectnaam, 'N', 1);
  vgc_blg.write_log('Landcode: '||p_land_code, v_objectnaam, 'N', 1);
  vgc_blg.write_log('Erkenningsnummer: '||p_erkenningsnummer, v_objectnaam, 'N', 1);
  vgc_blg.write_log('Activiteit: '||p_activiteit, v_objectnaam, 'N', 1);
  vgc_blg.write_log('Naam: '||p_naam, v_objectnaam, 'N', 1);
  vgc_blg.write_log('Postcode: '||p_postcode, v_objectnaam, 'N', 1);
  vgc_blg.write_log('Plaats: '||p_plaats, v_objectnaam, 'N', 1);

  -- initialiseren request
  r_rqt.request_id               := NULL;
  r_rqt.webservice_url           := vgc$algemeen.get_appl_register ('TNT_OPERATOR_WEBSERVICE');
  r_rqt.bestemd_voor             := NULL;
  r_rqt.webservice_logische_naam := 'VGC0701NT';
  --
  sync;
  --
  COMMIT;
  --
  --p_result := REPLACE(REPLACE(REPLACE(v_result,chr(38)||'apos;',''''),chr(38)||'amp;','"'),chr(38)||'quot;','"');
  --
  --vgc_blg.write_log('eind '||p_result, v_objectnaam, 'N', 1); /*#2*/
  --
EXCEPTION
  WHEN resource_busy
  THEN
    ROLLBACK;
    RAISE;
  WHEN OTHERS
  THEN
    vgc_blg.write_log('Exception2: '|| SQLERRM, v_objectnaam, 'N', 1);
    ROLLBACK;
    qms$errors.unhandled_exception(v_objectnaam);

END VGC0701NT;
--
/* Ophalen van de postcodegegevens uit TRACES-NT */

PROCEDURE VGC0702NT
 (P_LAND_CODE IN VARCHAR2
 ,P_POSTCODE IN VARCHAR2
 ,P_PLAATS IN VARCHAR2
 )
 IS
 PRAGMA AUTONOMOUS_TRANSACTION;
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.VGC0702NT#1';
/*********************************************************************
Wijzigingshistorie
doel:
Ophalen van de organisatiegegevens uit TRACES-NT

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
   1    16-07-2021 GLR     creatie
*********************************************************************/

--
  k_operation             CONSTANT  VARCHAR2(19 CHAR)                           := 'searchCity';
  v_antwoord              xmltype;
  v_cities                xmltype;
  v_ws_naam               VARCHAR2(100 CHAR) := 'retrieveGeographicData';
  l_timestamp_char        VARCHAR2(100);
  l_trx_timestamp_char    VARCHAR2(100);
  v_username              VARCHAR2(100);
  v_password              VARCHAR2(100);
  l_CreateTimestampString VARCHAR2(100);
  l_ExpireTimestampString VARCHAR2(100);
  v_timestamp             TIMESTAMP;
  l_nonce_raw             RAW(100);
  l_nonce_b64             VARCHAR2(24);
  l_password_digest_b64   VARCHAR2(100);
  l_offset                INTEGER := 0;
  v_result                VARCHAR2(200 CHAR);


  r_rqt                            vgc_requests%ROWTYPE;
  resource_busy                    EXCEPTION;
  PRAGMA EXCEPTION_INIT( resource_busy, -54 );
--
-- Stelt bericht op voor aanroep
--
  PROCEDURE maak_bericht(l_offset IN INTEGER)
  IS
  --
    CURSOR c_xml
    IS
      SELECT c_encoding ||
             xmlelement("soapenv:Envelope"
      ,        xmlattributes ( 'http://schemas.xmlsoap.org/soap/envelope/' AS "xmlns:soapenv"
                             , 'http://ec.europa.eu/sanco/tracesnt/base/v4' AS "xmlns:v4"
                             , 'http://ec.europa.eu/tracesnt/directory/geo/v1' as "xmlns:v1"
                             , 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'  AS "xmlns:oas")
      ,        xmlelement("soapenv:Header"
      ,          xmlattributes( 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd' AS "xmlns:wsse"
                              , 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'  AS "xmlns:wsu")
      ,          xmlelement("wsse:Security"
      ,            xmlelement("wsse:UsernameToken"
      ,            xmlattributes( 'UsernameToken-A5B8D7123A55CB6A75153751937547586' AS "wsu:Id" )
      ,              xmlelement("wsse:Username", v_username)
      ,              xmlelement("wsse:Password"
      ,                xmlattributes( 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest' AS "Type" )
      ,                l_password_digest_b64)
      ,              xmlelement("wsse:Nonce", l_nonce_b64)
      ,              xmlelement("wsu:Created", l_CreateTimestampString)
                   )
      ,            xmlelement("wsu:Timestamp"
      ,              xmlelement("wsu:Created", l_CreateTimestampString)
      ,              xmlelement("wsu:Expires", l_ExpireTimestampString)
                   )
                 )
      ,          xmlelement("v4:LanguageCode",'nl')
      ,          xmlelement("v4:WebServiceClientId",'vgc-client')
               )
      ,        xmlelement("soapenv:Body"
      ,          xmlattributes( 'http://schemas.xmlsoap.org/soap/envelope/' AS "xmlns:soapenv")
       ,         xmlelement("v1:SearchCityRequest"
      ,            xmlattributes( 'http://ec.europa.eu/tracesnt/directory/geo/v1' AS "xmlns:v1"
      ,                           'CITY_NAME' AS "sortPredicate"
      ,                           'true'  AS "sortAscending"
      ,                           '200'     AS "pageSize"
      ,                           l_offset  AS "offset")
      ,            CASE WHEN p_plaats is not null
                   THEN
                     xmlelement("v1:CityName", p_plaats)
                   END
      ,            CASE WHEN p_postcode is not null
                   THEN
                     xmlelement("v1:PostalCode", p_postcode)
                   END
      ,            xmlelement("v1:CountryID", upper(p_land_code))
      ,            xmlelement("v1:Status", 'VALID' )
                            )
              )
             ).getClobval()
      FROM dual
    ;

  BEGIN
  -- Ophalen credentials
    v_username := vgc$algemeen.get_appl_register('TNT_USERNAME');
    v_password := vgc$algemeen.get_appl_register('TNT_PASSWORD');
  --
    v_timestamp := SYSTIMESTAMP;
    l_timestamp_char      := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
    l_trx_timestamp_char  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM');
    l_nonce_raw           := utl_i18n.string_to_raw(dbms_random.string('a',16),'utf8');
    l_nonce_b64           := utl_i18n.raw_to_char(utl_encode.base64_encode(l_nonce_raw),'utf8');
    l_password_digest_b64 := utl_i18n.raw_to_char
                           ( utl_encode.base64_encode
                             ( dbms_crypto.hash
                               ( l_nonce_raw||utl_i18n.string_to_raw(l_timestamp_char||v_password,'utf8')
                               , dbms_crypto.hash_sh1
                               )
                             )
                           , 'utf8'
                           );
  --
    l_CreateTimestampString := TO_CHAR(v_timestamp,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
    v_timestamp :=v_timestamp + 3/1440;
    l_ExpireTimestampString := TO_CHAR(v_timestamp,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
  -- Opstellen bericht
    OPEN c_xml;
    FETCH c_xml INTO  r_rqt.webservice_bericht;
    CLOSE c_xml;
    escape_xml(r_rqt.webservice_bericht);
    --
  EXCEPTION
    WHEN OTHERS
    THEN
      IF c_xml%ISOPEN
      THEN
        CLOSE c_xml;
      END IF;
      RAISE;
  END maak_bericht;
  --

-- Verwerkt het binnengekomen resultaat
--
  FUNCTION verwerk RETURN BOOLEAN
  IS
    v_einde             boolean := false;
    l_sysdate           DATE := SYSDATE;
    l_user              VARCHAR2(35 CHAR) := USER;
    l_tpc_id            NUMBER;
    l_tay_id            NUMBER;
    l_tro_id            NUMBER;
    -- tijdelijke variabelen voor verwerken XML
    v_xml_tpc           xmltype;
    v_xml_tro           xmltype;
    v_xml_tay           xmltype;
    --
    v_generalOperationResult      VARCHAR2(200 CHAR);
    v_specificOperationResult     VARCHAR2(200 CHAR);
    v_xmlns1                      VARCHAR2(2000 CHAR) :=  'xmlns:ns7="http://ec.europa.eu/tracesnt/directory/operator/v1"';
    v_xmlns2                      VARCHAR2(2000 CHAR) :=  'xmlns:ns7="http://ec.europa.eu/tracesnt/directory/operator/v1"';
    v_xmlns3                      VARCHAR2(2000 CHAR) :=  'xmlns:ns7="http://ec.europa.eu/tracesnt/directory/operator/v1"'||' xmlns:ns3="http://ec.europa.eu/tracesnt/directory/common/v1"'||
                                                          ' xmlns:ns4="http://ec.europa.eu/tracesnt/directory/geo/city/v1"';
    v_xmlns                       VARCHAR2(2000 CHAR) :=  'xmlns:ns2="http://ec.europa.eu/sanco/tracesnt/base/v4" xmlns:ns3="http://ec.europa.eu/tracesnt/directory/common/v1" '||
                                                          'xmlns:ns4="http://ec.europa.eu/tracesnt/directory/geo/city/v1" xmlns:ns5="http://ec.europa.eu/tracesnt/directory/geo/region/v1" '||
                                                          'xmlns:ns6="http://ec.europa.eu/tracesnt/directory/geo/country/v1" xmlns:ns7="http://ec.europa.eu/tracesnt/directory/geo/v1" ';
                                                        --  'xmlns:ns8="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" xmlns:ns9="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd" xmlns:ns10="http://www.w3.org/2000/09/xmldsig#" xmlns:ns11="http://ec.europa.eu/tracesnt/body/v3" xmlns:ns12="urn:un:unece:uncefact:codelist:standard:ISO:ISO2AlphaLanguageCode:2006-10-27" pageSize=
    v_response                    xmltype;
    v_operatorsstr                clob;
    -- Query voor uitlezen organisaties uit response
    CURSOR c_tpc(i_xml xmltype, i_ns varchar2)
    IS
      SELECT extract(VALUE(tpc), '/ns7:CityIndex/@status',i_ns).getStringVal()   status
      ,      extract(VALUE(tpc), '/ns7:CityIndex/ns4:NamePostalCode',i_ns)  postcodes
      ,      extract(VALUE(tpc), '/ns7:CityIndex/ns4:CountryID/text()',i_ns).getStringVal()  land_code
      ,      extract(VALUE(tpc), '/ns7:CityIndex/ns4:Region', i_ns) regios
      FROM TABLE( xmlsequence(i_xml)) tpc
    ;
    --
    CURSOR c_xml_tpc(i_xml xmltype, i_ns VARCHAR2)
    IS
      SELECT extract(VALUE(rqt), '//ns4:NamePostalCode/@internalID', i_ns).getStringVal()  tnt_id
      ,      extract(VALUE(rqt), '//ns4:NamePostalCode/@status',i_ns).getStringVal()  status
      ,      extract(VALUE(rqt), '//ns4:NamePostalCode/ns4:Name/text()',i_ns).getStringVal()  plaats
      ,      extract(VALUE(rqt), '//ns4:NamePostalCode/ns4:PostalCode/text()',i_ns).getStringVal()  postcode
      FROM TABLE( xmlsequence(i_xml)) rqt
    ;
    --
    CURSOR c_xml_tro(i_xml xmltype, i_ns VARCHAR2)
    IS
      SELECT extract(VALUE(rqt), '//ns4:Region/ns5:Name/text()', i_ns).getStringVal() regio
      FROM TABLE( xmlsequence(i_xml)) rqt
    ;
   --
    CURSOR c_tps(i_land_code vgc_tnt_postcodes.land_code%TYPE
    ,            i_postcode vgc_tnt_postcodes.postcode%TYPE
    ,            i_stadsnaam_traces_nt vgc_tnt_postcodes.stadsnaam_traces_nt%TYPE
                )
    IS
      SELECT id
      FROM   vgc_tnt_postcodes
      WHERE  land_code = i_land_code
      AND    vertaal_tekst(i_land_code,nvl(postcode,'#$')) = nvl(i_postcode,'#$')
      AND    stadsnaam_traces_nt = i_stadsnaam_traces_nt
    ;
   --
    CURSOR c_tro(i_naam vgc_tnt_regios.naam%TYPE)
    IS
      SELECT id
      FROM   vgc_tnt_regios
      WHERE  naam = i_naam
    ;
    --
  BEGIN
    vgc_blg.write_log('Start: verwerk', v_objectnaam, 'J', 5);
    -- init variabelen voor verwerken
    v_response           :=  vgc_xml.extractxml(v_antwoord, '//ns7:SearchCityResponse', v_xmlns);
    vgc_blg.write_log('Lengte: 1', v_objectnaam, 'J' , 5);
    v_cities             :=  vgc_xml.extractxml(v_response, '//ns7:CityIndex',v_xmlns);
    vgc_blg.write_log('Lengte: 2', v_objectnaam, 'J' , 5);
    v_operatorsstr       :=  vgc_xml.extractxml_str(v_response, '//ns7:CityIndex/@status', v_xmlns);
    l_offset             :=  vgc_xml.extractxml_str(v_response, '//ns7:SearchCityResponse/@offset', v_xmlns);
    --
    vgc_blg.write_log('Lengte: ' || nvl(dbms_lob.getlength(v_operatorsstr),0)||' * '||l_offset, v_objectnaam, 'J' , 5);
    IF nvl(length(v_operatorsstr),0) = 0
    THEN
     vgc_blg.write_log('Einde Lengte: ' || nvl(dbms_lob.getlength(v_operatorsstr),0)||' * '||nvl(length(v_operatorsstr),-1), v_objectnaam, 'J' , 5);
      v_einde := true;
    END IF;
    --
    -- verwerk organisaties
    --
    FOR r_tpc IN c_tpc(v_cities, v_xmlns)
    LOOP
      vgc_blg.write_log('Verwerken: ' || r_tpc.land_code||r_tpc.status, v_objectnaam, 'J' , 5);

      DECLARE
        CURSOR c_tpe ( b_land_code IN vgc_tnt_postcodes.land_code%TYPE
                     , b_postcode vgc_tnt_postcodes.postcode%TYPE
                     , b_stadsnaam_traces_nt vgc_tnt_postcodes.stadsnaam_traces_nt%TYPE)
        IS
          SELECT vertaal_tekst(b_land_code,stadsnaam_vgc)
          FROM   vgc_tnt_postcodes tpe
          WHERE  tpe.land_code = b_land_code
          AND    tpe.postcode = b_postcode
          AND    upper(tpe.stadsnaam_traces_nt) = upper(b_stadsnaam_traces_nt)
        ;

        v_plaats vgc_tnt_operators.plaats%TYPE;
        v_tpc vgc_tnt_postcodes%ROWTYPE;

      BEGIN
        --
        -- vul rij met waarden
        --
        v_xml_tpc              := r_tpc.postcodes;
        v_xml_tro              := r_tpc.regios;
        --
        FOR r_xml_tpc IN c_xml_tpc(v_xml_tpc, v_xmlns)
        LOOP
          --
          IF nvl(r_xml_tpc.postcode,'*') = nvl(p_postcode,nvl(r_xml_tpc.postcode,'*'))
          THEN
            v_tpc.id               := vgc_tpc_seq1.nextval;
            v_tpc.tnt_id           := r_xml_tpc.tnt_id;
            IF r_tpc.status = 'DELETED' OR r_xml_tpc.status = 'DELETED'
            THEN
              v_tpc.status           := 'DELETED';
            ELSE
              v_tpc.status           := 'ACTIVE';
            END IF;
            v_tpc.stadsnaam_traces_nt   := substr(REPLACE(REPLACE(REPLACE(r_xml_tpc.plaats,chr(38)||'apos;',''''),chr(38)||'amp;','"'),chr(38)||'quot;','"'),1,100);
            --
            OPEN c_tpe (b_land_code => r_tpc.land_code
                       ,b_postcode => r_xml_tpc.postcode
                       ,b_stadsnaam_traces_nt => v_tpc.stadsnaam_traces_nt);
            FETCH c_tpe INTO v_plaats;
            CLOSE c_tpe;
            --
            v_tpc.stadsnaam_vgc       := nvl(v_plaats, vertaal_tekst(r_tpc.land_code,v_tpc.stadsnaam_traces_nt));
            v_tpc.stadsnaam_uppercase := upper(nvl(v_tpc.stadsnaam_vgc,v_tpc.stadsnaam_traces_nt));
            v_tpc.postcode            := substr(nvl(vertaal_tekst(r_tpc.land_code,r_xml_tpc.postcode),nvl(v_tpc.stadsnaam_vgc,v_tpc.stadsnaam_traces_nt)),1,100);
            v_tpc.land_code           := substr(nvl(r_tpc.land_code,'XX'),1,3);
            v_tpc.creation_date       := l_sysdate;
            v_tpc.created_by          := l_user;
            v_tpc.last_update_date    := l_sysdate;
            v_tpc.last_updated_by     := l_user;
            --
            IF v_tpc.stadsnaam_traces_nt is not null
            AND r_tpc.land_code != 'NL'
            THEN
              BEGIN
                 INSERT INTO vgc_tnt_postcodes VALUES v_tpc;

              EXCEPTION
                WHEN dup_val_on_index
                THEN
                  UPDATE vgc_tnt_postcodes  tpc
                  SET  tpc.tnt_id = v_tpc.tnt_id
                  ,    tpc.postcode = v_tpc.postcode
                  ,    tpc.stadsnaam_vgc = v_tpc.stadsnaam_vgc
                  ,    tpc.stadsnaam_traces_nt = v_tpc.stadsnaam_traces_nt
                  ,    tpc.stadsnaam_uppercase = nvl(upper(v_tpc.stadsnaam_vgc), v_tpc.stadsnaam_uppercase)
                  ,    tpc.land_code = v_tpc.land_code
                  ,    tpc.status = v_tpc.status
                  ,    tpc.last_update_date = l_sysdate
                  ,    tpc.last_updated_by  = l_user
                  WHERE tpc.tnt_id = v_tpc.tnt_id
                  OR    (tpc.tnt_id is null
                  AND   tpc.land_code = v_tpc.land_code
                  AND   tpc.postcode = v_tpc.postcode
                  AND   tpc.stadsnaam_traces_nt = v_tpc.stadsnaam_traces_nt)
                  ;
                WHEN OTHERS
                THEN
                  vgc_blg.write_log('Exception: '|| SQLERRM, v_objectnaam, 'N', 1);
                  RAISE;
              END;
                --
              OPEN c_tps (i_land_code => v_tpc.land_code
                         ,i_postcode => v_tpc.postcode
                         ,i_stadsnaam_traces_nt => v_tpc.stadsnaam_traces_nt);
              FETCH c_tps into l_tpc_id;
              CLOSE c_tps;
              --
              -- regios
              --
              FOR r_xml_tro IN c_xml_tro(v_xml_tro, v_xmlns)
              LOOP
                vgc_blg.write_log('Loop regios: ' || r_xml_tro.regio, v_objectnaam, 'J', 5);
                IF nvl(r_xml_tro.regio,'*') = '*'
                THEN
                  exit;
                END IF;

                DECLARE
                  v_tro vgc_tnt_regios%ROWTYPE;
                  v_tpr vgc_tnt_tpc_tro%ROWTYPE;
                BEGIN
                  v_tro.id               := vgc_tro_seq1.nextval;
                  v_tro.naam             := r_xml_tro.regio;
                  v_tro.creation_date    := l_sysdate;
                  v_tro.created_by       := l_user;
                  v_tro.last_update_date := l_sysdate;
                  v_tro.last_updated_by  := l_user;
                  --
                  BEGIN
                    INSERT INTO vgc_tnt_regios
                    VALUES v_tro;
                  EXCEPTION
                    WHEN dup_val_on_index
                    THEN
                     UPDATE vgc_tnt_regios tro
                        SET tro.last_update_date = v_tro.last_update_date
                        ,   tro.last_updated_by  = v_tro.last_updated_by
                      WHERE tro.naam  = v_tro.naam
                      ;
                    WHEN OTHERS
                    THEN
                     RAISE;
                  END;
                  --
                  OPEN c_tro (i_naam => v_tro.naam);
                  FETCH c_tro into l_tro_id;
                  CLOSE c_tro;
                  --
                  -- koppelen regio met operator
                  --
                  v_tpr.id               := vgc_tpr_seq1.nextval;
                  v_tpr.tpc_id           := l_tpc_id;
                  v_tpr.tro_id           := l_tro_id;
                  v_tpr.creation_date    := l_sysdate;
                  v_tpr.created_by       := l_user;
                  v_tpr.last_update_date := l_sysdate;
                  v_tpr.last_updated_by  := l_user;
                  BEGIN
                    INSERT INTO vgc_tnt_tpc_tro
                    VALUES v_tpr;
                  EXCEPTION
                    WHEN dup_val_on_index
                    THEN
                     UPDATE vgc_tnt_tpc_tro tpr
                        SET tpr.last_update_date = v_tpr.last_update_date
                        ,   tpr.last_updated_by  = v_tpr.last_updated_by
                      WHERE tpr.tpc_id = v_tpr.tpc_id
                      AND   tpr.tro_id = v_tpr.tro_id
                      ;
                    WHEN OTHERS
                    THEN
                     RAISE;
                  END;
                EXCEPTION
                  WHEN OTHERS
                  THEN
                    RAISE;
                END;
              END LOOP;
            END IF;
          END IF;
      end loop;

      EXCEPTION
        WHEN OTHERS
        THEN
          vgc_blg.write_log('Exception: '|| SQLERRM, v_objectnaam, 'N', 1);
          RAISE;
      END;
      l_offset := l_offset + 1;
    END LOOP;
    --
    IF p_plaats IS NULL
    THEN
    -- postcodes
      UPDATE vgc_tnt_postcodes
      SET status = 'DELETED'
      , last_update_date = sysdate
      WHERE land_code = p_land_code
      AND   postcode = p_postcode
      AND   trunc(last_update_date) != trunc(sysdate)
      ;
    ELSE
      -- plaatsnaam
      UPDATE vgc_tnt_postcodes
      SET status = 'DELETED'
      , last_update_date = sysdate
      WHERE land_code = p_land_code
      AND   stadsnaam_uppercase = upper(p_plaats)
      AND   trunc(last_update_date) != trunc(sysdate)
      ;
    END IF;
    --
    COMMIT;
    --
    if v_einde
    then
      vgc_blg.write_log('Einde: verwerk', v_objectnaam, 'J', 5);
    else
      vgc_blg.write_log('Einde naar volgende: verwerk', v_objectnaam, 'J', 5);
     end if;
    RETURN v_einde;
  EXCEPTION
    WHEN OTHERS
    THEN
      IF c_tpc%ISOPEN
      THEN
        CLOSE c_tpc;
      END IF;

      ROLLBACK;
      RETURN TRUE;

  END verwerk;

--
-- voert synchronisatie uit voor het opgegeven retrieval_type
--
  PROCEDURE sync
  IS
    v_page_number         NUMBER(9)       := 0;
    v_verwerking_klaar    BOOLEAN         := FALSE;

  BEGIN
    vgc_blg.write_log('Start: sync', v_objectnaam, 'J', 5);
    v_verwerking_klaar := FALSE;
    v_page_number := 0;
    WHILE v_verwerking_klaar = FALSE
    LOOP
      vgc_blg.write_log('IN loop: ' || SQLERRM, v_objectnaam, 'J', 5);
      -- initialiseren request
      r_rqt.request_id := NULL;
      r_rqt.status := vgc_ws_requests_nt.kp_in_uitvoering;
      r_rqt.resultaat := k_operation;
      -- opstellen bericht
      maak_bericht(l_offset);
   --   maak_bericht(v_page_number);
      -- aanroepen webservice
      vgc_ws_requests_nt.maak_http_request (r_rqt);
      COMMIT;
      -- indien fout bij aanroepen webservice geef foutmelding en stop verwerking
      IF r_rqt.webservice_returncode = 500
      THEN
        v_result := 'Fout bij ophalen van postcode in TNT';
      ELSIF r_rqt.webservice_returncode = 200
      THEN
        v_result := 'OK';
      ELSE
        vgc_blg.write_log('Webservice geeft http-code: ' || r_rqt.webservice_returncode, v_objectnaam, 'J', 5);
        v_result := 'Webservice geeft http-code: ' || r_rqt.webservice_returncode;
        raise_application_error(-20000, 'VGC-00502 #1' || v_ws_naam ||': 3Webservice geeft HTTP-code: ' || r_rqt.webservice_returncode);
      END IF;
      --
      vgc_blg.write_log('Voor escape_xml', v_objectnaam, 'J', 5);
      --escape_xml(r_rqt.webservice_antwoord);
      --update vgc_requests
      --s--et cim_importaangifte = r_rqt.webservice_antwoord
      --where request_id = r_rqt.request_id;
      --commit;
      vgc_blg.write_log('Voor v_antwoord', v_objectnaam, 'J', 5);
      select xmltype(r_rqt.webservice_antwoord) into v_antwoord
      from vgc_requests rqt
      where rqt.request_id = r_rqt.request_id;
      -- Verwerk indien nodig het gewijzigde wachtwoord
      --check_password_reset(i_response => v_antwoord);
      -- verwerk response
      vgc_blg.write_log('Voor v_verwerking_klaar', v_objectnaam, 'J', 5);
      v_verwerking_klaar := verwerk;
      v_page_number := v_page_number + 1;
    END LOOP;
    vgc_blg.write_log('Eind: sync', v_objectnaam, 'J', 5);

  EXCEPTION
    WHEN OTHERS
    THEN
      vgc_blg.write_log('Fout bij synchroniseren: ' || SQLERRM, v_objectnaam, 'J', 5);
      RAISE;

  END sync;

  --

BEGIN
  --
  --trace(v_objectnaam);
  vgc_blg.write_log('start', v_objectnaam, 'N', 1);
  vgc_blg.write_log('Landcode: '||p_land_code, v_objectnaam, 'N', 1);
  vgc_blg.write_log('Postcode: '||p_postcode, v_objectnaam, 'N', 1);
  vgc_blg.write_log('Plaats: '||p_plaats, v_objectnaam, 'N', 1);

  -- initialiseren request
  r_rqt.request_id               := NULL;
  r_rqt.webservice_url           := vgc$algemeen.get_appl_register ('TNT_GEOGRAPHIC_WEBSERVICE');
  r_rqt.bestemd_voor             := NULL;
  r_rqt.webservice_logische_naam := 'VGC0702NT';
  --
  sync;
  --
  COMMIT;
  --
  vgc_blg.write_log('eind', v_objectnaam, 'N', 1); /*#2*/
  --
EXCEPTION
  WHEN resource_busy
  THEN
    ROLLBACK;
    RAISE;
  WHEN OTHERS
  THEN
    vgc_blg.write_log('Exception: '|| SQLERRM, v_objectnaam, 'N', 1);
    ROLLBACK;
    qms$errors.unhandled_exception(v_objectnaam);

END VGC0702NT;
--
/* Ophalen van de organisatiegegevens uit TRACES-NT met activity-id*/

PROCEDURE VGC0703NT
 (P_NUMMER IN VARCHAR2
 )
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.VGC0703NT#1';
/*********************************************************************
Wijzigingshistorie
doel:
Ophalen van de organisatiegegevens uit TRACES-NT

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
   1    19-08-2022 GLR     creatie
*********************************************************************/

--
  k_operation             CONSTANT  VARCHAR2(30 CHAR)                           := 'getOperatorByActivity';
  v_antwoord              xmltype;
  v_operators             xmltype;
  v_ws_naam               VARCHAR2(100 CHAR) := 'retrieveOperatorData';
  v_result                VARCHAR2(200 CHAR);
  l_timestamp_char        VARCHAR2(100 CHAR);
  l_trx_timestamp_char    VARCHAR2(100 CHAR);
  v_username              VARCHAR2(100 CHAR);
  v_password              VARCHAR2(100 CHAR);
  l_CreateTimestampString VARCHAR2(100 CHAR);
  l_ExpireTimestampString VARCHAR2(100 CHAR);
  v_timestamp             TIMESTAMP;
  l_nonce_raw             RAW(100);
  l_nonce_b64             VARCHAR2(24 CHAR);
  l_password_digest_b64   VARCHAR2(100 CHAR);
  l_offset                INTEGER := 0;



  r_rqt                            vgc_requests%ROWTYPE;
  resource_busy                    EXCEPTION;
  PRAGMA EXCEPTION_INIT( resource_busy, -54 );
--
-- Stelt bericht op voor aanroep
--
  PROCEDURE maak_bericht(l_offset IN INTEGER)
  IS
  --
    CURSOR c_xml
    IS
      SELECT xmlelement("soapenv:Envelope"
      ,        xmlattributes ( 'http://schemas.xmlsoap.org/soap/envelope/' AS "xmlns:soapenv"
                             , 'http://ec.europa.eu/sanco/tracesnt/base/v4' AS "xmlns:v4"
                             , 'http://ec.europa.eu/tracesnt/directory/operator/v1' as "xmlns:v1"
                             , 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd'  AS "xmlns:oas")
      ,        xmlelement("soapenv:Header"
      ,          xmlattributes( 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd' AS "xmlns:wsse"
                              , 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd'  AS "xmlns:wsu")
      ,          xmlelement("wsse:Security"
      ,            xmlelement("wsse:UsernameToken"
      ,            xmlattributes( 'UsernameToken-A5B8D7123A55CB6A75153751937547586' AS "wsu:Id" )
      ,              xmlelement("wsse:Username", v_username)
      ,              xmlelement("wsse:Password"
      ,                xmlattributes( 'http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-username-token-profile-1.0#PasswordDigest' AS "Type" )
      ,                l_password_digest_b64)
      ,              xmlelement("wsse:Nonce", l_nonce_b64)
      ,              xmlelement("wsu:Created", l_CreateTimestampString)
                   )
      ,            xmlelement("wsu:Timestamp"
      ,              xmlelement("wsu:Created", l_CreateTimestampString)
      ,              xmlelement("wsu:Expires", l_ExpireTimestampString)
                   )
                 )
      ,          xmlelement("v4:LanguageCode",'nl')
      ,          xmlelement("v4:WebServiceClientId",'vgc-client')
               )
      ,        xmlelement("soapenv:Body"
      ,          xmlattributes( 'http://schemas.xmlsoap.org/soap/envelope/' AS "xmlns:soapenv")
      ,         xmlelement("v1:GetOperatorByActivityRequest"
      ,            xmlelement("v1:ID", p_nummer)
              )
                         )
             ).getClobval()
      FROM dual
    ;

  BEGIN
  -- Ophalen credentials
    v_username := vgc$algemeen.get_appl_register('TNT_USERNAME');
    v_password := vgc$algemeen.get_appl_register('TNT_PASSWORD');
  --
    v_timestamp := SYSTIMESTAMP;
    l_timestamp_char      := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
    l_trx_timestamp_char  := TO_CHAR(SYSTIMESTAMP,'YYYY-MM-DD"T"HH24:MI:SSTZH:TZM');
    l_nonce_raw           := utl_i18n.string_to_raw(dbms_random.string('a',16),'utf8');
    l_nonce_b64           := utl_i18n.raw_to_char(utl_encode.base64_encode(l_nonce_raw),'utf8');
    l_password_digest_b64 := utl_i18n.raw_to_char
                           ( utl_encode.base64_encode
                             ( dbms_crypto.hash
                               ( l_nonce_raw||utl_i18n.string_to_raw(l_timestamp_char||v_password,'utf8')
                               , dbms_crypto.hash_sh1
                               )
                             )
                           , 'utf8'
                           );
  --
    l_CreateTimestampString := TO_CHAR(v_timestamp,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
    v_timestamp :=v_timestamp + 3/1440;
    l_ExpireTimestampString := TO_CHAR(v_timestamp,'YYYY-MM-DD"T"HH24:MI:SS.FF3"Z"');
  -- Opstellen bericht
    OPEN c_xml;
    FETCH c_xml INTO  r_rqt.webservice_bericht;
    CLOSE c_xml;
    escape_xml(r_rqt.webservice_bericht);
    --
  EXCEPTION
    WHEN OTHERS
    THEN
      IF c_xml%ISOPEN
      THEN
        CLOSE c_xml;
      END IF;
      RAISE;
  END maak_bericht;
  --

-- Verwerkt het binnengekomen resultaat
--
  FUNCTION verwerk RETURN BOOLEAN
  IS
    v_einde             boolean := false;
    l_sysdate           DATE := SYSDATE;
    l_user              VARCHAR2(35 CHAR) := USER;
    l_tor_id            NUMBER;
    l_tay_id            NUMBER;
    l_tro_id            NUMBER;
    -- tijdelijke variabelen voor verwerken XML
    v_xml_tro           xmltype;
    v_xml_tay           xmltype;
    --
    v_generalOperationResult      VARCHAR2(200 CHAR);
    v_specificOperationResult     VARCHAR2(200 CHAR);
    v_xmlns1                      VARCHAR2(2000 CHAR) :=  'xmlns:ns7="http://ec.europa.eu/tracesnt/directory/operator/v1"'||' xmlns:ns0="http://schemas.xmlsoap.org/soap/envelope/"';
    v_xmlns2                      VARCHAR2(2000 CHAR) :=  'xmlns:ns7="http://ec.europa.eu/tracesnt/directory/operator/v1"';
    v_xmlns3                      VARCHAR2(2000 CHAR) :=  'xmlns:ns7="http://ec.europa.eu/tracesnt/directory/operator/v1"'||' xmlns:ns4="http://ec.europa.eu/tracesnt/directory/common/v1"'||
                                                          ' xmlns:ns5="http://ec.europa.eu/tracesnt/directory/geo/city/v1"';
    v_response                    xmltype;
    v_fault                       xmltype;
    v_operatorsstr                clob;
    v_faultstr                    clob;
    -- Query voor uitlezen organisaties uit response
    CURSOR c_tln(i_xml xmltype, i_ns varchar2)
    IS
      SELECT extract(VALUE(tln), '/ns7:Operator/@internalID', i_ns).getStringVal()  tnt_id
      ,      extract(VALUE(tln), '/ns7:Operator/ns7:Name/text()', i_ns).getStringVal() naam
      ,      extract(VALUE(tln), '/ns7:Operator/ns7:Activity', i_ns) activiteiten
      ,      extract(VALUE(tln), '/ns7:Operator/ns7:OperatorAddress[1]/ns7:Address/ns4:Street/text()', i_ns).getStringVal() adres
      ,      extract(VALUE(tln), '/ns7:Operator/ns7:OperatorAddress[1]/ns7:Address/ns4:City/ns5:PostalCode/text()', i_ns).getStringVal() postcode
      ,      extract(VALUE(tln), '/ns7:Operator/ns7:OperatorAddress[1]/ns7:Address/ns4:City/ns5:Name/text()', i_ns).getStringVal() plaats
      ,      extract(VALUE(tln), '/ns7:Operator/ns7:OperatorAddress[1]/ns7:Address/ns4:City/ns5:CountryID/text()', i_ns).getStringVal() landcode
      FROM TABLE( xmlsequence(i_xml)) tln
    ;
/*
    <ns7:GetOperatorByActivityResponse xmlns:ns2="http://ec.europa.eu/sanco/tracesnt/base/v4" xmlns:ns3="http://ec.europa.eu/tracesnt/directory/authority/v1" xmlns:ns4="http://ec.europa.eu/tracesnt/directory/common/v1" xmlns:ns5="http://ec.europa.eu/tracesnt/directory/geo/city/v1" xmlns:ns6="http://ec.europa.eu/tracesnt/directory/geo/region/v1" xmlns:ns7="http://ec.europa.eu/tracesnt/directory/operator/v1" xmlns:ns8="http://ec.europa.eu/tracesnt/directory/ocb/v1" xmlns:ns9="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-utility-1.0.xsd" xmlns:ns10="http://docs.oasis-open.org/wss/2004/01/oasis-200401-wss-wssecurity-secext-1.0.xsd" xmlns:ns11="http://www.w3.org/2000/09/xmldsig#" xmlns:ns12="http://ec.europa.eu/tracesnt/body/v3" xmlns:ns13="urn:un:unece:uncefact:codelist:standard:ISO:ISO2AlphaLanguageCode:2006-10-27">
      <ns7:Operator internalID="1274968">
        <ns7:Name>ACE FOOD SAS</ns7:Name>
        <ns7:OperatorAddress main="true">
          <ns7:Address internalID="1265217">
            <ns4:Street>11 AVENUE DE VERSAILLES .-</ns4:Street>
            <ns4:City internalID="648878">
              <ns5:Name languageID="nl">Parijs</ns5:Name>
              <ns5:PostalCode>75004</ns5:PostalCode>
              <ns5:CountryID>FR</ns5:CountryID>
            </ns4:City>
          </ns7:Address>
        </ns7:OperatorAddress>
        <ns7:Identifier type="comp_reg" name="Nationaal vennootschapsregister">NL0000043218</ns7:Identifier>
        <ns7:Activity internalID="1657112">
          <ns7:ActivityType>
            <ns7:Chapter name="Feed and Food of Non-Animal Origin">non_animal_origin_food_and_feed</ns7:Chapter>
            <ns7:Section name="Feed and Food of Non-Animal Origin">NON_ANIMAL_ORIGIN_FOOD_AND_FEED</ns7:Section>
            <ns7:Type name="Establishment">establishment</ns7:Type>
          </ns7:ActivityType>
          <ns7:Status>NEW</ns7:Status>
          <ns7:Address internalID="1265217">
            <ns4:Street>11 AVENUE DE VERSAILLES .-</ns4:Street>
            <ns4:City internalID="648878">
              <ns5:Name languageID="nl">Parijs</ns5:Name>
              <ns5:PostalCode>75004</ns5:PostalCode>
              <ns5:CountryID>FR</ns5:CountryID>
            </ns4:City>
          </ns7:Address>
        </ns7:Activity>
        <ns7:Activity internalID="1657111">
          <ns7:ActivityType>
            <ns7:Chapter name="Feed and Food of Non-Animal Origin">non_animal_origin_food_and_feed</ns7:Chapter>
            <ns7:Section name="Feed and Food of Non-Animal Origin">NON_ANIMAL_ORIGIN_FOOD_AND_FEED</ns7:Section>
            <ns7:Type name="Importer">importer</ns7:Type>
          </ns7:ActivityType>
          <ns7:Status>NEW</ns7:Status>
          <ns7:Address internalID="1265217">
            <ns4:Street>11 AVENUE DE VERSAILLES .-</ns4:Street>
            <ns4:City internalID="648878">
              <ns5:Name languageID="nl">Parijs</ns5:Name>
              <ns5:PostalCode>75004</ns5:PostalCode>
              <ns5:CountryID>FR</ns5:CountryID>
            </ns4:City>
          </ns7:Address>
        </ns7:Activity>
        <ns7:ChanProcedure>false</ns7:ChanProcedure>
      </ns7:Operator>
    </ns7:GetOperatorByActivityResponse>
*/



    --
    CURSOR c_xml_tay(i_xml xmltype, i_ns VARCHAR2)
    IS
      SELECT extract(VALUE(rqt), '//ns7:Activity/@internalID',i_ns).getStringVal()  tnt_id
      ,      extract(VALUE(rqt), '//ns7:Activity/ns7:Identifier/text()',i_ns).getStringVal()  erkenningsnummer
      ,      extract(VALUE(rqt), '//ns7:ActivityType/ns7:Chapter/text()', i_ns).getStringVal() hoofdstuk
      ,      extract(VALUE(rqt), '//ns7:ActivityType/ns7:Section/text()', i_ns).getStringVal() sectie
      ,      extract(VALUE(rqt), '//ns7:ActivityType/ns7:Type/text()', i_ns).getStringVal() type
      ,      extract(VALUE(rqt), '//ns7:Activity/ns7:Status/text()', i_ns).getStringVal()  status
      FROM TABLE( xmlsequence(i_xml)) rqt
    ;
    --
    CURSOR c_xml_tro(i_xml xmltype, i_ns VARCHAR2)
    IS
      SELECT extract(VALUE(rqt), '//ns5:Region[1]/text()', i_ns).getStringVal() regio
      FROM TABLE( xmlsequence(i_xml)) rqt
    ;
   --
    CURSOR c_tor(i_tnt_id vgc_tnt_operators.tnt_id%TYPE)
    IS
      SELECT id
      FROM   vgc_tnt_operators
      WHERE  tnt_id = i_tnt_id
    ;
   --
    CURSOR c_tro(i_naam vgc_tnt_regios.naam%TYPE)
    IS
      SELECT id
      FROM   vgc_tnt_regios
      WHERE  naam = i_naam
    ;
   --
    CURSOR c_tay(i_hoofdstuk vgc_tnt_activiteiten.hoofdstuk%TYPE, i_sectie vgc_tnt_activiteiten.sectie%TYPE, i_type vgc_tnt_activiteiten.type%TYPE )
    IS
      SELECT id
      FROM   vgc_tnt_activiteiten
      WHERE  nvl(hoofdstuk,'$') = nvl(i_hoofdstuk,'$')
        AND  sectie = i_sectie
        AND  type = i_type
    ;
    --
    l_operator_count number := 0;
  BEGIN
    vgc_blg.write_log('Start: verwerk', v_objectnaam, 'J', 5);
    -- init variabelen voor verwerken

    v_fault              :=  vgc_xml.extractxml(v_antwoord, '//ns0:Fault', v_xmlns1);
    v_faultstr           :=  vgc_xml.extractxml_str(v_antwoord, '//ns0:Fault/faultstring/text()', v_xmlns1);
    v_response           :=  vgc_xml.extractxml(v_antwoord, '//ns7:GetOperatorByActivityResponse', v_xmlns3);
    v_operators          :=  vgc_xml.extractxml(v_response, '//ns7:Operator',v_xmlns3);
--    v_operatorsstr       :=  vgc_xml.extractxml_str(v_response, '//ns7:Status/text()', v_xmlns3);
--    l_offset             :=  vgc_xml.extractxml_str(v_response, '//ns7:FindOperatorResponse/@offset', v_xmlns3);
    --
    vgc_blg.write_log('Start: verwerk', v_objectnaam, 'J', 5);
    IF nvl(length(v_faultstr),0) > 0
    THEN
      v_einde := true;
      v_result := to_char(v_faultstr);
    END IF;
    --
    -- verwerk organisaties
    --
    vgc_blg.write_log('Start: verwerk organisaties', v_objectnaam, 'J', 5);
    l_operator_count := 0;
    FOR r_tln IN c_tln(v_operators, v_xmlns3)
    LOOP
      l_operator_count := l_operator_count + 1;
      vgc_blg.write_log('Verwerken: ' || r_tln.tnt_id, v_objectnaam, 'J' , 5);
      DECLARE
        CURSOR c_tpe (b_land_code IN vgc_landen.code%TYPE, b_postcode vgc_tnt_postcodes.postcode%TYPE)
        IS
          SELECT stadsnaam_uppercase
          FROM   vgc_tnt_postcodes tpe
          WHERE  tpe.land_code = b_land_code
          AND    tpe.postcode = b_postcode
        ;

        v_plaats vgc_tnt_operators.plaats%TYPE;
        v_tor vgc_tnt_operators%ROWTYPE;

      BEGIN
                --
        OPEN c_tpe (b_land_code => r_tln.landcode
                   ,b_postcode => r_tln.postcode);
        FETCH c_tpe INTO v_plaats;
        CLOSE c_tpe;
        --
        -- vul rij met waarden
        --
        v_xml_tay              := r_tln.activiteiten;
    --    v_xml_tro              := r_tln.regios;
        v_tor.id               := vgc_tor_seq1.nextval;
        v_tor.tnt_id           := r_tln.tnt_id;
    --    v_tor.tnt_nummer       := substr(nvl(r_tln.tnt_nummer,r_tln.tnt_nummer_2),1,100);
    --    v_tor.tnt_nummer_type  := get_vgc_id_type(nvl(r_tln.tnt_nummer_type,r_tln.tnt_nummer_type_2));
        v_tor.naam             := substr(REPLACE(REPLACE(REPLACE(r_tln.naam,chr(38)||'apos;',''''),chr(38)||'amp;','&'),chr(38)||'quot;','"'),1,200);
        v_tor.adres            := substr(REPLACE(REPLACE(REPLACE(r_tln.adres,chr(38)||'apos;',''''),chr(38)||'amp;','&'),chr(38)||'quot;','"'),1,200);
        v_tor.plaats           := substr(REPLACE(REPLACE(REPLACE(r_tln.plaats,chr(38)||'apos;',''''),chr(38)||'amp;','&'),chr(38)||'quot;','"'),1,200);
        v_tor.postcode         := substr(nvl(r_tln.postcode,v_tor.plaats),1,100);
        v_tor.land_code        := substr(nvl(r_tln.landcode,'XX'),1,3);
        v_tor.naam_vgc         := vertaal_tekst(r_tln.landcode,v_tor.naam);
        v_tor.adres_vgc        := vertaal_tekst(r_tln.landcode,v_tor.adres);
        v_tor.plaats_vgc       := vertaal_tekst(r_tln.landcode,v_tor.plaats);
        v_tor.postcode_vgc     := vertaal_tekst(r_tln.landcode,v_tor.postcode);
        v_tor.herkomst         := 'TNT';
        v_tor.creation_date    := l_sysdate;
        v_tor.created_by       := l_user;
        v_tor.last_update_date := l_sysdate;
        v_tor.last_updated_by  := l_user;
        --
        vgc_blg.write_log('Verwerken: ' || v_tor.naam, v_objectnaam, 'J' , 5);
        --
        BEGIN
          INSERT INTO vgc_tnt_operators VALUES v_tor;

        EXCEPTION
          WHEN dup_val_on_index
          THEN
            UPDATE vgc_tnt_operators  tor
            SET  tor.naam  = v_tor.naam
            ,    tor.adres = v_tor.adres
            ,    tor.postcode = v_tor.postcode
            ,    tor.plaats = v_tor.plaats
            ,    tor.naam_vgc  = v_tor.naam_vgc
            ,    tor.adres_vgc = v_tor.adres_vgc
            ,    tor.postcode_vgc = v_tor.postcode_vgc
            ,    tor.plaats_vgc = v_tor.plaats_vgc
    --        ,    tor.tnt_nummer = v_tor.tnt_nummer
    --        ,    tor.tnt_nummer_type = v_tor.tnt_nummer_type
            ,    tor.last_update_date = l_sysdate
            ,    tor.last_updated_by  = l_user
            WHERE tor.tnt_id = v_tor.tnt_id
            ;
          WHEN OTHERS
          THEN
            vgc_blg.write_log('Exception: '|| SQLERRM, v_objectnaam, 'N', 1);
            RAISE;
        END;
        --
        OPEN c_tor (i_tnt_id => v_tor.tnt_id);
        FETCH c_tor into l_tor_id;
        CLOSE c_tor;
        --
        -- eerst ontkoppelen van oude activiteiten
        --
        DELETE FROM vgc_tnt_tor_tay tty
        WHERE tty.tor_id = l_tor_id
        ;
        --
        -- activiteiten
        --
        FOR r_xml_tay IN c_xml_tay(v_xml_tay, v_xmlns3)
        LOOP
          vgc_blg.write_log('Loop activiteiten: ' || r_xml_tay.hoofdstuk||'*'||r_xml_tay.sectie||'*'||r_xml_tay.type, v_objectnaam, 'J', 5);

         DECLARE
            v_tay vgc_tnt_activiteiten%ROWTYPE;
            v_tty vgc_tnt_tor_tay%ROWTYPE;
          BEGIN
            v_tay.id               := vgc_tay_seq1.nextval;
            v_tay.status           := r_xml_tay.status;
            v_tay.hoofdstuk        := r_xml_tay.hoofdstuk;
            v_tay.sectie           := r_xml_tay.sectie;
            v_tay.type             := r_xml_tay.type;
            v_tay.creation_date    := l_sysdate;
            v_tay.created_by       := l_user;
            v_tay.last_update_date := l_sysdate;
            v_tay.last_updated_by  := l_user;
            --
            BEGIN
              INSERT INTO vgc_tnt_activiteiten
              VALUES v_tay;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_activiteiten tay
                  SET tay.status           = v_tay.status
                  ,   tay.last_update_date = v_tay.last_update_date
                  ,   tay.last_updated_by  = v_tay.last_updated_by
                WHERE tay.hoofdstuk = v_tay.hoofdstuk
                  AND tay.sectie = v_tay.sectie
                  AND tay.type    = v_tay.type
                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
            --
            OPEN c_tay (i_hoofdstuk => v_tay.hoofdstuk, i_sectie => v_tay.sectie, i_type => v_tay.type);
            FETCH c_tay into l_tay_id;
            CLOSE c_tay;
            --
            -- koppelen activiteit met operator
            --
            v_tty.id                   := vgc_tty_seq1.nextval;
            v_tty.tor_id               := l_tor_id;
            v_tty.tay_id               := l_tay_id;
            v_tty.tnt_id               := r_xml_tay.tnt_id;
            v_tty.erkenningsnummer     := ltrim(rtrim(REPLACE(REPLACE(REPLACE(r_xml_tay.erkenningsnummer,chr(38)||'apos;',''''),chr(38)||'amp;','&'),chr(38)||'quot;','"')));
            v_tty.erkenningsnummer_vgc := vertaal_tekst(r_tln.landcode,v_tty.erkenningsnummer);
            v_tty.creation_date        := l_sysdate;
            v_tty.created_by           := l_user;
            v_tty.last_update_date     := l_sysdate;
            v_tty.last_updated_by      := l_user;
            BEGIN
              INSERT INTO vgc_tnt_tor_tay
              VALUES v_tty;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_tor_tay tty
                  SET tty.erkenningsnummer     = v_tty.erkenningsnummer
                  ,   tty.erkenningsnummer_vgc = v_tty.erkenningsnummer_vgc
                  ,   tty.tnt_id               = v_tty.tnt_id
                  ,   tty.last_update_date     = v_tty.last_update_date
                  ,   tty.last_updated_by      = v_tty.last_updated_by
                WHERE tty.tor_id = v_tty.tor_id
                AND   tty.tay_id = v_tty.tay_id
                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
          EXCEPTION
            WHEN OTHERS
            THEN
              RAISE;
          END;
        END LOOP;
        --
        -- regios
        --
   /*     FOR r_xml_tro IN c_xml_tro(v_xml_tro, v_xmlns3)
        LOOP
          vgc_blg.write_log('Loop regios: ' || r_xml_tro.regio, v_objectnaam, 'J', 5);
         IF nvl(r_xml_tro.regio,'*') = '*'
         THEN
           exit;
         END IF;

         DECLARE
            v_tro vgc_tnt_regios%ROWTYPE;
            v_tto vgc_tnt_tor_tro%ROWTYPE;
          BEGIN
            v_tro.id               := vgc_tro_seq1.nextval;
            v_tro.naam             := r_xml_tro.regio;
            v_tro.creation_date    := l_sysdate;
            v_tro.created_by       := l_user;
            v_tro.last_update_date := l_sysdate;
            v_tro.last_updated_by  := l_user;
            --
            BEGIN
              INSERT INTO vgc_tnt_regios
              VALUES v_tro;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_regios tro
                  SET tro.last_update_date = v_tro.last_update_date
                  ,   tro.last_updated_by  = v_tro.last_updated_by
                WHERE tro.naam  = v_tro.naam
                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
            --
            OPEN c_tro (i_naam => v_tro.naam);
            FETCH c_tro into l_tro_id;
            CLOSE c_tro;
            --
            -- koppelen regio met operator
            --
            v_tto.id               := vgc_tto_seq1.nextval;
            v_tto.tor_id           := l_tor_id;
            v_tto.tro_id           := l_tro_id;
            v_tto.creation_date    := l_sysdate;
            v_tto.created_by       := l_user;
            v_tto.last_update_date := l_sysdate;
            v_tto.last_updated_by  := l_user;
            BEGIN
              INSERT INTO vgc_tnt_tor_tro
              VALUES v_tto;
            EXCEPTION
              WHEN dup_val_on_index
              THEN
               UPDATE vgc_tnt_tor_tro tto
                  SET tto.last_update_date = v_tto.last_update_date
                  ,   tto.last_updated_by  = v_tto.last_updated_by
                WHERE tto.tor_id = v_tto.tor_id
                AND   tto.tro_id = v_tto.tro_id
                ;
              WHEN OTHERS
              THEN
               RAISE;
            END;
        EXCEPTION
          WHEN OTHERS
          THEN
            RAISE;
        END;
      END LOOP;*/
      EXCEPTION
        WHEN OTHERS
        THEN
          vgc_blg.write_log('Exception: '|| SQLERRM, v_objectnaam, 'N', 1);
          RAISE;
      END;
      l_offset := l_offset + 1;
    END LOOP;
    --
    COMMIT;
    --
    IF l_operator_count > 150
    THEN
      v_einde := FALSE;
    ELSE
      v_einde := TRUE;
    END IF;  
    --
    if v_einde
    then
      vgc_blg.write_log('Einde: verwerk', v_objectnaam, 'J', 5);
    else
      vgc_blg.write_log('Einde naar volgende: verwerk', v_objectnaam, 'J', 5);
     end if;
    RETURN v_einde;
  EXCEPTION
    WHEN OTHERS
    THEN
      IF c_tln%ISOPEN
      THEN
        CLOSE c_tln;
      END IF;

      ROLLBACK;
      RETURN TRUE;

  END verwerk;

--
-- voert synchronisatie uit voor het opgegeven retrieval_type
--
  PROCEDURE sync
  IS
    v_page_number         NUMBER(9)       := 0;
    v_verwerking_klaar    BOOLEAN         := FALSE;

  BEGIN
    vgc_blg.write_log('Start: sync', v_objectnaam, 'J', 5);
    v_verwerking_klaar := FALSE;
    v_page_number := 0;
    WHILE v_verwerking_klaar = FALSE
    LOOP
      vgc_blg.write_log('IN loop: ' || SQLERRM, v_objectnaam, 'J', 5);
      -- initialiseren request
      r_rqt.request_id := NULL;
      r_rqt.status := vgc_ws_requests_nt.kp_in_uitvoering;
      r_rqt.resultaat := k_operation;
      -- opstellen bericht
      maak_bericht(l_offset);
   --   maak_bericht(v_page_number);
      -- aanroepen webservice
      vgc_ws_requests_nt.maak_http_request (r_rqt);
      COMMIT;
      -- indien fout bij aanroepen webservice geef foutmelding en stop verwerking
      vgc_blg.write_log('returncode: ' || r_rqt.webservice_returncode, v_objectnaam, 'J', 5);
      IF r_rqt.webservice_returncode = 500
      THEN
        v_result := 'Fout bij ophalen van operator in TNT';
      ELSIF r_rqt.webservice_returncode = 200
      THEN
        v_result := 'OK';
      ELSE
        vgc_blg.write_log('Webservice geeft http-code: ' || r_rqt.webservice_returncode, v_objectnaam, 'J', 5);
        v_result := 'Webservice geeft http-code: ' || r_rqt.webservice_returncode;
        raise_application_error(-20000, 'VGC-00502 #1' || v_ws_naam ||': 3Webservice geeft HTTP-code: ' || r_rqt.webservice_returncode);
      END IF;
      --
      vgc_blg.write_log('Voor escape_xml', v_objectnaam, 'J', 5);
      --escape_xml(r_rqt.webservice_antwoord);
      --update vgc_requests
      --s--et cim_importaangifte = r_rqt.webservice_antwoord
      --where request_id = r_rqt.request_id;
      --commit;
      vgc_blg.write_log('Voor v_antwoord', v_objectnaam, 'J', 5);
      select xmltype(r_rqt.webservice_antwoord) into v_antwoord
      from vgc_requests rqt
      where rqt.request_id = r_rqt.request_id;
      -- Verwerk indien nodig het gewijzigde wachtwoord
      --check_password_reset(i_response => v_antwoord);
      -- verwerk response
     vgc_blg.write_log('Voor v_verwerking_klaar', v_objectnaam, 'J', 5);
      v_verwerking_klaar := verwerk;
      v_page_number := v_page_number + 1;
    END LOOP;
    vgc_blg.write_log('Eind: sync', v_objectnaam, 'J', 5);

  EXCEPTION
    WHEN OTHERS
    THEN
      vgc_blg.write_log('Fout bij synchroniseren: ' || SQLERRM, v_objectnaam, 'J', 5);
    --  RAISE;

  END sync;

  --

BEGIN
     --
     HIL_MESSAGE.SET_DEBUG_FLAG(true);
    --

  --
  --trace(v_objectnaam);
  vgc_blg.write_log('start', v_objectnaam, 'N', 1);
  vgc_blg.write_log('ID: '||p_nummer, v_objectnaam, 'N', 1);

  -- initialiseren request
  r_rqt.request_id               := NULL;
  r_rqt.webservice_url           := vgc$algemeen.get_appl_register ('TNT_OPERATOR_WEBSERVICE');
  r_rqt.bestemd_voor             := NULL;
  r_rqt.webservice_logische_naam := 'VGC0703NT';
  --
  sync;
  --
  COMMIT;
  --
  --p_result := REPLACE(REPLACE(REPLACE(v_result,chr(38)||'apos;',''''),chr(38)||'amp;','"'),chr(38)||'quot;','"');
  --
  --vgc_blg.write_log('eind '||p_result, v_objectnaam, 'N', 1); /*#2*/
  --
     --
     HIL_MESSAGE.SET_DEBUG_FLAG(false);
    --
EXCEPTION
  WHEN resource_busy
  THEN
    ROLLBACK;
    RAISE;
  WHEN OTHERS
  THEN
    vgc_blg.write_log('Exception2: '|| SQLERRM, v_objectnaam, 'N', 1);
    ROLLBACK;
    qms$errors.unhandled_exception(v_objectnaam);

END VGC0703NT;
--
PROCEDURE VERWERK_TRACES_ANTWOORD
  (P_WS_NAAM IN VARCHAR2
  ,P_REQUEST_ID IN VGC_REQUESTS.REQUEST_ID%TYPE
  ,P_PTJ_ID IN VGC_PARTIJEN.ID%TYPE
  ,P_PDF_JN IN VARCHAR2
  ,P_RESULTAAT IN BOOLEAN
  ,P_ERROR_HANDLING IN VARCHAR2)
IS
v_objectnaam vgc_batchlog.proces%type  := g_package_name||'.VERWERK_TRACES_ANTWOORD#1';
--
  CURSOR c_vdt (b_nummer vgc_v_veterin_documenten.nummer%TYPE
               ,b_ptj_id vgc_v_partijen.id%TYPE)
  IS
    SELECT '1'
    FROM   vgc_v_veterin_documenten
    WHERE  nummer = b_nummer
    AND    ptj_id = b_ptj_id
  ;
--
  CURSOR c_errors (i_xml xmltype, i_ns varchar2)
  IS
    SELECT extract(VALUE(rqt), '//ns2:ID/text()', i_ns).getStringVal() id
    ,      extract(VALUE(rqt), '//ns2:Message/text()',i_ns).getStringVal() message
    ,      extract(VALUE(rqt), '//ns2:Field/text()', i_ns).getStringVal() field
    FROM TABLE( xmlsequence(vgc_xml.extractxml(i_xml,'//ns2:Error',i_ns))) rqt
  ;
--
-- variabelen om de webservice response op te stellen, uit te lezen en te verwerken
  r_rqt                        vgc_requests%ROWTYPE;
  l_response                   xmltype;
  l_specific_operation_result  VARCHAR2(4000 CHAR);
  e_ws_error                   EXCEPTION;
  e_specific_operation_error   EXCEPTION;
  e_general_operation_error    EXCEPTION;
  l_identificatie              VARCHAR2(100 CHAR);
  l_chednummer                 VARCHAR2(50 CHAR);
  l_max_retry_traces           vgc_applicatie_registers.waarde%TYPE;
  l_chedresponse               CLOB := empty_clob();
  l_pdf                        BLOB := empty_blob();
  l_ns                         VARCHAR2(500 CHAR) := 'xmlns:ns0="http://ec.europa.eu/tracesnt/certificate/ched/submission/v01" '||
                                                     'xmlns:ns2="http://ec.europa.eu/sanco/tracesnt/error/v01" '||
                                                     'xmlns:m="http://nl/minlnv/cim/BerichtenboekSoapHttp.wsdl/types/" '||
                                                     'xmlns:S="http://schemas.xmlsoap.org/soap/envelope/" '||
                                                     'xmlns:ns12="urn:un:unece:uncefact:data:standard:ReusableAggregateBusinessInformationEntity:21"';
  l_antwoord                   VARCHAR2(4000 CHAR);
  l_succes                     VARCHAR2(4000 CHAR);
  l_fout                       VARCHAR2(32000 CHAR);
  l_fout2                      VARCHAR2(4000 CHAR);
  l_dummy                      VARCHAR2(1 CHAR);
--
BEGIN
  --
  vgc_blg.write_log('Start ' , v_objectnaam, 'J' , 5);
  --
  SELECT * INTO r_rqt
  FROM vgc_requests
  WHERE request_id = p_request_id;
  --COMMIT;
  --
  -- indien technische fout bij aanroepen webservice geef foutmelding en stop verwerking
  --
  --
  if NOT p_resultaat
  then
        vgc_blg.write_log('Procedure CIM fout verlopen', v_objectnaam, 'N', 5);
  else
        vgc_blg.write_log('Procedure CIM goed verlopen', v_objectnaam, 'N', 5);
  end if;
  IF NOT p_resultaat
  THEN
    --
    vgc_blg.write_log('Niet OK ' , v_objectnaam, 'J' , 5);
    --
    IF p_error_handling = 'N'
    THEN
      r_rqt.herstel_actie   := 'GN';
    ELSE
      IF r_rqt.herstel_actie = 'AU'
      THEN
        l_max_retry_traces :=  vgc$algemeen.get_appl_register('MAX_RETRY_TRACES');
        IF r_rqt.retry_teller >= l_max_retry_traces
        THEN
          r_rqt.herstel_actie := 'MR';
        END IF;
      ELSE
        r_rqt.herstel_actie := 'AU';
      END IF;
    END IF;
    --
    UPDATE vgc_requests
    SET    herstel_actie   = r_rqt.herstel_actie
    WHERE  request_id      = r_rqt.request_id
    ;
    --
    COMMIT;
    RAISE e_ws_error;
  ELSE
    --
    vgc_blg.write_log('Wel OK ' , v_objectnaam, 'J' , 5);
    --
    -- check antwoord (technisch goed)
    --
    l_chedresponse := dbms_xmlgen.convert(vgc_xml.extractxml(xmltype(r_rqt.webservice_antwoord),'//m:chedRespons/text()', l_ns).getClobVal(),dbms_xmlgen.ENTITY_dECODE);
    vgc_blg.write_log('Wel OK2 ' , v_objectnaam, 'J' , 5);
    --
    l_succes   := vgc_xml.extractxml_str(xmltype(l_chedresponse),'//ns12:ReasonInformation/text()',  l_ns);
    vgc_blg.write_log('Wel OK3 ' , v_objectnaam, 'J' , 5);
    l_fout     := vgc_xml.extractxml_str(xmltype(l_chedresponse),'//ns0:BusinessRulesValidationException', l_ns);
    --
    vgc_blg.write_log('Succesvol?? '||l_succes , v_objectnaam, 'J' , 5);
    --
    IF l_succes LIKE '%successfully%'
    THEN
      --
      -- geen fouten, verwerk antwoord
      --
      l_response := vgc_xml.extractxml(xmltype(r_rqt.webservice_antwoord),'//m:tntDetails', l_ns);
      l_identificatie := vgc_xml.extractxml_str(l_response, '//m:tntDetails/m:array/m:identificatie/text()', l_ns);
      l_chednummer := vgc_xml.extractxml_str(l_response, '//m:tntDetails/m:array/m:chednummer/text()', l_ns);
      --
      vgc_blg.write_log('CHEDNUMMER?? ' || l_chednummer, v_objectnaam, 'J' , 5);
      --
      IF l_chednummer like 'CHED%'
      THEN
          --
        UPDATE vgc_requests
          SET    resultaat   = l_identificatie
          ,      traces_certificaat_id = l_chednummer
          ,      webservice_logische_naam = p_ws_naam
          ,      operation_result = 'DONE'
          ,      herstel_actie    = 'GN'
        WHERE  request_id      = r_rqt.request_id
        ;
        --
        -- sla de teruggekregen traces certificaat id op bij de partij
        --
        UPDATE vgc_partijen ptj
          SET traces_certificaat_id = l_chednummer
        WHERE ptj.id = p_ptj_id
        ;
        --
        COMMIT;
        --
        -- verwerk pdf
        --
        vgc_blg.write_log('pdf schrijven?? ' || p_pdf_jn, v_objectnaam, 'J' , 5);
        --
        IF p_pdf_jn = 'J'
        THEN
          l_pdf := o2w_util.DECODE_BASE64(vgc_xml.extractxml(xmltype(r_rqt.webservice_antwoord),'//m:chedPdf/text()', l_ns).getClobVal());
          --
          -- check of pdf al bestaat
          --
          OPEN c_vdt(b_nummer     => l_chednummer
                    ,b_ptj_id     => p_ptj_id);
          FETCH c_vdt INTO l_dummy;
          IF c_vdt%NOTFOUND
          THEN
            CLOSE c_vdt;
            --
            -- Geen GGB gevonden , insert
            --
            vgc_blg.write_log('pdf schrijven nieuw ', v_objectnaam, 'J' , 5);
            --
            INSERT INTO vgc_v_veterin_documenten
              ( ptj_id
              , nummer
              , datum_afgifte
              , scan
              , type
              , aangiftejaar
              , bce_id
              , datum_ontvangst
              , ontvangen_ind
              )
            VALUES
              ( p_ptj_id
              , l_chednummer
              , sysdate
              , l_pdf
              , 'PDF'
              , r_rqt.aangiftejaar
              ,(select id from vgc_v_bescheid_codes where code = '006')
              , sysdate
              , 'J'
              );
          ELSE
            --
            vgc_blg.write_log('pdf schrijven update ', v_objectnaam, 'J' , 5);
            --
            CLOSE c_vdt;
            UPDATE vgc_veterin_documenten
              SET  scan = l_pdf
              ,    datum_ontvangst = sysdate
              ,    ontvangen_ind = 'J'
            WHERE nummer = l_chednummer
            AND   ptj_id = p_ptj_id;
          END IF;
          COMMIT;
        END IF;
      ELSE
        --
        -- er is iets fout gegaan
        --
        vgc_blg.write_log('Error in CIM interface ', v_objectnaam, 'J' , 5);
        --
        UPDATE vgc_requests
        SET    herstel_actie    = 'HM'
        ,      operation_result = 'Error in CIM interface'
        ,      webservice_logische_naam = p_ws_naam
        WHERE  request_id       = r_rqt.request_id;
        --
        COMMIT;
        --
        RAISE e_general_operation_error;
      END IF;
    ELSE
      --
      -- geen succes, fouten weergeven
      --
    vgc_blg.write_log('FOUT?? '||substr(l_fout,1,1950) , v_objectnaam, 'J' , 5);
      IF instr(l_fout,'<') > 0
      THEN
      --
      -- errors
      --
        FOR r_errors in c_errors(xmltype(l_fout), l_ns)
        LOOP
          vgc_blg.write_log('ERROR? '||substr(r_errors.message,1,1950) , v_objectnaam, 'J' , 5);
          l_specific_operation_result := substr(l_specific_operation_result || r_errors.id || ': '||  substr(r_errors.message,1,300) || ' ('|| r_errors.field || ') '||chr(10),1,4000);
    --      IF instr(l_specific_operation_result, 'Scien') > 0
    --      THEN
    --        log('Error in CIM Interface voor zending : '||r_rqt.ggs_nummer || '  -  ' || nvl(l_specific_operation_result,'specificOperationResult is leeg'),'E');
    --      END IF;
        END LOOP;
        --
        UPDATE vgc_requests
          SET  resultaat = l_specific_operation_result
          ,    herstel_actie    = 'HM'
          ,    operation_result = 'Error in CIM interface'
          ,    webservice_logische_naam = p_ws_naam
        WHERE  request_id = r_rqt.request_id
        ;
        COMMIT;
      ELSE
        l_fout2 := vgc_xml.extractxml_str(xmltype(l_chedresponse),'//ns0:CertificatePermissionDeniedException', l_ns);
        IF instr(l_fout2,'<') > 0
        THEN
          FOR r_errors in c_errors(xmltype(l_fout2), l_ns)
          LOOP
            l_specific_operation_result := l_specific_operation_result || r_errors.id || ': '||  substr(r_errors.message,1,300) || ' ('|| r_errors.field || ') '||chr(10);
          END LOOP;
          --
          UPDATE vgc_requests
            SET  resultaat = l_specific_operation_result
            ,    herstel_actie    = 'HM'
            ,    operation_result = 'Error in CIM interface'
            ,    webservice_logische_naam = p_ws_naam
          WHERE  request_id = r_rqt.request_id
          ;
          COMMIT;
        ELSE
          l_specific_operation_result := 'Onbekende fout in interface VGC_CIM302';
          UPDATE vgc_requests
            SET  resultaat = l_specific_operation_result
            ,    herstel_actie    = 'HM'
            ,    operation_result = 'Error in CIM interface'
            ,    webservice_logische_naam = p_ws_naam
          WHERE  request_id = r_rqt.request_id
          ;
          COMMIT;
          RAISE e_specific_operation_error;
        END IF;
      END IF;
    END IF;
  END IF;
  vgc_blg.write_log('Einde ' , v_objectnaam, 'J' , 5);
  --
EXCEPTION
  WHEN e_ws_error THEN
    vgc_blg.write_log('Exception: Webservice geeft http-code: ' || r_rqt.webservice_returncode, v_objectnaam, 'N', 1);
    raise_application_error(-20000, 'VGC-00502 #1' || r_rqt.webservice_logische_naam ||': Webservice geeft http-code: ' || r_rqt.webservice_returncode);

  WHEN e_specific_operation_error
  THEN
    vgc_blg.write_log('Exception: Aanroep webservice mislukt. Specifieke operatie fout ontvangen van Traces webservice: ' || nvl(l_specific_operation_result,'specificOperationResult is leeg'), v_objectnaam, 'N', 1);
    raise_application_error(-20000, 'VGC-00502 #1' ||  r_rqt.webservice_logische_naam ||': ' || l_specific_operation_result );

  WHEN e_general_operation_error
  THEN
    vgc_blg.write_log('Exception: Aanroep webservice mislukt. Generieke operatie fout ontvangen van Traces webservice: ' || l_specific_operation_result, v_objectnaam, 'N', 1);
    raise_application_error(-20000, 'VGC-00502 #1' ||  r_rqt.webservice_logische_naam ||': ' || l_specific_operation_result );

  WHEN OTHERS
  THEN
    vgc_blg.write_log('Exception: ' || SQLERRM, v_objectnaam, 'N', 5);
    qms$errors.unhandled_exception(v_objectnaam);
    RAISE;
END VERWERK_TRACES_ANTWOORD;
PROCEDURE VERWERK_TNT_ANTWOORD
  (P_WS_NAAM IN VARCHAR2
  ,P_GGS_NUMMER IN VGC_PARTIJEN.GGS_NUMMER%TYPE
  ,P_PTJ_ID IN VGC_PARTIJEN.ID%TYPE
  ,P_ERROR_HANDLING IN VARCHAR2)
IS
v_objectnaam vgc_batchlog.proces%type  := g_package_name||'.VERWERK_TNT_ANTWOORD#1';
--
  CURSOR c_errors (i_xml xmltype, i_ns varchar2)
  IS
    SELECT extract(VALUE(rqt), '//ns12:ID/text()', i_ns).getStringVal() id
    ,      extract(VALUE(rqt), '//ns12:Message/text()',i_ns).getStringVal() message
    ,      extract(VALUE(rqt), '//ns12:Field/text()', i_ns).getStringVal() field
    FROM TABLE( xmlsequence(vgc_xml.extractxml(i_xml,'//ns12:Error',i_ns))) rqt
  ;
  CURSOR c_errors2 (i_xml xmltype, i_ns varchar2)
  IS
    SELECT extract(VALUE(rqt), '//ns3:ID/text()', i_ns).getStringVal() id
    ,      extract(VALUE(rqt), '//ns3:Message/text()',i_ns).getStringVal() message
    ,      extract(VALUE(rqt), '//ns3:Field/text()', i_ns).getStringVal() field
    FROM TABLE( xmlsequence(vgc_xml.extractxml(i_xml,'//ns3:Error',i_ns))) rqt
  ;
  CURSOR c_rqt
  IS
    SELECT *
    FROM vgc_requests rqt
    WHERE ggs_nummer = p_ggs_nummer
    AND   webservice_logische_naam = p_ws_naam
    ORDER by request_id desc;
--
-- variabelen om de webservice response op te stellen, uit te lezen en te verwerken
  r_rqt                        vgc_requests%ROWTYPE;
  l_response                   xmltype;
  l_specific_operation_result  VARCHAR2(4000 CHAR);
  e_ws_error                   EXCEPTION;
  e_specific_operation_error   EXCEPTION;
  e_general_operation_error    EXCEPTION;
  l_identificatie              VARCHAR2(100 CHAR);
  l_chednummer                 VARCHAR2(50 CHAR);
  l_max_retry_traces           vgc_applicatie_registers.waarde%TYPE;
  l_chedresponse               CLOB := empty_clob();
  l_pdf                        BLOB := empty_blob();
  l_ns                         VARCHAR2(500 CHAR) := 'xmlns:ns0="http://ec.europa.eu/tracesnt/certificate/ched/submission/v01" '||
                                                     'xmlns:ns12="http://ec.europa.eu/sanco/tracesnt/error/v01" '||
                                                     'xmlns:ns6="http://ec.europa.eu/tracesnt/certificate/ched/submission/v01"'||
                                                     'xmlns:S="http://schemas.xmlsoap.org/soap/envelope/" ' ||
                                                     'xmlns:ns3="http://ec.europa.eu/sanco/tracesnt/error/v01" ';
  l_antwoord                   VARCHAR2(4000 CHAR);
  l_succes                     VARCHAR2(4000 CHAR);
  l_fout                       VARCHAR2(32000 CHAR);
  l_fout2                      VARCHAR2(4000 CHAR);
  l_dummy                      VARCHAR2(1 CHAR);
--
BEGIN
  --
  vgc_blg.write_log('Start' , v_objectnaam, 'J' , 5);
  --
  OPEN c_rqt;
  FETCH c_rqt INTO r_rqt;
  CLOSE c_rqt;
    vgc_blg.write_log('requestid: '||R_RQT.REQUEST_ID , v_objectnaam, 'J' , 5);
  --
  -- indien technische fout bij aanroepen webservice geef foutmelding en stop verwerking
  --
  --
  if r_rqt.status != 'AO'
  then
        vgc_blg.write_log('Procedure TNT fout verlopen', v_objectnaam, 'N', 5);
  else
        vgc_blg.write_log('Procedure TNT goed verlopen', v_objectnaam, 'N', 5);
  end if;
  IF r_rqt.webservice_returncode != '200'
  THEN
    --
    vgc_blg.write_log('Niet OK ' , v_objectnaam, 'J' , 5);
    --
    IF p_error_handling = 'N'
    THEN
      r_rqt.herstel_actie   := 'GN';
    ELSE
      IF r_rqt.herstel_actie = 'AU'
      THEN
        l_max_retry_traces :=  vgc$algemeen.get_appl_register('MAX_RETRY_TRACES');
        IF r_rqt.retry_teller >= l_max_retry_traces
        THEN
          r_rqt.herstel_actie := 'MR';
        END IF;
      ELSE
        r_rqt.herstel_actie := 'AU';
      END IF;
    END IF;
    --
    l_fout     := vgc_xml.extractxml_str(xmltype(r_rqt.webservice_antwoord),'//ns0:Fault', l_ns);
    --
    vgc_blg.write_log('FOUT?? '||substr(l_fout,1,1950) , v_objectnaam, 'J' , 5);
    IF instr(l_fout,'<ns12:Error>') > 0
    THEN
    --
    -- errors
    --
      FOR r_errors in c_errors(xmltype(l_fout), l_ns)
      LOOP
        vgc_blg.write_log('ERROR? '||substr(r_errors.message,1,1950) , v_objectnaam, 'J' , 5);
        l_specific_operation_result := substr(l_specific_operation_result || r_errors.id || ': '||  substr(r_errors.message,1,300) || ' ('|| r_errors.field || ') '||chr(10),1,4000);
  --      IF instr(l_specific_operation_result, 'Scien') > 0
  --      THEN
  --        log('Error in CIM Interface voor zending : '||r_rqt.ggs_nummer || '  -  ' || nvl(l_specific_operation_result,'specificOperationResult is leeg'),'E');
  --      END IF;
      END LOOP;
      --
      UPDATE vgc_requests
        SET  resultaat = l_specific_operation_result
        ,    herstel_actie    = 'HM'
        ,    operation_result = 'Error in TNT interface'
        ,    webservice_logische_naam = p_ws_naam
      WHERE  request_id = r_rqt.request_id
      ;
      COMMIT;
    ELSE
   vgc_blg.write_log('FOUT2?? '||substr(l_fout,1,1950) , v_objectnaam, 'J' , 5);
      l_fout2 := vgc_xml.extractxml_str(xmltype(r_rqt.webservice_antwoord),'//ns4:CertificatePermissionDeniedException', l_ns);
      IF instr(l_fout2,'<ns3:Error>') > 0
      THEN
    vgc_blg.write_log('FOUT2a?? '||substr(l_fout,1,1950) , v_objectnaam, 'J' , 5);
       FOR r_errors2 in c_errors2(xmltype(l_fout2), l_ns)
        LOOP
    vgc_blg.write_log('FOUT2b?? '||substr(l_fout,1,1950) , v_objectnaam, 'J' , 5);
          l_specific_operation_result := l_specific_operation_result || r_errors2.id || ': '||  substr(r_errors2.message,1,300) || ' ('|| r_errors2.field || ') '||chr(10);
        END LOOP;
        --
        UPDATE vgc_requests
          SET  resultaat = l_specific_operation_result
          ,    herstel_actie    = 'HM'
          ,    operation_result = 'Error in TNT interface'
          ,    webservice_logische_naam = p_ws_naam
        WHERE  request_id = r_rqt.request_id
        ;
        COMMIT;
      ELSE
        l_specific_operation_result := 'Onbekende fout in interface VGC_TNT';
        UPDATE vgc_requests
          SET  resultaat = l_specific_operation_result
          ,    herstel_actie    = 'HM'
          ,    operation_result = 'Error in TNT interface'
          ,    webservice_logische_naam = p_ws_naam
        WHERE  request_id = r_rqt.request_id
        ;
        COMMIT;
        RAISE e_specific_operation_error;
      END IF;
    END IF;
  ELSE
    --
    vgc_blg.write_log('Wel OK ' , v_objectnaam, 'J' , 5);
    --
    -- check antwoord (technisch goed)
    --
    IF r_rqt.resultaat = 'submitLaboratoryTests'
    THEN
      --
      -- geen fouten, verwerk antwoord
      --
      UPDATE vgc_requests
        SET     operation_result = 'DONE'
        ,       herstel_actie    = 'GN'
      WHERE  request_id      = r_rqt.request_id
      ;
      --
      COMMIT;
    ELSE
      --
      -- geen succes, fouten weergeven
      --
 --   l_chedresponse := dbms_xmlgen.convert(vgc_xml.extractxml(xmltype(r_rqt.webservice_antwoord),'//m:chedRespons/text()', l_ns).getClobVal(),dbms_xmlgen.ENTITY_dECODE);
 --   vgc_blg.write_log('Wel OK2 ' , v_objectnaam, 'J' , 5);
    --
 --   l_succes   := vgc_xml.extractxml_str(xmltype(l_chedresponse),'//ns12:ReasonInformation/text()',  l_ns);
 --   vgc_blg.write_log('Wel OK3 ' , v_objectnaam, 'J' , 5);
    l_fout     := vgc_xml.extractxml_str(xmltype(r_rqt.webservice_antwoord),'//ns6:BusinessRulesValidationException/text()', l_ns);
    --
    vgc_blg.write_log('FOUT?? '||substr(l_fout,1,1950) , v_objectnaam, 'J' , 5);
      IF instr(l_fout,'<ns12:Error>') > 0
      THEN
      --
      -- errors
      --
        FOR r_errors in c_errors(xmltype(l_fout), l_ns)
        LOOP
          vgc_blg.write_log('ERROR? '||substr(r_errors.message,1,1950) , v_objectnaam, 'J' , 5);
          l_specific_operation_result := substr(l_specific_operation_result || r_errors.id || ': '||  substr(r_errors.message,1,300) || ' ('|| r_errors.field || ') '||chr(10),1,4000);
    --      IF instr(l_specific_operation_result, 'Scien') > 0
    --      THEN
    --        log('Error in CIM Interface voor zending : '||r_rqt.ggs_nummer || '  -  ' || nvl(l_specific_operation_result,'specificOperationResult is leeg'),'E');
    --      END IF;
        END LOOP;
        --
        UPDATE vgc_requests
          SET  resultaat = l_specific_operation_result
          ,    herstel_actie    = 'HM'
          ,    operation_result = 'Error in TNT interface'
          ,    webservice_logische_naam = p_ws_naam
        WHERE  request_id = r_rqt.request_id
        ;
        COMMIT;
      ELSE
        l_fout2 := vgc_xml.extractxml_str(xmltype(l_chedresponse),'//ns0:CertificatePermissionDeniedException', l_ns);
        IF instr(l_fout2,'<') > 0
        THEN
          FOR r_errors in c_errors(xmltype(l_fout2), l_ns)
          LOOP
            l_specific_operation_result := l_specific_operation_result || r_errors.id || ': '||  substr(r_errors.message,1,300) || ' ('|| r_errors.field || ') '||chr(10);
          END LOOP;
          --
          UPDATE vgc_requests
            SET  resultaat = l_specific_operation_result
            ,    herstel_actie    = 'HM'
            ,    operation_result = 'Error in CIM interface'
            ,    webservice_logische_naam = p_ws_naam
          WHERE  request_id = r_rqt.request_id
          ;
          COMMIT;
        ELSE
          l_specific_operation_result := 'Onbekende fout in interface VGC_CIM302';
          UPDATE vgc_requests
            SET  resultaat = l_specific_operation_result
            ,    herstel_actie    = 'HM'
            ,    operation_result = 'Error in CIM interface'
            ,    webservice_logische_naam = p_ws_naam
          WHERE  request_id = r_rqt.request_id
          ;
          COMMIT;
          RAISE e_specific_operation_error;
        END IF;
      END IF;
    END IF;
  END IF;
  vgc_blg.write_log('Einde ' , v_objectnaam, 'J' , 5);
  --
EXCEPTION
  WHEN e_ws_error THEN
    vgc_blg.write_log('Exception: Webservice geeft http-code: ' || r_rqt.webservice_returncode, v_objectnaam, 'N', 1);
    raise_application_error(-20000, 'VGC-00502 #1' || r_rqt.webservice_logische_naam ||': Webservice geeft http-code: ' || r_rqt.webservice_returncode);

  WHEN e_specific_operation_error
  THEN
    vgc_blg.write_log('Exception: Aanroep webservice mislukt. Specifieke operatie fout ontvangen van Traces webservice: ' || nvl(l_specific_operation_result,'specificOperationResult is leeg'), v_objectnaam, 'N', 1);
    raise_application_error(-20000, 'VGC-00502 #1' ||  r_rqt.webservice_logische_naam ||': ' || l_specific_operation_result );

  WHEN e_general_operation_error
  THEN
    vgc_blg.write_log('Exception: Aanroep webservice mislukt. Generieke operatie fout ontvangen van Traces webservice: ' || l_specific_operation_result, v_objectnaam, 'N', 1);
    raise_application_error(-20000, 'VGC-00502 #1' ||  r_rqt.webservice_logische_naam ||': ' || l_specific_operation_result );

  WHEN OTHERS
  THEN
    vgc_blg.write_log('Exception: ' || SQLERRM, v_objectnaam, 'N', 5);
    qms$errors.unhandled_exception(v_objectnaam);
    RAISE;
END VERWERK_TNT_ANTWOORD;

/* meldt een beslissing over een importpartij aan TNT */
PROCEDURE REPORT_DECISION_TO_TNT
 (P_GGS_NUMMER IN VGC_PARTIJEN.GGS_NUMMER%TYPE
 ,P_DO_IT IN VARCHAR2
 ,P_BEZEMWAGEN_IND VARCHAR2
 )
 IS
-- pragma autonomous_transaction;
v_objectnaam vgc_batchlog.proces%type  := g_package_name||'.REPORT_DECISION_TO_TNT#1';
/*********************************************************************
Wijzigingshistorie
doel:
Ophalen van de speciestype vertaling

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  2     17-08-2021 GLR     Samengevoegd met REPORT_DECISION_TO_TRACES
  1     23-07-2021 GLR     creatie
*********************************************************************/
--
-- fetcht het relevante requestrecord uit de bezemwagen*/
  CURSOR c_ptj
  IS
    SELECT traces_certificaat_id
    ,      ptj_type
    ,      nvl(lmr.zegelnummer,'XXXX')
    ,      vdt.nummer
    FROM   vgc_partijen ptj
    ,      vgc_lab_monsters lmr
    ,      vgc_veterin_documenten vdt
    WHERE  ptj.ggs_nummer = p_ggs_nummer
    AND    lmr.cte_ptj_id (+) = ptj.id
    AND    vdt.ptj_id = ptj.id
    ORDER BY vdt.id asc
  ;

-- bepaalt het 'oude' requestnummer
  CURSOR c_rqt (b_traces_certificaat_id in vgc_requests.traces_certificaat_id%type)
  IS
    SELECT request_id
    ,      webservice_logische_naam
    ,      operation_result
    FROM   vgc_requests rqt
    WHERE  rqt.traces_certificaat_id = b_traces_certificaat_id
    AND    webservice_logische_naam IN ('VGC0504NT', 'VGC0505NT')
    ORDER BY request_id DESC
  ;

-- lock om een eventueel AU record van de bezemwagen te locken op record niveau
  CURSOR c_rqt_lock(i_request_id vgc_requests.request_id%TYPE)
  IS
    SELECT 1
    FROM   vgc_requests rqt
    WHERE  rqt.request_id = i_request_id
    FOR UPDATE NOWAIT
  ;

--
  v_debug_ind             BOOLEAN := CASE WHEN vgc$algemeen.get_appl_register ('DEBUG') = 'J' THEN TRUE ELSE FALSE END;
  v_verwerking_synchroon  BOOLEAN := CASE WHEN vgc$algemeen.get_appl_register ('REPORT_DECISION_SYNCHROON') = 'J' THEN TRUE ELSE FALSE END;
  v_execute               BOOLEAN := FALSE;
  v_no_debug              BOOLEAN := FALSE;
  v_job                   NUMBER;
  v_request_id_1          NUMBER;
  v_request_id_2          NUMBER;
  v_stap_nr               NUMBER;
  v_ind                   NUMBER:= 0;
  v_request_status        NUMBER;
  v_release_status        NUMBER;
  v_chednummer            VARCHAR2(50 CHAR);
  v_operation_result      VARCHAR2(50 CHAR);
  v_webservice_logische_naam      VARCHAR2(50 CHAR);
  v_ptj_type              VARCHAR2(3 CHAR);
  v_dummy                 NUMBER;
  v_lockname              VARCHAR2(50 CHAR) := 'REPORT_DECISION_' || to_char(p_ggs_nummer);
  v_lockhandle            VARCHAR2(128 CHAR);
  v_lmr_zegelnummer       VARCHAR2(20 CHAR);
  v_doc_nummer            VARCHAR2(100 CHAR);
  r_rqt                   vgc_requests%ROWTYPE;
  resource_busy           EXCEPTION;
  PRAGMA EXCEPTION_INIT(resource_busy, -54);
--
BEGIN
  --
  trace(v_objectnaam);
  vgc_blg.write_log('start', v_objectnaam, 'N' , 1);
  vgc_blg.write_log('p_ggs_nummer: '     || p_ggs_nummer , v_objectnaam, 'J' , 5);
  vgc_blg.write_log('p_do_it: '          || p_do_it , v_objectnaam, 'J' , 5);
  vgc_blg.write_log('p_bezemwagen_ind: ' || p_bezemwagen_ind, v_objectnaam, 'J' , 5);
  --
  -- partij ophalen
  --
  open c_ptj;
  fetch c_ptj into v_chednummer, v_ptj_type, v_lmr_zegelnummer, v_doc_nummer;
  close c_ptj;
  --
  open c_rqt(v_chednummer);
  fetch c_rqt into v_request_id_1, v_webservice_logische_naam, v_operation_result;
  close c_rqt;
  --
  IF instr(upper(v_doc_nummer),'NVWA') = 0
  THEN
    IF nvl(v_chednummer,'*') = '*' OR nvl(v_webservice_logische_naam,'*') IN ('*','VGC0504NT','VGC0505NT')
    THEN
      BEGIN
        vgc0505nt(p_ggs_nummer, v_request_id_1);
      EXCEPTION
      WHEN OTHERS
        THEN
          RAISE;
      END;
    END IF;
    --
    open c_ptj;
    fetch c_ptj into v_chednummer, v_ptj_type, v_lmr_zegelnummer, v_doc_nummer;
    close c_ptj;
    --
    open c_rqt(v_chednummer);
    fetch c_rqt into v_request_id_1, v_webservice_logische_naam, v_operation_result;
    close c_rqt;
    --
    IF substr(v_chednummer,1,5) in ('CHEDD','CHEDA','CHEDP')
--    IF (substr(v_chednummer,1,5) = 'CHEDD'
--    OR (substr(v_chednummer,1,5) in ('CHEDA','CHEDP') and v_lmr_zegelnummer != 'XXXX'))
    AND v_operation_result = 'DONE'
    THEN
      BEGIN
        vgc0503nt(p_ggs_nummer, v_request_id_1);
      EXCEPTION
      WHEN OTHERS
        THEN
         RAISE;
      END;
    END IF;
  END IF;

  -- release recordlock
  IF c_rqt_lock%ISOPEN
  THEN
    CLOSE c_rqt_lock;
  END IF;

  -- release userlock
  --v_release_status  := dbms_lock.release(v_lockhandle);
  vgc_blg.write_log('eind', v_objectnaam, 'N', 1);
EXCEPTION
  WHEN resource_busy
  THEN
    -- als openen van lock mislukt is record momenteel in bewerking --> ga verder met volgend record
    vgc_blg.write_log('Exception bij ggs_nummer: '  || r_rqt.ggs_nummer || ': ' || 'Requestrecord locked by another user' , v_objectnaam, 'N', 1);
    v_release_status  := dbms_lock.release(v_lockhandle);
  WHEN OTHERS
  THEN
    vgc_blg.write_log('Exception: ' || SQLERRM, v_objectnaam, 'N', 1);
    -- release recordlock
    IF c_rqt_lock%ISOPEN
    THEN
      CLOSE c_rqt_lock;
    END IF;

    -- release lock
    v_release_status  := dbms_lock.release(v_lockhandle);
    IF p_do_it = 'J' THEN
      ROLLBACK;
    ELSE
      qms$errors.unhandled_exception(v_objectnaam);
      RAISE;

    END IF;

END REPORT_DECISION_TO_TNT;

/* meldt een laboratorium test over een importpartij aan TNT */
PROCEDURE REPORT_LABTEST_TO_TNT
 (P_GGS_NUMMER IN VGC_PARTIJEN.GGS_NUMMER%TYPE
 ,P_DO_IT IN VARCHAR2
 ,P_BEZEMWAGEN_IND VARCHAR2
 )
 IS
-- pragma autonomous_transaction;
v_objectnaam vgc_batchlog.proces%type  := g_package_name||'.REPORT_LABTEST_TO_TNT#1';
/*********************************************************************
Wijzigingshistorie
doel:
Versturen van een LAB Test naar TNT

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  1     20-01-2022 GLR     creatie
*********************************************************************/
--
-- fetcht het relevante requestrecord uit de bezemwagen*/
  CURSOR c_ptj
  IS
    SELECT traces_certificaat_id
    ,      ptj_type
    ,      nvl(lmr.zegelnummer,'XXXX')
    ,      vdt.nummer
    FROM   vgc_partijen ptj
    ,      vgc_lab_monsters lmr
    ,      vgc_veterin_documenten vdt
    WHERE  ptj.ggs_nummer = p_ggs_nummer
    AND    lmr.cte_ptj_id (+) = ptj.id
    AND    vdt.ptj_id = ptj.id
    ORDER BY vdt.id asc
  ;

-- bepaalt het 'oude' requestnummer
  CURSOR c_rqt (b_traces_certificaat_id in vgc_requests.traces_certificaat_id%type)
  IS
    SELECT request_id
    ,      webservice_logische_naam
    ,      operation_result
    FROM   vgc_requests rqt
    WHERE  rqt.traces_certificaat_id = b_traces_certificaat_id
    AND    webservice_logische_naam = 'VGC0505NT'
    ORDER BY request_id DESC
  ;

-- lock om een eventueel AU record van de bezemwagen te locken op record niveau
  CURSOR c_rqt_lock(i_request_id vgc_requests.request_id%TYPE)
  IS
    SELECT 1
    FROM   vgc_requests rqt
    WHERE  rqt.request_id = i_request_id
    FOR UPDATE NOWAIT
  ;

--
  v_debug_ind             BOOLEAN := CASE WHEN vgc$algemeen.get_appl_register ('DEBUG') = 'J' THEN TRUE ELSE FALSE END;
  v_verwerking_synchroon  BOOLEAN := CASE WHEN vgc$algemeen.get_appl_register ('REPORT_LABTEST_SYNCHROON') = 'J' THEN TRUE ELSE FALSE END;
  v_execute               BOOLEAN := FALSE;
  v_no_debug              BOOLEAN := FALSE;
  v_job                   NUMBER;
  v_request_id_1          NUMBER;
  v_request_id_2          NUMBER;
  v_stap_nr               NUMBER;
  v_ind                   NUMBER:= 0;
  v_request_status        NUMBER;
  v_release_status        NUMBER;
  v_chednummer            VARCHAR2(50 CHAR);
  v_operation_result      VARCHAR2(50 CHAR);
  v_webservice_logische_naam      VARCHAR2(50 CHAR);
  v_ptj_type              VARCHAR2(3 CHAR);
  v_dummy                 NUMBER;
  v_lockname              VARCHAR2(50 CHAR) := 'REPORT_LABTEST_' || to_char(p_ggs_nummer);
  v_lockhandle            VARCHAR2(128 CHAR);
  v_lmr_zegelnummer       VARCHAR2(20 CHAR);
  v_doc_nummer            VARCHAR2(100 CHAR);
  r_rqt                   vgc_requests%ROWTYPE;
  resource_busy           EXCEPTION;
  PRAGMA EXCEPTION_INIT(resource_busy, -54);
--
BEGIN
  --
  trace(v_objectnaam);
  vgc_blg.write_log('start', v_objectnaam, 'N' , 1);
  vgc_blg.write_log('p_ggs_nummer: '     || p_ggs_nummer , v_objectnaam, 'J' , 5);
  vgc_blg.write_log('p_do_it: '          || p_do_it , v_objectnaam, 'J' , 5);
  --
  -- partij ophalen
  --
  open c_ptj;
  fetch c_ptj into v_chednummer, v_ptj_type, v_lmr_zegelnummer, v_doc_nummer;
  close c_ptj;
  --
  open c_rqt(v_chednummer);
  fetch c_rqt into v_request_id_1, v_webservice_logische_naam, v_operation_result;
  close c_rqt;
  --
  IF instr(upper(v_doc_nummer),'NVWA') = 0
  THEN
    IF nvl(v_chednummer,'*') = '*' OR nvl(v_webservice_logische_naam,'*') IN ('*','VGC0504NT')
    THEN
      BEGIN
        vgc0505nt(p_ggs_nummer, v_request_id_1);
      EXCEPTION
      WHEN OTHERS
        THEN
          RAISE;
      END;
    END IF;
    --
    open c_ptj;
    fetch c_ptj into v_chednummer, v_ptj_type, v_lmr_zegelnummer, v_doc_nummer;
    close c_ptj;
    --
    open c_rqt(v_chednummer);
    fetch c_rqt into v_request_id_1, v_webservice_logische_naam, v_operation_result;
    close c_rqt;
    --
  vgc_blg.write_log('v_chednummer: '          || v_chednummer , v_objectnaam, 'J' , 5);
  vgc_blg.write_log('v_lmr_zegelnummer: '          || v_lmr_zegelnummer , v_objectnaam, 'J' , 5);
  vgc_blg.write_log('v_operation_result: '          || v_operation_result , v_objectnaam, 'J' , 5);
    IF (substr(v_chednummer,1,5) = 'CHEDD'
    OR (substr(v_chednummer,1,5) in ('CHEDA','CHEDP') and v_lmr_zegelnummer != 'XXXX'))
    AND v_operation_result = 'DONE'
    THEN
      BEGIN
        vgc0506nt(p_ggs_nummer, v_request_id_1,'J');
      EXCEPTION
      WHEN OTHERS
        THEN
         RAISE;
      END;
    END IF;
  END IF;

  -- release recordlock
  IF c_rqt_lock%ISOPEN
  THEN
    CLOSE c_rqt_lock;
  END IF;

  -- release userlock
  --v_release_status  := dbms_lock.release(v_lockhandle);
  vgc_blg.write_log('eind', v_objectnaam, 'N', 1);
EXCEPTION
  WHEN resource_busy
  THEN
    -- als openen van lock mislukt is record momenteel in bewerking --> ga verder met volgend record
    vgc_blg.write_log('Exception bij ggs_nummer: '  || r_rqt.ggs_nummer || ': ' || 'Requestrecord locked by another user' , v_objectnaam, 'N', 1);
    v_release_status  := dbms_lock.release(v_lockhandle);
  WHEN OTHERS
  THEN
    vgc_blg.write_log('Exception: ' || SQLERRM, v_objectnaam, 'N', 1);
    -- release recordlock
    IF c_rqt_lock%ISOPEN
    THEN
      CLOSE c_rqt_lock;
    END IF;

    -- release lock
    v_release_status  := dbms_lock.release(v_lockhandle);
    IF p_do_it = 'J' THEN
      ROLLBACK;
    ELSE
      qms$errors.unhandled_exception(v_objectnaam);
      RAISE;

    END IF;

END REPORT_LABTEST_TO_TNT;
/* Haalt de traces gn_code op */
PROCEDURE GET_TNT_COMMODITY_IDS
 (P_TYPE_CONSIGNMENT IN VARCHAR2 := null
 ,P_PTJ_ID IN NUMBER := null
 ,P_GN_CODE IN OUT VARCHAR2
 ,P_CERTIFICAATTYPE IN VARCHAR2 := null
 )
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.GET_TNT_COMMODITY_IDS#9';
/*********************************************************************
Wijzigingshistorie
doel:
lockt de TNT service- en operationcredentials van een BIP

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  9     17-08-2021 GLR     Aanpassing aan TNT, hernoemd
  8     31-05-2031 GLR     Wijzigingen ivm MIG 6.0
  7     10-05-2015 GLR     Wijzijgingen ivm MIG 3.05
  6     27-04-2011 GTI     bvg RFC2 (Aanpassing 2)
  5     18-11-2010 GTI     bvg BBO101104-2
  4     08-11-2010 MVB     bvg BBO101104
  3     28-04-2010 KZE     Mediaan_0009
  2     09-04-2010 KZE     LMO100409
  1     17-04-2009 KZE/MVB creatie
*********************************************************************/

--
  v_gn_code         vgc_vp_producten.gn_code%TYPE;
  v_certtype        vgc_v_gn_vertaling_traces.certificaattype%TYPE;
  v_versienr_mig_in vgc_vp_partijen.versienr_mig_in%TYPE;
  v_producttype     vgc_vp_producten.producttype%TYPE;
  v_species         vgc_vp_producten.species%TYPE;

--
  CURSOR c_commodity_codes_vp(cp_vpj_id vgc_vp_partijen.id%TYPE)
  IS
    SELECT gn_code
    ,      producttype
    ,      species
    ,      versienr_mig_in
   ,      CASE WHEN vpj.classificatie = 'LEV'
           THEN
             'L'
           WHEN vpj.classificatie = 'PRD'
           THEN
             'P'
           ELSE
             'V'
           END certificaattype
    FROM   vgc_vp_partijen vpj
    ,      vgc_vp_producten vpt
    WHERE  vpj.id = cp_vpj_id
    AND    vpt.vpj_id = vpj.id
  ;

--
  CURSOR c_commodity_codes_vgc(cp_ptj_id vgc_partijen.id%TYPE)
  IS
    SELECT clo.gn_code
    ,      clo.producttype
    ,      clo.species
    ,      ptj.versienr_mig_in
    ,      CASE WHEN ptj.ptj_type = 'LPJ'
           THEN
             'L'
           WHEN ptj.ptj_type = 'NPJ'
           THEN
             'P'
           ELSE
             'V'
           END certificaattype
    FROM   vgc_partijen ptj
    ,      vgc_colli clo
    WHERE  ptj.id = cp_ptj_id
    AND    clo.ptj_id = ptj.id
    AND    clo.clo_id IS NULL
  ;

--
-- procedure om waardes op null te zetten indien geen resultaat gevonden
--
  PROCEDURE niet_gevonden
  IS
  BEGIN
    p_gn_code := NULL;
  END niet_gevonden;

  --

BEGIN
  vgc_blg.write_log('p_ptj_id: ' || p_ptj_id, v_objectnaam, 'J', 5);
  vgc_blg.write_log('p_gn_code: ' || p_gn_code, v_objectnaam, 'J', 5);
  vgc_blg.write_log('p_type_consignment: ' || p_type_consignment, v_objectnaam, 'J', 5);
  IF p_ptj_id IS NOT NULL
  THEN
    -- haal de productgegeven op bij de partij
    IF p_type_consignment = 'VP'
    THEN
      OPEN c_commodity_codes_vp(p_ptj_id);
      FETCH c_commodity_codes_vp INTO v_gn_code, v_producttype, v_species, v_versienr_mig_in, v_certtype;
      CLOSE c_commodity_codes_vp;
    ELSE
      OPEN c_commodity_codes_vgc(p_ptj_id);
      FETCH c_commodity_codes_vgc INTO v_gn_code, v_producttype, v_species, v_versienr_mig_in, v_certtype;
      CLOSE c_commodity_codes_vgc;
    END IF;
  ELSE
    -- Anders variabelen goed zetten
    v_gn_code := p_gn_code;
    v_certtype := p_certificaattype;
  END IF;
  --
  p_gn_code := v_gn_code;
  --
EXCEPTION
  WHEN OTHERS
  THEN
    IF c_commodity_codes_vp%ISOPEN
    THEN
      CLOSE c_commodity_codes_vp;
    END IF;

    IF c_commodity_codes_vgc%ISOPEN
    THEN
      CLOSE c_commodity_codes_vgc;
    END IF;
    qms$errors.unhandled_exception(v_objectnaam);
    RAISE;

END GET_TNT_COMMODITY_IDS;

/* Mapt de VGC weigeringsreden naar een TRACES weigeringsreden */

FUNCTION GET_TNT_REFUSAL_REASON
 (P_VGC_WEIGERINGSREDEN IN VARCHAR2
 ,P_WRN_TYPE IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
v_objectnaam vgc_batchlog.proces%type := g_package_name || '.GET_TNT_REFUSAL_REASON#2';
/*********************************************************************
Wijzigingshistorie
doel:
Mapt de VGC weigeringsreden naar een TNT weigeringsreden
Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  2     17-08-2021 GLR     Aanpassing aan TNT, hernoemd
  1     21-04-2009 KZE     creatie
*********************************************************************/
  CURSOR c_wrn
  IS
    SELECT wrn.omschrijving_traces
    FROM vgc_v_weigeringredenen wrn
    WHERE wrn.code = p_vgc_weigeringsreden
    AND   wrn.wrn_type = p_wrn_type
    ;
  v_traces_omschrijving VARCHAR2(100 CHAR);
BEGIN
  vgc_blg.write_log('start', v_objectnaam, 'J', 5);
  trace(v_objectnaam);
--
  OPEN c_wrn;
  fetch c_wrn INTO v_traces_omschrijving;
  CLOSE c_wrn;
--
  RETURN v_traces_omschrijving;
--
EXCEPTION
  WHEN OTHERS THEN
    qms$errors.unhandled_exception(v_objectnaam);
    RAISE;
END GET_TNT_REFUSAL_REASON;

FUNCTION GET_TNT_TEST_REASON
 (P_CODE IN VARCHAR2
 ,p_reden_monstername IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.GET_TNT_TEST_REASON#2';
/*********************************************************************
Wijzigingshistorie
doel:
Mapt een VGC testreden naar een TRACES testresultaat

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  2     17-08-2021 GLR     Aanpassing aan TNT, hernoemd
  1     15-06-2020 GLR     creatie
*********************************************************************/
CURSOR C_LMN
 IS
   SELECT traces_omschrijving
   FROM vgc_lab_monster_redenen
   WHERE code = p_code
   ;
l_redenen varchar2(100 char);
--
BEGIN
    vgc_blg.write_log(p_code || p_reden_monstername, v_objectnaam, 'N', 1);
  IF p_code IS NULL
  THEN
    IF p_reden_monstername = 'SPF'
    THEN
      RETURN 'RANDOM';
    ELSIF p_reden_monstername = 'VDG'
    THEN
      RETURN 'SUSPICION';
    ELSE
      RETURN 'REINFORCED';
    END IF;
  ELSE
    OPEN c_lmn;
    FETCH c_lmn into l_redenen;
    IF c_lmn%notfound
    THEN
      l_redenen := 'REINFORCED';
    END IF;
    CLOSE c_lmn;
    RETURN l_redenen;
  END IF;

EXCEPTION
  WHEN OTHERS THEN
    qms$errors.unhandled_exception(v_objectnaam);
    RAISE;
END GET_TNT_TEST_REASON;

/* Mapt een VGC testresultaat naar een ternair TNT testresultaat */
FUNCTION GET_TNT_TEST_RESULT_TER
 (P_VGC_SOORT_OORDEEL IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.GET_TNT_TEST_RESULT_TER#2';
/*********************************************************************
Wijzigingshistorie
doel:
Mapt een VGC testresultaat naar een ternair TNT testresultaat

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  2     17-08-2021 GLR     Aanpassing aan TNT, hernoemd
  1     06-04-2009 KZE     creatie
*********************************************************************/

--
BEGIN
  IF p_vgc_soort_oordeel = 'CFM'
  THEN
    RETURN 'SATISFACTORY';
  ELSIF p_vgc_soort_oordeel = 'NCM'
  THEN
    RETURN 'NOT_SATISFACTORY';
  ELSE
    RETURN 'DEROGATION_OR_NOTDONE';
  END IF;


EXCEPTION
  WHEN OTHERS THEN
    qms$errors.unhandled_exception(v_objectnaam);
    RAISE;

END GET_TNT_TEST_RESULT_TER;

/* Mapt een VGC testresultaat naar een binair TNT testresultaat */
FUNCTION GET_TNT_TEST_RESULT_BIN
 (P_VGC_SOORT_OORDEEL IN VARCHAR2
 ,P_VGC_SOORT_CHECK IN VARCHAR2 := null
 )
 RETURN VARCHAR2
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.GET_TNT_TEST_RESULT_BIN#3';
/*********************************************************************
Wijzigingshistorie
doel:
Mapt een VGC testresultaat naar een binair TNT testresultaat

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  3     17-08-2021 GLR     Aanpassing aan TNT, hernoemd
  2     01-05-2017 GLR     Alleen bij CFM en NCM gevuld antwoord, anders NULL
  1     21-04-2009 KZE     creatie
*********************************************************************/

--
BEGIN
--  IF p_vgc_soort_check IN ('O') AND p_vgc_soort_oordeel <> 'NCM'
--  THEN
--    RETURN 'SATISFACTORY';
--  END IF;
  IF p_vgc_soort_oordeel = 'CFM'
  THEN
    RETURN 'SATISFACTORY';
  ELSIF p_vgc_soort_oordeel = 'NCM'
  THEN
    RETURN 'NOT_SATISFACTORY';

  ELSE
    RETURN NULL;-- 'DEROGATION_OR_NOTDONE';

  END IF;

EXCEPTION
  WHEN OTHERS
  THEN
    qms$errors.unhandled_exception(v_objectnaam);
    RAISE;
END GET_TNT_TEST_RESULT_BIN;

/* Mapt een VGC verpakkingsvorm naar een TNT verpakkingsvorm */
FUNCTION GET_TNT_TYPE_OF_PACKAGES
 (P_CODE IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.GET_TNT_TYPE_OF_PACKAGES#2';
/*********************************************************************
Wijzigingshistorie
doel:
Mapt een VGC verpakkingsvorm naar een TNT verpakkingsvorm

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  2     17-08-2021 GLR     Aanpassing aan TNT, hernoemd
  1     06-04-2009 KZE     creatie
*********************************************************************/
CURSOR C_VVM
 IS
   SELECT traces_omschrijving
   FROM vgc_verpakkingsvormen
   WHERE code = p_code
   ;
  v_traces_omschrijving VARCHAR2(100 CHAR);
BEGIN
  vgc_blg.write_log('start', v_objectnaam, 'J', 5);
  trace(v_objectnaam);
--
  OPEN c_vvm;
  fetch c_vvm INTO v_traces_omschrijving;
  CLOSE c_vvm;
--
--  RETURN v_traces_omschrijving;
  RETURN p_code;
  --
EXCEPTION
  WHEN OTHERS THEN
    qms$errors.unhandled_exception(v_objectnaam);
    RAISE;
END GET_TNT_TYPE_OF_PACKAGES;

/* Mapt een VGC type onderzoek naar een TNT type onderzoek */

FUNCTION GET_TNT_TYPE_ONDERZOEK
 (P_VGC_TYPE_O IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.GET_TNT_TYPE_ONDERZOEK#3';
/*********************************************************************
Wijzigingshistorie
doel:
Mapt een VGC type onderzoek naar een TNT type onderzoek

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  3     17-08-2021 GLR     Aanpassing aan TNT, hernoemd
  2     01-05-2017 GLR     Alleen bij ZGL en VLG gevuld antwoord, anders NULL
  1     06-04-2009 KZE     creatie
*********************************************************************/

--
BEGIN
  IF p_vgc_type_o = 'ZGL'
  THEN
    RETURN 'SEAL_CHECK';
  ELSIF p_vgc_type_o = 'VLG'
  THEN
    RETURN 'FULL_CHECK';

  ELSE
    RETURN NULL;

  END IF;

EXCEPTION
  WHEN OTHERS THEN
    qms$errors.unhandled_exception(v_objectnaam);
    RAISE;

END GET_TNT_TYPE_ONDERZOEK;

/* Mapt een VGC bestemmingstype naar een TNT bestemmingstype */

FUNCTION GET_TNT_DESTINATION_TYPE
 (P_VGC_OPSLAG IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.GET_TNT_DESTINATION_TYPE#2';
/*********************************************************************
Wijzigingshistorie
doel:
Mapt een VGC type onderzoek naar een TNTtype onderzoek

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  2     17-08-2021 GLR     Aanpassing aan TNT, hernoemd
  1     21-04-2009 KZE     creatie
*********************************************************************/

--
BEGIN
  vgc_blg.write_log('start', v_objectnaam, 'J', 5);
  IF p_vgc_opslag = 'DET'
  THEN
    RETURN 'CUSTOMS_WAREHOUSE';
  ELSIF p_vgc_opslag  = 'VTG'
  THEN
    RETURN 'DIRECT_TO_SHIP';

  ELSIF p_vgc_opslag  = 'VZT'
  THEN
    RETURN 'FREE_ZONE_OR_FREE_WAREHOUSE' ;

  ELSIF p_vgc_opslag  = 'LVT'
  THEN
    RETURN 'SHIP_SUPPLIER';

  ELSIF p_vgc_opslag  = 'MFT'
  THEN
    RETURN 'MILITARY_FACILITY';

  ELSE
    RETURN NULL;

  END IF;

END GET_TNT_DESTINATION_TYPE;

/* Mapt de VGC bestemming naar een TNT bestemming */
FUNCTION GET_TNT_DESTINATION
 (P_VGC_GEBRUIKSDOEL IN VARCHAR2
 ,P_GBL_TYPE IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.GET_TNT_DESTINATION#2';
/*********************************************************************
Wijzigingshistorie
doel:
Mapt de VGC bestemming naar een TNT bestemming

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  2     17-08-2021 GLR     Aanpassing aan TNT, hernoemd
  1     21-04-2009 KZE     creatie
*********************************************************************/
  CURSOR c_gbl
  IS
    SELECT gbl.omschrijving_traces
    FROM vgc_v_gebruiksdoelen gbl
    WHERE gbl.code = p_vgc_gebruiksdoel
    AND   gbl.gbl_type = p_gbl_type
    ;
  v_traces_omschrijving VARCHAR2(100 CHAR);
BEGIN
  vgc_blg.write_log('start', v_objectnaam, 'J', 5);
  trace(v_objectnaam);
--
  OPEN c_gbl;
  fetch c_gbl INTO v_traces_omschrijving;
  CLOSE c_gbl;
--
  RETURN v_traces_omschrijving;
  --
END GET_TNT_DESTINATION;

/* Mapt de VGC bestemming naar een TNT bestemming */
FUNCTION GET_TNT_DESTINATION_2
 (P_VGC_GEBRUIKSDOEL IN VARCHAR2
 ,P_GBL_TYPE IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.GET_TNT_DESTINATION_2#2';
/*********************************************************************
Wijzigingshistorie
doel:
Mapt de VGC bestemming naar een TNT bestemming bij beslissing

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  2     17-08-2021 GLR     Aanpassing aan TNT, hernoemd
  1     21-04-2009 KZE     creatie
*********************************************************************/
  CURSOR c_gbl
  IS
    SELECT gbl.omschrijving_traces_deel2
    FROM vgc_v_gebruiksdoelen gbl
    WHERE gbl.code = p_vgc_gebruiksdoel
    AND   gbl.gbl_type = p_gbl_type
    ;
  v_traces_omschrijving VARCHAR2(100 CHAR);
BEGIN
  vgc_blg.write_log('start', v_objectnaam, 'J', 5);
  trace(v_objectnaam);
  OPEN c_gbl;
  fetch c_gbl INTO v_traces_omschrijving;
  CLOSE c_gbl;
  RETURN v_traces_omschrijving;
  --
END GET_TNT_DESTINATION_2;
/* leidt TRACES activiteiten af ahv gn-code en rol */
FUNCTION GET_TNT_ACTIVITY_CODE
 (P_GN_CODE IN VGC_TNT_GN_CODES_ACTIVITEIT.GN_CODE%TYPE
 ,P_VGC_ROL IN VARCHAR2
 ,P_TYPE_CONSIGNMENT IN VARCHAR2
 ,P_OE_CODE_ABB IN VARCHAR2 := null
 )
 RETURN VARCHAR2
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.GET_TNT_ACTIVITY_CODE#8';
/*********************************************************************
Wijzigingshistorie
doel:
leidt TNT activiteiten af ahv gn-code en rol

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  8     17-08-2021 GLR     Aanpassing aan TNT, hernoemd
  7     01-05-2017 GLR     gn_code_comp_id toegevoegd W1702 2938
  6     10-05-2015 GLR     Wijzigingen tbv MIG 3.05
  5     03-10-2013 DdV     ORG-810 fouten reduceren
  4     09-04-2010 KZE     LMO100409
  3     08-04-2010 KZE     LMO100408
  2     09-07-2009 KZE     VWA_BEVINDINGEN_TRACES
  1     21-04-2009 KZE     creatie
*********************************************************************/

--
  CURSOR c_code
  IS
    SELECT CASE WHEN p_vgc_rol = 'AF'
           THEN
             af_activity_code
           WHEN p_vgc_rol = 'DP'
           THEN
             dp_activity_code
           WHEN p_vgc_rol = 'IM'
           THEN
             im_activity_code
           WHEN p_vgc_rol = 'OE'
           THEN
             oe_activity_code
           WHEN p_vgc_rol = 'TR'
           THEN
             tr_activity_code
           END
    FROM   vgc_tnt_gn_codes_activiteit vtag
    WHERE  p_gn_code LIKE vtag.gn_code || '%'
    AND    vtag.certificaattype = p_type_consignment
    ORDER BY length(vtag.gn_code) DESC
  ;

--
  CURSOR c_toe  (cp_oe_code vgc_tnt_oe_codes.oe_code%TYPE)
  IS
    SELECT traces_code
    FROM   vgc_tnt_oe_codes
    WHERE  nvl(oe_code,'*')  = NVL(UPPER(cp_oe_code),'*')
  ;

--
  v_activity_code VARCHAR2(100 CHAR) := NULL;

BEGIN
  vgc_blg.write_log('p_gn_code: ' || p_gn_code, v_objectnaam, 'J', 5);
  vgc_blg.write_log('p_vgc_rol: ' || p_vgc_rol, v_objectnaam, 'J', 5);
  vgc_blg.write_log('p_type_consignment: ' || p_type_consignment, v_objectnaam, 'J', 5);
  --
  trace(v_objectnaam);
  -- kijk eerst of je met een derde land relatie te maken hebt
  IF p_vgc_rol = 'OE'
  THEN
    -- zo ja probeer de meegegeven codeafkorting te vertalen naar een geldige activity code
    OPEN  c_toe(p_oe_code_abb);
    FETCH c_toe INTO v_activity_code;
    CLOSE c_toe;
    vgc_blg.write_log('v_activity_code_toe: ' || v_activity_code, v_objectnaam, 'J', 5);
    -- is het niet gelukt, probeer dan via de gn_code de activity code te achterhalen
    IF v_activity_code IS NULL
    THEN
       OPEN c_code;
       FETCH c_code INTO v_activity_code;
       CLOSE c_code;
       -- is de opgehaalde activity_code gelijk aan LMS
       IF v_activity_code = 'LMS'
       THEN
         -- in dit geval is de activity code niet te bepalen en retoruneren we dat deze waarce required is
         v_activity_code := 'LMS-code required';
       END IF;

    END IF;

  ELSE
   -- voor alle andere relaties prik in de tabel met de traces gn_code
    OPEN c_code;
    FETCH c_code INTO v_activity_code;
    CLOSE c_code;

  END IF;

  vgc_blg.write_log('v_activity_code: ' || v_activity_code, v_objectnaam, 'J', 5);
  RETURN v_activity_code;
EXCEPTION
  WHEN OTHERS
  THEN
    RETURN NULL;

END GET_TNT_ACTIVITY_CODE;

/* Mapt de VGC maatregel naar een TNT maatregel */
FUNCTION GET_TNT_MEASURE
 (P_VGC_AANVULLENDE_BESTEMMING IN VGC_VETERIN_BESTEMMINGEN.CODE%TYPE
 )
 RETURN VARCHAR2
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.GET_TNT_MEASURE#2';
/*********************************************************************
Wijzigingshistorie
doel:
Mapt de VGC maatregel naar een TRACES maatregel

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  2     17-08-2021 GLR     Aanpassing aan TNT, hernoemd
  1     09-04-2009 KZE     creatie
*********************************************************************/
--
BEGIN
  trace(v_objectnaam);
  RETURN CASE WHEN p_vgc_aanvullende_bestemming = 'DTF'
  THEN
    'INTERNAL_MARKET'
  WHEN p_vgc_aanvullende_bestemming  = 'TLK'
  THEN
    'TEMPORARY_ADMISSION'
  WHEN p_vgc_aanvullende_bestemming   = 'TKR'
  THEN
    'RE_ENTRY'
  ELSE
    NULL
  END;
EXCEPTION
  WHEN OTHERS THEN
    dbms_output.put_line(SQLERRM);
    qms$errors.unhandled_exception(v_objectnaam);
    RAISE;
END GET_TNT_MEASURE;

/* Mapt de VGC producttemperatuur naar een TNT producttemperatuur */
FUNCTION GET_TNT_PRODUCT_TEMPERATURE
 (P_VGC_CONSERVERINGSMETHODE IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.GET_TNT_PRODUCT_TEMPERATURE#2';
/*********************************************************************
Wijzigingshistorie
doel:
Mapt de VGC producttemperatuur naar een TNT producttemperatuur

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  2     17-08-2021 GLR     Aanpassing aan TNT, hernoemd
  1     06-04-2009 KZE     creatie
*********************************************************************/

--
BEGIN
  trace(v_objectnaam);
  RETURN CASE WHEN P_VGC_CONSERVERINGSMETHODE = 'GKD'
  THEN
    'CHILLED'
  WHEN P_VGC_CONSERVERINGSMETHODE = 'BVN'
  THEN
    'FROZEN'
  WHEN P_VGC_CONSERVERINGSMETHODE= 'KAM'
  THEN
    'AMBIENT'
  ELSE
    NULL
  END;
EXCEPTION
  WHEN OTHERS THEN
    qms$errors.unhandled_exception(v_objectnaam);
    RAISE;
END GET_TNT_PRODUCT_TEMPERATURE;

/* Mapt de TNT nummer type naar een VGC ID type */
FUNCTION GET_VGC_ID_TYPE
 (P_TNT_NUMMER_TYPE IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.GET_VGC_ID_TYPE#1';
/*********************************************************************
Wijzigingshistorie
doel:
Mapt de TNT nummer type naar een VGC ID type

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  1     12-11-2021 GLR     creatie
*********************************************************************/

--
BEGIN
  RETURN CASE WHEN UPPER(P_TNT_NUMMER_TYPE) = 'TRACES_NUM'
  THEN
    'TNT'
  WHEN UPPER(P_TNT_NUMMER_TYPE) = 'EORI'
  THEN
    'EOR'
  WHEN UPPER(P_TNT_NUMMER_TYPE) = 'VAT'
  THEN
    'BTW'
  WHEN UPPER(P_TNT_NUMMER_TYPE) IS NOT NULL AND UPPER(P_TNT_NUMMER_TYPE) NOT IN ('TRACES_NUM','EORI','VAT')
  THEN
    'VEN'
  ELSE
    NULL
  END;
EXCEPTION
  WHEN OTHERS THEN
    qms$errors.unhandled_exception(v_objectnaam);
    RAISE;
END GET_VGC_ID_TYPE;
/* Mapt een VGC transporttype naar een TNT transporttype */
FUNCTION GET_TNT_TRANSPORT_TYPE
 (P_VGC_TRANSPORT_IDENTIFICATIE IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.GET_TNT_TRANSPORT_TYPE#2';
/*********************************************************************
Wijzigingshistorie
doel:
Mapt een VGC transporttype naar een TNT transporttype

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  2     17-08-2021 GLR     Aanpassing aan TNT, hernoemd
  1     06-04-2009 KZE     creatie
*********************************************************************/
--
BEGIN
  trace(v_objectnaam);
  RETURN CASE WHEN P_VGC_TRANSPORT_IDENTIFICATIE = '01'
  THEN
    'PLANE'
  WHEN P_VGC_TRANSPORT_IDENTIFICATIE IN ('02', '06')
  THEN
    'ROAD'
  WHEN P_VGC_TRANSPORT_IDENTIFICATIE = '03'
  THEN
    'RAIL'
  WHEN P_VGC_TRANSPORT_IDENTIFICATIE IN ('04', '05')
  THEN
    'SHIP'
  ELSE
    'OTHER'
  END;
EXCEPTION
  WHEN OTHERS THEN
    qms$errors.unhandled_exception(v_objectnaam);
    RAISE;
END GET_TNT_TRANSPORT_TYPE;

/* Converteert een vp- of vgc-datum naar een ws-datum notatie */
FUNCTION GET_WS_DATE
 (P_VP_DATE IN VARCHAR2
 ,P_VGC_DATE IN DATE
 ,P_MASK IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
 v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.GET_WS_DATE#1';
/*********************************************************************
Wijzigingshistorie
doel:
Converteert een vp- of vgc-datum naar een ws-datum notatie

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
 1      27-04-2009 KZE     creatie
 2      11-04-2022 GLR     Zomer/wintertijd toegevoegd
*********************************************************************/

--
FUNCTION datum_in_zomertijd
 (p_datum IN DATE
 )
 RETURN VARCHAR2
 IS
 v_jaar        NUMBER(4);
 -- vertaal een willekeurige zondag naar een textwaarde die overeenkomt met de NLS_DATE_LANGUAGE instellingen
 v_zondag      VARCHAR2(255) DEFAULT to_char( to_date( '20011230', 'yyyymmdd' ), 'day' );
BEGIN
  v_jaar := extract (YEAR FROM p_datum);
  if p_datum
     --  eerste dag van de zomertijd: laatste zondag in maart
     BETWEEN   next_day(to_date('3103'||v_jaar, 'DDMMYYYY') - 7, v_zondag)
     -- laatste dag van de zomertijd: de zaterdag voor de laatste zondag in oktober
     AND       next_day(to_date('3110'||v_jaar, 'DDMMYYYY') - 7, v_zondag) - 1
 THEN
   RETURN 'J' ;
 ELSE
   RETURN 'N' ;
 END IF;
END;
--
BEGIN
  IF p_vp_date IS NOT NULL
  THEN
    IF p_mask = 'yymmdd'
    THEN
      RETURN to_char(to_date(p_vp_date, p_mask), 'yyyy-mm-dd') || 'T00:00:00';
    ELSIF p_mask = 'yymmddHH24MI'
    THEN
      RETURN to_char(to_date(p_vp_date, p_mask), 'yyyy-mm-dd')|| 'T' || to_char(to_date(p_vp_date, p_mask), 'HH24:MI') || ':00';

    ELSIF p_mask = 'yymmddHH24MISS'
    THEN
      RETURN to_char(to_date(p_vp_date, p_mask), 'yyyy-mm-dd')|| 'T' || to_char(to_date(p_vp_date, p_mask), 'HH24:MI') || ':00.000Z';

    ELSE
      RETURN NULL;

    END IF;

  END IF;

  --
  IF p_vgc_date IS NOT NULL
  THEN
    IF p_mask = 'yymmdd'
    THEN
      RETURN CASE WHEN p_vgc_date IS NULL
      THEN
        NULL
      ELSE
        to_char(p_vgc_date, 'yyyy-mm-dd') || 'T00:00:00'
      END;
    ELSIF p_mask = 'yymmddHH24MI'
    THEN
      RETURN CASE WHEN p_vgc_date IS NULL
      THEN
        NULL
      ELSE
        to_char(p_vgc_date, 'yyyy-mm-dd')|| 'T' || to_char(p_vgc_date,'HH24:MI') || ':00'
      END;
    ELSIF p_mask = 'yymmddHH24MISS'
    THEN
      RETURN CASE WHEN p_vgc_date IS NULL
      THEN
        NULL
      WHEN datum_in_zomertijd (p_vgc_date) = 'J'
      THEN
        to_char(p_vgc_date, 'yyyy-mm-dd')|| 'T' || to_char(p_vgc_date,'HH24:MI') || ':00.000+02:00'
      ELSE
        to_char(p_vgc_date, 'yyyy-mm-dd')|| 'T' || to_char(p_vgc_date,'HH24:MI') || ':00.000+01:00'
      END;
    ELSE
      RETURN NULL;

    END IF;

  END IF;

  --
  RETURN NULL;
  --
EXCEPTION
  WHEN OTHERS
  THEN
    RETURN NULL;

END get_ws_date;

/* Mapt een VGC labtestresultaat naar een TNT labtestresultaat */
FUNCTION GET_TNT_LABTEST_RESULT
 (P_VGC_LABTEST_OORDEEL IN VARCHAR2
 ,P_TYPE IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.GET_TNT_LABTEST_RESULT#2';
/*********************************************************************
Wijzigingshistorie
doel:
Mapt een VGC labtestresultaat naar een TNT labtestresultaat

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  2     17-08-2021 GLR     Aanpassing aan TNT, hernoemd
 1      21-04-2009 KZE     creatie
*********************************************************************/

--
BEGIN
  IF p_vgc_labtest_oordeel = 'CFM'
  THEN
    RETURN 'SATISFACTORY';
  ELSIF p_vgc_labtest_oordeel = 'NCM'
  THEN
    RETURN 'NOT_SATISFACTORY';
  ELSE
   IF P_TYPE = 'L'
   THEN
     RETURN 'NOT_INTERPRETABLE';
   ELSE
     RETURN 'PENDING';
   END IF;
  END IF;
EXCEPTION
  WHEN OTHERS THEN
    qms$errors.unhandled_exception(v_objectnaam);
    RAISE;
END GET_TNT_LABTEST_RESULT;
/* Concateneren lab-test methoden */
FUNCTION GET_TNT_LABTEST_METHODEN
 (P_MOK_ID IN VGC_V_PARTIJEN.ID%TYPE
 ,P_TYPE IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.GET_TNT_LABTEST_METHODEN#1';
/*********************************************************************
Wijzigingshistorie
doel:
In 1 veld alle methode weergeven voor TNT

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
 1      03-02-2022 GLR     creatie
*********************************************************************/

--
--
  CURSOR c_mme   ( b_id IN NUMBER)
  IS
    SELECT   rtrim(mme.methode) methode
    ,        rtrim(mme.resultaat) resultaat
    FROM     vgc_v_monsteronderzoek_methode mme
    WHERE    mme.mok_id = b_id
    ORDER BY mme.id ASC
  ;
  r_mme c_mme%ROWTYPE;
  l_teller NUMBER(9) := 0;
  l_methode VARCHAR2(200 CHAR);
  l_resultaat VARCHAR2(200 CHAR);
  l_return VARCHAR2(2000 CHAR);
  l_nextline VARCHAR2(10 CHAR) := chr(10);
--
BEGIN
  vgc_blg.write_log('start '||p_mok_id, v_objectnaam, 'J', 5);
  --
  FOR r_mme IN c_mme(p_mok_id)
  LOOP
    l_teller := l_teller + 1;
    IF l_teller > 1
    THEN
      l_methode := '/'||r_mme.methode;
      l_resultaat := '/'||r_mme.resultaat;
      IF p_type = 'M'
      THEN
        l_return := concat(l_return,l_methode);
      ELSE
        l_return := concat(l_return,l_resultaat);
      END IF;
    ELSE
      l_methode := r_mme.methode;
      l_resultaat := r_mme.resultaat;
      IF p_type = 'M'
      THEN
        l_return := l_methode;
      ELSE
        l_return := l_resultaat;
      END IF;
    END IF;
    EXIT WHEN length(l_return) > 1000;
  END LOOP;
  --
  vgc_blg.write_log('einde '||l_return, v_objectnaam, 'J', 5);
--  l_return := substr(l_return,1,50)||l_nextline||substr(l_return,51,100);
  RETURN substr(ltrim(rtrim(l_return)),1,250);
EXCEPTION
  WHEN OTHERS
  THEN
    qms$errors.unhandled_exception('GET_TNT_LABTEST_METHODEN');
END get_tnt_labtest_methoden;
/* Haalt een unieke TNT operator op */

FUNCTION GET_UNIQUE_TNT_OPERATOR
 (p_land_code IN     VARCHAR2
 ,p_erkenningsnummer IN VARCHAR2
 ,p_activiteit IN VARCHAR2
 )
 RETURN NUMBER
IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.GET_UNIQUE_TNT_OPERATOR#1';
/*********************************************************************
Wijzigingshistorie
doel:
Haalt een unieke TNT operator op

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
 1      30-09-2021 GLR     creatie
*********************************************************************/
  CURSOR c_toe
  IS
    SELECT id
    ,      status
    FROM   vgc_v_tnt_operator_data toe
    WHERE  toe.land_code = p_land_code
    AND    toe.erkenningsnummer = p_erkenningsnummer
    AND    toe.activiteit = nvl(p_activiteit,'establishment')
    ORDER BY toe.status desc
    ;
    l_id number;
  BEGIN
    FOR r_toe IN c_toe
    LOOP
      IF r_toe.status = 'VALID'
      THEN
        l_id := r_toe.id;
        EXIT;
      ELSE
        l_id := r_toe.id;
      END IF;
    END LOOP;
  RETURN l_id;
END GET_UNIQUE_TNT_OPERATOR;
/* Vertalen van een kolom van cyrillisch naar romaans. */

FUNCTION VERTAAL_TEKST
 (P_LAND_CODE IN VGC_TNT_POSTCODES.LAND_CODE%TYPE
 ,P_TEKST IN VARCHAR2
 )
 RETURN VARCHAR2
 IS
v_objectnaam vgc_batchlog.proces%TYPE := g_package_name || '.VERTAAL_TEKST#2';
/*********************************************************************
Wijzigingshistorie
doel:
Vertalen van een KOLOM van cyrillisch naar romaans

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
 1      20-12-2011 RMO     creatie, RFC2 Aanvulling
 2      11-11-2021 GLR     Algemener gemaakt
*********************************************************************/

--
  CURSOR c_kvt_lnd (b_land_code          vgc_karakter_vertaling.land_code%TYPE)
  IS
    SELECT 'x'
    FROM   vgc_karakter_vertaling kvt
    WHERE  kvt.land_code = b_land_code
  ;

--
  CURSOR c_kvt (p_land_code          vgc_karakter_vertaling.land_code%TYPE
               ,p_karakter_origineel vgc_karakter_vertaling.karakter_origineel%TYPE )
  IS
    SELECT kvt.karakter_romaans
    FROM   vgc_karakter_vertaling kvt
    WHERE  kvt.land_code = p_land_code
    AND    kvt.karakter_origineel = p_karakter_origineel
  ;

--
  pl_karakter_romaans   vgc_karakter_vertaling.karakter_romaans%TYPE;
  pl_tekst_romaans      VARCHAR2(1000 CHAR) := NULL;
  pl_found_lnd          BOOLEAN;
  pl_found_kvt          BOOLEAN;
  pl_dummy              VARCHAR2(1 CHAR);
--

BEGIN
  OPEN c_kvt_lnd (p_land_code);
  FETCH c_kvt_lnd INTO pl_dummy;
  pl_found_lnd := c_kvt_lnd%FOUND;
  CLOSE c_kvt_lnd;
  IF pl_found_lnd
  THEN
    -- Speciaal geval 1: Bulgarije, indien zowel cyrillische als romaanse naam voorkomt,
    -- gescheiden door een liggend streepje, dan hoeft er niet te worden vertaald
    IF p_land_code = 'BG' AND instr(p_tekst,' - ') <> 0
    THEN
      pl_tekst_romaans := substr(p_tekst,1,instr(p_tekst,' - ')-1);
    ELSE
      IF length(p_tekst) > 0
      THEN
      FOR i IN 1..length(p_tekst)
      LOOP
        OPEN c_kvt (p_land_code, substr(p_tekst,i,1));
        FETCH c_kvt INTO pl_karakter_romaans;
        pl_found_kvt := c_kvt%FOUND;
        CLOSE c_kvt;
         --
        IF pl_found_kvt
        THEN
          pl_tekst_romaans := pl_tekst_romaans || pl_karakter_romaans;
        ELSE
          pl_tekst_romaans := pl_tekst_romaans || substr(p_tekst,i,1);
        END IF;
      END LOOP;
    END IF;
    END IF;
  END IF;
  --
  IF p_tekst = pl_tekst_romaans
  OR pl_tekst_romaans IS NULL
  THEN
    RETURN p_tekst;
  ELSE
    RETURN pl_tekst_romaans;

  END IF;

EXCEPTION
  WHEN OTHERS
  THEN
    IF c_kvt_lnd%ISOPEN
    THEN
      CLOSE c_kvt_lnd;
    END IF;

    IF c_kvt%ISOPEN
    THEN
      CLOSE c_kvt;
    END IF;

    vgc_blg.write_log('Exception: ' || SQLERRM, v_objectnaam, 'N', 1);
    qms$errors.unhandled_exception(v_objectnaam);

END VERTAAL_TEKST;

/* Controleren van et adres van een relatie. */

FUNCTION VALIDE_ADRES_RELATIE
 (O_STADSNAAM_TRACES OUT VARCHAR2
 ,O_POSTCODE_TRACES OUT VARCHAR2
 ,P_TYPE_RELATIE IN VARCHAR2
 ,P_LAND_CODE IN VARCHAR2
 ,P_STADSNAAM IN VARCHAR2
 ,P_POSTCODE IN VARCHAR2
 )
 RETURN BOOLEAN
 IS
v_objectnaam vgc_batchlog.proces%TYPE  := g_package_name||'.VALIDE_ADRES_RELATIE#3';
/*********************************************************************
Wijzigingshistorie
doel:
Controleren van het adres van een relatie

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  3     13-08-2021 GLR     Aangepast aan TNT postcode controle
  2     09-01-2012 RMO     bvg RFC2-Aanvulling
  1     28-03-2011 KZE     creatie 1
*********************************************************************/

--
  CURSOR c_lnd(b_land_code VARCHAR2)
  IS
    SELECT lnd.eu_ind, lnd.postcode_controle, lnd.compare_module
    FROM   vgc_landen lnd
    WHERE  lnd.code = b_land_code
  ;

--
  CURSOR c_tpe(b_land_code VARCHAR2,
               b_plaatsnaam VARCHAR2,
               b_postcode VARCHAR2)
  IS
    SELECT tpe.stadsnaam_traces_nt,
           tpe.postcode
    FROM   vgc_tnt_postcodes tpe
    WHERE  tpe.land_code = b_land_code
    AND    (upper(tpe.stadsnaam_vgc) = b_plaatsnaam
    OR     upper(tpe.stadsnaam_traces_nt) = b_plaatsnaam)
    AND    (tpe.postcode = b_postcode OR b_postcode IS NULL)
    AND    tpe.status = 'ACTIVE'
  ;
--
  r_tpe                c_tpe%ROWTYPE;
  v_eu_ind             vgc_landen.eu_ind%TYPE;
  v_compare_module     vgc_landen.compare_module%TYPE;
  v_postcode_controle  vgc_landen.postcode_controle%TYPE;
  v_postcode_match     vgc_tnt_postcodes.postcode%TYPE;
  v_result             VARCHAR2(200 CHAR);
--
BEGIN
  vgc_blg.write_log('start', v_objectnaam, 'J', 1);
  vgc_blg.write_log('p_type_relatie: ' || p_type_relatie, v_objectnaam, 'J', 5);
  vgc_blg.write_log('p_land_code: ' || p_land_code, v_objectnaam, 'J', 5);
  vgc_blg.write_log('p_stadsnaam: ' || p_stadsnaam, v_objectnaam, 'J', 5);
  vgc_blg.write_log('p_postcode: ' || p_postcode, v_objectnaam, 'J', 5);
  --
  -- ophalen land data
  --
  OPEN c_lnd(p_land_code);
  FETCH c_lnd INTO v_eu_ind, v_postcode_controle, v_compare_module;
  -- als land niet gevonden
  IF c_lnd%NOTFOUND
  THEN
    CLOSE c_lnd;
    vgc_blg.write_log('land niet gevonden', v_objectnaam, 'J', 5);
    RETURN FALSE;
  ELSE
    CLOSE c_lnd;
  END IF;
  --
  -- controle op geldige plaatsnaam bij land
  --
  OPEN c_tpe(p_land_code, upper(p_stadsnaam), NULL);
  FETCH c_tpe INTO r_tpe;
  IF c_tpe%NOTFOUND
  THEN
    CLOSE c_tpe;
    IF p_land_code = 'NL'
    THEN
      -- nederlandse plaats, staat in tabel en niet zoeken in TNT
      --
      vgc_blg.write_log('Nederlandse stad niet gevonden: '  || p_stadsnaam, v_objectnaam, 'J', 5);
      o_stadsnaam_traces := p_stadsnaam;
      RETURN FALSE;
    ELSE
      vgc_blg.write_log('stad niet gevonden, ophalen uit TNT: '  || p_stadsnaam, v_objectnaam, 'J', 5);
      o_stadsnaam_traces := p_stadsnaam;
      --
      -- ophalen uit TNT
      --
      BEGIN
        vgc_ws_traces_nt.vgc0702nt (p_land_code,null,p_stadsnaam);
      EXCEPTION
      WHEN OTHERS
        THEN
          NULL;
      END;
      --
      -- nogmaals proberen
      --
      OPEN c_tpe(p_land_code, upper(p_stadsnaam), NULL);
      FETCH c_tpe INTO r_tpe;
      IF c_tpe%NOTFOUND
      THEN
        CLOSE c_tpe;
        vgc_blg.write_log('stad niet gevonden in TNT: '  || p_stadsnaam, v_objectnaam, 'J', 5);
        o_stadsnaam_traces := p_stadsnaam;
        RETURN FALSE;
      ELSE
        CLOSE c_tpe;
        o_stadsnaam_traces := r_tpe.stadsnaam_traces_nt;
        o_postcode_traces := NULL; --reset, kan de verkeerde zijn
        vgc_blg.write_log('stad gevonden in TNT: '  || o_stadsnaam_traces, v_objectnaam, 'J', 5);
      END IF;
    END IF;
  ELSE
    CLOSE c_tpe;
    o_stadsnaam_traces := r_tpe.stadsnaam_traces_nt;
    o_postcode_traces := NULL; --reset, kan de verkeerde zijn
    vgc_blg.write_log('stad gevonden: '  || o_stadsnaam_traces, v_objectnaam, 'J', 5);
  END IF;
  --
  -- controle op geldige postcode bij land en plaatsnaam
  --
  IF v_postcode_controle = 'J' AND p_postcode IS NOT NULL
  THEN
    vgc_blg.write_log('postcode controle vereist', v_objectnaam, 'J', 5);
    --
    IF p_land_code = 'NL'
    THEN
      v_postcode_match := substr(p_postcode, 1,4);
    ELSE
      v_postcode_match := p_postcode;
    END IF;
    r_tpe := NULL;
    OPEN c_tpe(p_land_code, upper(p_stadsnaam), v_postcode_match);
    FETCH c_tpe INTO r_tpe;
    IF c_tpe%NOTFOUND
    THEN
      CLOSE c_tpe;
      IF p_land_code = 'NL'
      THEN
        -- Nederlandse plaats, staat in tabel en niet zoeken in TNT
        --
        vgc_blg.write_log('Nederlandse postcode niet gevonden: '  || v_postcode_match, v_objectnaam, 'J', 5);
        o_postcode_traces := v_postcode_match;
        RETURN FALSE;
      ELSE
        vgc_blg.write_log('postcode niet gevonden, ophalen uit TNT: '  || v_postcode_match, v_objectnaam, 'J', 5);
        o_postcode_traces := v_postcode_match;
        vgc_blg.write_log('postcode ophalen uit TNT', v_objectnaam, 'J', 5);
        --
        -- ophalen uit TNT
        --
        BEGIN
          vgc_ws_traces_nt.vgc0702nt (p_land_code,v_postcode_match,null);
        EXCEPTION
        WHEN OTHERS
          THEN
            NULL;
        END;
        --
        -- nogmaals proberen
        --
        OPEN c_tpe(p_land_code, upper(p_stadsnaam), v_postcode_match);
        FETCH c_tpe INTO r_tpe;
        IF c_tpe%NOTFOUND
        THEN
          CLOSE c_tpe;
          vgc_blg.write_log('postcode niet gevonden in TNT: '  || v_postcode_match, v_objectnaam, 'J', 5);
          o_postcode_traces := v_postcode_match;
          RETURN FALSE;
        ELSE
          CLOSE c_tpe;
          o_postcode_traces := r_tpe.postcode;
          vgc_blg.write_log('postcode gevonden in TNT: '  || o_postcode_traces, v_objectnaam, 'J', 5);
        END IF;
      END IF;
    ELSE
      CLOSE c_tpe;
      o_postcode_traces := r_tpe.postcode;
      vgc_blg.write_log('postcode gevonden in TNT: '  || o_postcode_traces, v_objectnaam, 'J', 5);
    END IF;
  END IF;
  --
  vgc_blg.write_log('eind', v_objectnaam, 'J', 1);
  --
  RETURN TRUE;
EXCEPTION
  WHEN OTHERS
  THEN
    IF c_lnd%ISOPEN
    THEN
      CLOSE c_lnd;
    END IF;

    IF c_tpe%ISOPEN
    THEN
      CLOSE c_tpe;
    END IF;

    vgc_blg.write_log('exception: ' || SQLERRM , v_objectnaam, 'N', 1);
    RAISE;

END VALIDE_ADRES_RELATIE;

FUNCTION VALIDE_LAND_RELATIE
 (P_TYPE_RELATIE IN VARCHAR2
 ,P_LAND_CODE IN VARCHAR2
 ,P_CVED_TYPE IN VARCHAR2
 ,P_VETERINAIRE_BESTEMMING IN VARCHAR2
 )
 RETURN BOOLEAN
 IS
v_objectnaam vgc_batchlog.proces%TYPE  := g_package_name||'.VALIDE_LAND_RELATIE#4';
/*********************************************************************
Wijzigingshistorie
doel:
Controleren van het land van een relatie

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
 4      13-08-2021 GLR     Aangepast aan TNT postcode controle
 3      29-03-2012 GLR     toevoegen land_controle
 2      29-06-2011 GTI     bvg BBO110601
 1      28-03-2011 KZE     creatie
*********************************************************************/

--
  CURSOR c_lnd(b_land_code VARCHAR2)
  IS
    SELECT lnd.eu_ind
    ,      lnd.land_controle
    FROM   vgc_landen lnd
    WHERE  lnd.code = b_land_code
  ;

--
  v_eu_ind       VARCHAR2(1 CHAR);
  v_land_controle VARCHAR2(1 CHAR);
--

BEGIN
    vgc_blg.write_log('start', v_objectnaam, 'J', 1);
    vgc_blg.write_log('p_type_relatie: ' || p_type_relatie, v_objectnaam, 'J', 5);
    vgc_blg.write_log('p_land_code: ' || p_land_code, v_objectnaam, 'J', 5);
    vgc_blg.write_log('p_cved_type: ' || p_cved_type, v_objectnaam, 'J', 5);
    vgc_blg.write_log('p_veterinaire_bestemming: ' || p_veterinaire_bestemming, v_objectnaam, 'J', 5);
    -- ophalen of landdata
    OPEN c_lnd(p_land_code);
    FETCH c_lnd INTO v_eu_ind, v_land_controle;
    -- als land niet gevonden
    IF c_lnd%NOTFOUND
    THEN
      vgc_blg.write_log('land niet gevonden', v_objectnaam, 'J', 5);
      RETURN FALSE;
    END IF;

    CLOSE c_lnd;

    vgc_blg.write_log('eind', v_objectnaam, 'J', 1);
    RETURN TRUE;
  EXCEPTION
    WHEN OTHERS
    THEN
      IF c_lnd%ISOPEN
      THEN
        CLOSE c_lnd;
      END IF;

      vgc_blg.write_log('exception: ' || SQLERRM , v_objectnaam, 'N', 1);
      RAISE;

  END valide_land_relatie;

FUNCTION GET_RELATIE_ELEMENT
 (P_TYPE_RELATIE IN VARCHAR2
 ,P_NAAM IN VARCHAR2
 ,P_LAND_CODE IN VARCHAR2
 ,P_STADSNAAM IN VARCHAR2
 ,P_POSTCODE IN VARCHAR2
 ,P_STRAAT_POSTBUS IN VARCHAR2
 ,P_HUISNUMMER IN VARCHAR2
 ,P_HUISNUMMER_TOEVOEGING IN VARCHAR2
 ,P_ACTIVITY_CODE IN VARCHAR2
 ,P_ID_TYPE IN VARCHAR2
 ,P_TRACES_ID IN VARCHAR2
 )
 RETURN XMLTYPE
 IS
v_objectnaam vgc_batchlog.proces%TYPE  := g_package_name||'.GET_RELATIE_ELEMENT#1';
/*********************************************************************
Wijzigingshistorie
doel:
Ophalen onderdelen van de  relatie

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
 1      28-03-2011 KZE     creatie
*********************************************************************/

--
  v_stadsnaam_traces vgc_tnt_postcodes.stadsnaam_traces_nt%TYPE;
  v_postcode_traces vgc_tnt_postcodes.postcode%TYPE;
--
  CURSOR c_xml
  IS
    SELECT xmlforest(
             xmlforest( p_activity_code "referenceDataCode" )  "activity"
--    ,        xmlforest( case when p_traces_id is not null then p_traces_id else null end "approvalNumber"
-->DDV!
    ,        xmlforest( case
                          when p_traces_id = 'X'
                            then null
                          when p_traces_id = '.'
                            then null
                          when p_traces_id like 'VGC%'
                            then null
                          when p_traces_id is not null
                            then p_traces_id
                          else null
                        end "approvalNumber"
    ,                   case
                          when length(p_traces_id) = 11
                            and substr(p_traces_id,1,2) = 'NL'
                          then 'EORI'
                        else p_id_type
                        end "approvalNumberType"
    ,                   p_land_code "countryCode"   )  "business"
    ,        xmlforest(
               xmlforest( v_stadsnaam_traces "name"
    ,                     v_postcode_traces "regionPostalCode"
               ) "city"
    ,          p_naam "name"
    ,          ltrim(rtrim(nvl(p_straat_postbus, 'UNKNOWN') || ' ' || p_huisnummer || p_huisnummer_toevoeging)) "streetNumber"
             ) "businessDetail"
           )
    FROM dual
  ;

--
  v_result xmltype;
  v_valide_straat_postcode BOOLEAN;

BEGIN
  vgc_blg.write_log('start', v_objectnaam, 'J', 1);
  vgc_blg.write_log('p_type_relatie: ' || p_type_relatie, v_objectnaam, 'J', 5);
  vgc_blg.write_log('p_naam: ' || p_naam, v_objectnaam, 'J', 5);
  vgc_blg.write_log('p_stadsnaam: ' || p_stadsnaam, v_objectnaam, 'J', 5);
  vgc_blg.write_log('p_land_code: ' || p_land_code, v_objectnaam, 'J', 5);
  vgc_blg.write_log('p_straat_postbus: ' || p_straat_postbus, v_objectnaam, 'J', 5);
  vgc_blg.write_log('p_huisnummer: ' || p_huisnummer, v_objectnaam, 'J', 5);
  vgc_blg.write_log('p_huisnummer_toevoeging: ' || p_huisnummer_toevoeging, v_objectnaam, 'J', 5);
  vgc_blg.write_log('p_activitycode: ' || p_activity_code, v_objectnaam, 'J', 5);
  vgc_blg.write_log('p_traces_id: ' || p_traces_id, v_objectnaam, 'J', 5);
  -- ophalen traces stadsnaam en plaatsnaam (indien valid)
  v_valide_straat_postcode := valide_adres_relatie(v_stadsnaam_traces, v_postcode_traces, p_type_relatie, p_land_code, p_stadsnaam, p_postcode);
  --
  OPEN c_xml;
  FETCH c_xml INTO v_result;
  CLOSE c_xml;
  --
  vgc_blg.write_log('eind', v_objectnaam, 'J', 5);
  --
  RETURN v_result;
EXCEPTION
  WHEN OTHERS
  THEN
    vgc_blg.write_log('exception: ' || SQLERRM , v_objectnaam, 'N', 1);
    RAISE;

END GET_RELATIE_ELEMENT;

/* Generieke controle van een bestaande request uit tabel VGC_REQUESTS. */

PROCEDURE CHECK_BESTAANDE_RQT
 (R_RQT IN OUT VGC_REQUESTS%ROWTYPE
 ,P_ERROR_HANDLING IN VARCHAR2 := 'J'
 )
 IS
v_objectnaam vgc_batchlog.proces%TYPE  := g_package_name||'.CHECK_BESTAANDE_RQT#2';
/*********************************************************************
Wijzigingshistorie
doel:
Generieke controle van een bestaande request

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
 3      20-10-2010 KZE     RFC1-6-001
 2      25-06-2010 DRO     bvg RFC1-7
 1      04-08-2010 GTI     creatie
*********************************************************************/

--
  v_max_retry_traces  vgc_applicatie_registers.waarde%TYPE;

BEGIN
  trace(v_objectnaam);
  vgc_blg.write_log('start' , v_objectnaam, 'N', 1);
  IF p_error_handling = 'J'
  THEN
    IF r_rqt.herstel_actie NOT IN ('AU')
    THEN
      raise_application_error(-20000, g_package_name || r_rqt.webservice_logische_naam ||': Aanroep webservice afgebroken. Herstel actie heeft een waarde ongelijk aan Automatisch.');
    END IF;

  END IF;

  --
  v_max_retry_traces :=  vgc$algemeen.get_appl_register('MAX_RETRY_TRACES');
  --
  vgc_blg.write_log('retry teller '||r_rqt.retry_teller , v_objectnaam, 'N', 1);
  vgc_blg.write_log('max retry '||v_max_retry_traces , v_objectnaam, 'N', 1);
  IF r_rqt.retry_teller >= v_max_retry_traces
  THEN
    vgc_blg.write_log('MR' , v_objectnaam, 'N', 1);
    r_rqt.herstel_actie := 'MR';
    UPDATE vgc_requests
    SET    herstel_actie = r_rqt.herstel_actie
    WHERE  request_id    = r_rqt.request_id;

    raise_application_error(-20000, g_package_name || r_rqt.webservice_logische_naam ||': Aanroep webservice afgebroken. Retry teller heeft een waarde groter dan maximaal is toegestaan.');
  ELSE
    r_rqt.retry_teller := r_rqt.retry_teller + 1;
    UPDATE vgc_requests
    SET    retry_teller  = r_rqt.retry_teller
    WHERE  request_id    = r_rqt.request_id;
    vgc_blg.write_log('retry tellen '||r_rqt.retry_teller , v_objectnaam, 'N', 1);

  END IF;
  commit;
EXCEPTION
  WHEN OTHERS
  THEN
    RAISE;

END CHECK_BESTAANDE_RQT;
/* Procedure die dienstdoet als bezemwagen voor mislukte requesten */

PROCEDURE BEZEMWAGEN
 IS
v_objectnaam vgc_batchlog.proces%TYPE  := g_package_name||'.BEZEMWAGEN#4';
/*********************************************************************
Wijzigingshistorie
doel:
Bezemwagen

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
   4    06-09-2022 GLR      Herschreven deel ivm koppeling TNT
   3    05-12-2011 GLR      Bepalen startdatum bezemwagen uit view gehaald
   2    25-10-2010 KZE      Mediaan_0011
                            RFC1-6-001
   1     28-06-2010 KZE     creatie
*********************************************************************/

--
  v_startdatum             vgc_requests.datum%TYPE := to_date(vgc$algemeen.get_appl_register ('BEZEMWAGEN_BEGINDATUM'), 'DD-MM-YYYY');
--
  CURSOR c_bwn
  IS
    SELECT *
    FROM   vgc_v_tnt_bezemwagen bwn
    WHERE  bwn.datum > sysdate - 1
    AND    bwn.aantal_pogingen < 5
  ;
--
  l_request_id number;
BEGIN
  trace(v_objectnaam);
  vgc_blg.write_log('start', v_objectnaam, 'N', 1);
  FOR r_bwn IN c_bwn
  LOOP
    BEGIN
      IF r_bwn.webservice_logische_naam = 'VGC0503NT' 
      THEN  
        -- call report_decision_to_traces
        report_decision_to_tnt(r_bwn.ggs_nummer, 'J', 'J');
      ELSE
        vgc_ws_traces_nt.vgc0505nt(r_bwn.ggs_nummer,l_request_id,'J');
      END IF;    
      COMMIT;
    EXCEPTION
      WHEN OTHERS
      THEN
        vgc_blg.write_log('Exception bij ggs_nummer: ' || r_bwn.ggs_nummer || ': ' || SQLERRM, v_objectnaam, 'N', 1);

    END;
  END LOOP;

  vgc_blg.write_log('eind', v_objectnaam, 'N', 1);
EXCEPTION
  WHEN OTHERS
  THEN
    vgc_blg.write_log('Exception: ' || SQLERRM, v_objectnaam, 'N', 1);
    ROLLBACK;

END BEZEMWAGEN;

PROCEDURE DEFAULT_PC_COMPARE_MODULE
 (O_POSTCODE_TRACES OUT VARCHAR2
 ,P_LAND_CODE IN VARCHAR2
 ,P_STADSNAAM IN VARCHAR2
 ,P_POSTCODE IN VARCHAR2
 )
 IS
v_objectnaam vgc_batchlog.proces%TYPE  := g_package_name||'.DEFAULT_POSTCODE_COMPARE_MODULE#2';
/*********************************************************************
Wijzigingshistorie
doel:
Default Postcode check

Versie  Wanneer    Wie      Wat
------- ---------- --------------------------------------------------
  2     09-01-2012 RMO     bvg RFC2-Aanvulling
  1     14-04-2011 KZE     creatie
*********************************************************************/

--
  CURSOR c_tpe(b_land_code VARCHAR2,
               b_stadsnaam VARCHAR2,
               b_postcode VARCHAR2)
  IS
    SELECT tpe.postcode
    FROM   vgc_tnt_postcodes tpe
    WHERE  tpe.land_code = b_land_code
      AND  tpe.stadsnaam_uppercase = b_stadsnaam
      AND  b_postcode LIKE tpe.postcode || '%'
  ;

--

BEGIN
  vgc_blg.write_log('start', v_objectnaam, 'J', 1);
  OPEN c_tpe(p_land_code, upper(p_stadsnaam), p_postcode);
  FETCH c_tpe INTO o_postcode_traces;
  IF c_tpe%NOTFOUND
  THEN
    vgc_blg.write_log('geen match gevonden', v_objectnaam, 'J', 5);
    o_postcode_traces := NULL;
  ELSE
    vgc_blg.write_log('match gevonden: ' || o_postcode_traces, v_objectnaam, 'J', 5);

  END IF;

  CLOSE c_tpe;
  vgc_blg.write_log('eind', v_objectnaam, 'J', 1);
EXCEPTION
  WHEN OTHERS
  THEN
    IF c_tpe%ISOPEN
    THEN
      CLOSE c_tpe;
    END IF;

    vgc_blg.write_log('exception: ' || SQLERRM , v_objectnaam, 'N', 1);
    RAISE;

END default_pc_compare_module;
/* Mail de logging naar FB */
PROCEDURE LOG
 (P_TEKST IN VARCHAR2
 ,P_TYPE IN VARCHAR2 := 'I'
 )
 IS
/* Naam         : LOG                                                         */
/* Omschrijving : Mail de logging naar FB                                     */
/* Auteur       : G.L. Rijkers                                                */
/* Creatiedatum : 02.09.2021                                                  */
/*                                                                            */
/* Revisie      :                                                             */
/*  02.09.2021 GLR          Creatie                                           */
/*                                                                            */
  v_objectnaam vgc_batchlog.proces%type  := g_package_name||'.LOG#1';
  l_aan VARCHAR2(32000 CHAR) := vgc$algemeen.get_appl_register('CIM_MAIL_FAB');
  l_log VARCHAR2(32000 CHAR) := 'Onderstaand de logging van de interface met CIM op '||to_char(sysdate,'fmdd month rrrr','nls_date_language=''DUTCH''')||utl_tcp.crlf||utl_tcp.crlf;
BEGIN
  vgc_blg.write_log('Start' , v_objectnaam, 'J' , 5);
  IF UPPER(P_TYPE) = 'E' THEN
  --  l_aan := l_aan||';'||vgc$algemeen.get_appl_register('CIM_MAIL_AB');
    l_log := l_log||utl_tcp.crlf||'Er is een fout opgetreden in de interface:'||utl_tcp.crlf||p_tekst||utl_tcp.crlf;
  ELSE
    l_log := l_log||utl_tcp.crlf||p_tekst||utl_tcp.crlf;
  END IF;
  --
  vgc_blg.write_log('Aan : '||l_aan , v_objectnaam, 'J' , 5);
  alg_mail.sendmail(p_recipient    => l_aan
                   ,p_subject      => 'Logverslag van de interface met CIM op '||to_char(sysdate,'fmdd month rrrr','nls_date_language=''DUTCH''')
                   ,p_message      => l_log
                   ,p_attachment   => l_log
                   ,p_att_naam     => 'Logverslag_VGC_CIM_'||to_char(sysdate,'yyyymmdd')||'.txt'
                   );
  vgc_blg.write_log('Einde' , v_objectnaam, 'J' , 5);
END;
END VGC_WS_TRACES_NT;

