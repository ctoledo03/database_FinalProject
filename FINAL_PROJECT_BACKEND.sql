SET SERVEROUTPUT ON;

SELECT R_BOOKID_SEQ.NEXTVAL FROM DUAL;
SELECT B_BOOKID_SEQ.NEXTVAL FROM DUAL;

-- USER PACKAGE STARTS HERE

CREATE OR REPLACE PACKAGE USERPACKAGE AS
    FUNCTION SEARCHBOOK(BOOK_ID NUMBER) RETURN VARCHAR2;
    PROCEDURE BORROWBOOK (BOOK_ID NUMBER, USER_ID NUMBER);
    PROCEDURE RETURNBOOK (BOOK_ID NUMBER, USER_ID NUMBER);
    PROCEDURE RESERVEBOOK (BOOK_ID NUMBER, USER_ID NUMBER);
END USERPACKAGE;

CREATE OR REPLACE PACKAGE BODY USERPACKAGE AS 
    FUNCTION SEARCHBOOK(BOOK_ID NUMBER) RETURN VARCHAR2 IS
        AVAILABLE NUMBER(2);
        BOOK_TITLE VARCHAR2(30);
        BOOK_LOCATION VARCHAR2(6);
    BEGIN
        -- Using an alias for better clarity
        SELECT BOOK_COUNT INTO AVAILABLE FROM LIBRARY_BOOKS LB WHERE LB.BOOK_ID = SEARCHBOOK.BOOK_ID;
        SELECT BOOK_NAME INTO BOOK_TITLE FROM LIBRARY_BOOKS LB WHERE LB.BOOK_ID = SEARCHBOOK.BOOK_ID;
        SELECT BOOK_LOC INTO BOOK_LOCATION FROM LIBRARY_BOOKS LB WHERE LB.BOOK_ID = SEARCHBOOK.BOOK_ID;
        
        IF AVAILABLE = 0 THEN
            RETURN 'Book ID not found.';
        ELSE
            RETURN AVAILABLE || ' copies of ' || BOOK_TITLE || ' is available at ' || BOOK_LOCATION;
        END IF;
    END SEARCHBOOK;
    
    ----------------------------------------------------------------------------------------------------------------
    
    PROCEDURE BORROWBOOK (BOOK_ID NUMBER, USER_ID NUMBER) IS 
        B_BOOK_SEQ NUMBER;
        BOOK_NAME VARCHAR2(30);
        IS_RESERVED VARCHAR2(5);
        COPY_COUNT NUMBER;
        USER_BORROWED VARCHAR2(5) := 'FALSE';
        ROWCOUNT NUMBER;
        BORROWED VARCHAR2(5) := 'FALSE';
        RESERVED_COUNT NUMBER;
        PRIORITY_ID NUMBER; -- ID OF THE FIRST PERSON TO RESERVE (THE ONE WITH THE LOWEST R_BOOK_ID)
    BEGIN
        SELECT B_BOOKID_SEQ.CURRVAL INTO B_BOOK_SEQ FROM DUAL;
        SELECT BOOK_NAME, RESERVED, BOOK_COUNT INTO BOOK_NAME, IS_RESERVED, COPY_COUNT FROM LIBRARY_BOOKS WHERE LIBRARY_BOOKS.BOOK_ID = BORROWBOOK.BOOK_ID;
        
        FOR REC IN (SELECT BOOK_ID, BORROWER_ID FROM BORROWED_BOOKS) LOOP
            IF REC.BOOK_ID = BOOK_ID AND REC.BORROWER_ID = USER_ID THEN
                USER_BORROWED := 'TRUE';
            END IF;
        END LOOP;
        
        IF IS_RESERVED = 'FALSE' OR COPY_COUNT > 1  THEN
            IF COPY_COUNT <> 0 AND USER_BORROWED = 'FALSE' THEN
                UPDATE LIBRARY_BOOKS SET BOOK_COUNT = BOOK_COUNT - 1 WHERE LIBRARY_BOOKS.BOOK_ID = BORROWBOOK.BOOK_ID;
                UPDATE BORROWED_BOOKS SET BORROWER_ID = USER_ID WHERE B_BOOK_ID = (B_BOOK_SEQ + 1);
                DBMS_OUTPUT.PUT_LINE('You have successfully borrowed the book ' || BOOK_NAME || '. Your Borrowing Book ID is ' || (B_BOOK_SEQ + 1));
                BORROWED := 'TRUE';
            END IF;
        ELSE -- IF IT IS RESERVED AND THERE'S ONLY 1 COPY LEFT, CHECK IF THE BORROWER IS THE SAME PERSON WHO RESERVED THE BOOK
            IF COPY_COUNT <> 0 AND USER_BORROWED = 'FALSE' THEN
                SELECT RESERVER_ID INTO PRIORITY_ID
                    FROM (
                        SELECT RESERVER_ID, R_BOOK_ID
                        FROM RESERVED_BOOKS
                        WHERE BOOK_ID = BORROWBOOK.BOOK_ID
                        ORDER BY R_BOOK_ID
                        FETCH FIRST 1 ROW ONLY);
            
                FOR REC IN (SELECT R_BOOK_ID, BOOK_ID, RESERVER_ID FROM RESERVED_BOOKS) LOOP
                    IF REC.BOOK_ID = BOOK_ID AND REC.RESERVER_ID = USER_ID AND REC.RESERVER_ID = PRIORITY_ID THEN -- IF THE BORROWER IS ALSO THE RESERVER
                        -- DO AN IF HERE TO CHECK IF THE LOWEST R_BOOK_ID IS THE ID OF THE PERSON BORROWING
                        UPDATE LIBRARY_BOOKS SET BOOK_COUNT = BOOK_COUNT - 1 WHERE LIBRARY_BOOKS.BOOK_ID = BORROWBOOK.BOOK_ID;
                        UPDATE BORROWED_BOOKS SET BORROWER_ID = USER_ID WHERE B_BOOK_ID = (B_BOOK_SEQ + 1);
                        DELETE FROM RESERVED_BOOKS WHERE R_BOOK_ID = REC.R_BOOK_ID;
                        DBMS_OUTPUT.PUT_LINE('You have successfully borrowed your reserved book ' || BOOK_NAME || '. Your Borrowing Book ID is ' || (B_BOOK_SEQ + 1));                    
                        BORROWED := 'TRUE';
                    END IF;
                END LOOP;
                
                SELECT COUNT(*) INTO RESERVED_COUNT FROM RESERVED_BOOKS WHERE RESERVED_BOOKS.BOOK_NAME = BORROWBOOK.BOOK_NAME;
                IF RESERVED_COUNT = 0 THEN
                    UPDATE LIBRARY_BOOKS SET RESERVED = 'FALSE' WHERE LIBRARY_BOOKS.BOOK_ID = BORROWBOOK.BOOK_ID;
                END IF;
            END IF;
        END IF;
        
        IF USER_BORROWED = 'TRUE' THEN
            DBMS_OUTPUT.PUT_LINE('You have already borrowed this book.');
        ELSIF BORROWED = 'FALSE' THEN
            DBMS_OUTPUT.PUT_LINE('This book is unavailable for borrowing. You can reserve it and you will be notified when the book is available again.');
            DBMS_OUTPUT.PUT_LINE('If you have already reserved this book, then you are in a queue for the book.');
        END IF;
        
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Please check if either BOOK_ID or USER_ID are valid IDs. ' || SQLERRM);
    END BORROWBOOK;
    
    ----------------------------------------------------------------------------------------------------------------
    
    PROCEDURE RETURNBOOK (BOOK_ID NUMBER, USER_ID NUMBER) IS
        RECORD_COUNT NUMBER;
        TITLE_COUNT NUMBER;
    BEGIN
        SELECT COUNT(*) INTO RECORD_COUNT FROM BORROWED_BOOKS WHERE BORROWED_BOOKS.BOOK_ID = BOOK_ID AND BORROWED_BOOKS.BORROWER_ID = USER_ID;
        SELECT COUNT(*) INTO TITLE_COUNT FROM BORROWED_BOOKS WHERE BORROWED_BOOKS.BOOK_ID = BOOK_ID AND BORROWED_BOOKS.BORROWER_ID = USER_ID;
        
        IF RECORD_COUNT <> 0 THEN
            UPDATE LIBRARY_BOOKS SET BOOK_COUNT = BOOK_COUNT + 1 WHERE LIBRARY_BOOKS.BOOK_ID = BOOK_ID;
            DELETE FROM BORROWED_BOOKS WHERE BORROWED_BOOKS.BOOK_ID = BOOK_ID AND BORROWED_BOOKS.BORROWER_ID = USER_ID;
            DBMS_OUTPUT.PUT_LINE('Thank you for returning the book you have borrowed.');
            STAFFPACKAGE.NOTIFYUSER(BOOK_ID);
        ELSE 
            DBMS_OUTPUT.PUT_LINE('No record of a user borrowing the book you have entered.');
        END IF;
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Please check if either BOOK_ID or USER_ID are valid IDs. ' || SQLERRM);
    END RETURNBOOK;
    
    ----------------------------------------------------------------------------------------------------------------
    
    PROCEDURE RESERVEBOOK (BOOK_ID NUMBER, USER_ID NUMBER) IS
        R_BOOK_SEQ NUMBER;
        BOOK_NAME VARCHAR2(30);
    BEGIN
        SELECT R_BOOKID_SEQ.CURRVAL INTO R_BOOK_SEQ FROM DUAL;
        SELECT BOOK_NAME INTO BOOK_NAME FROM LIBRARY_BOOKS WHERE LIBRARY_BOOKS.BOOK_ID = RESERVEBOOK.BOOK_ID;

        UPDATE LIBRARY_BOOKS SET RESERVED = 'TRUE' WHERE LIBRARY_BOOKS.BOOK_ID = RESERVEBOOK.BOOK_ID;
        UPDATE RESERVED_BOOKS SET RESERVER_ID = USER_ID WHERE R_BOOK_ID = (R_BOOK_SEQ + 1);
        
        DBMS_OUTPUT.PUT_LINE('You have successfully reserved the book ' || BOOK_NAME || '. Your Reserving Book ID is ' || (R_BOOK_SEQ + 1));
    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE('Please check if either BOOK_ID or USER_ID are valid IDs. ' || SQLERRM);
    END RESERVEBOOK;
    
