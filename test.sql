-- FUNCTION: contact_tracing
-- TEST CASE 1:
-- Expectation: Will return a set of eids and these will be deleted from Joins
SELECT * FROM declare_health(223, '2021-12-08', 37);
UPDATE Employees SET cc_end_date = null;
SELECT * FROM Employees WHERE eid in (1,20,223,400, 433);
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
SELECT * from declare_health(450,'2022-01-28', 36);
Update Employees SET cc_end_date = null;
SELECT * FROM Employees WHERE eid in (1,2,3);
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
CloseContacts as (
    SELECT DISTINCT * FROM Joins j, MeetingRoomsAffected m
    WHERE j.date < date'2022-01-28' AND j.date >= date '2022-01-28' - INTERVAL '3 DAYS'
    AND j.room = m.room
    AND j.floor = m.floor /*same room*/
    AND j.time = m.time /*same time; same session*/
)
SELECT * FROM CloseContacts;

-- TEST CASE 2a:
SELECT * FROM declare_health(450, '2022-01-28', 35);
SELECT * FROM contact_tracing(450, '2022-01-28');
SELECT * FROM Sessions WHERE booker_eid = 450 AND date > '2022-01-28';
SELECT * FROM Employees WHERE eid in (1,2,3);
 --- TEST CASE 2b: Booker declares fever  --> cc_end_date should be updated and session on 2022-01-29 will be deleted
SELECT * FROM declare_health(450, '2022-01-28', 41);
SELECT * FROM contact_tracing(450, '2022-01-28');
SELECT * FROM Sessions WHERE booker_eid = 450 AND date > '2022-01-28';
SELECT * FROM Employees WHERE eid in (1,2,3);
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
-- FUNCTION: add_room
SELECT * FROM meetingrooms;
SELECT * FROM add_room(2, 5, 'Test Room', 7, 7, 492);
SELECT * FROM meetingrooms;
--------------------------------------------------------------------------------------------------------------------------------------------
-- FUNCTION: search_room
-- Test 1: Search for rooms with unavailable capacity (should be empty)
SELECT * from sessions order by date;
SELECT * FROM search_room('20', '2022-01-01','9:15:00','11:33:00');

-- Test 2: Search for rooms which should be available(should be all rooms)
SELECT * from sessions order by date;
SELECT * FROM search_room('5', '2022-01-01','9:15:00','11:33:00');

-- Test 3: There is a session at 16:00:00 in room 1 floor 4 (all rooms except this)
SELECT * from sessions order by date;
SELECT * FROM search_room('5', '2022-01-01','9:15:00','18:33:00');

-- Test 4: Rooms with capcity of 11 (only 1 room)
SELECT * from sessions order by date;
SELECT * FROM search_room('11', '2022-01-01','9:15:00','18:33:00');
--------------------------------------------------------------------------------------------------------------------------------------------
-- FUNCTION: join_meeting
-- Test 1: Join a 1 hour slot with rounding
SELECT * FROM joins j where j.time='17:00:00' AND j.date='2022-04-15';
SELECT * FROM join_meeting(4, 2, '2022-04-15','17:00:00', '17:59:00', 124);
SELECT * FROM joins j where j.time='17:00:00' AND j.date='2022-04-15';

-- Test 2: Join a multi hour meeting **TODO: add data
SELECT * FROM joins j where j.time='17:00:00' AND j.date='2022-04-15';
SELECT * FROM join_meeting(4, 2, '2022-04-15','17:00:00', '17:59:00', 124);
SELECT * FROM joins j where j.time='17:00:00' AND j.date='2022-04-15';

-- Test 3: Try to joins meeting with time ending= invalid (The entry is added to all multi-hour valid slots or none)
SELECT * FROM joins j where j.time='17:00:00' AND j.date='2022-04-15';
SELECT * FROM join_meeting(4, 2, '2022-04-15','17:00:00', '19:59:00', 125);
SELECT * FROM joins j where j.time='17:00:00' AND j.date='2022-04-15';


