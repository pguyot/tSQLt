:SETVAR tSQLtFacade tSQLtFacade
GO
EXEC tSQLt.NewTestClass 'Facade_CreateFacadeDb_Tests';
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSSPFacade calls Private_GenerateCreateProcedureSpyStatement]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'tSQLt.Private_GenerateCreateProcedureSpyStatement';

  EXEC('CREATE PROC dbo.AProc AS RETURN;'); 
  DECLARE @ProcedureObjectId INT = OBJECT_ID('dbo.AProc');
  
  EXEC Facade.CreateSSPFacade @FacadeDbName = '$(tSQLtFacade)', @ProcedureObjectId = @ProcedureObjectId;

  SELECT 
      ProcedureObjectId,
      OriginalProcedureName
    INTO #Actual FROM tSQLt.Private_GenerateCreateProcedureSpyStatement_SpyProcedureLog;

  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  
  INSERT INTO #Expected
  VALUES(@ProcedureObjectId,'[dbo].[AProc]');

  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSSPFacade passes NULL in @LogTableName & @CommandToExecute for Private_GenerateCreateProcedureSpyStatement]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'tSQLt.Private_GenerateCreateProcedureSpyStatement';

  EXEC('CREATE PROC dbo.AProc AS RETURN;'); 
  DECLARE @ProcedureObjectId INT = OBJECT_ID('dbo.AProc');
  
  EXEC Facade.CreateSSPFacade @FacadeDbName = '$(tSQLtFacade)', @ProcedureObjectId = @ProcedureObjectId;

  SELECT 
      LogTableName,
      CommandToExecute
    INTO #Actual FROM tSQLt.Private_GenerateCreateProcedureSpyStatement_SpyProcedureLog;

  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  
  INSERT INTO #Expected
  VALUES(NULL,NULL);

  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSSPFacade executes @CreateProcedureStatement from Private_GenerateCreateProcedureSpyStatement in $(tSQLtFacade)]
AS
BEGIN
  EXEC tSQLt.SpyProcedure 
         @ProcedureName = 'tSQLt.Private_GenerateCreateProcedureSpyStatement', 
         @CommandToExecute='SET @CreateProcedureStatement = ''CREATE PROCEDURE dbo.AProc AS RETURN;'';';

  EXEC Facade.CreateSSPFacade @FacadeDbName = '$(tSQLtFacade)', @ProcedureObjectId = NULL;

  DECLARE @Actual NVARCHAR(MAX);
  SELECT @Actual = definition FROM $(tSQLtFacade).sys.sql_modules WHERE object_id = OBJECT_ID('$(tSQLtFacade).dbo.AProc');
  
  EXEC tSQLt.AssertEqualsString @Expected = 'CREATE PROCEDURE dbo.AProc AS RETURN;', @Actual = @Actual;
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSSPFacade works for other schema that does exist in the facade db]
AS
BEGIN
  EXEC('CREATE SCHEMA SomeOtherSchemaForFacadeTests;');
  EXEC $(tSQLtFacade).sys.sp_executesql N'EXEC(''CREATE SCHEMA SomeOtherSchemaForFacadeTests;'');',N'';

  EXEC('CREATE PROC SomeOtherSchemaForFacadeTests.AnotherProc AS RETURN 42;'); 
  DECLARE @ProcedureObjectId INT = OBJECT_ID('SomeOtherSchemaForFacadeTests.AnotherProc');
  
  EXEC Facade.CreateSSPFacade @FacadeDbName = '$(tSQLtFacade)', @ProcedureObjectId = @ProcedureObjectId;

  EXEC tSQLt.AssertObjectExists @ObjectName = '$(tSQLtFacade).SomeOtherSchemaForFacadeTests.AnotherProc';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSSPFacade works for other schema that does NOT exist in the facade db]
AS
BEGIN
  DECLARE @SchemaName NVARCHAR(MAX) = 'SomeRandomSchema'+CONVERT(NVARCHAR(MAX),CAST(NEWID() AS VARBINARY(MAX)),2);
  DECLARE @cmd NVARCHAR(MAX);

  SET @cmd = 'CREATE SCHEMA '+@SchemaName+';';
  EXEC(@cmd);

  SET @cmd = 'CREATE PROC '+@SchemaName+'.AnotherProc AS RETURN 42;'; 
  EXEC(@cmd);
  

  DECLARE @ProcedureObjectId INT = OBJECT_ID(@SchemaName+'.AnotherProc');
  EXEC Facade.CreateSSPFacade @FacadeDbName = '$(tSQLtFacade)', @ProcedureObjectId = @ProcedureObjectId;


  DECLARE @RemoteProcedureName NVARCHAR(MAX) = '$(tSQLtFacade).'+@SchemaName+'.AnotherProc'; 
  EXEC tSQLt.AssertObjectExists @ObjectName = @RemoteProcedureName;
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test Facade.sys.procedures exists]
AS
BEGIN
  SELECT * INTO #Actual FROM Facade.[sys.procedures];
  SELECT * INTO #Expected FROM sys.procedures;

  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSSPFacades doesn't call CreateSSPFacade if there's no SSP]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateSSPFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.procedures]';

  EXEC Facade.CreateSSPFacades @FacadeDbName = '$(tSQLtFacade)';

  EXEC tSQLt.AssertEmptyTable @TableName = 'Facade.[CreateSSPFacade_SpyProcedureLog]';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSSPFacades calls CreateSSPFacade for single SSP]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateSSPFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.procedures]';
  EXEC('INSERT INTO Facade.[sys.procedures](object_id,schema_id,name)VALUES (1001,SCHEMA_ID(''tSQLt''),''AProc'');');

  EXEC Facade.CreateSSPFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT ProcedureObjectId INTO #Actual FROM Facade.[CreateSSPFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES(1001);
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO

CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSSPFacades calls CreateSSPFacade for multiple SSPs]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateSSPFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.procedures]';
  EXEC('INSERT INTO Facade.[sys.procedures](object_id,schema_id,name)VALUES (1001,SCHEMA_ID(''tSQLt''),''AProc1'');');
  EXEC('INSERT INTO Facade.[sys.procedures](object_id,schema_id,name)VALUES (1002,SCHEMA_ID(''tSQLt''),''AProc2'');');
  EXEC('INSERT INTO Facade.[sys.procedures](object_id,schema_id,name)VALUES (1003,SCHEMA_ID(''tSQLt''),''AProc3'');');

  EXEC Facade.CreateSSPFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT ProcedureObjectId INTO #Actual FROM Facade.[CreateSSPFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES(1001),(1002),(1003);
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO

CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSSPFacades calls CreateSSPFacade for schema tSQLt only]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateSSPFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.procedures]';
  EXEC('INSERT INTO Facade.[sys.procedures](object_id,schema_id,name)VALUES (1001,SCHEMA_ID(''tSQLt''),''AProc1'');');
  EXEC('INSERT INTO Facade.[sys.procedures](object_id,schema_id,name)VALUES (1002,SCHEMA_ID(''dbo''),''AProc2'');');
  EXEC('INSERT INTO Facade.[sys.procedures](object_id,schema_id,name)VALUES (1003,SCHEMA_ID(''tSQLt''),''AProc3'');');

  EXEC Facade.CreateSSPFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT ProcedureObjectId INTO #Actual FROM Facade.[CreateSSPFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES(1001),(1003);
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO

CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSSPFacades ignores Private SSPs]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateSSPFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.procedures]';
  EXEC('INSERT INTO Facade.[sys.procedures](object_id,schema_id,name)VALUES (1001,SCHEMA_ID(''tSQLt''),''AProc1'');');
  EXEC('INSERT INTO Facade.[sys.procedures](object_id,schema_id,name)VALUES (1002,SCHEMA_ID(''tSQLt''),''Private_AProc2'');');
  EXEC('INSERT INTO Facade.[sys.procedures](object_id,schema_id,name)VALUES (1003,SCHEMA_ID(''tSQLt''),''PrivateProc3'');');
  EXEC('INSERT INTO Facade.[sys.procedures](object_id,schema_id,name)VALUES (1004,SCHEMA_ID(''tSQLt''),''PrIVateProc3'');');
  EXEC('INSERT INTO Facade.[sys.procedures](object_id,schema_id,name)VALUES (1005,SCHEMA_ID(''tSQLt''),''PRIVATEProc3'');');

  EXEC Facade.CreateSSPFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT ProcedureObjectId INTO #Actual FROM Facade.[CreateSSPFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES(1001);
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO

CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTBLorVWFacade copies a simple table to the $(tSQLtFacade) database]
AS
BEGIN
  CREATE TABLE dbo.SomeRandomTable(a INT);

  DECLARE @TableObjectId INT = OBJECT_ID('dbo.SomeRandomTable');
  
  EXEC Facade.CreateTBLorVWFacade @FacadeDbName = '$(tSQLtFacade)', @TableObjectId = @TableObjectId;

  EXEC tSQLt.AssertObjectExists @ObjectName = '$(tSQLtFacade).dbo.SomeRandomTable';
END;
GO

CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTBLorVWFacade copies another table to the $(tSQLtFacade) database]
AS
BEGIN
  CREATE TABLE dbo.SomeOtherTable(a INT);

  DECLARE @TableObjectId INT = OBJECT_ID('dbo.SomeOtherTable');
  
  EXEC Facade.CreateTBLorVWFacade @FacadeDbName = '$(tSQLtFacade)', @TableObjectId = @TableObjectId;

  EXEC tSQLt.AssertObjectExists @ObjectName = '$(tSQLtFacade).dbo.SomeOtherTable';
END;
GO

CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTBLorVWFacade copies table into a schema that does not exist in the $(tSQLtFacade) database]
AS
BEGIN
  DECLARE @SchemaName NVARCHAR(MAX) = 'SomeRandomSchema'+CONVERT(NVARCHAR(MAX),CAST(NEWID() AS VARBINARY(MAX)),2);
  DECLARE @cmd NVARCHAR(MAX);

  SET @cmd = 'CREATE SCHEMA '+@SchemaName+';';
  EXEC(@cmd);

  SET @cmd = 'CREATE TABLE '+@SchemaName+'.SomeTable(a INT);';
  EXEC(@cmd);

  DECLARE @TableObjectId INT = OBJECT_ID(@SchemaName+'.SomeTable');
  
  EXEC Facade.CreateTBLorVWFacade @FacadeDbName = '$(tSQLtFacade)', @TableObjectId = @TableObjectId;

  DECLARE @RemoteObjectName NVARCHAR(MAX) = '$(tSQLtFacade).'+@SchemaName+'.SomeTable'; 
  EXEC tSQLt.AssertObjectExists @ObjectName = @RemoteObjectName;
END;
GO


CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTBLorVWFacade copies all columns with their data types]
AS
BEGIN
  CREATE TABLE dbo.SomeOtherTable(a INT IDENTITY(1,1), bb CHAR(1) NULL, ccc DATETIME NOT NULL, dddd NVARCHAR(MAX));

  DECLARE @TableObjectId INT = OBJECT_ID('dbo.SomeOtherTable');
  
  EXEC Facade.CreateTBLorVWFacade @FacadeDbName = '$(tSQLtFacade)', @TableObjectId = @TableObjectId;

  SELECT 
      C.name,
      C.column_id,
      C.system_type_id,
      C.user_type_id,
      C.max_length,
      C.precision,
      C.scale,
      C.is_nullable,
      C.is_identity
    INTO #Actual FROM $(tSQLtFacade).sys.columns AS C WHERE C.object_id = OBJECT_ID('$(tSQLtFacade).dbo.SomeOtherTable');

  SELECT 
      C.name,
      C.column_id,
      C.system_type_id,
      C.user_type_id,
      C.max_length,
      C.precision,
      C.scale,
      C.is_nullable,
      C.is_identity
    INTO #Expected FROM sys.columns AS C WHERE C.object_id = @TableObjectId;

  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
  
END;
GO

CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTBLorVWFacade creates a facade table for a view in the $(tSQLtFacade) database]
AS
BEGIN
  EXEC ('CREATE VIEW dbo.SomeRandomView AS SELECT CAST(1 AS INT) columnNameA;');

  DECLARE @TableObjectId INT = OBJECT_ID('dbo.SomeRandomView');
  
  EXEC Facade.CreateTBLorVWFacade @FacadeDbName = '$(tSQLtFacade)', @TableObjectId = @TableObjectId;
  
  SELECT 'Is a table.' AS resultColumn INTO #Actual
  FROM $(tSQLtFacade).sys.tables T 
	JOIN $(tSQLtFacade).sys.schemas S ON (T.schema_id = S.schema_id)
  WHERE T.name = 'SomeRandomView' AND S.name = 'dbo';

  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;

  INSERT INTO #Expected VALUES ('Is a table.');

  EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';  
END;
GO

CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSFNFacade executes the statement returned from tSQLt.Private_CreateFakeFunctionStatement in the $(tSQLtFacade) database]
AS
BEGIN
  EXEC tSQLt.FakeFunction @FunctionName = N'tSQLt.Private_CreateFakeFunctionStatement',
                          @FakeDataSource = N'SELECT ''CREATE FUNCTION dbo.aRandomFunction () RETURNS INT AS BEGIN RETURN 1; END;'' CreateStatement';

  EXEC Facade.CreateSFNFacade @FacadeDbName = '$(tSQLtFacade)', @FunctionObjectId = NULL;

  SELECT 'Is a function.' AS resultColumn INTO #Actual
    FROM $(tSQLtFacade).sys.objects O 
	JOIN $(tSQLtFacade).sys.schemas S ON (O.schema_id = S.schema_id)
   WHERE O.name = 'aRandomFunction' 
	 AND S.name = 'dbo'
	 AND O.type = 'FN';

  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;

  INSERT INTO #Expected VALUES ('Is a function.');

  EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';  
END;
GO
CREATE FUNCTION Facade_CreateFacadeDb_Tests.[THROW @FunctionObjectId]
(
  @FunctionObjectId INT,
  @ReturnValue NVARCHAR(MAX)
)
RETURNS TABLE
AS
RETURN SELECT 'RAISERROR (''@FunctionObjectId=%i'',16,1,' + CAST(@FunctionObjectId AS NVARCHAR(MAX)) + ');' CreateStatement;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSFNFacade passes the correct object id to tSQLt.Private_CreateFakeFunctionStatement]
AS
BEGIN
  EXEC tSQLt.FakeFunction @FunctionName = N'tSQLt.Private_CreateFakeFunctionStatement',
                          @FakeFunctionName = 'Facade_CreateFacadeDb_Tests.[THROW @FunctionObjectId]';

  EXEC tSQLt.ExpectException @ExpectedMessage = N'@FunctionObjectId=4217';
  
  EXEC Facade.CreateSFNFacade @FacadeDbName = '$(tSQLtFacade)', @FunctionObjectId = 4217;

END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSFNFacade creates schema if it doesn't already exist]
AS
BEGIN
  DECLARE @SchemaName NVARCHAR(MAX) = 'SomeRandomSchema'+CONVERT(NVARCHAR(MAX),CAST(NEWID() AS VARBINARY(MAX)),2);
  DECLARE @FakeDataSourceStatement NVARCHAR(MAX) = N'SELECT ''CREATE FUNCTION ' + @SchemaName + '.aRandomFunction () RETURNS INT AS BEGIN RETURN 1; END;'' CreateStatement';
  DECLARE @cmd NVARCHAR(MAX) = 'CREATE SCHEMA ' + @SchemaName; 
  DECLARE @FunctionObjectId INT;

  EXEC (@cmd); 
  EXEC ('CREATE FUNCTION ' + @SchemaName + '.aRandomFunction () RETURNS INT AS BEGIN RETURN 1; END;');
  SET @FunctionObjectId = OBJECT_ID(@SchemaName + '.aRandomFunction');

  EXEC tSQLt.FakeFunction @FunctionName = N'tSQLt.Private_CreateFakeFunctionStatement',
                          @FakeDataSource = @FakeDataSourceStatement;

  EXEC Facade.CreateSFNFacade @FacadeDbName = '$(tSQLtFacade)', @FunctionObjectId = @FunctionObjectId;

  SELECT 'Is a function.' AS resultColumn INTO #Actual
    FROM $(tSQLtFacade).sys.objects O 
	JOIN $(tSQLtFacade).sys.schemas S ON (O.schema_id = S.schema_id)
   WHERE O.name = 'aRandomFunction' 
	 AND S.name = @SchemaName
	 AND O.type = 'FN';

  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;

  INSERT INTO #Expected VALUES ('Is a function.');

  EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';  END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSSPFacade works for schema with single quote]