END USERPACKAGE;

-- TRIGGER FOR BORROWING BOOKS
CREATE OR REPLACE TRIGGER BORROW_BOOK_TRIGGER BEFORE UPDATE OF BOOK_COUNT ON LIBRARY_BOOKS 
FOR EACH ROW WHEN (NEW.BOOK_COUNT < OLD.BOOK_COUNT)
    DECLARE
        BOOK_ID NUMBER(6);
        BOOK_NAME VARCHAR2(30);
    BEGIN
        BOOK_ID := :NEW.BOOK_ID;
        BOOK_NAME := :NEW.BOOK_NAME;
        
        INSERT INTO BORROWED_BOOKS (BOOK_ID, BOOK_NAME) VALUES (BOOK_ID, BOOK_NAME);
END;
/

-- TRIGGER FOR RESERVING BOOKS
CREATE OR REPLACE TRIGGER RESERVE_BOOK_TRIGGER BEFORE UPDATE OF RESERVED ON LIBRARY_BOOKS 
FOR EACH ROW WHEN (NEW.RESERVED = 'TRUE')
    DECLARE
        -- Declare variables to store relevant information
        BOOK_ID NUMBER(6);
        BOOK_NAME VARCHAR2(30);
    BEGIN
        -- Retrieve user and book details from the updated row
        BOOK_ID := :NEW.BOOK_ID;
        BOOK_NAME := :NEW.BOOK_NAME;
        
        -- Insert a record into BORROWED_BOOKS table
        INSERT INTO RESERVED_BOOKS (BOOK_ID, BOOK_NAME) VALUES (BOOK_ID, BOOK_NAME);
