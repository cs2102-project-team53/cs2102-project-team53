-- #########  BASIC  #########-- 

-- This routine is used to add a new department. 
-- Usage: SELECT * FROM add_department(9, 'Test Department');
-- Noel
CREATE OR REPLACE FUNCTION add_department
    (IN did INT, IN dname VARCHAR(50))
RETURNS VOID AS $$
BEGIN
    INSERT INTO Departments (did, dname) 
    VALUES(did, dname);
END;
$$ LANGUAGE plpgsql;

-- This routine is used to remove a department
-- Usage: SELECT * FROM remove_department(9);
-- Noel
CREATE OR REPLACE FUNCTION remove_department
    (IN _did INT)
RETURNS VOID AS $$
BEGIN
    DELETE FROM Departments d
    WHERE did = _did;
END;
$$ LANGUAGE plpgsql;

-- Check if a department still has employees before deleting
CREATE OR REPLACE FUNCTION check_department_empty()
RETURNS TRIGGER AS $$
DECLARE
    employees_count INT;
    room_count INT;
BEGIN
    -- Check for any employees in the dept who have not resigned/been fired
    SELECT COUNT(*) INTO employees_count FROM Employees e WHERE e.did=OLD.did AND e.resigned_date IS NULL;
    
    -- Check if any meeting rooms that exist in the department
    SELECT COUNT(*) INTO room_count FROM MeetingRooms mr WHERE mr.did=OLD.did;
    
    IF employees_count > 0 THEN
        RAISE EXCEPTION 'Deletion not allowed as the department still has employees';
        RETURN NULL;
    END IF;

    IF room_count > 0 THEN
        RAISE EXCEPTION 'Deletion not allowed as the department still has associated meeting rooms';
        RETURN NULL;
    END IF;

    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS department_deletion_check ON Departments;
CREATE TRIGGER department_deletion_check
BEFORE DELETE ON Departments
FOR EACH ROW
EXECUTE FUNCTION check_department_empty();


-- Remove employees from future meetings/bookings on resigning
CREATE OR REPLACE FUNCTION remove_resigned_employees()
RETURNS TRIGGER AS $$
DECLARE
    has_resigned INT;
    is_booker INT;
BEGIN
    SELECT COUNT(*) INTO has_resigned FROM Employees e WHERE e.eid=NEW.eid AND e.resigned_date IS NOT NULL;
    
    IF (has_resigned=1) THEN
        DELETE FROM Sessions s WHERE s.booker_eid=NEW.eid AND s.date > NEW.resigned_date;
        DELETE FROM Joins j WHERE (j.eid = NEW.eid AND j.date >= NEW.resigned_date);
        RETURN NULL;
    END IF;
    
    RETURN NULL;
   
END;
$$ LANGUAGE plpgsql;


DROP TRIGGER IF EXISTS employee_resign_removal ON Employees;
CREATE TRIGGER employee_resign_removal
AFTER UPDATE ON Employees
FOR EACH ROW
EXECUTE FUNCTION remove_resigned_employees();



-- This routine is used to add a new room
-- As a new room requires the initial capacity to be set in updates table, a manager_eid is also required as input
-- Usage: SELECT * FROM add_room (5, 4, 'Test', 2, 7);
-- Noel
CREATE OR REPLACE FUNCTION add_room
    (IN _room INT, IN _floor INT, IN _rname VARCHAR(50), IN _did INT, IN _capacity INT, IN _manager_eid INT)
RETURNS VOID AS $$
BEGIN 
    -- Insert into MeetingRooms
    INSERT INTO MeetingRooms (room, floor, rname, did)
    VALUES (_room, _floor, _rname, _did);
    
    INSERT INTO Updates (manager_eid, room, floor, date, new_cap)
    VALUES (_manager_eid, _room, _floor, CURRENT_DATE, _capacity);  
END;
$$ LANGUAGE plpgsql;

-- Usage: SELECT * FROM change_capacity(1, 1, 12, current_date, 499)
-- Van
DROP FUNCTION IF EXISTS change_capacity(floor_in int, room_in int, cap int, date_in Date, m_eid int);
CREATE OR REPLACE FUNCTION change_capacity(IN floor_in int, IN room_in int, IN cap int, IN date_in Date, IN m_eid int)
RETURNS VOID AS $$
BEGIN
      INSERT INTO Updates(room, floor, date, new_cap, manager_eid) VALUES (room_in, floor_in, date_in, cap, m_eid );
END;
$$ language plpgsql;