-- Test 4: Cannot join past meetings **TODO: add past meeting data
SELECT * FROM joins j where j.time='17:00:00' AND j.date='2022-04-15';
SELECT * FROM join_meeting(4, 2, '2022-04-15','17:00:00', '17:59:00', 124);
SELECT * FROM joins j where j.time='17:00:00' AND j.date='2022-04-15';

-- Test 5: Cannot join with fever
SELECT * FROM joins j where j.time='12:00:00' AND j.date='2022-01-07';

SELECT * FROM declare_health(20, CURRENT_DATE, 38.6);
SELECT * FROM healthdeclaration where eid=20;

SELECT * FROM join_meeting(2, 3, '2022-01-07','12:00:00', '13:00:00', 20);
SELECT * FROM joins j where j.time='12:00:00' AND j.date='2022-01-07';


-- Test 6: Cannot join approved meeting
SELECT * FROM approve_meeting(2, 3, '2022-01-07','12:00:00', '13:00:00', 478);
SELECT * FROM sessions where date='2022-01-07';

SELECT * FROM join_meeting(2, 3, '2022-01-07','12:00:00', '13:00:00', 23);
SELECT * FROM joins where date='2022-01-07';


-- Test 7: Resigned employee cannot join
SELECT * FROM joins where date = '2023-04-01';

SELECT * FROM remove_employee(301, '2021-06-04');
SELECT * FROM Employees where eid=301;
SELECT * FROM join_meeting(2, 3, '2023-04-01','18:00:00', '19:00:00', 301);

SELECT * FROM joins where date = '2023-04-01';

-- Test 8: Cannot exceed capacity
SELECT * FROM joins where date = '2023-04-01'; --8 employees
SELECT * FROM updates where room=3 and floor=2; --cap=10
SELECT * FROM join_meeting(2, 3, '2023-04-01','18:00:00', '19:00:00', 302);
SELECT * FROM join_meeting(2, 3, '2023-04-01','18:00:00', '19:00:00', 303);
SELECT * FROM join_meeting(2, 3, '2023-04-01','18:00:00', '19:00:00', 304);

SELECT * FROM joins where date = '2023-04-01'; --10 employees (full)


-- Test 9: Active Close contact cannot join **TODO

--------------------------------------------------------------------------------------------------------------------------------------------

-- FUNCTION: view_future_meeting

-- Test 1: Approve meetings and call function
SELECT * FROM joins j, sessions s where j.date=s.date and j.eid=476 order by j.date;
SELECT * FROM view_future_meeting('2021-02-20', 476);

SELECT * FROM approve_meeting(2, 1, '2023-05-16', '17:00:00', '17:01:00', 451);
SELECT * FROM approve_meeting(2,3, '2023-01-07', '16:00:00', '17:00:00', 478);

SELECT * FROM view_future_meeting('2021-02-20', 476);
SELECT * FROM joins j, sessions s where j.date=s.date and j.eid=476 order by j.date;

--------------------------------------------------------------------------------------------------------------------------------------------

-- FUNCTION: leave_meeting

-- Test 1: Leave a single hour meeting
SELECT * FROM joins where date='2022-04-15';
SELECT * FROM leave_meeting(4, 2, '2022-04-15','17:00:00', '18:00:00', 407);
SELECT * FROM joins where date='2022-04-15';

-- Test 2: Employee cannot leave approved meeting
SELECT * FROM sessions where approver_eid IS NOT NULL;
SELECT * FROM leave_meeting(2, 1, '2023-05-16','17:00:00', '18:00:00', 355);
SELECT * FROM joins where date='2023-05-16';

-- Test 3: People with fever on current day can leave meeting
SELECT * FROM sessions where approver_eid IS NOT NULL;
SELECT * FROM joins where date='2023-05-16';
SELECT * FROM declare_health(51, CURRENT_DATE, 38.6); -- This employee is removed from all future meeting approved or not
SELECT * FROM joins where date='2023-05-16';

