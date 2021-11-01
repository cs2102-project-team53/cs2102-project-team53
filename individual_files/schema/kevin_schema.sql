CREATE TABLE Employees (
    eid             INTEGER PRIMARY KEY,
    ename           VARCHAR(50),
    email           VARCHAR(50) UNIQUE,
    home_phone      NUMERIC,
    mobile_phone    NUMERIC,
    office_phone    NUMERIC,
    resigned_date   DATE,
    did             INTEGER NOT NULL,
    FOREIGN KEY (did) REFERENCES Departments(did)
);

CREATE TABLE Departments (
    did     INTEGER PRIMARY KEY,
    dname   VARCHAR(50)
);

CREATE TABLE MeetingRooms (
    floor   INTEGER,
    room    INTEGER,
    rname   VARCHAR(50),
    did     INTEGER NOT NULL,
    PRIMARY KEY (floor, room),
    FOREIGN KEY (did) REFERENCES Departments(did)
);

CREATE TABLE Junior (
    eid     INTEGER PRIMARY KEY,
    FOREIGN KEY (eid) REFERENCES Employees(eid) ON DELETE CASCADE
);

CREATE TABLE Booker (
    eid     INTEGER PRIMARY KEY,
    FOREIGN KEY (eid) REFERENCES Employees(eid) ON DELETE CASCADE
);

CREATE TABLE Senior (
    eid     INTEGER PRIMARY KEY,
    FOREIGN KEY (eid) REFERENCES Booker(eid) ON DELETE CASCADE
);

CREATE TABLE Manager (
    eid     INTEGER PRIMARY KEY,
    FOREIGN KEY (eid) REFERENCES Booker(eid) ON DELETE CASCADE
);

CREATE TABLE Updates (
    floor   INTEGER,
    room    INTEGER,
    eid     INTEGER,
    date    DATE,
    new_cap INTEGER,
    PRIMARY KEY (floor, room, eid, date),
    FOREIGN KEY (floor, room) REFERENCES MeetingRooms(floor, room) ON DELETE CASCADE,
    FOREIGN KEY (eid) REFERENCES Manager(eid)
);

CREATE TABLE MeetingSessions (
    floor           INTEGER,
    room            INTEGER,
    booker_eid      INTEGER NOT NULL, 
    manager_eid     INTEGER,
    session_time    TIME,            
    session_date    DATE,
    PRIMARY KEY (floor, room, session_time, session_date),
    FOREIGN KEY (floor, room) REFERENCES MeetingRooms(floor, room) ON DELETE CASCADE,
    FOREIGN KEY (booker_eid) REFERENCES Booker(eid),
    FOREIGN KEY (manager_eid) REFERENCES Manager(eid)
);

CREATE TABLE Joins (
    eid             INTEGER,
    floor           INTEGER,
    room            INTEGER,
    session_time    TIME,            
    session_date    DATE,
    PRIMARY KEY (eid, floor, room, session_time, session_date),
    FOREIGN KEY (floor, room, session_time, session_date) REFERENCES MeetingSessions(floor, room, session_time, session_date) ON DELETE CASCADE,
    FOREIGN KEY (eid) REFERENCES Employees(eid)
);

CREATE TABLE HealthDeclaration (
    eid                 INTEGER,
    declaration_date    DATE,
    temp                NUMERIC,
    PRIMARY KEY (eid, declaration_date),
    FOREIGN KEY (eid) REFERENCES Employees(eid)
);