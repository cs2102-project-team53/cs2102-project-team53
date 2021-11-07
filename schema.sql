DROP TABLE IF EXISTS Departments, Employees, Junior, Booker, Senior, Manager, HealthDeclaration, MeetingRooms, Sessions, Updates, Joins CASCADE;

CREATE TABLE Departments (
	did INT PRIMARY KEY,
	dname VARCHAR(50)
);

CREATE TABLE Employees (
    eid INTEGER PRIMARY KEY,
    did INT NOT NULL,
    ename VARCHAR(50) NOT NULL,
    email VARCHAR(50) UNIQUE,
    mobile_number NUMERIC,
	home_number NUMERIC,
	office_number NUMERIC,
    resigned_date DATE,
    cc_end_date DATE,
    FOREIGN KEY (did) REFERENCES Departments(did) ON DELETE SET NULL
);

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

CREATE TABLE HealthDeclaration (
    date DATE,
	eid INTEGER,
	temp NUMERIC NOT NULL,
    fever BOOLEAN GENERATED ALWAYS AS (temp > 37.5) STORED,
	PRIMARY KEY (eid, date),
	FOREIGN KEY (eid) REFERENCES Employees(eid) ON DELETE CASCADE ON UPDATE CASCADE,
	CONSTRAINT temp_range_check CHECK ((temp >= 34 AND temp<=43))
);

CREATE TABLE MeetingRooms(
    room INTEGER,
	floor INTEGER,
	rname VARCHAR(50),
	did INT NOT NULL,
	PRIMARY KEY (room, floor),
	FOREIGN KEY (did) REFERENCES Departments(did)
    
);

CREATE TABLE Sessions (
    time TIME,
	date DATE,
	room INTEGER,
	floor INTEGER,
	booker_eid INT NOT NULL,
	approver_eid INTEGER,
	UNIQUE (booker_eid, time, date),
    PRIMARY KEY(time, date, room, floor),    
    FOREIGN KEY (room, floor) REFERENCES MeetingRooms(room, floor) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (booker_eid) REFERENCES Booker(eid) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (approver_eid) REFERENCES Manager(eid)
);

CREATE TABLE Updates(
    manager_eid INTEGER,
    room INTEGER,
    floor INTEGER,
	date DATE,
    new_cap INTEGER,
    PRIMARY KEY (manager_eid, date, room, floor),
    FOREIGN KEY (manager_eid) REFERENCES Manager(eid),
    FOREIGN KEY (room, floor) REFERENCES MeetingRooms(room, floor)
);

CREATE TABLE Joins (
    eid INTEGER,
    time TIME,
    date DATE,
    room INTEGER,
    floor INTEGER,
    UNIQUE (eid, time, date),
    PRIMARY KEY (eid, time, date, room, floor),
    FOREIGN KEY (eid) REFERENCES Employees(eid),
    FOREIGN KEY (time, date, room, floor) REFERENCES Sessions (time, date, room, floor) ON DELETE CASCADE ON UPDATE CASCADE
);


DROP FUNCTION IF EXISTS add_department, add_employee, add_room, approve_meeting, book_room, change_capacity, contact_tracing, declare_health, future_meetings, join_meeting,
leave_meeting, non_compliance, remove_department, remove_employee, search_room, unbook_room, view_booking_report, view_future_meeting, view_manager_report, add_booker_to_joins,
after_health_dec, after_update_cc, after_updating_cap, can_approve_session, can_book_room, can_join_meeting, can_leave_meeting, can_unbook_room, check_bookers_exclusivity,
check_department_empty, check_employees_exclusivity, check_employees_kind, check_updating_capacity, handle_employees_deletion, remove_resigned_employees CASCADE;

DROP TRIGGER IF EXISTS department_deletion_check ON Departments;
DROP TRIGGER IF EXISTS employee_resign_removal ON Employees;
DROP TRIGGER IF EXISTS trigger_before_new_cap ON Updates;
DROP TRIGGER IF EXISTS trigger_after_new_cap ON Updates;
DROP TRIGGER IF EXISTS employees_manual_insert_check ON Employees;
DROP TRIGGER IF EXISTS prohibit_employees_deletion ON Employees;
DROP TRIGGER IF EXISTS junior_isa_check ON junior;
DROP TRIGGER IF EXISTS booker_isa_check ON booker;
DROP TRIGGER IF EXISTS senior_isa_check ON senior;
DROP TRIGGER IF EXISTS manager_isa_check ON manager;
DROP TRIGGER IF EXISTS check_booking_constraints ON Sessions;
DROP TRIGGER IF EXISTS trigger_after_sessions_insert ON Sessions;
DROP TRIGGER IF EXISTS check_unbooking_constraints ON Sessions;
DROP TRIGGER IF EXISTS check_join_contraints ON Joins;
DROP TRIGGER IF EXISTS check_leave_contraints ON Joins;
DROP TRIGGER IF EXISTS check_approve_contraints ON Sessions;
DROP TRIGGER IF EXISTS trigger_after_update_cc ON Employees;
DROP TRIGGER IF EXISTS trigger_health_dec ON HealthDeclaration;