-- Updating Constraints:
-- 1. Only Managers from the same dept only can update capacity [24]
-- 2. If new_cap for that date already exists, Update instead of Insert
DROP FUNCTION IF EXISTS check_updating_capacity();
CREATE OR REPLACE FUNCTION check_updating_capacity() RETURNS TRIGGER AS $$
    DECLARE
        is_manager INT;
        is_same_dept INT;
        date_entry_exists INT;

    BEGIN
        -- Check if Employee is a Manager
        SELECT COUNT(*) INTO is_manager FROM Manager m WHERE m.eid = NEW.manager_eid;

        -- Check if Manager is in the same Department as the Session
        SELECT COUNT(*) INTO is_same_dept FROM MeetingRooms mr, Employees e
        WHERE e.eid = NEW.manager_eid AND mr.did = e.did AND mr.floor = NEW.floor AND mr.room = NEW.room;

        IF (is_manager = 0) THEN
            RAISE EXCEPTION 'Only Managers can update capacity';
        END IF;

        IF(is_same_dept = 0) THEN
            RAISE EXCEPTION 'Only managers from same department as meeting room can update capacity. Aborting.';
        END IF;

        --Passes manager checks --> do insert/update
        -- For INSERT type:
            --If date, room, floor exists in Updates --> change to UPDATE
            --If date, room, floor not exists --> INSERT
        -- For UPDATE type:
            -- Just update
        IF (TG_OP = 'UPDATE') THEN
            RETURN NEW;

        ELSEIF (TG_OP = 'INSERT') THEN
            SELECT COUNT(*) INTO date_entry_exists FROM Updates u WHERE
                u.room = NEW.room AND
                u.floor = NEW.floor AND
                u.date = NEW.date  ;

            -- date entry alr exists --> call update instead
            IF (date_entry_exists > 0) THEN
                RAISE NOTICE 'Date entry alr exists';
                UPDATE Updates SET manager_eid = NEW.manager_eid, new_cap = NEW.new_cap WHERE
                    date = NEW.date AND
                    room = NEW.room AND
                    floor = NEW.floor;
                RETURN NULL;
            -- date entry does not exist --> INSERT
            ELSE
                RETURN NEW;
            END IF;
        END IF;
END;
$$ language plpgsql;

DROP TRIGGER IF EXISTS trigger_before_new_cap ON Updates;
CREATE TRIGGER trigger_before_new_cap
BEFORE INSERT OR UPDATE ON updates
FOR EACH ROW
EXECUTE FUNCTION check_updating_capacity();

-- Does: Delete sessions which exceed the new capacity after Updates is updated.
DROP FUNCTION IF EXISTS after_updating_cap();
CREATE OR REPLACE FUNCTION after_updating_cap() RETURNS TRIGGER
AS $$
BEGIN

    RAISE NOTICE '## post_updated_cap: Deleting from appropriate sessions after updating capacity';
    DELETE FROM Sessions s WHERE (
        s.floor = NEW.floor AND
        s.room = NEW.room AND
        s.date >= NEW.date AND
        (SELECT COUNT(j.eid) FROM Joins j
        WHERE j.floor = s.floor AND
              j.room = s.room AND
              j.time = s.time AND
              j.date = s.date
        GROUP BY (j.floor, j.room, j.time, j.date)) > NEW.new_cap) ;
    RETURN NULL;
END;
$$ language plpgsql;

DROP TRIGGER IF EXISTS trigger_after_new_cap ON Updates;
CREATE TRIGGER trigger_after_new_cap
AFTER INSERT OR UPDATE ON Updates
FOR EACH ROW EXECUTE FUNCTION after_updating_cap();




-- Employee constraints:
-- 1. Each employee must be one and only one of the three kinds of employees: junior, senior or manager. [12]
-- 2. When an employee resign, all past records are kept. [33]

-- This trigger disallows the insertion of an employee without inserting to junior, senior, or manager on the same transaction. 
-- This is possible through defining the trigger to be `DEFERRABLE INITIALLY DEFERRED`
-- This will not break he add_employee function as I assume it is counted as a single transaction.

-- Correct usage (Inserting both to employee and to junior/senior/manager in a single transaction):
-- BEGIN TRANSACTION;
-- insert into employees values (1000, 1, 'Test', 'Test@gmail.com', 1237127123, 1238123128, 1823128382);
-- insert into junior values (1000);
-- COMMIT;

-- Incorrect usage (Inserting only to employees in a single transaction):
-- BEGIN TRANSACTION;
-- insert into employees values (1001, 1, 'Test', 'Test2@gmail.com', 1237127123, 1238123128, 1823128382);
-- COMMIT;

-- Employees need to be one of junior, senior or manager.
CREATE OR REPLACE FUNCTION check_employees_kind()
RETURNS TRIGGER AS $$
DECLARE
    is_assigned INT := 0;
BEGIN
    SELECT COUNT(*) INTO is_assigned FROM Junior j WHERE NEW.eid=j.eid;

    IF is_assigned = 0 THEN
        SELECT COUNT(*) INTO is_assigned FROM Senior s WHERE NEW.eid=s.eid;
    END IF;

    IF is_assigned = 0 THEN
        SELECT COUNT(*) INTO is_assigned FROM Manager m WHERE NEW.eid=m.eid;
    END IF;

    IF is_assigned = 0 THEN
        DELETE FROM Employees e WHERE e.eid = NEW.eid;

        RAISE EXCEPTION 'An employee needs to be one of the three kinds of employees: junior, senior or manager';
    END IF;

    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS employees_manual_insert_check ON Employees;
CREATE CONSTRAINT TRIGGER employees_manual_insert_check
AFTER INSERT OR UPDATE ON Employees -- DEFERRABLE triggers can only be used for AFTER, not BEFORE
DEFERRABLE INITIALLY DEFERRED
FOR EACH ROW
EXECUTE FUNCTION check_employees_kind();

-- Prohibit manual deletion of an employee.
CREATE OR REPLACE FUNCTION handle_employees_deletion()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Manual deletion of employee(s) are prohibited.';
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS prohibit_employees_deletion ON Employees;
CREATE TRIGGER prohibit_employees_deletion
BEFORE DELETE ON Employees
FOR EACH ROW
EXECUTE FUNCTION handle_employees_deletion();

