SET HEADING ON
SET FEEDBACK ON
SET PAGESIZE 100
SET LINESIZE 200

PROMPT Checking invalid objects...

COLUMN object_name FORMAT A40
COLUMN object_type FORMAT A25
COLUMN status FORMAT A10

SELECT object_name, object_type, status
FROM user_objects
WHERE status = 'INVALID'
ORDER BY object_type, object_name;

DECLARE
    l_invalid_count NUMBER;
BEGIN
    SELECT COUNT(*)
    INTO l_invalid_count
    FROM user_objects
    WHERE status = 'INVALID';

    IF l_invalid_count > 0 THEN
        RAISE_APPLICATION_ERROR(-20001, 'Invalid database objects found after deployment.');
    END IF;
END;
/

EXIT