-- This routine is used to add a new department. 
-- Usage: SELECT * FROM add_department(9, 'Test Department');
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
CREATE OR REPLACE FUNCTION remove_department
    (IN _did INT)
RETURNS VOID AS $$
BEGIN
    DELETE FROM Departments d
	WHERE did = _did;
END;
$$ LANGUAGE plpgsql;


-- This routine is used to add a new room
-- Usage: SELECT * FROM add_room (5, 4, 'Test', 2, 7);
-- TODO: Add m_eid to input params
CREATE OR REPLACE FUNCTION add_room
    (IN _room INT, IN _floor INT, IN _rname VARCHAR(50), IN _did INT, IN _capacity INT)
RETURNS VOID AS $$
DECLARE
	manager_eid INT;
BEGIN 
    -- Insert into MeetingRooms
    INSERT INTO MeetingRooms (room, floor, rname, did)
	VALUES (_room, _floor, _rname, _did);
	
	-- Initialise a random manager_eid with a manger in the same department and insert room capacity into Updates
	SELECT eid FROM employees e WHERE e.eid IN (SELECT eid FROM Manager) AND e.did=_did LIMIT 1 INTO manager_eid;
	INSERT INTO Updates (manager_eid, room, floor, date, new_cap)
	VALUES (manager_eid, _room, _floor, CURRENT_DATE, _capacity);	
END;
$$ LANGUAGE plpgsql;


-- This routine is used to search for available rooms.
-- Returns: The routine returns a table containing all meeting rooms that are available from the start hour (inclusive) to the end hour (exclusive). 
--          In other words, [start hour, end hour). Note that the number of hours may be greater than 1 hour and it must be available.
-- Usage: SELECT * FROM search_room('10', '2021-07-20','11:00:00','12:00:00')
CREATE OR REPLACE FUNCTION search_room
    (IN _capacity INT, IN _date DATE, IN _start_hour TIME, IN _end_hour TIME)
RETURNS TABLE(floor INT, room INT, did INT, capacity INT) AS $$
BEGIN 
    RETURN QUERY

	-- Find the latest capacity update date for each room
	WITH latest_update_date AS (
		SELECT u.room, u.floor, max(date) FROM Updates u
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
		s.time >= _start_hour
		AND s.time<_end_hour
		AND s.date=_date
	)

	SELECT * FROM all_rooms r 
	WHERE (r.room, r.floor) NOT IN (SELECT * FROM occupied_rooms)
	ORDER BY r.new_cap;
END;
$$ LANGUAGE plpgsql;




-- This routine is to be used by employee to find all future meetings this employee is going to have that are already approved.
-- Returns: The routine returns a table containing all meetings that are already approved for which this employee is joining from the given start date onwards. 
--          Note that the employee need not be the one booking this meeting room.
-- Usage: SELECT * FROM view_future_meeting('2021-02-20', 475) 
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

-- This routine is used to join a booked meeting room. The employee ID is the ID of the employee that is joining the booked meeting room. 
-- If the employee is allowed to join, the routine will process the join. Since an approved meeting
-- cannot have a change in participants, the employee is not allowed to join an approved meeting.
-- Usage SELECT * FROM join_meeting(4, 2, '2021-08-10','13:00:00', '14:00:00', 12);
-- Contraints satified: [17], [19], [23], [26]
-- Qn: Should a close contact be allowed to join meetings/book rooms?
CREATE OR REPLACE FUNCTION join_meeting
    (IN _floor INT, _room INT, _date DATE, _start_hour TIME, _end_hour TIME, _eid INT)
RETURNS VOID AS $$
DECLARE
    start_time TIME:= _start_hour;
	end_time TIME:= _end_hour;
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
    -- Check if employee has fever
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
-- Usage SELECT * FROM leave_meeting(4, 2, '2021-08-10','13:00:00', '14:00:00', 12);
-- Contraints satified: [23]
CREATE OR REPLACE FUNCTION leave_meeting
    (IN _floor INT, _room INT, _date DATE, _start_hour TIME, _end_hour TIME, _eid INT)
RETURNS VOID AS $$
DECLARE
    start_time TIME:= _start_hour;
	end_time TIME:= _end_hour;
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