-- This routine is used to add a new employee.
-- Usage: SELECT * FROM add_employee('kevin', 88735936, 'SENIOR', 1);
-- TESTING FUNCTIONS:
-- SELECT * FROM add_employee('Vanshiqa', 90915145, 'JUNIOR', 1);
-- SELECT * FROM add_employee('Anshiqa Agrawal', 90915145, 'JUNIOR', 1);
-- SELECT * FROM add_employee('Charlie Agrawal', 90915145, 'JUNIOR', 3);
-- SELECT * FROM add_employee('Charlie Agrawal', 90915145, 'JUNIOR', 3); -- check if unique email id generated w duplicate name
-- SELECT * FROM add_employee('Charlie', 90915145, 'JUNIR', 3); -- mispelt kind.
-- Kevin
CREATE OR REPLACE FUNCTION add_employee
    (IN ename VARCHAR(50), IN mobile_number NUMERIC, IN kind VARCHAR(50), IN did INTEGER)
RETURNS VOID AS $$
DECLARE
    max_eid INT;
    new_eid INT;
BEGIN
    IF kind NOT IN ('JUNIOR', 'SENIOR', 'MANAGER') THEN
        RETURN;
    END IF;

    SELECT COALESCE(MAX(eid), 0) INTO max_eid FROM Employees; -- Defaults to 0 if there are no rows yet
    new_eid := max_eid + 1;


    INSERT INTO Employees(eid, ename, email, mobile_number, did)
    VALUES (new_eid, ename, CONCAT(REPLACE(ename, ' ', ''), new_eid, '@gmail.com'), mobile_number, did);

    IF kind = 'JUNIOR' THEN
        INSERT INTO Junior (eid) VALUES (new_eid);
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
BEFORE INSERT OR UPDATE ON Junior
FOR EACH ROW
EXECUTE FUNCTION check_employees_exclusivity();

DROP TRIGGER IF EXISTS booker_isa_check ON booker;
CREATE TRIGGER booker_isa_check
BEFORE INSERT OR UPDATE ON Booker
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

-- This routine is used to remove an employee by setting the resigned_date to the given last_day.
-- Usage: -- SELECT * FROM remove_employee(501, '2021-06-04');
-- Kevin
CREATE OR REPLACE FUNCTION remove_employee
    (IN _eid INT, IN last_day DATE)
RETURNS VOID AS $$
BEGIN
-- update resignedDate of employee with the given eid
    UPDATE Employees e
    SET resigned_date = last_day
    WHERE e.eid = _eid;
END;
$$ LANGUAGE plpgsql;


-- #########  CORE  #########-- 

-- This routine is used to search for available rooms.
-- Returns: The routine returns a table containing all meeting rooms that are available from the start hour (inclusive) to the end hour (exclusive) on the given date. 
--          In other words, [start hour, end hour). Note that the number of hours may be greater than 1 hour and it must be available.
-- Usage: SELECT * FROM search_room('7', '2022-11-27','9:15:00','11:33:00')
-- Noel
CREATE OR REPLACE FUNCTION search_room
    (IN _capacity INT, IN _date DATE, IN _start_hour TIME, IN _end_hour TIME)
RETURNS TABLE(floor INT, room INT, did INT, capacity INT) AS $$
BEGIN
    RETURN QUERY

    -- Find the latest capacity update date for each room before or on the _date
    WITH latest_update_date AS (
        SELECT u.room, u.floor, max(date) FROM Updates u
        WHERE u.date <= _date
        GROUP BY u.room, u.floor
    ),
    -- Find the latest capacity of each room
    latest_capacities AS (
        SELECT * FROM Updates u
        WHERE (u.room, u.floor, u.date) IN (SELECT * FROM latest_update_date)
    ),
    -- Find all rooms which meet the required capacity
    all_rooms AS (
        SELECT m.room, m.floor, m.did, l.new_cap FROM MeetingRooms m, latest_capacities l  WHERE
        m.room=l.room
        AND m.floor=l.floor
        AND l.new_cap>=_capacity
    ),
    -- Find all the rooms which are occupied at the given date and time range
    occupied_rooms AS (
        SELECT s.room, s.floor FROM sessions s WHERE
        s.time >= (SELECT date_trunc('hour', _start_hour + interval '0 minute')) --Round down _start_hour
        AND s.time< (SELECT date_trunc('hour', _end_hour + interval '59 minute')) --Round up _end_hour
        AND s.date=_date
    )

    SELECT * FROM all_rooms r 
    WHERE (r.room, r.floor) NOT IN (SELECT * FROM occupied_rooms)
    ORDER BY r.new_cap;
END;
$$ LANGUAGE plpgsql;


-- TEST QUERY: select * from book_room(1, 1, '2021-12-19', '10:00:00', '14:00:00', 318);  
-- KhiaXeng
DROP FUNCTION IF EXISTS book_room;
CREATE OR REPLACE FUNCTION book_room(IN floor_number INT, room_number INT, start_date DATE, start_hour TIME, end_hour TIME, eid INT)
RETURNS VOID AS $$
DECLARE
    start_time TIME := (SELECT date_trunc('hour', start_hour + interval '0 minute'));
    end_time TIME := (SELECT date_trunc('hour', end_hour + interval '59 minute'));
