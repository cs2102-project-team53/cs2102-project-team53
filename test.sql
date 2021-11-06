-- FUNCTION: declare_health
-- TEST CASE 1:
-- Expectation: Will perform contact tracing
SELECT * FROM HealthDeclaration h WHERE h.eid = 500 ;
SELECT * FROM declare_health(500, '2021-10-20', 41.1);
SELECT * FROM HealthDeclaration h WHERE h.eid = 500 ;
--------------------------------------------------------------------------------------------------------------------------------------------

-- FUNCTION: contact_tracing
-- TEST CASE 1:
-- Expectation: Will return a set of eids and these will be deleted from Joins
--DELETE FROM Sessions  WHERE date = '2022-01-01' AND room = 1 and floor = 4 AND time='16:00:00';
--INSERT INTO Sessions  (time, date, room, floor, booker_eid) VALUES ('16:00:00', '2022-01-01',1,  4, 433);
-- insert into Joins (eid, time, date, room, floor) values (1, '16:00:00', '2022-01-01', 1, 4);
-- insert into Joins (eid, time, date, room, floor) values (223, '16:00:00', '2022-01-01', 1, 4);
-- insert into Joins (eid, time, date, room, floor) values (400, '16:00:00', '2022-01-01', 1, 4);
-- insert into Joins (eid, time, date, room, floor) values (20, '16:00:00', '2022-01-01', 1, 4);
 SELECT * FROM approve_meeting(4, 1, '2022-01-01', '16:00:00', '17:00:00', 482);
WITH MeetingRoomsAffected as (
    SELECT m.room, m.floor, s.time FROM MeetingRooms m NATURAL JOIN Joins j NATURAL JOIN Sessions s
    WHERE j.eid = 223
    AND j.date < date '2022-01-02' AND j.date >= date '2022-01-02' - INTERVAL '3 DAYS'
    AND s.approver_eid IS NOT NULL
),

-- Find close contacts: employees in the same approved meeting room FROM the past 3 (i.e., FROM day D-3 to day D) days
CloseContacts as (
    SELECT DISTINCT * FROM Joins j, MeetingRoomsAffected m
    WHERE j.date < date'2022-01-02' AND j.date >= date '2022-01-02' - INTERVAL '3 DAYS'
    AND j.room = m.room
    AND j.floor = m.floor /*same room*/
    AND j.time = m.time /*same time; same session*/
)
SELECT * FROM CloseContacts;
-- INSERT INTO HealthDeclaration (date, eid, temp) VALUES ('2021-01-02', 223, 41.2);
WITH MeetingRoomsAffected as (
    SELECT m.room, m.floor, s.time FROM MeetingRooms m NATURAL JOIN Joins j NATURAL JOIN Sessions s
    WHERE j.eid = 223
    AND j.date < date '2022-01-02' AND j.date >= date '2022-01-02' - INTERVAL '3 DAYS'
    AND s.approver_eid IS NOT NULL
),

-- Find close contacts: employees in the same approved meeting room FROM the past 3 (i.e., FROM day D-3 to day D) days
CloseContacts as (
    SELECT DISTINCT * FROM Joins j, MeetingRoomsAffected m
    WHERE j.date < date'2022-01-02' AND j.date >= date '2022-01-02' - INTERVAL '3 DAYS'
    AND j.room = m.room
    AND j.floor = m.floor /*same room*/
    AND j.time = m.time /*same time; same session*/
)
SELECT * FROM CloseContacts;
--------------------------------------------------------------------------------------------------------------------------------------------

