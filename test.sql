-- FUNCTION: declare_health
-- TEST CASE 1:
-- Expectation: Will perform contact tracing
SELECT * FROM HealthDeclaration h WHERE h.eid = 500 ;
SELECT * FROM declare_health(500, '2021-10-21', 41);
SELECT * FROM HealthDeclaration h WHERE h.eid = 500 ;

--------------------------------------------------------------------------------------------------------------------------------------------

-- FUNCTION: contact_tracing
-- TEST CASE 1:
-- Expectation: Will return a set of eids and these will be deleted from Joins

SELECT * FROM declare_health(223, '2021-12-08', 37);
UPDATE Employees SET cc_end_date = null;
DELETE FROM Sessions WHERE date = '2021-12-07' AND room = 1 and floor = 4 AND time='16:00:00';
SELECT * FROM book_room(4, 1, '2021-12-07', '16:00:00', '17:00:00', 433);
SELECT * FROM join_meeting(4, 1, '2021-12-07', '16:00:00', '17:00:00', 1);
SELECT * FROM join_meeting(4, 1, '2021-12-07', '16:00:00', '17:00:00', 20);
SELECT * FROM join_meeting(4, 1, '2021-12-07', '16:00:00', '17:00:00', 223);
SELECT * FROM join_meeting(4, 1, '2021-12-07', '16:00:00', '17:00:00', 400);
SELECT * FROM approve_meeting(4, 1, '2021-12-07', '16:00:00', '17:00:00', 482);
-- Suppose date of fever is going to be '2021-12-08'
WITH MeetingRoomsAffected as (
    SELECT m.room, m.floor, s.time FROM MeetingRooms m NATURAL JOIN Joins j NATURAL JOIN Sessions s
    WHERE j.eid = 223
    AND j.date < date '2021-12-08' AND j.date >= date '2021-12-08' - INTERVAL '3 DAYS'
    AND s.approver_eid IS NOT NULL
),
CloseContacts as (
    SELECT DISTINCT * FROM Joins j, MeetingRoomsAffected m
    WHERE j.date < date '2021-12-08' AND j.date >= date '2021-12-08' - INTERVAL '3 DAYS'
    AND j.eid <> 223
    AND j.room = m.room
    AND j.floor = m.floor /*same room*/
    AND j.time = m.time /*same time; same session*/
)
SELECT * FROM CloseContacts NATURAL JOIN Employees;
-- TEST QUERY:
SELECT * FROM Joins WHERE room = 1 AND floor = 4 AND date = '2021-12-07';
SELECT * FROM declare_health(223, '2021-12-08', 41);
SELECT * FROM HealthDeclaration WHERE eid = 223 AND date = '2021-12-08';
SELECT * FROM contact_tracing(223,'2021-12-08');
SELECT * FROM Employees WHERE eid in (1,20,223,400, 433);


-- TEST CASE 2:
-- Expectation: Will delete future bookings of employee w fever
SELECT * FROM Employees e, MeetingRooms mr WHERE mr.room = 2 AND mr.floor = 2 AND mr.did = e.did AND e.eid IN (Select * FROM Manager);
DELETE FROM Sessions WHERE  time = '14:00:00' AND date = '2022-01-27' AND room =  2 AND floor = 2 and booker_eid = 450;
SELECT * from book_room(2, 2, '2022-01-27', '14:00:00', '15:00:00', 450);
SELECT * FROM join_meeting(2,  2, '2022-01-27', '14:00:00', '15:00:00', 1);
SELECT * FROM join_meeting(2, 2, '2022-01-27', '14:00:00', '15:00:00', 2);
SELECT * FROM join_meeting(2, 2, '2022-01-27', '14:00:00', '15:00:00', 3);
SELECT * FROM approve_meeting(2,2, '2022-01-27', '14:00:00', '15:00:00', 453);
SELECT * from book_room(2, 2, '2022-01-29', '14:00:00', '15:00:00', 450);
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
SELECT * FROM declare_health(450, '2022-01-28', 40);
SELECT * FROM contact_tracing(450, '2022-01-28');
SELECT * FROM Sessions WHERE booker_eid = 450 AND date > '2022-01-28';
SELECT * FROM Employees WHERE eid in (1,2,3);