AS
BEGIN
  DECLARE @SchemaName NVARCHAR(MAX) = QUOTENAME('SomeRandomSchema'''+CONVERT(NVARCHAR(MAX),CAST(NEWID() AS VARBINARY(MAX)),2));
  DECLARE @cmd NVARCHAR(MAX);

  SET @cmd = 'CREATE SCHEMA ' + @SchemaName + ';';
  EXEC(@cmd);

  SET @cmd = 'CREATE PROC ' + @SchemaName + '.AnotherProc AS RETURN 42;'; 
  EXEC(@cmd);
  
  DECLARE @ProcedureObjectId INT = OBJECT_ID(@SchemaName+'.AnotherProc');
  EXEC Facade.CreateSSPFacade @FacadeDbName = '$(tSQLtFacade)', @ProcedureObjectId = @ProcedureObjectId;

  DECLARE @RemoteProcedureName NVARCHAR(MAX) = '$(tSQLtFacade).'+@SchemaName+'.AnotherProc'; 
  EXEC tSQLt.AssertObjectExists @ObjectName = @RemoteProcedureName;
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSSPFacade works for procedure names with single quote]
AS
BEGIN
  DECLARE @cmd NVARCHAR(MAX);

  SET @cmd = 'CREATE PROC dbo.[Anothe''rProc] AS RETURN 42;'; 
  EXEC(@cmd);
  
  DECLARE @ProcedureObjectId INT = OBJECT_ID('dbo.[Anothe''rProc]');
  EXEC Facade.CreateSSPFacade @FacadeDbName = '$(tSQLtFacade)', @ProcedureObjectId = @ProcedureObjectId;

  DECLARE @RemoteProcedureName NVARCHAR(MAX) = '$(tSQLtFacade).dbo.[Anothe''rProc]'; 
  EXEC tSQLt.AssertObjectExists @ObjectName = @RemoteProcedureName;
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTBLorVWFacade works for table names with single quote]
AS
BEGIN
  CREATE TABLE dbo.[SomeR'andomTable] (a INT);

  DECLARE @TableObjectId INT = OBJECT_ID('dbo.[SomeR''andomTable]');

  EXEC Facade.CreateTBLorVWFacade @FacadeDbName = '$(tSQLtFacade)', @TableObjectId = @TableObjectId;

  EXEC tSQLt.AssertObjectExists @ObjectName = '$(tSQLtFacade).dbo.[SomeR''andomTable]';

END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSFNFacade works for function names with single quote]
AS
BEGIN
  DECLARE @FakeDataSourceStatement NVARCHAR(MAX) = N'SELECT ''CREATE FUNCTION dbo.[aRando''''mFunction] () RETURNS INT AS BEGIN RETURN 1; END;'' CreateStatement';
  DECLARE @FunctionObjectId INT;

  EXEC ('CREATE FUNCTION dbo.[aRando''mFunction] () RETURNS INT AS BEGIN RETURN 1; END;');
  SET @FunctionObjectId = OBJECT_ID('dbo.[aRando''mFunction]');

  EXEC tSQLt.FakeFunction @FunctionName = N'tSQLt.Private_CreateFakeFunctionStatement',
                          @FakeDataSource = @FakeDataSourceStatement;

  EXEC Facade.CreateSFNFacade @FacadeDbName = '$(tSQLtFacade)', @FunctionObjectId = @FunctionObjectId;

  SELECT 'Is a function.' AS resultColumn INTO #Actual
    FROM $(tSQLtFacade).sys.objects O 
	JOIN $(tSQLtFacade).sys.schemas S ON (O.schema_id = S.schema_id)
   WHERE O.name = 'aRando''mFunction' 
	 AND S.name = 'dbo'
	 AND O.type = 'FN';

  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;

  INSERT INTO #Expected VALUES ('Is a function.');

  EXEC tSQLt.AssertEqualsTable @Expected = N'#Expected', @Actual = N'#Actual';

END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTBLorVWFacades doesn't call CreateTBLorVWFacade if there are no tables]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateTBLorVWFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.tables]';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.views]';

  EXEC Facade.CreateTBLorVWFacades @FacadeDbName = '$(tSQLtFacade)';

  EXEC tSQLt.AssertEmptyTable @TableName = 'Facade.[CreateTBLorVWFacade_SpyProcedureLog]';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTBLorVWFacades calls CreateTBLorVWFacade for single table]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateTBLorVWFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.tables]';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.views]';
  EXEC('INSERT INTO Facade.[sys.tables](object_id,schema_id,name)VALUES (1001,SCHEMA_ID(''tSQLt''),''aRandomTable'');');

  EXEC Facade.CreateTBLorVWFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT TableObjectId INTO #Actual FROM Facade.[CreateTBLorVWFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES(1001);
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTBLorVWFacades calls CreateTBLorVWFacade for multiple tables]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateTBLorVWFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.tables]';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.views]';
  EXEC('INSERT INTO Facade.[sys.tables](object_id,schema_id,name) VALUES (1001,SCHEMA_ID(''tSQLt''),''aRandomTable'');');
  EXEC('INSERT INTO Facade.[sys.tables](object_id,schema_id,name) VALUES (1002,SCHEMA_ID(''tSQLt''),''bRandomTable'');');
  EXEC('INSERT INTO Facade.[sys.tables](object_id,schema_id,name) VALUES (1003,SCHEMA_ID(''tSQLt''),''cRandomTable'');');

  EXEC Facade.CreateTBLorVWFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT TableObjectId INTO #Actual FROM Facade.[CreateTBLorVWFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES(1001),(1002),(1003);
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTBLorVWFacades calls CreateTBLorVWFacade only for tables which are not Private]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateTBLorVWFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.tables]';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.views]';
  EXEC('INSERT INTO Facade.[sys.tables](object_id,schema_id,name) VALUES (1001,SCHEMA_ID(''tSQLt''),''aRandomTable'');');
  EXEC('INSERT INTO Facade.[sys.tables](object_id,schema_id,name) VALUES (1002,SCHEMA_ID(''tSQLt''),''PrivateRandomTable'');');
  EXEC('INSERT INTO Facade.[sys.tables](object_id,schema_id,name) VALUES (1003,SCHEMA_ID(''tSQLt''),''PrIVateRandomTable'');');
  EXEC('INSERT INTO Facade.[sys.tables](object_id,schema_id,name) VALUES (1004,SCHEMA_ID(''tSQLt''),''PRIVATERandomTable'');');
  EXEC('INSERT INTO Facade.[sys.tables](object_id,schema_id,name) VALUES (1005,SCHEMA_ID(''tSQLt''),''cRandomTable'');');

  EXEC Facade.CreateTBLorVWFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT TableObjectId INTO #Actual FROM Facade.[CreateTBLorVWFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES(1001),(1005);
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTBLorVWFacades calls CreateTBLorVWFacade only for tables which are in the tSQLt schema]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateTBLorVWFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.tables]';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.views]';
  EXEC('INSERT INTO Facade.[sys.tables](object_id,schema_id,name) VALUES (1001,SCHEMA_ID(''tSQLt''),''aRandomTable'');');
  EXEC('INSERT INTO Facade.[sys.tables](object_id,schema_id,name) VALUES (1002,SCHEMA_ID(''tSQLt''),''bRandomTable'');');
  EXEC('INSERT INTO Facade.[sys.tables](object_id,schema_id,name) VALUES (1003,SCHEMA_ID(''dbo''),''cRandomTable'');');

  EXEC Facade.CreateTBLorVWFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT TableObjectId INTO #Actual FROM Facade.[CreateTBLorVWFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES(1001),(1002);
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTBLorVWFacades also works for views]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateTBLorVWFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.tables]';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.views]';
  EXEC('INSERT INTO Facade.[sys.views](object_id,schema_id,name) VALUES (1001,SCHEMA_ID(''tSQLt''),''aRandomView'');');
  EXEC('INSERT INTO Facade.[sys.views](object_id,schema_id,name) VALUES (1002,SCHEMA_ID(''tSQLt''),''bRandomView'');');
  EXEC('INSERT INTO Facade.[sys.views](object_id,schema_id,name) VALUES (1003,SCHEMA_ID(''dbo''),''cRandomView'');');
  EXEC('INSERT INTO Facade.[sys.views](object_id,schema_id,name) VALUES (1004,SCHEMA_ID(''tSQLt''),''PrivateRandomView'');');
  EXEC('INSERT INTO Facade.[sys.views](object_id,schema_id,name) VALUES (1005,SCHEMA_ID(''tSQLt''),''PrIVateRandomView'');');
  EXEC('INSERT INTO Facade.[sys.views](object_id,schema_id,name) VALUES (1006,SCHEMA_ID(''tSQLt''),''PRIVATERandomView'');');

  EXEC Facade.CreateTBLorVWFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT TableObjectId INTO #Actual FROM Facade.[CreateTBLorVWFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES(1001),(1002);
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSSPFacades passes @FacadeDbName to CreateSSPFacade]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateSSPFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.procedures]';
  EXEC('INSERT INTO Facade.[sys.procedures](object_id,schema_id,name)VALUES (1001,SCHEMA_ID(''tSQLt''),''AProc'');');

  EXEC Facade.CreateSSPFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT FacadeDbName INTO #Actual FROM Facade.[CreateSSPFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES('$(tSQLtFacade)');
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTBLorVWFacades passes @FacadeDbName to CreateTBLorVWFacade]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateTBLorVWFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.tables]';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.views]';
  EXEC('INSERT INTO Facade.[sys.tables](object_id,schema_id,name)VALUES (1001,SCHEMA_ID(''tSQLt''),''AProc'');');

  EXEC Facade.CreateTBLorVWFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT FacadeDbName INTO #Actual FROM Facade.[CreateTBLorVWFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES('$(tSQLtFacade)');
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSFNFacades doesn't call CreateSFNFacade if there are no functions]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateSFNFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.objects]';

  EXEC Facade.CreateSFNFacades @FacadeDbName = '$(tSQLtFacade)';

  EXEC tSQLt.AssertEmptyTable @TableName = 'Facade.[CreateSFNFacade_SpyProcedureLog]';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSFNFacades calls CreateSFNFacade if there is one function]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateSFNFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.objects]';
  EXEC('INSERT INTO Facade.[sys.objects](object_id,schema_id,name,type)VALUES (1001,SCHEMA_ID(''tSQLt''),''aRandomFunction'',''FN'');');

  EXEC Facade.CreateSFNFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT FacadeDbName, FunctionObjectId INTO #Actual FROM Facade.[CreateSFNFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES('$(tSQLtFacade)', 1001);
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';

END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSFNFacades calls CreateSFNFacade if there are multiple functions]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateSFNFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.objects]';
  EXEC('INSERT INTO Facade.[sys.objects](object_id,schema_id,name,type)VALUES (1001,SCHEMA_ID(''tSQLt''),''aRandomFunction'',''FN'');');
  EXEC('INSERT INTO Facade.[sys.objects](object_id,schema_id,name,type)VALUES (1002,SCHEMA_ID(''tSQLt''),''bRandomFunction'',''FN'');');
  EXEC('INSERT INTO Facade.[sys.objects](object_id,schema_id,name,type)VALUES (1003,SCHEMA_ID(''tSQLt''),''cRandomFunction'',''FN'');');

  EXEC Facade.CreateSFNFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT FacadeDbName, FunctionObjectId INTO #Actual FROM Facade.[CreateSFNFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES('$(tSQLtFacade)', 1001), ('$(tSQLtFacade)', 1002), ('$(tSQLtFacade)', 1003);
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';

END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSFNFacades calls CreateSFNFacade only for functions which are not Private]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateSFNFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.objects]';
  EXEC('INSERT INTO Facade.[sys.objects](object_id,schema_id,name,type)VALUES (1001,SCHEMA_ID(''tSQLt''),''aRandomFunction'',''FN'');');
  EXEC('INSERT INTO Facade.[sys.objects](object_id,schema_id,name,type)VALUES (1002,SCHEMA_ID(''tSQLt''),''PrivateRandomFunction'',''FN'');');
  EXEC('INSERT INTO Facade.[sys.objects](object_id,schema_id,name,type)VALUES (1003,SCHEMA_ID(''tSQLt''),''PrIVateRandomFunction'',''FN'');');
  EXEC('INSERT INTO Facade.[sys.objects](object_id,schema_id,name,type)VALUES (1004,SCHEMA_ID(''tSQLt''),''PRIVATERandomFunction'',''FN'');');
  EXEC('INSERT INTO Facade.[sys.objects](object_id,schema_id,name,type)VALUES (1005,SCHEMA_ID(''tSQLt''),''cRandomFunction'',''FN'');');

  EXEC Facade.CreateSFNFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT FunctionObjectId INTO #Actual FROM Facade.[CreateSFNFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES(1001), (1005);
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';

END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSFNFacades calls CreateSFNFacade only for functions which are in the tSQLt schema]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateSFNFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.objects]';
  EXEC('INSERT INTO Facade.[sys.objects](object_id,schema_id,name,type)VALUES (1001,SCHEMA_ID(''tSQLt''),''aRandomFunction'',''FN'');');
  EXEC('INSERT INTO Facade.[sys.objects](object_id,schema_id,name,type)VALUES (1002,SCHEMA_ID(''tSQLt''),''bRandomFunction'',''FN'');');
  EXEC('INSERT INTO Facade.[sys.objects](object_id,schema_id,name,type)VALUES (1003,SCHEMA_ID(''dbo''),''cRandomFunction'',''FN'');');

  EXEC Facade.CreateSFNFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT FunctionObjectId INTO #Actual FROM Facade.[CreateSFNFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES(1001), (1002);
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';

END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateSFNFacades calls CreateSFNFacade only for functions]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateSFNFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.objects]';
  EXEC('INSERT INTO Facade.[sys.objects](object_id,schema_id,name,type)VALUES (1002,SCHEMA_ID(''tSQLt''),''bRandomObject'',''IF'');');
  EXEC('INSERT INTO Facade.[sys.objects](object_id,schema_id,name,type)VALUES (1003,SCHEMA_ID(''tSQLt''),''cRandomObject'',''TF'');');
  EXEC('INSERT INTO Facade.[sys.objects](object_id,schema_id,name,type)VALUES (1004,SCHEMA_ID(''tSQLt''),''dRandomObject'',''FS'');');
  EXEC('INSERT INTO Facade.[sys.objects](object_id,schema_id,name,type)VALUES (1005,SCHEMA_ID(''tSQLt''),''eRandomObject'',''FT'');');
  EXEC('INSERT INTO Facade.[sys.objects](object_id,schema_id,name,type)VALUES (1001,SCHEMA_ID(''tSQLt''),''aRandomObject'',''FN'');');
  EXEC('INSERT INTO Facade.[sys.objects](object_id,schema_id,name,type)VALUES (1006,SCHEMA_ID(''tSQLt''),''fRandomObject'',''P'');');
  EXEC('INSERT INTO Facade.[sys.objects](object_id,schema_id,name,type)VALUES (1007,SCHEMA_ID(''tSQLt''),''gRandomObject'',''SN'');');

  EXEC Facade.CreateSFNFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT FunctionObjectId INTO #Actual FROM Facade.[CreateSFNFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES(1001), (1002), (1003), (1004), (1005);
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';

END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTypeFacade copies a simple table type to the $(tSQLtFacade) database]
AS
BEGIN
  CREATE TYPE dbo.SomeRandomType AS TABLE (a INT);

  DECLARE @UserTypeId INT = TYPE_ID('dbo.SomeRandomType');
  
  EXEC Facade.CreateTypeFacade @FacadeDbName = '$(tSQLtFacade)', @UserTypeId = @UserTypeId;

  DECLARE @RemoteTypeId INT;
  EXEC $(tSQLtFacade).sys.sp_executesql N'SET @TypeId = (SELECT TYPE_ID(''dbo.SomeRandomType''));',N'@TypeId INT OUTPUT', @RemoteTypeId OUT;

  EXEC tSQLt.AssertNotEquals @Expected=NULL, @Actual = @RemoteTypeId, @Message = N'Remote Type not found. ';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTypeFacade errors with appropriate message if type is not a table_type]
AS
BEGIN
  CREATE TYPE dbo.SomeRandomType FROM INT;
  DECLARE @UserTypeId INT = TYPE_ID('dbo.SomeRandomType');
  
  EXEC tSQLt.ExpectException @ExpectedMessagePattern = '%CreateTypeFacade currently handles only TABLE_TYPEs%', @ExpectedSeverity = 16, @ExpectedState = 10;
  
  EXEC Facade.CreateTypeFacade @FacadeDbName = '$(tSQLtFacade)', @UserTypeId = @UserTypeId;
END;
GO

CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTypeFacade works for other schema that does exist in the facade db]
AS
BEGIN
  EXEC('CREATE SCHEMA SomeOtherSchemaForFacadeTests;');
  EXEC $(tSQLtFacade).sys.sp_executesql N'EXEC(''CREATE SCHEMA SomeOtherSchemaForFacadeTests;'');',N'';

  CREATE TYPE SomeOtherSchemaForFacadeTests.SomeRandomType AS TABLE (a INT);

  DECLARE @UserTypeId INT = TYPE_ID('SomeOtherSchemaForFacadeTests.SomeRandomType');
  
  EXEC Facade.CreateTypeFacade @FacadeDbName = '$(tSQLtFacade)', @UserTypeId = @UserTypeId;

  DECLARE @RemoteTypeId INT;
  EXEC $(tSQLtFacade).sys.sp_executesql N'SET @TypeId = (SELECT TYPE_ID(''SomeOtherSchemaForFacadeTests.SomeRandomType''));',N'@TypeId INT OUTPUT', @RemoteTypeId OUT;

  EXEC tSQLt.AssertNotEquals @Expected=NULL, @Actual = @RemoteTypeId, @Message = N'Remote Type not found. ';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTypeFacade copies table type into a schema that does not exist in the $(tSQLtFacade) database]
AS
BEGIN
  DECLARE @SchemaName NVARCHAR(MAX) = 'SomeRandomSchema'+CONVERT(NVARCHAR(MAX),CAST(NEWID() AS VARBINARY(MAX)),2);
  DECLARE @cmd NVARCHAR(MAX);

  SET @cmd = 'CREATE SCHEMA '+@SchemaName+';';
  EXEC(@cmd);

  SET @cmd = 'CREATE TYPE ' + @SchemaName + '.SomeRandomType AS TABLE (a INT);';
  EXEC(@cmd);

  DECLARE @UserTypeId INT = TYPE_ID(@SchemaName + '.SomeRandomType');
  EXEC Facade.CreateTypeFacade @FacadeDbName = '$(tSQLtFacade)', @UserTypeId = @UserTypeId;

  DECLARE @RemoteTypeId INT;
  SET @cmd = 'SET @TypeId = (SELECT TYPE_ID(''' + @SchemaName + '.SomeRandomType''));';
  EXEC $(tSQLtFacade).sys.sp_executesql @cmd,N'@TypeId INT OUTPUT', @RemoteTypeId OUT;

  EXEC tSQLt.AssertNotEquals @Expected=NULL, @Actual = @RemoteTypeId, @Message = N'Remote Type not found. ';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTypeFacade copies table type with multiple columns to the $(tSQLtFacade) database]