BEGIN
    WHILE start_time < end_time LOOP
        INSERT INTO Sessions(time, date, room, floor, booker_eid) VALUES (start_time, start_date, room_number, floor_number, eid);
        start_time := start_time + '01:00:00'; -- ** Can only use single quotes.
    END LOOP;
END;
$$ LANGUAGE plpgsql;


-- Booking constraints:
-- 1. Booker must not have fever [16]
-- 2. Only Booker (ISA senior/manager) can book a room [do i check if eid exist in Booker or check both junior and booker?] [13/14]
-- 3. Meeting room can only be booked by ONE group for given date and time (enforced by PK) [15]
-- 4. Employee booking the room automatically joins the meeting (separate AFTER trigger?) [18] ****
-- 5. Can only book room for future meetings/dates [25]
-- 6. Booker must not be resigned [34]
-- Do we need to check if booker is already in another meeting? since he will be auto added into this booking's meeting *****

-- ** the latest schema now uses booker_eid instead of eid.
CREATE OR REPLACE FUNCTION can_book_room()
RETURNS TRIGGER AS $$
DECLARE
    has_fever BOOLEAN;
    is_booker INT;
    is_future_date BOOLEAN;
    has_resigned BOOLEAN;
BEGIN
    -- Check if Booker has a fever
    SELECT hd.fever INTO has_fever FROM HealthDeclaration hd WHERE hd.eid = NEW.booker_eid AND hd.date = CURRENT_DATE;
    
    -- Check if Employee is a Booker
    SELECT COUNT(*) INTO is_booker FROM Booker b WHERE b.eid = NEW.booker_eid;
    
    -- Check if Booking is a future date
    is_future_date := (NEW.date > CURRENT_DATE);
    
    -- Check if Booker has resigned
    has_resigned := (SELECT e.resigned_date FROM Employees e WHERE e.eid = NEW.booker_eid)  IS NOT NULL;
    
    IF has_fever THEN
        RAISE EXCEPTION 'Bookers with a fever cannot book a room';
    END IF;
    
    IF is_booker = 0 THEN
        RAISE EXCEPTION 'Employee is not a Booker(Senior/Manager)';
    END IF;
    
    IF is_future_date = FALSE THEN
        RAISE EXCEPTION 'Rooms can only be booked for future dates';
    END IF;
    
    IF has_resigned THEN
        RAISE EXCEPTION 'Resigned employees cannot book a room';
    END IF;

    RETURN NEW; -- ** Need to RETURN NEW for the insert to go through
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS check_booking_constraints ON Sessions;
CREATE TRIGGER check_booking_constraints
BEFORE INSERT ON Sessions
FOR EACH ROW EXECUTE FUNCTION can_book_room();

-- Trigger function to add Booker into Joins after Booker adds an entry into Sessions
CREATE OR REPLACE FUNCTION add_booker_to_joins()
RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO Joins(eid, time, date, room, floor) VALUES (NEW.booker_eid, NEW.time, NEW.date, NEW.room, NEW.floor);
    RETURN NEW;
END;
$$ language plpgsql;

DROP TRIGGER IF EXISTS trigger_after_sessions_insert ON Sessions;
CREATE TRIGGER trigger_after_sessions_insert
AFTER INSERT ON Sessions
FOR EACH ROW EXECUTE FUNCTION add_booker_to_joins();


-- ** TEST QUERY: select * from unbook_room(1, 1, '2021-12-19', '10:00:00', '12:00:00', 318);
-- KhiaXeng
DROP FUNCTION IF EXISTS unbook_room;
CREATE OR REPLACE FUNCTION unbook_room(IN floor_number INT, room_number INT, start_date DATE, start_hour TIME, end_hour TIME, eid INT)
RETURNS VOID AS $$
DECLARE
    start_time TIME := (SELECT date_trunc('hour', start_hour + interval '0 minute'));
    end_time TIME := (SELECT date_trunc('hour', end_hour + interval '59 minute'));
BEGIN
    WHILE start_time < end_time LOOP
        DELETE FROM Sessions 
        WHERE floor = floor_number
            AND room = room_number
            AND date = start_date
            AND time = start_time
            AND booker_eid = eid;
        start_time:= start_time + '01:00:00';
    END LOOP;
END;    
$$ LANGUAGE plpgsql;

-- Unbooking constraints:
-- 1. Input eid must be the same as eid of the Booking to be removed. (Enforced in unbook_room())
-- 2. If the booking is already approved, also remove the approval (i thought if booking is removed, approval is also removed?)
-- 3. Need to remove participants of the meeting after unbooking (separate AFTER TRIGGER or can just add removal of Joins in this function) ****
-- 4. Check for future date. ****


-- Trigger to check if a Session has a future date before unbooking
CREATE OR REPLACE FUNCTION can_unbook_room()
RETURNS TRIGGER AS $$
DECLARE
    is_future_date BOOLEAN;
BEGIN
    -- Check if Booking is a future date
    is_future_date := (OLD.date > CURRENT_DATE);
    
    IF is_future_date = FALSE THEN
        RAISE EXCEPTION 'Can only unbook rooms of a future date';
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS check_unbooking_constraints ON Sessions;
CREATE TRIGGER check_unbooking_constraints
BEFORE DELETE ON Sessions
FOR EACH ROW EXECUTE FUNCTION can_unbook_room();


