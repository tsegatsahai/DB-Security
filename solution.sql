--Create a view that contains the hierarchy relationships between the classifications 
CREATE VIEW classification
with schemabinding
AS
	--Using CTE (for recursion) to figure out the parent-child relationships
	WITH MarkingHierarchy
		AS(
		SELECT ParentMarkingString, ChildMarkingString
		FROM dbo.tblMarkingHierarchy
		
		UNION ALL

		SELECT M.ParentMarkingString, P.ChildMarkingString
		FROM dbo.tblMarkingHierarchy P
		INNER JOIN MarkingHierarchy M 
		ON P.ParentMarkingString = M.ChildMarkingString )

		--'secret' still dominates 'secret' so I'm adding that as a parent-child relationship in the view
		SELECT ParentMarkingString, ChildMarkingString FROM MarkingHierarchy 
		UNION
		SELECT ParentMarkingString, ParentMarkingString FROM dbo.tblMarkingHierarchy
		UNION
		SELECT ChildMarkingString, ChildMarkingString FROM dbo.tblMarkingHierarchy
GO

--create filter predicate for select 
CREATE OR ALTER FUNCTION dbo.emp_filter_pred(@lid int)
RETURNS TABLE
WITH SCHEMABINDING
AS
	RETURN
		SELECT 1 AS filter_result
			--The user can SELECT the rows where thier labelID dominates that of the rows'
			WHERE @lid IN (SELECT LabelID FROM dbo.tblUniqueLabelMarking WHERE MarkingString IN (
									--SELECT all the markings(children) dominated by the current marking (parent)
									SELECT ChildMarkingString FROM dbo.classification 
										WHERE ParentMarkingString =((SELECT MarkingString FROM dbo.tblUniqueLabelMarking
												--labelID of the current USER
												WHERE LabelID = (SELECT LabelID FROM dbo.Clearance
														WHERE UserName = USER_NAME()) AND CategoryID = 1))))
			AND
		--Use EXCEPT to determine if the compartments associated with the current user dominate the compartments associated with the row
		NULL=ALL(SELECT MarkingString FROM dbo.tblUniqueLabelMarking
					WHERE LabelID = @lid AND CategoryID = 2
						EXCEPT
				 SELECT MarkingString FROM dbo.tblUniqueLabelMarking
					WHERE LabelID = (SELECT LabelID FROM dbo.Clearance WHERE UserName = USER_NAME()) AND CategoryID = 2)
	
GO


--create block predicate for delete 
CREATE OR ALTER FUNCTION dbo.emp_block_pred(@lid int)
RETURNS TABLE
WITH SCHEMABINDING
AS
	RETURN 
		SELECT 1 AS block_result
			--The user can DELETE the rows where thier labelID dominates that of the rows'
			WHERE @lid IN (SELECT LabelID FROM dbo.tblUniqueLabelMarking WHERE MarkingString IN (
									--SELECT all the markings(children) dominated by the current marking (parent)
									SELECT ChildMarkingString FROM dbo.classification 
										WHERE ParentMarkingString =((SELECT MarkingString FROM dbo.tblUniqueLabelMarking 
											--labelID of the current USER
											WHERE LabelID = (SELECT LabelID FROM dbo.Clearance
												WHERE UserName = USER_NAME()) AND CategoryID = 1))))
			AND
		--Use EXCEPT to determine if the compartments associated with the current user dominate the compartments associated with the row
		NULL=ALL(SELECT MarkingString FROM dbo.tblUniqueLabelMarking 
					WHERE LabelID = @lid AND CategoryID = 2
						EXCEPT
				 SELECT MarkingString FROM dbo.tblUniqueLabelMarking	
					WHERE LabelID = (SELECT LabelID FROM dbo.Clearance WHERE UserName = USER_NAME()) AND CategoryID = 2)

GO

--block predicate for the update
CREATE OR ALTER FUNCTION dbo.emp_update_block_pred(@lid int)
RETURNS TABLE
WITH SCHEMABINDING
AS 
	RETURN 
		SELECT 1 AS blocl_result
			--Use EXCEPT to determine if the compartments associated with the current user 
			--dominate the compartments associated with the row
			--Not checking for classification dominance (hierarchy)
			WHERE NULL = ALL (SELECT MarkingString FROM dbo.tblUniqueLabelMarking 
							  WHERE LabelID = @lid 
									EXCEPT
							  SELECT MarkingString FROM dbo.tblUniqueLabelMarking
							  WHERE LabelID = (SELECT LabelID FROM dbo.Clearance WHERE UserName = USER_NAME()))

GO