-- TEST CASE 3:
-- Expectation: Do nothing cause no fever
SELECT * from declare_health(450,'2022-01-28', 36);
Update Employees SET cc_end_date = null;
SELECT * FROM Employees e, MeetingRooms mr WHERE mr.room = 2 AND mr.floor = 2 AND mr.did = e.did AND e.eid IN (Select * FROM Manager);
DELETE FROM Sessions WHERE  time = '14:00:00' AND date = '2022-01-27' AND room =  2 AND floor = 2 and booker_eid = 450;
SELECT * from book_room(2, 2, '2022-01-27', '14:00:00', '15:00:00', 450);
SELECT * FROM join_meeting(2,  2, '2022-01-27', '14:00:00', '15:00:00', 1);
SELECT * FROM join_meeting(2, 2, '2022-01-27', '14:00:00', '15:00:00', 2);
SELECT * FROM join_meeting(2, 2, '2022-01-27', '14:00:00', '15:00:00', 3);
SELECT * FROM approve_meeting(2,2, '2022-01-27', '14:00:00', '15:00:00', 453);
SELECT * from book_room(2, 2, '2022-01-29', '14:00:00', '15:00:00', 450);
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
SELECT * FROM declare_health(450, '2022-01-28', 35);
SELECT * FROM contact_tracing(450, '2022-01-28');
SELECT * FROM Sessions WHERE booker_eid = 450 AND date > '2022-01-28';
--------------------------------------------------------------------------------------------------------------------------------------------

-- FUNCTION: non_compliance
-- Expectation: Shows lists of employees who didn't declare temp
SELECT * FROM non_compliance('2021-10-18', '2021-10-19'); -- show before and after tables.
SELECT * FROM non_compliance('2021-11-16', '2021-11-19');
--------------------------------------------------------------------------------------------------------------------------------------------

--------------------------------------------------------------------------------------------------------------------------------------------

-- FUNCTION: change_capacity
-- TEST CASE 1:
-- Expectation: Disallowed because manager from diff dept to meeting room
SELECT * FROM updates;
SELECT * FROM (Employees e NATURAL JOIN Manager m), MeetingRooms mr WHERE mr.room = 1 AND mr.floor =  1 AND  mr.did = e.did;
SELECT * FROM change_capacity(1,1, 1, '2021-05-01', 454) ;
SELECT * FROM updates;

-- TEST CASE 2:
-- Expectation: Allowed because manager from same dept. Sessions will be deleted
SELECT * FROM change_capacity(3,2, 3, '2021-05-01', 500) ;
INSERT INTO Sessions (time, date, room, floor, booker_eid, approver_eid) VALUES ('14:00:00', '2022-09-01', 2, 3, 410, null);
INSERT INTO Joins (eid, time, date, room, floor) VALUES (100, '14:00:00', '2022-09-01', 2,3);
INSERT INTO Joins (eid, time, date, room, floor) VALUES (110, '14:00:00', '2022-09-01', 2,3);
INSERT INTO Joins (eid, time, date, room, floor) VALUES (121, '14:00:00', '2022-09-01', 2,3);
-- SELECT * FROM (Employees e NATURAL JOIN Manager m), MeetingRooms mr WHERE mr.room = 2 AND mr.floor = 3 AND  mr.did = e.did;
SELECT * FROM Sessions s WHERE s.room = 2 AND s.floor = 3 AND s.date >= '2022-09-01';
SELECT * FROM Joins j WHERE j.room = 2 AND j.floor = 3 AND j.date >= '2022-09-01';
SELECT * FROM change_capacity(3,2, 0, '2021-05-01', 500) ;
 SELECT * FROM Sessions s WHERE s.room = 2 AND s.floor = 3 AND s.date >= '2022-09-01';
SELECT * FROM Joins j WHERE j.room = 2 AND j.floor = 3 AND j.date >= '2022-09-01';

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
