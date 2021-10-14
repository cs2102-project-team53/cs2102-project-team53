DROP TABLE IF EXISTS employees, meeting_rooms, departments, junior, booker, senior, manager, sessions, joins, updates, health_declaration;

CREATE TABLE departments
(
	did				INTEGER,
	dname			VARCHAR(255),
	PRIMARY KEY (did)
);

CREATE TABLE employees 
(
	eid				INTEGER,
	ename			TEXT,
	email			TEXT,
	resigned_date	DATE,
	contact_home	NUMERIC,
	contact_mobile	NUMERIC,
	contact_office	NUMERIC,
	did				INTEGER,
	PRIMARY KEY (eid),
 	FOREIGN KEY (did) REFERENCES departments(did) -- PK constraint will enforce "exactly one"
);

CREATE TABLE meeting_rooms
(
	floor			INTEGER,
	room			INTEGER,
	rname			TEXT,
	did				INTEGER,
	PRIMARY KEY (floor, room),
	FOREIGN KEY (did) REFERENCES departments(did) -- PK constraint will enforce "exactly one"
);

CREATE TABLE junior (
	eid     		INTEGER, 
	PRIMARY KEY (eid),
	FOREIGN KEY (eid) REFERENCES employees(eid) ON DELETE CASCADE
);

CREATE TABLE booker (
	eid     		INTEGER, 
	PRIMARY KEY (eid),
	FOREIGN KEY (eid) REFERENCES employees(eid) ON DELETE CASCADE
);

CREATE TABLE senior (
	eid     		INTEGER, 
	PRIMARY KEY (eid),
	FOREIGN KEY (eid) REFERENCES booker(eid) ON DELETE CASCADE
);

CREATE TABLE manager (
	eid     		INTEGER, 
	PRIMARY KEY (eid),
	FOREIGN KEY (eid) REFERENCES booker(eid) ON DELETE CASCADE
);

CREATE TABLE sessions (
	room			INTEGER,
	floor			INTEGER,
	time			TIME,
	date			DATE,
	booker_eid		INTEGER,
	manager_eid		INTEGER,
	PRIMARY KEY (room, floor, time, date),
	FOREIGN KEY (floor, room) REFERENCES meeting_rooms(floor, room) ON DELETE CASCADE,
	FOREIGN KEY (booker_eid) REFERENCES booker(eid),
	FOREIGN KEY (manager_eid) REFERENCES manager(eid)
);

CREATE TABLE joins (
	eid 			INTEGER,
	room			INTEGER,
	floor			INTEGER,
	time			TIME,
	date			DATE,
	PRIMARY KEY (eid, room, floor, time, date),
	FOREIGN KEY (room, floor, time, date) REFERENCES sessions(room, floor, time, date) ON DELETE CASCADE
);

CREATE TABLE updates (
	date			DATE,
	manager_eid		INTEGER,
	room			INTEGER,
	floor			INTEGER,
	new_cap			INTEGER,
	PRIMARY KEY (date, manager_eid, room, floor),
	FOREIGN KEY (manager_eid) REFERENCES manager(eid),
	FOREIGN KEY (room, floor) REFERENCES meeting_rooms(floor, room)
);

CREATE TABLE health_declaration (
	date			DATE,
	eid 			INTEGER,
	temp			NUMERIC,
	PRIMARY KEY (date, eid),
	FOREIGN KEY (eid) REFERENCES employees(eid)	
);