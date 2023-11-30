SET SERVEROUTPUT ON;

-- USER PACKAGE STARTS HERE

CREATE OR REPLACE PACKAGE USERPACKAGE AS
    FUNCTION SEARCHBOOK(BOOK_ID NUMBER) RETURN VARCHAR2;
    --PROCEDURE BORROWBOOK (BOOK_ID NUMBER);
END USERPACKAGE;

CREATE OR REPLACE PACKAGE BODY USERPACKAGE AS 
    FUNCTION SEARCHBOOK(BOOK_ID NUMBER) RETURN VARCHAR2 IS
        AVAILABLE NUMBER;
        BOOK_LOCATION VARCHAR2;
    BEGIN
        -- Using an alias for better clarity
        SELECT BOOK_COUNT INTO AVAILABLE FROM LIBRARY_BOOKS LB WHERE LB.BOOK_ID = SEARCHBOOK.BOOK_ID;
        SELECT BOOK_LOC INTO BOOK_LOCATION FROM LIBRARY_BOOKS LB WHERE LB.BOOK_ID = SEARCHBOOK.BOOK_ID;
        
        IF AVAILABLE = 0 THEN
            RETURN 'Book ID not found.';
        ELSE
            RETURN AVAILABLE || ' copies of ' || ' is available at ' || BOOK_LOC;
        END IF;
    END SEARCHBOOK;
END USERPACKAGE;


DECLARE
    IS_AVAILABLE VARCHAR2(50);
BEGIN
    IS_AVAILABLE := USERPACKAGE.SEARCHBOOK(1005);
    DBMS_OUTPUT.PUT_LINE(IS_AVAILABLE);
END;


-- USER PACKAGE ENDS HERE


-- STAFF PACKAGE STARTS HERE

CREATE OR REPLACE PACKAGE STAFFPACKAGE AS
    PROCEDURE ADDBOOK(TITLE VARCHAR2, LOCATION VARCHAR2, COUNT NUMBER);
    PROCEDURE DELETEBOOK(BOOK_ID NUMBER, COUNT NUMBER);
END STAFFPACKAGE;
/
    PROCEDURE GENERATEREPORT(REPORT_TYPE VARCHAR2);
    PROCEDURE NOTIFYUSER(BOOK_ID NUMBER);

CREATE OR REPLACE PACKAGE BODY STAFFPACKAGE AS
    PROCEDURE ADDBOOK(TITLE VARCHAR2, LOCATION VARCHAR2, COUNT NUMBER) IS
        v_book_id LIBRARY_BOOKS.BOOK_ID%TYPE;
        v_existing_count LIBRARY_BOOKS.BOOK_COUNT%TYPE;

    BEGIN
        -- Check if the book already exists
        SELECT BOOK_ID, BOOK_COUNT
        INTO v_book_id, v_existing_count
        FROM LIBRARY_BOOKS
        WHERE BOOK_NAME = TITLE AND BOOK_LOC = LOCATION;

        -- Book exists, update the count
        UPDATE LIBRARY_BOOKS
        SET BOOK_COUNT = v_existing_count + COUNT
        WHERE BOOK_ID = v_book_id;

        -- Book doesn't exist, insert a new record
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                INSERT INTO LIBRARY_BOOKS (BOOK_NAME, BOOK_LOC, BOOK_COUNT)
                VALUES (TITLE, LOCATION, COUNT);
    END ADDBOOK;
    
    PROCEDURE DELETEBOOK(BOOK_ID NUMBER, COUNT NUMBER) IS
        v_existing_count LIBRARY_BOOKS.BOOK_COUNT%TYPE;

    BEGIN
        -- Retrieve the existing count for the book
        SELECT BOOK_COUNT
        INTO v_existing_count
        FROM LIBRARY_BOOKS
        WHERE BOOK_ID = BOOK_ID;

        -- Check if the count to delete is greater than the existing count
        IF COUNT > v_existing_count THEN
            DBMS_OUTPUT.PUT_LINE('Error: Cannot delete more copies than available.');
        ELSE
            -- Update the count
            UPDATE LIBRARY_BOOKS
            SET BOOK_COUNT = v_existing_count - COUNT
            WHERE BOOK_ID = BOOK_ID;
        END IF;
    END DELETEBOOK;
    
    PROCEDURE GENERATEREPORT(REPORT_TYPE VARCHAR2) IS
    BEGIN
        -- Generate report based on the specified type
        IF REPORT_TYPE = 'Books borrowed' THEN
            FOR rec IN (SELECT * FROM BORROWED_BOOKS) LOOP
                DBMS_OUTPUT.PUT_LINE('Book ID: ' || rec.BOOK_ID || ', User ID: ' || rec.USER_ID || ', Borrow Date: ' || rec.BORROW_DATE);
            END LOOP;
        ELSIF REPORT_TYPE = 'Books reserved' THEN
            FOR rec IN (SELECT * FROM RESERVED_BOOKS) LOOP
                DBMS_OUTPUT.PUT_LINE('Book ID: ' || rec.BOOK_ID || ', User ID: ' || rec.USER_ID || ', Reserve Date: ' || rec.RESERVE_DATE);
            END LOOP;
        ELSE
            DBMS_OUTPUT.PUT_LINE('Error: Invalid report type.');
        END IF;
    END GENERATEREPORT;
    
END STAFFPACKAGE;
/





