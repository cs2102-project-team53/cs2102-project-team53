CREATE OR REPLACE FUNCTION declare_health(eid INT,
                        date Date,
                    temp NUMERIC)
RETURNS VOID AS $$
    BEGIN
    INSERT INTO HealthDeclaration(date, eid, temp)
    VALUES(date, eid, temp);
    END;
    $$ language plpgsql;


--returns table of all employee eids that are close contact with eid_in
    --remove eid_in from all future meetings
    --cancel meeting eid_in booked
--for all employees in same approved meeting room from past 3 days --> close contacts
   -- removed from future meetings for next 7 days
    -- what is same approved meeting room??
   -- ?? NEED TO CHANGE ANYTHING FOR THESE EMPLOYEES??
CREATE OR REPLACE FUNCTION contact_tracing(eid_in INT) RETURNS SETOF RECORD
    AS $$ BEGIN
    DELETE FROM Joins WHERE (eid = eid_in AND date >= current_date);
    DELETE FROM Sessions WHERE (booker_eid = eid_in AND date >= current_date);
    with
    MeetingRoomsAffected as (
        Select m.room, m.floor FROM MeetingRooms m NATURAL JOIN Joins j NATURAL JOIN Sessions s
        WHERE j.eid = eid_in AND
              j.date < current_date AND j.date >= current_date - INTERVAL '3 DAYS' AND
              s.approver_eid is not NULL),
    CloseContacts as (
    SELECT j.eid FROM Joins j, MeetingRoomsAffected m
        WHERE j.date <= current_date AND j.date >= current_date - INTERVAL '3 DAYS' AND
              j.room = m.room AND j.floor = m.floor /*same room*/)
    DELETE FROM Joins j where j.eid in (Select * from CloseContacts) AND
                              j.date >= current_date AND j.date <= current_date + INTERVAL '7 DAYS';
    with
    MeetingRoomsAffected as (
        Select m.room, m.floor FROM MeetingRooms m NATURAL JOIN Joins j NATURAL JOIN Sessions s
        WHERE j.eid = eid_in AND
              j.date < current_date AND j.date >= current_date - INTERVAL '3 DAYS' AND
              s.approver_eid is not NULL)
    SELECT j.eid FROM Joins j, MeetingRoomsAffected m
        WHERE j.date <= current_date AND j.date >= current_date - INTERVAL '3 DAYS' AND
              j.room = m.room AND j.floor = m.floor /*same room*/;
    END;
    $$ language plpgsql;


-- ??? CREATE TRIGGER TO RUN contact_tracing AFTER insert/update into healthDeclaration
-- CREATE TRIGGER trigger_contact_tracing
--     AFTER INSERT OR UPDATE ON healthdeclaration
--     FOR EACH ROW EXECUTE FUNCTION contact_tracing();


--returns eid and num days not declared from [start, end] order by desc num_days
CREATE OR REPLACE FUNCTION non_compliance(startDate Date, endDate Date) RETURNS SETOF RECORD AS
    $$
    BEGIN
        SELECT h.eid, count(*) as num_days from HealthDeclaration h
        WHERE h.date >= startDate and h.date <= endDate and h.temp is null
        group by h.eid
        order by num_days desc;
    END;
    $$ language plpgsql;


CREATE OR REPLACE FUNCTION change_capacity(floor_in int, room_in int, cap int, date_in Date, m_eid int) RETURNS VOID AS
    $$
    BEGIN
        UPDATE Updates SET (manager_eid, date, new_cap) = (m_eid, date_in, cap)
        WHERE room = room_in AND floor = floor_in;
    END;
$$ language plpgsql;



-- TRIGGER TO CHECK MANAGER UPDATING MEETING ROOM CAP IS FROM SAME DEPT AS MEETING ROOM
CREATE OR REPLACE FUNCTION check_updating() RETURNS TRIGGER AS $$
BEGIN
 IF ( (select e.did FROM Employees e where e.eid = NEW.manager_eid) !=
      (select m.did from MeetingRooms m NATURAL JOIN Updates u
      WHERE m.room = NEW.room AND m.floor = NEW.floor))
THEN
    RAISE NOTICE 'Only managers from the same department can update capacity';
    Return  NULL;
END IF;
END
    $$ language plpgsql;

CREATE TRIGGER trigger_check_updating
    BEFORE INSERT OR UPDATE ON updates
    FOR EACH ROW EXECUTE  FUNCTION check_updating();

----- 