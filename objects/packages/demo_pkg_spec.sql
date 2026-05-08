CREATE OR REPLACE PACKAGE demo_pkg AS
    PROCEDURE add_message(p_message IN VARCHAR2);
    FUNCTION get_message_count RETURN NUMBER;
    PROCEDURE health_check;
END demo_pkg;
/