-- Test 4: Meeting is cancelled if Booker leaves
SELECT * FROM sessions where date='2022-04-01';
SELECT * FROM joins where date='2022-04-01';
SELECT * FROM leave_meeting(3, 2, '2022-04-01','14:00:00', '15:00:00', 472);
SELECT * FROM sessions where date='2022-04-01';
SELECT * FROM joins where date='2022-04-01';

-- Test 5: If booker has fever, then meeting is cancelled
SELECT * FROM sessions where approver_eid IS NOT NULL;
SELECT * FROM joins where date='2023-05-16';
SELECT * FROM declare_health(355, CURRENT_DATE, 38.6);
SELECT * FROM joins where date='2023-05-16';
SELECT * FROM sessions where date='2023-05-16';

-- Test 6: Active close contacts can leave meeting **TODO: Since the cc only if cc_end -7 <=cur_day <= cc_end need to add data

-- Test 7: Leave multi-hour meeting (Can leave partially but must be valid. If any leave time is invalid then rollback) **TODO: add multi-hour data

--------------------------------------------------------------------------------------------------------------------------------------------





--------------------------------------------------------------------------------------------------------------------------------------------

-- FUNCTION: add_employee
-- Test 1: New junior will be added with an eid of 501
SELECT * FROM employees ORDER BY eid DESC LIMIT 5;
SELECT * FROM add_employee('Test Junior', 90915245, 'JUNIOR', 1);
SELECT * FROM employees ORDER BY eid DESC LIMIT 5;
SELECT * FROM junior ORDER BY eid DESC LIMIT 5;

-- Test 2: New senior will be added with an eid of 502
SELECT * FROM employees ORDER BY eid DESC LIMIT 5;
SELECT * FROM add_employee('Test Senior', 90915245, 'SENIOR', 1);
SELECT * FROM employees ORDER BY eid DESC LIMIT 5;
SELECT * FROM booker ORDER BY eid DESC LIMIT 5;
SELECT * FROM senior ORDER BY eid DESC LIMIT 5;

-- Test 3: New manager will be added with an eid of 503
SELECT * FROM employees ORDER BY eid DESC LIMIT 5;
SELECT * FROM add_employee('Test Manager', 90915245, 'MANAGER', 1);
SELECT * FROM employees ORDER BY eid DESC LIMIT 5;
SELECT * FROM booker ORDER BY eid DESC LIMIT 5;
SELECT * FROM manager ORDER BY eid DESC LIMIT 5;

-- Test 4: Cannot add employees without adding to junior, senior or manager
-- Expected: ERROR:  An employee needs to be one of the three kinds of employees: junior, senior or manager
INSERT INTO employees VALUES(1000, 1, 'Manual insert', 'Manualinsert@gmail.com', 90915245);

-- Test 5: An employee cannot have two types
-- Expected: ERROR:  An employee cannot be both a junior and a booker(senior/manager)
INSERT INTO junior values(503);

-- Test 6: An employee cannot have two types
-- Expected: ERROR:  An employee cannot be both a senior and a manager
INSERT INTO senior values(503);

--------------------------------------------------------------------------------------------------------------------------------------------

-- FUNCTION: remove_employee
-- Test 1: Resigned date will be set to the date passed as input
SELECT * FROM employees WHERE resigned_date IS NOT NULL ORDER BY resigned_date DESC LIMIT 5;
SELECT * FROM remove_employee(501, '2021-11-07');
SELECT * FROM employees WHERE resigned_date IS NOT NULL ORDER BY resigned_date DESC LIMIT 5;

-- Test 2: Manual deletions are prohibited
-- Expected: ERROR:  Manual deletion of employee(s) are prohibited.
DELETE FROM employees WHERE eid=501;

--------------------------------------------------------------------------------------------------------------------------------------------