END;
/

-- SEARCH BOOK (WORKING)
DECLARE
    IS_AVAILABLE VARCHAR2(50);
BEGIN
    IS_AVAILABLE := USERPACKAGE.SEARCHBOOK(1056);
    DBMS_OUTPUT.PUT_LINE(IS_AVAILABLE);
END;

-- BORROW BOOK (WORKING)
BEGIN
    USERPACKAGE.BORROWBOOK(1056, 2);
END;

-- RETURN BOOK (WORKING)
BEGIN
    USERPACKAGE.RETURNBOOK(1056, 2);
END;

-- RESERVE BOOK (WORKING)
BEGIN
    USERPACKAGE.RESERVEBOOK(1055, 2);
END;

-- USER PACKAGE ENDS HERE


-- STAFF PACKAGE STARTS HERE

CREATE OR REPLACE PACKAGE STAFFPACKAGE AS
    PROCEDURE ADDBOOK(TITLE VARCHAR2, LOCATION VARCHAR2, COUNT NUMBER);
    PROCEDURE DELETEBOOK(BOOK_ID NUMBER, DEL_COUNT NUMBER);
    PROCEDURE GENERATEREPORT(REPORT_TYPE VARCHAR2);
    PROCEDURE NOTIFYUSER(BOOK_ID NUMBER);
