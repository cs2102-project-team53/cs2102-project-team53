-- declare_health(eid_in, date_in, temp_in)
    -- TO CHECK:
        -- declaring twice a day? -
        -- can someone who hasnt declared health book room? --> No
-- contact_tracing(eid)
-- non_compliance(startDate, endDate)
-- change_capacity(floor_in, room_in, date_in, m_eid)

-- This routine is used for daily declaration of temperature.
-- Usage: SELECT * FROM declare_health(1, '2021-03-16', 37.6);
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


-- TESTING QUERIES:
--SELECT * FROM contact_tracing(500, '2022-10-08'); -- employee has fever

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

-- TESTING QUERIES:
-- INSERT INTO HealthDeclaration (date, eid, temp) VALUES ('2021-12-31', 223, 41.2);



-- This routine is used to find all employees that do not comply with the daily health declaration (i.e., to snitch).
-- RETURNs: The routine RETURNs a table containing all employee ID that do not declare their temperature at least once FROM the start date
--          (inclusive) to the end date (inclusive). In other words, [start date, end date] along with 
--           the number of days the employee did not declare their temperature within the given period. (ORDER BY DESC numDays )
-- Usage: SELECT * FROM non_compliance('2021-11-17', '2021-11-22');
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

-- Usage: SELECT * FROM change_capacity(1, 1, 12, current_date, 499)
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

        --passes manager checks --> do insert/update
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

-- TESTING QUERIES:
-- INSERT INTO Updates(room, floor, date, new_cap, manager_eid) VALUES (2,3 ,'2021-06-01',0, 499 ); -- manager from different dept
-- INSERT INTO Updates(room, floor, date, new_cap, manager_eid) VALUES (2,3 ,'2021-05-02',2, 494 ); -- manager from same dept
-- SELECT * FROM change_capacity(3,2 ,45,'2021-05-03', 494);
-- INSERT INTO Updates(room, floor, date, new_cap, manager_eid) VALUES (2,3 ,'2021-05-01',1, 494 ); -- manager from same dept

-- Does: delete sessions which exceed the new capacity after it is updated.
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
