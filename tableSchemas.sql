
--Create tables for category, marking, and labels.
create table tblCategory
(
	ID	int primary key,
	Name	varchar(30) NOT NULL,
	Hierarchical	char(1) DEFAULT('N') check (Hierarchical in ('Y', 'N')),
);

create table tblMarking
(
	CategoryID	int REFERENCES tblCategory(ID),
	MarkingString	varchar(30) NOT NULL,
	PRIMARY KEY(CategoryID, MarkingString)
);

create table tblMarkingHierarchy
(
	CategoryID	int,
	ParentMarkingString	varchar(30),
	ChildMarkingString	varchar(30),
	PRIMARY KEY(CategoryID, ParentMarkingString, ChildMarkingString),
	FOREIGN KEY(CategoryID, ParentMarkingString) 
		REFERENCES tblMarking(CategoryID, MarkingString),
	FOREIGN KEY(CategoryID, ChildMarkingString) 
		REFERENCES tblMarking(CategoryID, MarkingString)
);


/*
create table tblUniqueLabel
(
	ID	int PRIMARY KEY
);
*/

create table tblUniqueLabelMarking
(
	LabelID			int ,
	CategoryID		int,
	MarkingString	varchar(30),
	PRIMARY KEY(LabelID, CategoryID, MarkingString),
	FOREIGN KEY(CategoryID, MarkingString) 
		REFERENCES tblMarking(CategoryID, MarkingString)
);


--Categories
INSERT tblCategory (ID, Name, Hierarchical) VALUES
(1, 'Classification', 'Y'),
(2, 'Department', 'N');
GO

-- markings
INSERT tblMarking (CategoryID, MarkingString) VALUES 	
--Classification
(1, 'Top Secret'),
(1, 'Secret'),
(1, 'Classified'),
(1, 'Unclassified'),
--Department
(2, 'A'),
(2, 'B'),
(2, 'C'),
(2, 'D'),
(2, 'E'),
(2, 'F');

--Classification hierarchy
INSERT tblMarkingHierarchy (CategoryID, ParentMarkingString, ChildMarkingString) VALUES	
(1, 'Top Secret', 'Secret'),
(1, 'Secret', 'Classified'),
(1, 'Classified', 'Unclassified');

--tblUniqueLabel
--INSERT tblUniqueLabel(ID) VALUES	
--(0), (1), (2), (3), (4), (5), (6);


--tblUniqueLabelMarking

--label 0: Unclassified
INSERT tblUniqueLabelMarking(LabelID, CategoryID, MarkingString) VALUES	
(0, 1, 'Unclassified');


--label 1: Secret, A, C
INSERT tblUniqueLabelMarking(LabelID, CategoryID, MarkingString) VALUES	
(1, 1, 'Secret'),
(1, 2, 'A'),
(1, 2, 'C');
		
--label 2: Classified, A
INSERT tblUniqueLabelMarking(LabelID, CategoryID, MarkingString) VALUES	
(2, 1, 'Classified'),
(2, 2, 'A');

--label 3: Secret, B, C, D
INSERT tblUniqueLabelMarking(LabelID, CategoryID, MarkingString) VALUES	
(3, 1, 'Secret'),
(3, 2, 'B'),
(3, 2, 'C'),
(3, 2, 'D');

--label 4: Unclassified, C
INSERT tblUniqueLabelMarking(LabelID, CategoryID, MarkingString) VALUES	
(4, 1, 'Unclassified'),
(4, 2, 'C');

--label 5: Unclassified, C, D
INSERT tblUniqueLabelMarking(LabelID, CategoryID, MarkingString) VALUES	
(5, 1, 'Unclassified'),
(5, 2, 'C');
(5, 2, 'D');

--label 6: Classified
INSERT tblUniqueLabelMarking(LabelID, CategoryID, MarkingString) VALUES	
(6, 1, 'Classified');

GO


CREATE TABLE EMPLOYEE
(
	Fname		VARCHAR(15)	NOT NULL,
	Minit		CHAR,
	Lname		VARCHAR(15)	NOT NULL,
	Ssn			CHAR(9)		NOT NULL,
	BDATE		DATE		,
	Address		VARCHAR(30),
	Sex			CHAR,
	Salary		DECIMAL(10, 2),
	LabelID		int DEFAULT NULL, -- REFERENCES tblUniqueLabel(ID),
	PRIMARY KEY(Ssn),
)

INSERT INTO EMPLOYEE (Fname, Minit, Lname, Ssn, BDate, Address, Sex, Salary, LabelID) VALUES 
('James', 'E', 'Borg', '888665555', '1937-11-10', '450 Stone, Houston, TX', 'M', 55000, 1),
('Franklin', 'T', 'Wong', '333445555', '1955-12-08', '638 Voss, Houston, TX', 'M', 40000, 2),
('John', 'B', 'Smith', '123456789', '1965-01-09', '731 Fondren, Houston, TX', 'M', 30000, 3),
('Jennifer', 'S', 'Wallace', '987654321', '1941-06-20', '291 Berry, Bellaire, TX', 'F', 43000, 4),
('Alicia', 'J', 'Zelaya', '999887777', '1968-01-19', '3321 Castle, Spring, TX', 'F', 25000, 5),
('Ramesh', 'K', 'Narayan', '666884444', '1962-09-15', '975 Fire Oak, Humble, TX', 'M', 38000, 6),
('Joyce', 'A', 'English', '453453453', '1978-07-31', '5631 Rice, Houston, TX', 'F', 25000, 6),
('Ahmad', 'V', 'Jabbar', '987987987', '1969-03-29', '980 Dallas, Houston, TX', 'M', 25000, 6);


--create users and table for users
CREATE TABLE Clearance
(
	UserName	varchar(255) primary key,
	LabelID		int NOT NULL --REFERENCES tblUniqueLabel(ID)
)
GO

CREATE USER Alice WITHOUT LOGIN;
CREATE USER Bob WITHOUT LOGIN;

GO

INSERT INTO Clearance (UserName, LabelID) VALUES 
('Alice', 1),  --Alice dominates labels 0, 1, 2, 4, 6
('Bob', 3);	--Bob dominates labels 0, 3, 4, 5, 6
GO


/*
	clean up
	
	drop table if exists Clearance;
	drop table if exists Employee;
	
	drop table if exists tblUniqueLabelMarking;
	drop table if exists tblMarkingHierarchy;
	drop table if exists tblMarking;
	drop table if exists tblCategory;
	
	drop user Alice;
	drop user Bob;
*/





