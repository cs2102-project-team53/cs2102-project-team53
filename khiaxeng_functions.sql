--book_room(floor_number, room_number, date, start_hour, end_hour, employee_id)
--unbook_room()
--approve_meeting()
--view_booking_report()
DROP FUNCTION IF EXISTS book_room;
CREATE OR REPLACE FUNCTION book_room(IN floor_number INT, room_number INT, start_date DATE, start_hour TIME, end_hour TIME, eid INT)
RETURNS VOID AS $$
DECLARE
	start_time TIME := start_hour;
	end_time TIME := end_hour;
BEGIN
	WHILE start_time < end_time LOOP
		INSERT INTO Sessions(time, date, room, floor, booker_eid) VALUES (start_time, start_date, room_number, floor_number, eid);
		start_time := start_time + "01:00:00";
	END LOOP;
END;
$$ LANGUAGE plpgsql;


-- Booking constraints:
-- 1. Booker must not have fever [16]
-- 2. Only Booker (ISA senior/manager) can book a room [do i check if eid exist in Booker or check both junior and booker?] [13/14]
-- 3. Meeting room can only be booked by ONE group for given date and time (enforced by PK) [15]
-- 4. Employee booking the room automatically joins the meeting (separate AFTER trigger?) [18]
-- 5. Can only book room for future meetings/dates [25]
-- 6. Booker must not be resigned [34]
-- Do we need to check if booker is already in another meeting? since he will be auto added into this booking's meeting
CREATE OR REPLACE FUNCTION can_book_room()
RETURNS TRIGGER AS $$
DECLARE
	has_fever BOOLEAN;
	is_booker INT;
	is_future_date BOOLEAN;
	has_resigned BOOLEAN;
BEGIN
	-- Check if Booker has a fever
	SELECT hd.fever INTO has_fever FROM HealthDeclaration hd WHERE hd.eid = NEW.eid AND hd.date = CURRENT_DATE;
	
	-- Check if Employee is a Booker
	SELECT COUNT(*) INTO is_booker FROM Booker b WHERE b.eid = NEW.eid;
	
	-- Check if Booking is a future date
	is_future_date := (NEW.date > CURRENT_DATE);
	
	-- Check if Booker has resigned
	has_resigned := (SELECT e.resigned_date FROM Employees e WHERE e.eid = NEW.eid)	IS NOT NULL;
	
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
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS check_booking_constraints ON Sessions;
CREATE TRIGGER check_booking_constraints
BEFORE INSERT ON Sessions
FOR EACH ROW EXECUTE FUNCTION can_book_room();

DROP FUNCTION IF EXISTS unbook_room;
CREATE OR REPLACE FUNCTION unbook_room(IN floor_number INT, room_number INT, start_date DATE, start_hour TIME, end_hour TIME, eid INT)
RETURNS VOID AS $$
DECLARE
	start_time TIME := start_hour;
	end_time TIME := end_hour;
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
-- 3. Need to remove participants of the meeting after unbooking (separate AFTER TRIGGER?)

DROP FUNCTION IF EXISTS approve_meeting;
CREATE OR REPLACE FUNCTION approve_meeting(IN floor_number INT, room_number INT, start_date DATE, start_hour TIME, end_hour TIME, eid INT)
RETURNS VOID AS $$
DECLARE
	start_time TIME := start_hour;
	end_time TIME := end_hour;
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
-- 3. Booked meeting is approved at most once (how to enforce this?) [22]
-- 4. Once approved, there should be no more changes in the participants and the participants will 
-- 	  definitely come to the meeting on the stipulated day. (how to enforce this?) [23]
-- 5. approver_eid in Employees table must not be resigned. [34]
-- 6. Approved meeting must be in a future date. [27]
CREATE OR REPLACE FUNCTION can_approve_session()
RETURNS TRIGGER AS $$
DECLARE
	is_manager INT;
	is_same_department BOOLEAN;
	approver_has_resigned BOOLEAN;
	is_future_date BOOLEAN;
BEGIN	
	-- Check if Employee is a Manager
	SELECT COUNT(*) INTO is_manager FROM Manager m WHERE m.eid = NEW.eid;
	
	-- Check if Manager is in the same Department as the Session
	SELECT COUNT(*) INTO is_same_department FROM MeetingRooms mr, Employees e 
	WHERE e.eid = NEW.eid AND mr.did = e.did AND mr.floor = NEW.floor_number AND mr.room = NEW.room_number;
	
	-- Check if Booking is a future date
	is_future_date := (NEW.date > CURRENT_DATE);
	
	-- Check if Manager has resigned
	approver_has_resigned := (SELECT e.resigned_date FROM Employees e WHERE e.eid = NEW.eid)	IS NOT NULL;
	
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
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS check_approve_contraints ON Sessions;
CREATE TRIGGER check_approve_contraints
BEFORE UPDATE ON Sessions
FOR EACH ROW
EXECUTE FUNCTION can_approve_session();

-- Sample usage: SELECT * FROM view_booking_report('2020-01-01', 410);
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