AS
BEGIN
  CREATE TYPE dbo.SomeRandomType AS TABLE (a INT, bb NVARCHAR(MAX), ccc DATETIME2);

  DECLARE @UserTypeId INT = TYPE_ID('dbo.SomeRandomType');
  
  EXEC Facade.CreateTypeFacade @FacadeDbName = '$(tSQLtFacade)', @UserTypeId = @UserTypeId;

  DECLARE @LocalTypeTableObjectId INT = (SELECT t.type_table_object_id FROM sys.table_types t WHERE t.user_type_id = @UserTypeId);
 
  DECLARE @RemoteTypeTableObjectId INT;
  EXEC $(tSQLtFacade).sys.sp_executesql N'SET @RemoteTypeTableObjectId = (SELECT t.type_table_object_id FROM sys.table_types t WHERE t.user_type_id = TYPE_ID(''dbo.SomeRandomType''));',N'@RemoteTypeTableObjectId INT OUTPUT', @RemoteTypeTableObjectId OUT;

  SELECT 
      C.name,
      C.column_id,
      C.system_type_id,
      C.user_type_id,
      C.max_length,
      C.precision,
      C.scale,
      C.is_nullable,
      C.is_identity
    INTO #Actual FROM $(tSQLtFacade).sys.columns AS C WHERE C.object_id = @RemoteTypeTableObjectId;

  SELECT 
      C.name,
      C.column_id,
      C.system_type_id,
      C.user_type_id,
      C.max_length,
      C.precision,
      C.scale,
      C.is_nullable,
      C.is_identity
    INTO #Expected FROM sys.columns AS C WHERE C.object_id = @LocalTypeTableObjectId;

  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTypeFacades doesn't call CreateTypeFacade if there are no types]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateTypeFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.types]';

  EXEC Facade.CreateTypeFacades @FacadeDbName = '$(tSQLtFacade)';

  EXEC tSQLt.AssertEmptyTable @TableName = 'Facade.[CreateTypeFacade_SpyProcedureLog]';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTypeFacades calls CreateTypeFacade once if there is one type]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateTypeFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.types]';
  EXEC ('INSERT INTO Facade.[sys.types] (user_type_id, schema_id, name) VALUES (101, SCHEMA_ID(''tSQLt''),''aType'');');

  EXEC Facade.CreateTypeFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT FacadeDbName, UserTypeId INTO #Actual FROM Facade.[CreateTypeFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES('$(tSQLtFacade)', 101);
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTypeFacades calls CreateTypeFacade once each for multiple types]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateTypeFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.types]';
  EXEC ('INSERT INTO Facade.[sys.types] (user_type_id, schema_id, name) VALUES (101, SCHEMA_ID(''tSQLt''),''aType'');');
  EXEC ('INSERT INTO Facade.[sys.types] (user_type_id, schema_id, name) VALUES (102, SCHEMA_ID(''tSQLt''),''bType'');');
  EXEC ('INSERT INTO Facade.[sys.types] (user_type_id, schema_id, name) VALUES (103, SCHEMA_ID(''tSQLt''),''cType'');');

  EXEC Facade.CreateTypeFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT FacadeDbName, UserTypeId INTO #Actual FROM Facade.[CreateTypeFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES('$(tSQLtFacade)', 101),('$(tSQLtFacade)', 102),('$(tSQLtFacade)', 103);
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTypeFacades calls CreateTypeFacade only for types which are in the tSQLt schema]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateTypeFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.types]';
  EXEC ('INSERT INTO Facade.[sys.types] (user_type_id, schema_id, name) VALUES (101, SCHEMA_ID(''tSQLt''),''aType'');');
  EXEC ('INSERT INTO Facade.[sys.types] (user_type_id, schema_id, name) VALUES (102, SCHEMA_ID(''dbo''),''bType'');');
  EXEC ('INSERT INTO Facade.[sys.types] (user_type_id, schema_id, name) VALUES (103, SCHEMA_ID(''tSQLt''),''cType'');');

  EXEC Facade.CreateTypeFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT FacadeDbName, UserTypeId INTO #Actual FROM Facade.[CreateTypeFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES('$(tSQLtFacade)', 101),('$(tSQLtFacade)', 103);
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateTypeFacades calls CreateTypeFacade only for types which are not Private]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateTypeFacade';
  EXEC tSQLt.FakeTable @TableName = 'Facade.[sys.types]';
  EXEC ('INSERT INTO Facade.[sys.types] (user_type_id, schema_id, name) VALUES (101, SCHEMA_ID(''tSQLt''),''aType'');');
  EXEC ('INSERT INTO Facade.[sys.types] (user_type_id, schema_id, name) VALUES (102, SCHEMA_ID(''tSQLt''),''bType'');');
  EXEC ('INSERT INTO Facade.[sys.types] (user_type_id, schema_id, name) VALUES (103, SCHEMA_ID(''tSQLt''),''PrivateType'');');
  EXEC ('INSERT INTO Facade.[sys.types] (user_type_id, schema_id, name) VALUES (104, SCHEMA_ID(''tSQLt''),''PRIVATEType'');');
  EXEC ('INSERT INTO Facade.[sys.types] (user_type_id, schema_id, name) VALUES (105, SCHEMA_ID(''tSQLt''),''PrIVateType'');');

  EXEC Facade.CreateTypeFacades @FacadeDbName = '$(tSQLtFacade)';

  SELECT FacadeDbName, UserTypeId INTO #Actual FROM Facade.[CreateTypeFacade_SpyProcedureLog];
  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES('$(tSQLtFacade)', 101),('$(tSQLtFacade)', 102);
  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateAllFacadeObjects calls all Facades procedures]