--Creating the security policy and adding the created predicates
CREATE security policy dbo.sec_policy
ADD FILTER PREDICATE dbo.emp_filter_pred(LabelID) on dbo.Employee,
ADD BLOCK PREDICATE dbo.emp_block_pred(LabelID) on dbo.Employee BEFORE DELETE,
ADD BLOCK PREDICATE dbo.emp_update_block_pred(LabelID) on dbo.Employee BEFORE UPDATE;


--Instead-of Insert trigger so the label of the current user will be assigned to the label of the newly created row
GO
CREATE OR ALTER TRIGGER emp_insert_trigger
ON dbo.Employee
INSTEAD OF INSERT
AS
	INSERT INTO dbo.EMPLOYEE
		SELECT Fname, Minit, Lname, Ssn, BDate, Address, Sex, Salary, Labid = (SELECT LabelID FROM dbo.Clearance WHERE UserName = USER_NAME())
		FROM inserted
GO



--Create DDL trigger for CREATING USER
CREATE OR ALTER TRIGGER user_trigger
ON DATABASE
FOR CREATE_USER
AS 
	DECLARE @name varchar(255)
	--Accessing the object name (userName) from eventdata() and entering it into the Clearance table 
	INSERT dbo.Clearance(UserName, LabelID) VALUES (EVENTDATA().value('(/EVENT_INSTANCE/ObjectName)[1]', 'varchar(255)'), 0);

GO

--Function that will return the differences in markings between two labels 
--Returns a table with one column (count) which will hold 0 (that means there is no difference between the two labels)
--or it will hold any other value greater than 0 (that means there is a difference between the two labels)
--will be used in a trigger to make sure there will be no identical labels 
CREATE OR ALTER FUNCTION isDifferent
(@label1 int,
 @label2 int)
RETURNS TABLE
WITH SCHEMABINDING
AS
	RETURN(SELECT COUNT(*) as diff_count
	FROM(
		(
		SELECT MarkingString FROM dbo.tblUniqueLabelMarking WHERE LabelID = @label1 
		EXCEPT
		SELECT MarkingString FROM dbo.tblUniqueLabelMarking WHERE LabelID = @label2
		) UNION
		(SELECT MarkingString FROM dbo.tblUniqueLabelMarking WHERE LabelID = @label2 
		EXCEPT
		SELECT MarkingString FROM dbo.tblUniqueLabelMarking WHERE LabelID = @label1 )
		)AS diff
		)

GO

--After-trigger for INSERT and UPDATE to make sure there are no idential markings
CREATE OR ALTER TRIGGER after_trigger
ON dbo.tblUniqueLabelMarking 
AFTER INSERT, UPDATE
AS 
	DECLARE @start int;
	DECLARE @end int;
	DECLARE @insertedLabel int;
	DECLARE @diff int;
	SELECT @start = min(LabelID) FROM dbo.tblUniqueLabelMarking
	SELECT @end = max(LabelID) FROM dbo.tblUniqueLabelMarking
	SELECT @insertedLabel = LabelID FROM inserted
	--Use a while-loop to find a markings identical to the markings associated with the new inserted label
	WHILE (@start <= @end)
	BEGIN
		IF (@start <> @insertedLabel)
		BEGIN
			SELECT @diff = diff_count FROM isDifferent (@start, @insertedLabel)
			--if the labels' markings are the same, rollback the INSERT and break out of the while-loop
			IF @diff = 0
				BEGIN
					ROLLBACK
					BREAK
				END
		END
		SET @start = @start + 1
	END

GO

--After-trigger for DELETE to make sure there will be no two labels with identical markings
--Similar to the trigger above
CREATE OR ALTER TRIGGER after_trigger_delete
ON dbo.tblUniqueLabelMarking 
AFTER DELETE
AS 
	DECLARE @start int;
	DECLARE @end int;
	DECLARE @deletedLabel int;
	DECLARE @diff int;
	SELECT @start = min(LabelID) FROM dbo.tblUniqueLabelMarking
	SELECT @end = max(LabelID) FROM dbo.tblUniqueLabelMarking
	SELECT @deletedLabel = LabelID FROM deleted
	--Use a while-loop to find a markings identical to the markings associated with the new deleted label
	WHILE (@start <= @end)
	BEGIN
		IF (@start <> @deletedLabel)
		BEGIN
			SELECT @diff = diff_count FROM isDifferent (@start, @deletedLabel)
			--if the labels' markings are the same, rollback the DELETE and break out of the while-loop
			IF @diff = 0
				BEGIN
					ROLLBACK
					BREAK
				END
		END
		SET @start = @start + 1
	END