-- Trigger to remove participants from Joins after deleting a Booking from Sessions
CREATE OR REPLACE FUNCTION remove_participants_after_unbooking()
RETURNS TRIGGER AS $$
BEGIN
    DELETE FROM Joins j WHERE (
        j.time = OLD.time AND
        j.date = OLD.date AND
        j.room = OLD.room AND
        j.floor = OLD.floor);
    RETURN NULL;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_after_sessions_delete ON Sessions;
CREATE TRIGGER trigger_after_sessions_delete
AFTER DELETE ON Sessions
FOR EACH ROW EXECUTE FUNCTION remove_participants_after_unbooking();


-- This routine is used to join a booked meeting room. The employee ID is the ID of the employee that is joining the booked meeting room. 
-- If the employee is allowed to join, the routine will process the join. Since an approved meeting
-- cannot have a change in participants, the employee is not allowed to join an approved meeting.
-- Usage: SELECT * FROM join_meeting(4, 2, '2022-04-15','17:00:00', '17:59:00', 124);
--        SELECT * FROM joins j where j.time='17:00:00' AND j.date='2022-04-15'
-- Contraints satified: [17], [19], [23], [26]
-- Qn: Should a close contact be allowed to join meetings/book rooms?
-- Noel
CREATE OR REPLACE FUNCTION join_meeting
    (IN _floor INT, _room INT, _date DATE, _start_hour TIME, _end_hour TIME, _eid INT)
RETURNS VOID AS $$
DECLARE
    start_time TIME:= (SELECT date_trunc('hour', _start_hour + interval '0 minute'));
    end_time TIME:= (SELECT date_trunc('hour', _end_hour + interval '59 minute'));
BEGIN
    WHILE start_time < end_time LOOP
        INSERT INTO Joins (eid, time, date, room, floor) VALUES (_eid, start_time, _date, _room, _floor);
        start_time:= start_time + '01:00:00';
    END LOOP;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION can_join_meeting()
-- Constraints for Joining
-- 1. Can only join future meetings [26]
-- 2. Can only join if no fever [19]
-- 3. Cannot join approved meetings [23] 
-- 4. Employee should not have resigned [34]
-- 5. Meeting Room Capacity cannot be exceeded 
RETURNS TRIGGER AS $$
DECLARE
    has_fever BOOLEAN;
    is_meeting_approved INT;
    has_retired BOOLEAN;
    current_occupancy INT;
    max_capacity INT;
BEGIN
    -- Check if employee has fever (If employee has not declared temperature, then it he has_fever wil default to true to prevent any joining of meetings)
    SELECT COALESCE(fever, true) INTO has_fever FROM HealthDeclaration h WHERE h.eid = New.eid  AND h.date = CURRENT_DATE;
    
    -- Check if meeting is approved
    SELECT COALESCE(approver_eid, 0) INTO is_meeting_approved FROM Sessions s 
    WHERE s.time = NEW.time
    AND s.date = NEW.date
    AND s.room = NEW.room
    AND s.floor = NEW.floor;
    
    -- Check if employee retired
    SELECT NOT EXISTS(SELECT 1 FROM Employees e WHERE e.eid=NEW.eid AND e.resigned_date IS NULL) INTO has_retired;
    
    -- Find current_occupancy of meeting
    SELECT COUNT(*) INTO current_occupancy FROM Joins j 
    WHERE j.date=NEW.date
    AND j.time=NEW.time
    AND j.room=NEW.room
    AND j.floor=NEW.floor;
    
    -- Find latest max capacity meeting room
    SELECT new_cap INTO max_capacity FROM Updates u
    WHERE u.room=NEW.room and u.floor=NEW.floor AND date=(SELECT max(date) FROM Updates
    GROUP BY room, floor
    HAVING room=NEW.room and floor=NEW.floor
    );
                                   
  
    IF has_fever THEN
        RAISE EXCEPTION 'Employee with fever cannot join meeting';
        RETURN NULL;
    END IF;
    IF NEW.date < CURRENT_DATE THEN
        RAISE EXCEPTION 'Employee can only join future meetings';
    END IF;
    IF is_meeting_approved<>0 THEN
        RAISE EXCEPTION 'Employee cannot join approved meetings';
    END IF;
    IF has_retired THEN
        RAISE EXCEPTION 'Employee has retired from the company!';
    END IF;
    IF current_occupancy >= max_capacity THEN
        RAISE EXCEPTION 'Sorry the room is fully booked';
    END IF;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS check_join_contraints ON Joins;
CREATE TRIGGER check_join_contraints
BEFORE INSERT ON Joins
FOR EACH ROW
EXECUTE FUNCTION can_join_meeting();


-- This routine is used to leave a booked meeting room. If this employee is not the meeting in the first place, then do nothing. 
-- Otherwise, process the leave. Since an approved meeting cannot have a change in participants, the employee is not allowed to leave an approved meeting.
-- Usage: SELECT * FROM leave_meeting(4, 2, '2022-04-15','17:00:00', '18:00:00', 124);
-- Contraints satified: [23]
-- Noel
CREATE OR REPLACE FUNCTION leave_meeting
    (IN _floor INT, _room INT, _date DATE, _start_hour TIME, _end_hour TIME, _eid INT)
