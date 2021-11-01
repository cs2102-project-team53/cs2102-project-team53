-- VANSHIQA --
CREATE TABLE HealthDeclaration(
    date date,
    temp integer not null,
    fever boolean, --derived
    eid int references Employees(eid) on delete cascade
    PRIMARY KEY (eid, date)
--     constraint 34 <= temp <= 43
);
-- declare_health()
-- contact_tracing()
-- non_compliance()

-- KEVIN --
create table Employees(
    eid integer primary key ,
    ename varchar(255) not null ,
    email varchar(255) unique not null ,
    homePhone integer,
    mobilePhone integer,
    officePhone integer,
    resignedDate date,
    isCloseContact boolean,
    closeContactDate date,
    did integer references Department(did) not null
    -- trigger
    -- DELETE  --> BEFORE --> RAISE EXCEPTION("not allowed to dept cause has employees")
); /* put deptId here */
--add_employee()
--remove_employee()
--view_manager_report()


-- MATHEW --
create table Joins(
    eid int references Employees,
    time time,
    date Date,
    room int,
    floor int,
    foreign key (room, floor, date, time)  references Sessions on delete cascade on update cascade,
    primary key (room, floor,date,time, eid)
--     check eid.resigned == null,
--     constraint cannotJoin(eid, date) !=1
);
-- join_meeting()
-- leave_meeting()
-- view_future_meeting()

-- MATHEW --
create table Department(
    did integer primary key ,
    dname varchar(255)
);
-- add_department()
-- remove_department()


-- TRIGGER functions
create table Junior(
    eid integer PRIMARY KEY references Employees(eid) on delete cascade on update cascade
);

create table Booker(
     eid integer PRIMARY KEY references Employees(eid) on delete CASCADE on update cascade
);
create table Senior(
    eid integer PRIMARY KEY references Booker(eid) on delete CASCADE on update cascade
);
create table Manager(
    eid integer PRIMARY KEY references Booker(eid) on delete CASCADE on update cascade
);

-- KHIAXENG --
create table Sessions(
    booker_eid int references Booker(eid),
    time varchar(255),
    date Date not null,
    room int ,
    floor int ,
    approver_eid int references Manager(eid),
    primary key (time, date, room, floor),
    foreign key (room, floor)  references MeetingRooms(room, floor) on delete cascade on update cascade
--     constraint hasFever(booked_eid) != 1,
--      constraint (approver.did == did of meeting room and approver.resigned == null),
--      constraint isFutureDate,
--      constraint eid.resigned == null,
--      constraint cannotJoin(eid, date) != 1
);
--book_room()
--unbook_room()
--approve_meeting()
--view_booking_report()


-- MATHEW --
create table MeetingRooms(
    room int,
    floor int ,
    rname varchar(50),
    primary key (room, floor),
    did int references Department(did)
    -- add trigger to insert into Updates
);
--add_room()
--search_room()

-- VANSHIQA --
create table Updates(
    manager_eid int references Manager(eid),
    date Date,
    capacity int not null,
    room int,
    floor int,
    foreign key (room, floor) references MeetingRooms,
    primary key (date, room, floor)
                    -- How to ensure total participation of meeting room?
--     constraint isSameDept(eid, room,floor) == 1;
);
--change_capacity()


-- 3. [[Session]] uses {endTime} as key.  Just note that a [[Session]] may be approved partially
-- (e.g., booked from 10 to 12, but only approved from 10 to 11).
-- It can be done this way, but be prepared to split the {startTime} and {endTime} into multiple entries to accommodate this.


-- 3. The same [MeetingRoom] can be [<Books>] by different people at the same {startTime} + {endTime}, which should not happen.



-- create FUNCTION hasFever (empId int) RETURNS int AS $$
--     SELECT 1 FROM HealthDeclaration h WHERE h.eid == empId AND  h.fever ;
--     $$ language sql;
--
-- create FUNCTION isSameDept(manId int, inRoom int, inFloor int) RETURNS int AS $$
--     SELECT 1 FROM MeetingRooms m, Employees e WHERE m.did == e.did AND m.room==inRoom AND m.floor == inFloor;
-- $$ language sql;
--
--
-- create FUNCTION isFutureDate(inDate Date) RETURNS boolean as $$
--         Date(inDate) > Date(NOW());
--     $$ language sql;
--
--
-- create FUNCTION cannotJoin(empId int, meetingDate date) RETURNS int AS $$
--     SELECT 1 FROM Employees e WHERE e.eid == empId AND e.isCloseContact AND e.closeContactDate + 7 <= meetingDate;
-- $$ language sql;
-- end;