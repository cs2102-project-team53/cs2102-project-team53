-- declare_health(eid_in, date_in, temp_in)
    -- TO CHECK:
        -- declaring twice a day?
        -- can someone who hasnt declared health book room?
-- contact_tracing(eid)
-- non_compliance(startDate, endDate)
-- change_capacity(floor_in, room_in, date_in, m_eid)

-- Usage: declar_health(1, '2021--MM-DD', 37)
DROP FUNCTION IF EXISTS declare_health;
CREATE OR REPLACE FUNCTION declare_health(eid_in INT,
                        date_in Date,
                    temp_in NUMERIC)
RETURNS VOID AS $$
    BEGIN
    INSERT INTO HealthDeclaration(date, eid, temp)
    VALUES(date_in, eid_in, temp_in);
    END;
    $$ language plpgsql;

-- Usage: contact_tracing(318)
-- Returns: table of eid as cc_eid that are close contact with eid_in
-- Does:
    --remove eid_in from all future meetings
    --cancel meeting eid_in booked
    -- for all employees in same approved meeting room from past 3 days --> close contacts
       -- removed from future meetings for next 7 days
    /*
*/
-- DOESNT WORK
CREATE OR REPLACE FUNCTION contact_tracing(eid_in INT)
RETURNS TABLE(cc_eid INT) AS $$
BEGIN
    DELETE FROM Joins WHERE (eid = eid_in AND date >= current_date);
    DELETE FROM Sessions WHERE (booker_eid = eid_in AND date >= current_date);
    RETURN QUERY
    WITH MeetingRoomsAffected as (
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
              j.room = m.room AND j.floor = m.floor ;/*same room*/
--     LOOP
--         cc_eid := cc_record.cc_eid;
--
--     end loop;
    END;
    $$ language plpgsql;

select * from contact_tracing(2);

-- ??? CREATE TRIGGER TO RUN contact_tracing AFTER insert/update into healthDeclaration
-- CREATE TRIGGER trigger_contact_tracing
--     AFTER INSERT OR UPDATE ON healthdeclaration
--     FOR EACH ROW EXECUTE FUNCTION contact_tracing();
--returns eid and num days not declared from [start, end] order by desc num_days
DROP FUNCTION IF EXISTS non_compliance(startDate Date, endDate Date);
CREATE OR REPLACE FUNCTION non_compliance(startDate Date, endDate Date) RETURNS TABLE(eid INT, days BIGINT) AS
    $$
    DECLARE
        num_days INT;
    BEGIN
       num_days = endDate - startDate;
        --count how many times each employee declared.
        --return if count < numDays
        RETURN QUERY
       with num_declarations as
           ( SELECT h.eid, count(*) as num_declared from HealthDeclaration h
             WHERE h.date >= startDate and h.date <= endDate and h.temp is not null
             group by h.eid
             order by num_days asc) -- asc means eid with most temps declared first
        select e.eid,
               CASE WHEN e.eid NOT IN (select t.eid from num_declarations t)
                   THEN num_days
                   ELSE num_days - (select t.num_declared from num_declarations t where t.eid=e.eid)
               END as num_undeclared
            from Employees e order by num_undeclared desc ;
    END;
    $$ language plpgsql;

-- dates: 2021-11-17  to 2021-11-19
select * from non_compliance('2021-11-17', '2021-11-19');




CREATE OR REPLACE FUNCTION change_capacity(floor_in int, room_in int, cap int, date_in Date, m_eid int)
RETURNS VOID AS
    $$
    BEGIN
        INSERT INTO Updates(manager_eid, room, floor, date, new_cap) VALUES (m_eid, room_in, floor_in, date_in, cap);
    END;
$$ language plpgsql;

-- Updating Constraints:
-- 1. Manager from same dept only can update capacity [24]
CREATE OR REPLACE FUNCTION do_updating_capacity() RETURNS TRIGGER AS $$
BEGIN
 IF ( (select e.did FROM Employees e where e.eid = NEW.manager_eid) !=
      (select m.did from MeetingRooms m NATURAL JOIN Updates u
      WHERE m.room = NEW.room AND m.floor = NEW.floor))
THEN
    RAISE NOTICE 'Only managers from the same department can update capacity';
    Return  NULL;
ELSE
     return NEW;
END IF;
END
    $$ language plpgsql;

DROP TRIGGER IF EXISTS trigger_before_new_cap ON Updates;
CREATE TRIGGER trigger_before_new_cap
    BEFORE INSERT OR UPDATE ON updates
    FOR EACH ROW EXECUTE  FUNCTION do_updating_capacity();


-- Does: delete sessions which exceed the new capacity after it is updated.
CREATE OR REPLACE FUNCTION post_updated_cap() RETURNS TRIGGER
AS $$
    BEGIN
        --is there a trigger to delete from Joins if deleted in sessions? (Khiaxeng)
        delete from Sessions s where (
            s.floor = NEW.floor and s.room = NEW.room and s.date >= NEW.date and
            (select count(j.eid) from Joins j
            where j.floor = s.floor and j.room = s.room and j.time = s.time and j.date = s.date
            group by (j.floor, j.room, j.time, j.date)) > NEW.new_cap) ;
        return null;
    END;
    $$ language plpgsql;

DROP TRIGGER IF EXISTS trigger_after_new_cap ON Updates;
CREATE TRIGGER trigger_after_new_cap
    AFTER INSERT OR UPDATE ON updates
    FOR EACH ROW EXECUTE FUNCTION post_updated_cap();

select * from change_capacity(1,1,1,'2021-07-20', 475);