-- Example usage: SELECT * FROM add_employee('kevin', 88735936, 'SENIOR', 1);
CREATE OR REPLACE FUNCTION add_employee
    (IN ename VARCHAR(50), IN mobile_number INT, IN kind VARCHAR(50), IN did INTEGER)
RETURNS VOID AS $$
DECLARE
    max_eid INT;
    new_eid INT;
BEGIN
    SELECT COALESCE(MAX(eid), 0) INTO max_eid FROM Employees; -- Defaults to 0 if there are no rows yet
    new_eid := max_eid + 1;

    INSERT INTO Employees (eid, ename, email, mobile_number, did)
    VALUES (new_eid, ename, CONCAT(ename, '@gmail.com'), mobile_number, did);

    IF kind = 'JUNIOR' THEN
        INSERT INTO Junior (eid) VALUES (new_eid); -- idk if SQL smart enough to differentiate the two eid
    ELSE
        INSERT INTO Booker (eid) VALUES (new_eid);
        
        IF kind = 'SENIOR' THEN         
            INSERT INTO Senior (eid) VALUES (new_eid);
        ELSIF kind = 'MANAGER' THEN
            INSERT INTO Manager (eid) VALUES (new_eid);
        END IF;
    END IF;

END;
$$ LANGUAGE plpgsql;

-- Usage: SELECT * FROM remove_employee(1, 'YYYY-MM-DD');
CREATE OR REPLACE FUNCTION remove_employee
    (IN _eid INT, IN last_day DATE, OUT status INT)
RETURNS INT AS $$
BEGIN
-- update resignedDate of employee with the given eid
    UPDATE Employees e
    SET resignedDate = last_day
    WHERE e.eid = _eid; -- idk if SQL smart enough to differentiate the two eid
END;
$$ LANGUAGE plpgsql;



-- Usage: SELECT * FROM view_manager_report('2020-04-07', 1);
CREATE OR REPLACE FUNCTION view_manager_report
    (IN start_date DATE, IN _eid INT)
RETURNS TABLE(floor_number INT, room_number INT, date DATE, start_hour DOUBLE PRECISION, eid INT) AS $$
DECLARE
    is_manager INT;
    department INT;
BEGIN
    SELECT COUNT(*) INTO is_manager FROM Manager m WHERE m.eid = _eid;
    SELECT d.did INTO department FROM Employees e, Departments d WHERE e.eid=_eid AND e.did=d.did;

    IF is_manager = 0 THEN
        RETURN;
    END IF;

    RETURN query
    SELECT s.floor as floor_number, s.room as room_number, s.date, extract(hour from s.time) as start_hour, _eid as eid
    FROM Sessions s JOIN MeetingRooms m ON s.room=m.room
    WHERE s.approver_eid IS NULL
    AND m.did=department
    AND start_date <= s.date
    ORDER BY s.date, s.time ASC;

END;
$$ LANGUAGE plpgsql;


-- If already in Junior, cannot be in Booker and vice versa
CREATE OR REPLACE FUNCTION check_employees_exclusivity()
RETURNS TRIGGER AS $$
DECLARE
    is_other_type INT := 0;
BEGIN
    IF TG_TABLE_NAME='junior' THEN
        SELECT COUNT(*) INTO is_other_type FROM Booker b WHERE NEW.eid=b.eid;
    ELSE
        SELECT COUNT(*) INTO is_other_type FROM Junior j WHERE NEW.eid=j.eid;
    END IF;

    IF is_other_type > 0 THEN
        RAISE EXCEPTION 'An employee cannot be both a junior and a booker(senior/manager)';
        RETURN NULL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS junior_isa_check ON junior;
CREATE TRIGGER junior_isa_check
BEFORE INSERT ON Junior
FOR EACH ROW
EXECUTE FUNCTION check_employees_exclusivity();

DROP TRIGGER IF EXISTS booker_isa_check ON booker;
CREATE TRIGGER booker_isa_check
BEFORE INSERT ON Booker
FOR EACH ROW
EXECUTE FUNCTION check_employees_exclusivity();


-- If already in Manager, cannot be in Senior and vice versa
CREATE OR REPLACE FUNCTION check_bookers_exclusivity()
RETURNS TRIGGER AS $$
DECLARE
    is_other_type INT := 0;
BEGIN
    IF TG_TABLE_NAME = 'manager' THEN
        SELECT COUNT(*) INTO is_other_type FROM Senior s WHERE NEW.eid=s.eid;
    ELSE
        SELECT COUNT(*) INTO is_other_type FROM Manager m WHERE NEW.eid=m.eid;
    END IF;

    IF is_other_type > 0 THEN
        RAISE EXCEPTION 'A booker cannot be both a senior and a manager';
        RETURN NULL;
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS senior_isa_check ON senior;
CREATE TRIGGER senior_isa_check
BEFORE INSERT ON Senior
FOR EACH ROW
EXECUTE FUNCTION check_bookers_exclusivity();

DROP TRIGGER IF EXISTS manager_isa_check ON manager;
CREATE TRIGGER manager_isa_check
BEFORE INSERT ON Manager
FOR EACH ROW
EXECUTE FUNCTION check_bookers_exclusivity();


-- Check if a department still has employees before deleting
CREATE OR REPLACE FUNCTION check_department_empty()
RETURNS TRIGGER AS $$
DECLARE
    employees_count INT;
BEGIN
    SELECT COUNT(*) INTO employees_count FROM Employees e, Departments d WHERE e.did=d.did AND d.did=OLD.did;

    IF employees_count > 0 THEN
        RAISE EXCEPTION 'Deletion not allowed as the department still has employees';
        RETURN NULL;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER department_deletion_check
BEFORE DELETE ON Departments
FOR EACH ROW
EXECUTE FUNCTION check_department_empty();