RETURNS VOID AS $$
DECLARE
    start_time TIME:= (SELECT date_trunc('hour', _start_hour + interval '0 minute'));
    end_time TIME:= (SELECT date_trunc('hour', _end_hour + interval '59 minute'));
BEGIN  
    WHILE start_time < end_time LOOP
        DELETE FROM Joins 
        WHERE eid=_eid
        AND time=start_time
        AND date=_date
        AND room=_room
        AND floor=_floor;
        start_time:= start_time + '01:00:00';
    END LOOP;
END;
$$ LANGUAGE plpgsql;


CREATE OR REPLACE FUNCTION can_leave_meeting()
-- Constraints for Leaving
-- 1. Cannot leave approved meetings [23]
RETURNS TRIGGER AS $$
DECLARE
    is_meeting_approved INT;
BEGIN
    -- check if meeting is approved
    SELECT COALESCE(approver_eid, 0) INTO is_meeting_approved FROM Sessions s 
    WHERE s.time = OLD.time
    AND s.date = OLD.date
    AND s.room = OLD.room
    AND s.floor = OLD.floor;
    
    IF is_meeting_approved<>0 THEN
        RAISE EXCEPTION 'Employee cannot leave approved meetings';
    END IF;
    RETURN OLD;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS check_leave_contraints ON Joins;
CREATE TRIGGER check_leave_contraints
BEFORE DELETE ON Joins
FOR EACH ROW
EXECUTE FUNCTION can_leave_meeting();

-- KhiaXeng
DROP FUNCTION IF EXISTS approve_meeting;
CREATE OR REPLACE FUNCTION approve_meeting(IN floor_number INT, room_number INT, start_date DATE, start_hour TIME, end_hour TIME, eid INT)
RETURNS VOID AS $$
DECLARE
    start_time TIME := (SELECT date_trunc('hour', start_hour + interval '0 minute'));
    end_time TIME := (SELECT date_trunc('hour', end_hour + interval '59 minute'));
BEGIN
    WHILE start_time < end_time LOOP
        UPDATE Sessions s
        SET approver_eid = eid
        WHERE floor = floor_number
            AND room = room_number
            AND date = start_date
            AND time = start_time;
        start_time:= start_time + '01:00:00';
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- Approve meeting constraints:
-- 1. Only manager can approve meetings [20]
-- 2. The approved meeting must be in the same Department as the Manager [21]
-- 3. Booked meeting is approved at most once (how to enforce this?) [22] **** (check if approver_eid is not null, if true then skip)
-- 4. Once approved, there should be no more changes in the participants and the participants will 
--    definitely come to the meeting on the stipulated day. (already enforced in Joins) [23]
-- 5. approver_eid in Employees table must not be resigned. [34]
-- 6. Approved meeting must be in a future date. [27]
CREATE OR REPLACE FUNCTION can_approve_session()
RETURNS TRIGGER AS $$
DECLARE
    is_manager INT;
    is_same_department INT;
    approver_has_resigned BOOLEAN;
    is_future_date BOOLEAN;
    is_approved BOOLEAN;
BEGIN   
    -- Check if Employee is a Manager
    SELECT COUNT(*) INTO is_manager FROM Manager m WHERE m.eid = NEW.approver_eid;
    
    -- Check if Manager is in the same Department as the Session
    SELECT COUNT(*) INTO is_same_department FROM MeetingRooms mr, Employees e 
    WHERE e.eid = NEW.approver_eid AND mr.did = e.did AND mr.floor = NEW.floor AND mr.room = NEW.room;
    
    -- Check if Booking is a future date
    is_future_date := (NEW.date > CURRENT_DATE);
    
    -- Check if Manager has resigned
    approver_has_resigned := (SELECT e.resigned_date FROM Employees e WHERE e.eid = NEW.approver_eid) IS NOT NULL;
    
    -- Check if Booking has been approved before
    is_approved := (OLD.approver_eid IS NOT NULL);
    
    IF is_manager = 0 THEN
        RAISE EXCEPTION 'Employee is not a Manager';
    END IF;
    
    IF is_same_department = 0 THEN
        RAISE EXCEPTION 'Manager is not in the same department as booked room';
    END IF;
    
    IF is_future_date = FALSE THEN
        RAISE EXCEPTION 'Sessions can only be approved for future dates';
    END IF;
    
    IF approver_has_resigned THEN
        RAISE EXCEPTION 'Resigned Managers cannot approve a Session';
    END IF;
    
    IF is_approved THEN
        RAISE EXCEPTION 'Booking has been approved already';
    END IF;

    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS check_approve_contraints ON Sessions;
CREATE TRIGGER check_approve_contraints
BEFORE UPDATE ON Sessions
FOR EACH ROW
EXECUTE FUNCTION can_approve_session();


-- #########  HEALTH  #########-- 

-- This routine is used for daily declaration of temperature.
-- Usage: SELECT * FROM declare_health(1, '2021-03-16', 37.6);
-- Van
DROP FUNCTION IF EXISTS declare_health;
CREATE OR REPLACE FUNCTION declare_health(IN eid_in INT, IN date_in Date, IN temp_in NUMERIC)
RETURNS VOID AS $$
BEGIN
    INSERT INTO HealthDeclaration(date, eid, temp)
    VALUES(date_in, eid_in, temp_in);
END;
$$ language plpgsql;


