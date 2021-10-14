DROP TABLE IF EXISTS Employees, Junior, Booker, Senior, Manager, Contacts, HealthDeclaration, Departments, MeetingRooms, Sessions, Updates, Joins CASCADE;


CREATE TABLE Departments (
	did INT PRIMARY KEY,
	dname VARCHAR(50)
);

-- dept_id is included in employees and set to NOT NULL to enforce total part constraints. If a separate not joins table is use, there 
-- is a possibility og of works in being empty while employees and depts have values. 
-- Q: How should the on delete for did be set? 
CREATE TABLE Employees (
	eid INT PRIMARY KEY,
	did INT NOT NULL,
	ename VARCHAR(50),
	email VARCHAR(50) UNIQUE,
	contact INT,
	resigned_date DATE,
	FOREIGN KEY (did) REFERENCES Departments(did)
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

CREATE TABLE Contacts (
	eid INT PRIMARY KEY,
	mobile_number INT,
	home_number INT,
	office_number INT,
	FOREIGN KEY (eid) REFERENCES Employees(eid) ON DELETE CASCADE ON UPDATE CASCADE
);

-- Health decln is a weak entity set where the date is the paritial key. Many to one relationship where
-- health_declaration has total participation. If store is not used, fever is only calculated during a read
CREATE TABLE HealthDeclaration (
	date DATE NOT NULL,
	eid INT NOT NULL,
	temp NUMERIC NOT NULL,
    fever BOOLEAN GENERATED ALWAYS AS (temp > 37.5) STORED,
	PRIMARY KEY (eid, date),
	FOREIGN KEY (eid) REFERENCES Employees(eid),
	CONSTRAINT temp_range_check CHECK ((temp >= 34 AND temp<=43))
);



-- Combined with did to replace located in and enforce total part
-- Q: How should the on delete be handled?
CREATE TABLE MeetingRooms (
	room INT,
	floor INT,
	rname VARCHAR(50),
	did INT NOT NULL,
	PRIMARY KEY (room, floor),
	FOREIGN KEY (did) REFERENCES Departments(did)
);

-- Combined with booker id to replace books and enforce total part
-- Combined with approver_id (id of manager)
-- Q: How should the on delete be handled?
CREATE TABLE Sessions (
	time TIME,
	date DATE,
	room INT,
	floor INT,
	booker_id INT NOT NULL,
	approver_id INT,
	PRIMARY KEY(time, date, room, floor),
	FOREIGN KEY (room, floor) REFERENCES MeetingRooms(room, floor) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (booker_id) REFERENCES Booker(eid) ON DELETE CASCADE ON UPDATE CASCADE,
	FOREIGN KEY (approver_id) REFERENCES Manager(eid)
	
);

-- Q: How to enforce total participation of meeting rooms?
CREATE TABLE Updates (
    eid INT,
    room INT,
    floor INT,
	date DATE,
    new_cap INT,
    PRIMARY KEY (eid, date, room, floor),
    FOREIGN KEY (eid) REFERENCES Manager(eid),
    FOREIGN KEY (room, floor) REFERENCES MeetingRooms(room, floor)
);

-- Q: How to enforce total participation of sessions?
CREATE TABLE Joins (
    eid INT,
    time TIME,
    date DATE,
    room INT,
    floor INT,
    PRIMARY KEY (eid, time, date, room, floor),
    FOREIGN KEY (eid) REFERENCES Employees(eid),
    FOREIGN KEY (time, date, room, floor) REFERENCES Sessions (time, date, room, floor)
);