END STAFFPACKAGE;

CREATE OR REPLACE PACKAGE BODY STAFFPACKAGE AS
    PROCEDURE ADDBOOK(TITLE VARCHAR2, LOCATION VARCHAR2, COUNT NUMBER) IS
        BOOK_ID LIBRARY_BOOKS.BOOK_ID%TYPE;
        BOOK_COUNT LIBRARY_BOOKS.BOOK_COUNT%TYPE;
    BEGIN
        -- Check if the book already exists
        SELECT BOOK_ID, BOOK_COUNT INTO BOOK_ID, BOOK_COUNT FROM LIBRARY_BOOKS WHERE BOOK_NAME = TITLE AND BOOK_LOC = LOCATION;

        -- Book exists, update the count
        UPDATE LIBRARY_BOOKS SET BOOK_COUNT = BOOK_COUNT + COUNT WHERE BOOK_ID = BOOK_ID;
        DBMS_OUTPUT.PUT_LINE('Book count successfully updated');


        -- Book doesn't exist, insert a new record
        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                INSERT INTO LIBRARY_BOOKS (BOOK_NAME, BOOK_LOC, BOOK_COUNT) VALUES (TITLE, LOCATION, COUNT);
                DBMS_OUTPUT.PUT_LINE('New book successfully added.');
    END ADDBOOK;
    
    PROCEDURE DELETEBOOK(BOOK_ID NUMBER, DEL_COUNT NUMBER) IS
        BK_COUNT LIBRARY_BOOKS.BOOK_COUNT%TYPE;
    BEGIN
        -- Retrieve the existing count for the book
        SELECT BOOK_COUNT INTO BK_COUNT FROM LIBRARY_BOOKS WHERE LIBRARY_BOOKS.BOOK_ID = DELETEBOOK.BOOK_ID;

        -- Check if the count to delete is greater than the existing count
        IF DEL_COUNT > BK_COUNT THEN
            DBMS_OUTPUT.PUT_LINE('Error: Cannot delete more copies than available.');
        ELSE
            -- Update the count
            UPDATE LIBRARY_BOOKS SET BOOK_COUNT = BK_COUNT - DEL_COUNT WHERE BOOK_ID = DELETEBOOK.BOOK_ID;
            DBMS_OUTPUT.PUT_LINE('Successfully updated the copies available.');
        END IF;
    END DELETEBOOK;
    
    PROCEDURE GENERATEREPORT(REPORT_TYPE VARCHAR2) IS
        -- Declare cursors for each report type
        CURSOR BORROWED_CURSOR IS
            SELECT BOOK_ID, BOOK_NAME, BORROWER_ID FROM BORROWED_BOOKS;
        
        CURSOR RESERVED_CURSOR IS
            SELECT BOOK_ID, BOOK_NAME, RESERVER_ID FROM RESERVED_BOOKS;
        
        -- Declare variables to store fetched data
        BORROWED_ID BORROWED_BOOKS.BOOK_ID%TYPE;
        BORROWED_NAME BORROWED_BOOKS.BOOK_NAME%TYPE;
        BORROWER_ID BORROWED_BOOKS.BORROWER_ID%TYPE;
        
        RESERVED_ID RESERVED_BOOKS.BOOK_ID%TYPE;
        RESERVED_NAME RESERVED_BOOKS.BOOK_NAME%TYPE;
        RESERVER_ID RESERVED_BOOKS.RESERVER_ID%TYPE;
    BEGIN
    -- Generate report based on the specified type
        IF REPORT_TYPE = 'BORROWED' THEN
            -- Open the borrowed cursor
            OPEN BORROWED_CURSOR;
            
            -- Fetch and print records
            LOOP
                FETCH BORROWED_CURSOR INTO BORROWED_ID, BORROWED_NAME, BORROWER_ID;
                EXIT WHEN BORROWED_CURSOR%NOTFOUND;
                DBMS_OUTPUT.PUT_LINE('Book ID: ' || BORROWED_ID || ', Book Name: ' || BORROWED_NAME || ', User ID: ' || BORROWER_ID);
            END LOOP;
            
            -- Close the borrowed cursor
            CLOSE BORROWED_CURSOR;
            
        ELSIF REPORT_TYPE = 'RESERVED' THEN
            -- Open the reserved cursor
            OPEN RESERVED_CURSOR;
            
            -- Fetch and print records
            LOOP
                FETCH RESERVED_CURSOR INTO RESERVED_ID, RESERVED_NAME, RESERVER_ID;
                EXIT WHEN RESERVED_CURSOR%NOTFOUND;
                DBMS_OUTPUT.PUT_LINE('Book ID: ' || RESERVED_ID || ', Book Name: ' || RESERVED_NAME || ', User ID: ' || RESERVER_ID);
            END LOOP;
            
            -- Close the reserved cursor
            CLOSE RESERVED_CURSOR;
            
        ELSE
            DBMS_OUTPUT.PUT_LINE('Error: Invalid report type.');
        END IF;
    END GENERATEREPORT;
    
    PROCEDURE NOTIFYUSER(BOOK_ID NUMBER) IS
        RESERVED_COUNT NUMBER;
        NEXT_PRIORITY_ID NUMBER;
        BOOK_NAME LIBRARY_BOOKS.BOOK_NAME%TYPE;
        PRIORITY_NAME USERS.USER_NAME%TYPE;
    BEGIN
        SELECT COUNT(*) INTO RESERVED_COUNT FROM RESERVED_BOOKS WHERE BOOK_ID = NOTIFYUSER.BOOK_ID;
        
        IF RESERVED_COUNT <> 0 THEN
            -- THIS IS GOING TO SELECT THE USER WHO HAS THE PRIORITY OF BORROWING THE BOOK IMMEDIATELY
            DBMS_OUTPUT.PUT_LINE('I GOT HERE 1');
            SELECT RESERVER_ID INTO NEXT_PRIORITY_ID
                    FROM (
                        SELECT RESERVER_ID, R_BOOK_ID
                        FROM RESERVED_BOOKS
                        WHERE BOOK_ID = NOTIFYUSER.BOOK_ID
                        ORDER BY R_BOOK_ID
                        FETCH FIRST 1 ROW ONLY);
            
            DBMS_OUTPUT.PUT_LINE('I GOT HERE 2');
            SELECT USER_NAME INTO PRIORITY_NAME FROM USERS WHERE USERS.USER_ID = NEXT_PRIORITY_ID;
            DBMS_OUTPUT.PUT_LINE('I GOT HERE 3');
            SELECT BOOK_NAME INTO BOOK_NAME FROM LIBRARY_BOOKS WHERE BOOK_ID = NOTIFYUSER.BOOK_ID;
            DBMS_OUTPUT.PUT_LINE('I GOT HERE 4');
            
            DBMS_OUTPUT.PUT_LINE('Mr./Ms. ' || PRIORITY_NAME || ', your reserved book ' || BOOK_NAME || ' is available for borrowing.');
        END IF;
    END NOTIFYUSER;
    
END STAFFPACKAGE;
/

-- ADD BOOK
BEGIN
    STAFFPACKAGE.ADDBOOK('Java Programming', 'D15R40', 1);
END;

-- DELETE BOOK
BEGIN
    STAFFPACKAGE.DELETEBOOK(1055, 3);
END;

-- GENERATE REPORT
BEGIN
    STAFFPACKAGE.GENERATEREPORT('RESERVED');
END;





