DROP TABLE IF EXISTS Departments, Employees, Junior, Booker, Senior, Manager, HealthDeclaration, MeetingRooms, Sessions, Updates, Joins CASCADE;

-- MATHEW --
-- add_department()
-- remove_department()
CREATE TABLE Departments (
	did INT PRIMARY KEY,
	dname VARCHAR(50)
);

-- KEVIN --
--add_employee()
--remove_employee()
--view_manager_report()
CREATE TABLE Employees (
    eid INTEGER PRIMARY KEY,
    did INT NOT NULL,
    ename VARCHAR(50) NOT NULL,
    email VARCHAR(50) UNIQUE,
    mobile_number INTEGER,
	home_number INTEGER,
	office_number INTEGER,
    resigned_date DATE,
    FOREIGN KEY (did) REFERENCES Departments(did)
    -- trigger
    -- DELETE  --> BEFORE --> RAISE EXCEPTION("not allowed to dept cause has employees")
); /* put deptId here */

-- KEVIN: Add TRIGGER functions for ISA relationship
CREATE TABLE Junior (
	eid INT PRIMARY KEY,
	FOREIGN KEY (eid) REFERENCES Employees(eid) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Booker (
	eid INT PRIMARY KEY,
	FOREIGN KEY (eid) REFERENCES Employees(eid) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Senior (
	eid INT PRIMARY KEY,
	FOREIGN KEY (eid) REFERENCES Booker(eid) ON DELETE CASCADE ON UPDATE CASCADE
);

CREATE TABLE Manager (
	eid INT PRIMARY KEY,
	FOREIGN KEY (eid) REFERENCES Booker(eid) ON DELETE CASCADE ON UPDATE CASCADE
);



-- VANSHIQA --
-- declare_health()
-- contact_tracing()
-- non_compliance()
CREATE TABLE HealthDeclaration (
    date DATE,
	eid INTEGER,
	temp NUMERIC NOT NULL,
    fever BOOLEAN GENERATED ALWAYS AS (temp > 37.5) STORED,
	PRIMARY KEY (eid, date),
	FOREIGN KEY (eid) REFERENCES Employees(eid),
	CONSTRAINT temp_range_check CHECK ((temp >= 34 AND temp<=43))
);


-- MATHEW --
--add_room()
--search_room()
CREATE TABLE MeetingRooms(
    room INTEGER,
	floor INTEGER,
	rname VARCHAR(50),
	did INT NOT NULL,
	PRIMARY KEY (room, floor),
	FOREIGN KEY (did) REFERENCES Departments(did)
    -- add trigger to insert into Updates
);

-- KHIAXENG --
--book_room()
--unbook_room()
--approve_meeting()
--view_booking_report()
CREATE TABLE Sessions (
    time TIME,
	date DATE,
	room INTEGER,
	floor INTEGER,
	booker_eid INT NOT NULL,
	approver_eid INTEGER,
    PRIMARY KEY(time, date, room, floor),
    FOREIGN KEY (room, floor) REFERENCES MeetingRooms(room, floor) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (booker_eid) REFERENCES Booker(eid) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (approver_eid) REFERENCES Manager(eid)
--     constraint hasFever(booked_eid) != 1,
--      constraint (approver.did == did of meeting room and approver.resigned == null),
--      constraint isFutureDate,
--      constraint eid.resigned == null,
--      constraint cannotJoin(eid, date) != 1
);

-- VANSHIQA --
--change_capacity()
CREATE TABLE Updates(
    manager_eid INTEGER,
    room INTEGER,
    floor INTEGER,
	date DATE,
    new_cap INTEGER,
    PRIMARY KEY (manager_eid, date, room, floor),
    FOREIGN KEY (manager_eid) REFERENCES Manager(eid),
    FOREIGN KEY (room, floor) REFERENCES MeetingRooms(room, floor)
-- How to ensure total participation of meeting room?
--     constraint isSameDept(manager_eid, room,floor) == 1;
);


-- MATHEW --
-- join_meeting()
-- leave_meeting()
-- view_future_meeting()
create table Joins (
    eid INTEGER,
    time TIME,
    date DATE,
    room INTEGER,
    floor INTEGER,
    PRIMARY KEY (eid, time, date, room, floor),
    FOREIGN KEY (eid) REFERENCES Employees(eid),
    FOREIGN KEY (time, date, room, floor) REFERENCES Sessions (time, date, room, floor) ON DELETE CASCADE ON UPDATE CASCADE
--     check eid.resigned == null,
--     How to enforce total participation of sessions?
--     constraint cannotJoin(eid, date) !=1
);









-- 3. [[Session]] uses {endTime} as key.  Just note that a [[Session]] may be approved partially
-- (e.g., booked from 10 to 12, but only approved from 10 to 11).
-- It can be done this way, but be prepared to split the {startTime} and {endTime} into multiple entries to accommodate this.


-- 3. The same [MeetingRoom] can be [<Books>] by different people at the same {startTime} + {endTime}, which should not happen.



-- create FUNCTION hasFever (empId int) RETURNS int AS $$
--     SELECT 1 FROM HealthDeclaration h WHERE h.eid == empId AND  h.fever ;
--     $$ language sql;
--
-- create FUNCTION isSameDept(manId INTEGER, inRoom INTEGER, inFloor int) RETURNS int AS $$
--     SELECT 1 FROM MeetingRooms m, Employees e WHERE m.did == e.did AND m.room==inRoom AND m.floor == inFloor;
-- $$ language sql;
--
--
-- create FUNCTION isFutureDate(inDate Date) RETURNS boolean as $$
--         Date(inDate) > Date(NOW());
--     $$ language sql;
--
--
-- create FUNCTION cannotJoin(empId INTEGER, meetingDate date) RETURNS int AS $$
--     SELECT 1 FROM Employees e WHERE e.eid == empId AND e.isCloseContact AND e.closeContactDate + 7 <= meetingDate;
-- $$ language sql;
-- end;