CREATE OR REPLACE PACKAGE BODY demo_pkg AS

    PROCEDURE add_message(p_message IN VARCHAR2) AS
    BEGIN
        INSERT INTO demo_message (message)
        VALUES (p_message);

        COMMIT;
    END add_message;

    FUNCTION get_message_count RETURN NUMBER AS
        l_count NUMBER;
    BEGIN
        SELECT COUNT(*)
        INTO l_count
        FROM demo_message;

        RETURN l_count;
    END get_message_count;

    PROCEDURE health_check AS
        l_count NUMBER;
    BEGIN
        l_count := get_message_count;
        DBMS_OUTPUT.PUT_LINE('DEMO_PKG health check OK. Message count=' || l_count);
    END health_check;

END demo_pkg;
/