-- This routine is used for contact tracing.
-- If employee has fever then:
--   1. The employee is removed FROM all future meeting room booking, approved or not.
--      - If the employee is the one booking the room, the booking is cancelled, approved or not.
--      - This employee cannot book a room until they are no longer having fever 
--   2. All employees in the same approved meeting room FROM the past 3 (i.e., FROM day D-3 to day D) days are contacted.
--      - These employees (called close contacts) are removed FROM future meeting in the next 7 days (i.e., FROM day D to day D+7).
-- Usage: SELECT * FROM contact_tracing(499, '2021-11-17')
-- RETURNS: table of eid as cc_eid that are close contact with eid_in
-- Does:
    -- remove eid_in FROM all future meetings if they have fever
    -- Cancel meeting eid_in booked
    -- for all employees in same approved meeting room FROM past 3 days --> close contacts are removed FROM future meetings for next 7 days
-- Van
CREATE OR REPLACE FUNCTION contact_tracing(IN eid_in INT, IN trace_date DATE)
RETURNS TABLE(cc_eid INT) AS $$
BEGIN
    IF NOT (SELECT h.fever FROM HealthDeclaration h
         WHERE h.eid = eid_in AND h.date = trace_date) THEN
             RAISE NOTICE  '## Employee doesnt have fever, aborting';
        RETURN;
    ELSE
        RAISE NOTICE 'Employee has fever, checking for close contacts';
    -- Find all approved meetings FROM the past 3 days which employee was part of
	WITH MeetingRoomsAffected as (
        SELECT m.room, m.floor FROM MeetingRooms m NATURAL JOIN Joins j NATURAL JOIN Sessions s
        WHERE j.eid = eid_in
        AND j.date < trace_date AND j.date >= trace_date - INTERVAL '3 DAYS'
        AND s.approver_eid IS NOT NULL
	),

	-- Find close contacts: employees in the same approved meeting room FROM the past 3 (i.e., FROM day D-3 to day D) days
    CloseContacts as (
		SELECT DISTINCT j.eid FROM Joins j, MeetingRoomsAffected m
		WHERE j.date < trace_date AND j.date >= trace_date - INTERVAL '3 DAYS'
		AND j.room = m.room
		AND j.floor = m.floor /*same room*/
	)
--    	DELETE FROM Joins j WHERE j.eid IN (SELECT * FROM CloseContacts)
-- 	AND j.date >= trace_date + INTERVAL '1000 DAYS' AND j.date <= trace_date + INTERVAL '7 DAYS';

    UPDATE Employees SET cc_end_date = trace_date + INTERVAL '7 DAYS' WHERE
        eid IN (SELECT * FROM CloseContacts) AND cc_end_date < trace_date + INTERVAL '7 DAYS';

    -- Deleting close contacts from future meetings --> Done in trigger function below

    RETURN QUERY
	-- Find all approved meetings FROM the past 3 days which employee was part of
	WITH MeetingRoomsAffected as (
        SELECT m.room, m.floor, s.time FROM MeetingRooms m NATURAL JOIN Joins j NATURAL JOIN Sessions s
        WHERE j.eid = eid_in
        AND j.date < trace_date AND j.date >= trace_date - INTERVAL '3 DAYS'
        AND s.approver_eid IS NOT NULL
	),

	-- Find close contacts: employees in the same approved meeting room FROM the past 3 (i.e., FROM day D-3 to day D) days
    CloseContacts as (
		SELECT DISTINCT j.eid FROM Joins j, MeetingRoomsAffected m
		WHERE j.date < trace_date AND j.date >= trace_date - INTERVAL '3 DAYS'
		AND j.room = m.room
		AND j.floor = m.floor /*same room*/
        AND j.time = m.time /*same time; same session*/
	)
	SELECT * FROM CloseContacts;

	-- √ The employee is removed FROM all future meeting room booking, approved or not. √
     DELETE FROM Joins WHERE (eid = eid_in AND date >= trace_date);
--
-- 	-- √ If the employee is the one booking the room, the booking is cancelled, approved or not.
 	DELETE FROM Sessions WHERE (booker_eid = eid_in AND date >= trace_date);

	END IF;
END
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trigger_after_update_cc ON Employees;
CREATE TRIGGER trigger_after_update_cc
AFTER UPDATE ON Employees
FOR EACH ROW WHEN (NEW.cc_end_date is not NULL) EXECUTE FUNCTION after_update_cc();


DROP FUNCTION IF EXISTS after_update_cc;
CREATE OR REPLACE FUNCTION after_update_cc()
RETURNS TRIGGER AS $$
BEGIN
    DELETE From Joins j WHERE
        j.eid = NEW.eid AND
        j.date <= NEW.cc_end_date;
    DELETE From Sessions s WHERE
        s.booker_eid = NEW.eid AND
        s.date <= NEW.cc_end_date;
    RETURN NULL;
END;
$$ language plpgsql;

--  TRIGGER TO RUN contact_tracing AFTER insert/update into healthDeclaration
DROP TRIGGER IF EXISTS trigger_health_dec ON HealthDeclaration;
CREATE TRIGGER trigger_health_dec
AFTER INSERT OR UPDATE ON HealthDeclaration
FOR EACH ROW WHEN (NEW.fever) EXECUTE FUNCTION after_health_dec();


