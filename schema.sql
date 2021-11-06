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
