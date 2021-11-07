DELETE FROM Joins;
DELETE FROM Updates;
DELETE FROM Sessions;
DELETE FROM MeetingRooms;
DELETE FROM HealthDeclaration;
DELETE FROM Junior;
DELETE FROM Employees;
DELETE FROM Departments;


-- Departments
insert into Departments (did, dname) values (1, 'Sales');
insert into Departments (did, dname) values (2, 'Engineering');
insert into Departments (did, dname) values (3, 'Marketing');
insert into Departments (did, dname) values (4, 'Business Development');
insert into Departments (did, dname) values (5, 'Accounting');
insert into Departments (did, dname) values (6, 'Research and Development');
insert into Departments (did, dname) values (7, 'Legal');
insert into Departments (did, dname) values (8, 'Human Resources');
insert into Departments (did, dname) values (9, 'Outreach');
insert into Departments (did, dname) values (10, 'Investor Relations');