DROP FUNCTION IF EXISTS after_health_dec();
CREATE OR REPLACE FUNCTION after_health_dec() RETURNS TRIGGER AS $$
    BEGIN
        PERFORM contact_tracing(NEW.eid, NEW.date);
        RETURN NULL;
    END
$$
language plpgsql;


-- #########  ADMIN  #########-- 

-- This routine is used to find all employees that do not comply with the daily health declaration (i.e., to snitch).
-- RETURNs: The routine RETURNs a table containing all employee ID that do not declare their temperature at least once FROM the start date 
--          (inclusive) to the end date (inclusive). In other words, [start date, end date] along with 
--           the number of days the employee did not declare their temperature within the given period. (ORDER BY DESC numDays )
-- Usage: SELECT * FROM non_compliance('2021-11-17', '2021-11-22');
-- Van
DROP FUNCTION IF EXISTS non_compliance(startDate Date, endDate Date);
CREATE OR REPLACE FUNCTION non_compliance(IN startDate Date, IN endDate Date) 
RETURNS TABLE(eid INT, days BIGINT) AS $$
DECLARE
    num_days INT;
BEGIN
   num_days = endDate - startDate + 1;
   RETURN QUERY
   --count how many times each employee declared temperature and RETURN if count < numDays
   WITH num_declarations AS ( 
         SELECT h.eid, count(*) AS num_declared FROM HealthDeclaration h
         WHERE h.date >= startDate AND h.date <= endDate AND h.temp IS NOT NULL
         GROUP BY h.eid
   )

    SELECT * FROM (SELECT DISTINCT(e.eid),
          CASE WHEN e.eid NOT IN (SELECT t.eid FROM num_declarations t)
               THEN num_days
               ELSE num_days - (SELECT t.num_declared FROM num_declarations t WHERE t.eid=e.eid)
          END AS num_undeclared
    FROM Employees e, num_declarations t
    ORDER BY num_undeclared DESC) t2 WHERE t2.num_undeclared > 0 ;
END;
$$ language plpgsql;

-- Sample usage: SELECT * FROM view_booking_report('2020-01-01', 410);
-- KhiaXeng
CREATE OR REPLACE FUNCTION view_booking_report(IN input_start_date DATE, input_eid INT)
RETURNS TABLE(floor_number INT, room_number INT, start_date DATE, start_hour TIME, is_approved BOOLEAN) AS $$
BEGIN
    RETURN QUERY
    
    SELECT s.floor, s.room, s.date, s.time, 
            CASE WHEN approver_eid IS NULL
            THEN FALSE
            ELSE TRUE
            END
    FROM Sessions s
    WHERE s.date >= input_start_date AND s.booker_eid = input_eid
    ORDER BY s.date, s.time ASC;
END;
$$ LANGUAGE plpgsql;

-- This routine is to be used by employee to find all future meetings this employee is going to have that are already approved.
-- Returns: The routine returns a table containing all meetings that are already approved for which this employee is joining from the given start date onwards. 
--          Note that the employee need not be the one booking this meeting room.
-- SELECT * FROM approve_meeting(2,1, '2023-05-16', '17:00:00', '17:01:00', 478);
-- SELECT * FROM approve_meeting(2,3, '2023-01-07', '16:00:00', '17:00:00', 478);
-- Usage: SELECT * FROM view_future_meeting('2021-02-20', 476)
-- Noel
CREATE OR REPLACE FUNCTION view_future_meeting
    (IN _start_date DATE, IN _eid INT)

RETURNS TABLE(floor INT, room INT, date DATE, start_hour TIME) AS $$
BEGIN 
    RETURN QUERY 
    
    SELECT j.floor, j.room, j.date, j.time FROM Joins j 
    WHERE j.eid = _eid
    AND j.date >=_start_date
    -- Check that meeting is approved
    AND (j.floor, j.room, j.date, j.time) NOT IN
    (SELECT s.floor, s.room, s.date, s.time FROM Sessions s WHERE s.approver_eid IS NULL)
    ORDER BY j.date, j.time ASC;
END;
$$ LANGUAGE plpgsql;


-- This routine is to be used by manager to find all meeting rooms that 
-- require approval with the same department as the manager. 
-- Returns a table containing all meeting that are booked but not yet approved from the given start_date onwards.
-- Usage: SELECT * FROM view_manager_report('2020-04-07', 1);
-- Kevin
CREATE OR REPLACE FUNCTION view_manager_report
    (IN start_date DATE, IN _eid INT)
RETURNS TABLE(floor_number INT, room_number INT, date DATE, start_hour DOUBLE PRECISION, booker_eid INT) AS $$
DECLARE
    is_manager INT;
    department INT;
BEGIN
    SELECT COUNT(*) INTO is_manager FROM Manager m WHERE m.eid = _eid;
    SELECT e.did INTO department FROM Employees e WHERE e.eid=_eid;

    IF is_manager = 0 THEN
        RETURN;
    ELSE
        RETURN QUERY
        SELECT s.floor as floor_number, s.room as room_number, s.date, extract(hour from s.time) as start_hour, _eid as eid
        FROM Sessions s NATURAL JOIN MeetingRooms m
        WHERE s.approver_eid IS NULL
        AND m.did=department
        AND start_date <= s.date
        ORDER BY s.date, s.time ASC;
    END IF;
END;
$$ LANGUAGE plpgsql;