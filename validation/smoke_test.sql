SET SERVEROUTPUT ON
SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 100
SET LINESIZE 200

PROMPT Running smoke test...

BEGIN
    demo_pkg.add_message('Smoke test message from Oracle DB CI/CD pipeline');
    demo_pkg.health_check;
END;
/

SELECT COUNT(*) AS demo_message_count
FROM demo_message;

EXIT