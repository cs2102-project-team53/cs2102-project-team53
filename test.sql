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
DELETE FROM Sessions  WHERE date = '2022-01-01' AND room = 1 and floor = 4 AND time='16:00:00';
INSERT INTO Sessions  (time, date, room, floor, booker_eid) VALUES ('16:00:00', '2022-01-01',1,  4, 433);
insert into Joins (eid, time, date, room, floor) values (1, '16:00:00', '2022-01-01', 1, 4);
insert into Joins (eid, time, date, room, floor) values (223, '16:00:00', '2022-01-01', 1, 4);
insert into Joins (eid, time, date, room, floor) values (400, '16:00:00', '2022-01-01', 1, 4);
insert into Joins (eid, time, date, room, floor) values (20, '16:00:00', '2022-01-01', 1, 4);
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
-- TEST QUERY:

DELETE FROM healthdeclaration WHERE date > '2021-01-02' AND eid = 223;
INSERT INTO HealthDeclaration (date, eid, temp) VALUES ('2022-01-02', 223, 41.2);

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
SELECT * FROM CloseContacts NATURAL JOIN Employees e;
SELECT * FROM Employees WHERE eid in (1,20,223,400, 433);
SELECT * FROM Joins WHERE  eid in (1,20,223,400, 433) AND date <= '2022-01-02';
-- TEST CASE 2:
-- Expectation: Will do nothing because no fever
-- SELECT * FROM approve_meeting(2,2, '2022-01-27', '14:00:00', '15:00:00', 453);

SELECT * FROM Employees e, MeetingRooms mr WHERE mr.room = 2 AND mr.floor = 2 AND mr.did = e.did AND e.eid IN (Select * FROM Manager);
WITH MeetingRoomsAffected as (
    SELECT m.room, m.floor, s.time FROM MeetingRooms m NATURAL JOIN Joins j NATURAL JOIN Sessions s
    WHERE j.eid = 450 -- booker of this meeting.
    AND j.date < date '2022-01-28' AND j.date >= date '2022-01-28' - INTERVAL '3 DAYS'
    AND s.approver_eid IS NOT NULL
),

-- Find close contacts: employees in the same approved meeting room FROM the past 3 (i.e., FROM day D-3 to day D) days
CloseContacts as (
    SELECT DISTINCT * FROM Joins j, MeetingRoomsAffected m
    WHERE j.date < date'2022-01-28' AND j.date >= date '2022-01-28' - INTERVAL '3 DAYS'
    AND j.room = m.room
    AND j.floor = m.floor /*same room*/
    AND j.time = m.time /*same time; same session*/
)
SELECT * FROM CloseContacts;
-- TEST QUERY:
-- DELETE FROM HealthDeclaration h WHERE h.eid = 285 AND h.date > '2022-01-28';
-- INSERT INTO HealthDeclaration (date, eid, temp) VALUES ('2022-01-28', 285, 40);  -- session booked for 2022-01-27, 14:00:00, 450, 2, 2

WITH MeetingRoomsAffected as (
    SELECT m.room, m.floor, s.time FROM MeetingRooms m NATURAL JOIN Joins j NATURAL JOIN Sessions s
    WHERE j.eid = 450
    AND j.date < date '2022-01-28' AND j.date >= date '2022-01-28' - INTERVAL '3 DAYS'
    AND s.approver_eid IS NOT NULL
),

-- Find close contacts: employees in the same approved meeting room FROM the past 3 (i.e., FROM day D-3 to day D) days
CloseContacts as (
    SELECT DISTINCT * FROM Joins j, MeetingRoomsAffected m
    WHERE j.date < date'2022-01-28' AND j.date >= date '2022-01-28' - INTERVAL '3 DAYS'
    AND j.room = m.room
    AND j.floor = m.floor /*same room*/
    AND j.time = m.time /*same time; same session*/
)
SELECT * FROM CloseContacts NATURAL JOIN Employees;


--------------------------------------------------------------------------------------------------------------------------------------------

-- FUNCTION: non_compliance
-- Expectation: Shows lists of employees who didn't declare temp
SELECT * FROM non_compliance('2021-10-18', '2021-10-19');
SELECT * FROM non_compliance('2021-11-16', '2021-11-19');
--------------------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------------------

-- FUNCTION: change_capacity
-- TEST CASE 1:
-- Expectation: Disallowed because manager from diff dept to meeting room
-- SELECT * FROM change_capacity(2,3, 0, '2021-05-01', 499) ;
-- TEST CASE 2:
-- Expectation: Allowed because manager from same dept. Sessions will be deleted
-- INSERT INTO Sessions (time, date, room, floor, booker_eid, approver_eid) VALUES ('14:00:00', '2022-09-01', 2, 3, 400, null);
-- INSERT INTO Joins (eid, time, date, room, floor) VALUES (1, '14:00:00', '2022-09-01', 2,3);
-- INSERT INTO Joins (eid, time, date, room, floor) VALUES (2, '14:00:00', '2022-09-01', 2,3);
-- INSERT INTO Joins (eid, time, date, room, floor) VALUES (3, '14:00:00', '2022-09-01', 2,3);
-- SELECT * FROM (Employees e NATURAL JOIN Manager m), MeetingRooms mr WHERE mr.room = 2 AND mr.floor = 3 AND  mr.did = e.did;
-- SELECT * FROM Sessions s WHERE s.room = 2 AND s.floor = 3 AND s.date >= '2022-09-01';
-- SELECT * FROM Joins j WHERE j.room = 2 AND j.floor = 3 AND j.date >= '2022-09-01';
-- SELECT * FROM change_capacity(3,2, 0, '2021-05-01', 500) ;
-- SELECT * FROM Sessions s WHERE s.room = 2 AND s.floor = 3 AND s.date >= '2022-09-01';
-- SELECT * FROM Joins j WHERE j.room = 2 AND j.floor = 3 AND j.date >= '2022-09-01';

--------------------------------------------------------------------------------------------------------------------------------------------


-- FUNCTION: add_departments
-- Expectation: New dept will be added
SELECT * FROM departments;
SELECT * FROM add_department(9, 'Test Department');
SELECT * FROM departments;

--------------------------------------------------------------------------------------------------------------------------------------------
-- FUNCTION: add_departments
-- Test 1: Remove department without any rooms/employees
SELECT * FROM remove_department(9);
SELECT * FROM departments;

-- Test 2: Remove department with employees (will fail)
SELECT * FROM remove_department(1);
SELECT * FROM departments;

-- Test 3: Remove department with no employees but rooms (will fail)
SELECT * FROM add_department(9, 'Test Department');
SELECT * FROM add_employee('Charles', 90915145, 'MANAGER', 9); --Add a manager to allow add_room
SELECT * FROM add_room (5, 2, 'Test Room', 9, 7, 501);
SELECT * FROM remove_employee(501, '2021-06-04');
SELECT * FROM remove_department(9);
-- Remove meeting room and show it works
DELETE FROM Updates where room=5;
DELETE FROM meetingrooms where did=9;
SELECT * FROM remove_department(9);
SELECT * FROM departments;
--------------------------------------------------------------------------------------------------------------------------------------------