-- FUNCTION: view_manager_report
-- Test 1: Manager report
SELECT * FROM manager WHERE eid=500;
SELECT did FROM employees WHERE eid=500;
SELECT s.date, s.time, m.did, s.approver_eid FROM Sessions s NATURAL JOIN MeetingRooms m WHERE s.approver_eid IS NULL AND m.did=6 AND '2021-02-04' <= s.date ORDER BY s.date, s.time ASC;
SELECT * FROM view_manager_report('2021-02-04', 500);

-- Test 2: If not a manager, return nothing
SELECT * FROM manager WHERE eid=400;
SELECT * FROM view_manager_report('2021-02-04', 400);

--------------------------------------------------------------------------------------------------------------------------------------------

-- FUNCTION: book_room()
-- Positive case
select * from book_room(1, 1, '2021-11-15', '14:00:00', '15:00:00', 454);
select * from sessions where date = '2021-11-15' and room = 1 and floor = 1;
select * from sessions where date = '2021-11-15' and room = 1 and floor = 1;

--------------------------------------------------------------------------------------------------------------------------------------------
-- Booker must not have a fever
-- EXPECTED - ERROR:  Bookers with a fever cannot book a room
SELECT * FROM Employees WHERE eid = 318;
SELECT * FROM declare_health(318, '2021-11-07', 38.0);
SELECT * FROM HealthDeclaration WHERE eid = 318;
SELECT * FROM book_room(1, 1, '2021-11-07', '10:00:00', '14:00:00', 318);

--------------------------------------------------------------------------------------------------------------------------------------------

-- Only Booker (ISA senior/manager) can book a room
-- EXPECTED - ERROR:  Employee is not a Booker(Senior/Manager)
-- eid 454 is a Manager
-- SELECT * FROM Manager WHERE eid = 454
select * from book_room(1, 1, '2021-11-16', '14:00:00', '15:00:00', 454);
SELECT * FROM Sessions WHERE booker_eid = 454 AND floor = 1 AND room = 1;

--------------------------------------------------------------------------------------------------------------------------------------------

-- Employee booking the room automatically joins the meeting
-- EXPECTED - An entry corresponding to the book_room() details is found in Joins, where the booker is added into Joins
SELECT * FROM book_room(1, 1, '2021-12-19', '10:00:00', '14:00:00', 319);
SELECT * FROM Joins WHERE eid = 319;

--------------------------------------------------------------------------------------------------------------------------------------------

-- Can only book room for future meetings/dates
-- EXPECTED - ERROR:  Rooms can only be booked for future dates
SELECT * FROM book_room(1, 1, '2020-12-19', '10:00:00', '14:00:00', 319);

--------------------------------------------------------------------------------------------------------------------------------------------

-- Booker must not be resigned
-- ERROR:  Resigned employees cannot book a room
SELECT * FROM remove_employee(320, '2021-06-04');
SELECT * FROM book_room(1, 1, '2021-12-20', '10:00:00', '14:00:00', 320);

--------------------------------------------------------------------------------------------------------------------------------------------

-- FUNCTION: unbook_room()
-- Remove participants of the meeting after unbook_room()

-- Shows the table containing all the participants of this meeting in the Joins table
select * from joins where date = '2022-01-01' AND time = '16:00:00' AND room = 1 AND floor = 4;

-- Unbooks this meeting
select * from unbook_room(4, 1, '2022-01-01', '16:00:00', '17:00:00', 443);

-- Participants are now removed from the Joins table
select * from joins where date = '2022-01-01' AND time = '16:00:00' AND room = 1 AND floor = 4;

--------------------------------------------------------------------------------------------------------------------------------------------

-- FUNCTION: approve_meeting()
-- Only manager can approve meetings
-- EXPECTED - ERROR:  Employee is not a Manager (eid 450 is not a manager)
select * from approve_meeting(1, 3, '2022-01-16', '09:00:00', '10:00:00', 450);

--------------------------------------------------------------------------------------------------------------------------------------------

-- The approved meeting must be in the same Department as the Manager
-- EXPECTED - ERROR:  Manager is not in the same department as booked room
select * from approve_meeting(2, 2, '2022-01-20', '09:00:00', '10:00:00', 452)