AS
BEGIN
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateSFNFacades';
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateSSPFacades';
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateTBLorVWFacades';
  EXEC tSQLt.SpyProcedure @ProcedureName = 'Facade.CreateTypeFacades';

  EXEC Facade.CreateAllFacadeObjects @FacadeDbName = '$(tSQLtFacade)';

  SELECT * INTO #Actual FROM
  (
    SELECT FacadeDbName, 'UDT' AS [Procedure] FROM Facade.[CreateTypeFacades_SpyProcedureLog]
    UNION ALL
    SELECT FacadeDbName, 'SFN' AS [Procedure] FROM Facade.[CreateSFNFacades_SpyProcedureLog]
    UNION ALL
    SELECT FacadeDbName, 'SSP' AS [Procedure] FROM Facade.[CreateSSPFacades_SpyProcedureLog]
    UNION ALL
    SELECT FacadeDbName, 'TBLorVW' AS [Procedure] FROM Facade.[CreateTBLorVWFacades_SpyProcedureLog]
  ) SPL;

  SELECT TOP(0) A.* INTO #Expected FROM #Actual A RIGHT JOIN #Actual X ON 1=0;
  INSERT INTO #Expected
  VALUES('$(tSQLtFacade)','UDT'),('$(tSQLtFacade)','SFN'), ('$(tSQLtFacade)','SSP'), ('$(tSQLtFacade)','TBLorVW');

  EXEC tSQLt.AssertEqualsTable '#Expected','#Actual';
END;
GO
CREATE PROCEDURE Facade_CreateFacadeDb_Tests.[test CreateAllFacadeObjects doesn't error]
AS
BEGIN
  EXEC tSQLt.ExpectNoException;

  EXEC Facade.CreateAllFacadeObjects @FacadeDbName = '$(tSQLtFacade)';
END;
GO
