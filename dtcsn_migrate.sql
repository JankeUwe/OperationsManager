USE [dtcSN]
GO
SET NOCOUNT ON;

-- ============================================================
-- dtcSN – Migrationsscript (Originalschema -> verbessertes Schema)
-- Erstellt:  Uwe Janke, dtcSoftware
-- Zweck:     Passt eine bestehende dtcSN-Installation an ohne
--            Daten zu veraendern oder zu loeschen.
--
-- Idempotent: Kann mehrfach ausgefuehrt werden.
-- Voraussetzung: dtcSN existiert und ist erreichbar.
--
-- Aenderungen:
--   [1] Spalte Computer.Insterted -> Inserted (sp_rename)
--   [2] Constraints umbenennen
--   [3] Rollen: db_owner entfernen, granulare Rechte setzen
--   [4] Funktionen: Tippfehler + fn_CustDomainCount INT
--   [5] Prozeduren umbenennen (ReadPoperties, ShowPoperties,
--       SetCaseSensitiv, _02a_, _02b_, 03a_)
--   [6] Prozeduren: TRY/CATCH, SET NOCOUNT, Logik-Fixes
--   [7] Neue Prozedur: _00_ExtendTargetTables
-- ============================================================

PRINT '============================================================'
PRINT ' dtcSN Migration – Start'
PRINT '============================================================'
PRINT ''

-- ============================================================
-- [1] SPALTEN UMBENENNEN
-- ============================================================
PRINT '[1] Spalten umbenennen...'

-- Computer.Insterted -> Computer.Inserted
IF EXISTS (
    SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
    WHERE Table_Name = 'Computer' AND Column_Name = 'Insterted'
)
BEGIN
    EXEC sp_rename 'dbo.Computer.Insterted', 'Inserted', 'COLUMN'
    PRINT '    OK  Computer.Insterted -> Inserted'
END
ELSE
    PRINT '    --  Computer.Inserted bereits korrekt'

PRINT ''

-- ============================================================
-- [2] CONSTRAINTS UMBENENNEN
-- ============================================================
PRINT '[2] Constraints umbenennen...'

-- DF_Computer_Insterted -> DF_Computer_Inserted
IF OBJECT_ID('dbo.DF_Computer_Insterted', 'D') IS NOT NULL
   AND OBJECT_ID('dbo.DF_Computer_Inserted', 'D') IS NULL
BEGIN
    EXEC sp_rename 'dbo.DF_Computer_Insterted', 'DF_Computer_Inserted'
    PRINT '    OK  DF_Computer_Insterted -> DF_Computer_Inserted'
END
ELSE
    PRINT '    --  Constraint DF_Computer_Inserted bereits korrekt'

-- DF_SQLServer_Insterted -> DF_SQLServer_Inserted
IF OBJECT_ID('dbo.DF_SQLServer_Insterted', 'D') IS NOT NULL
   AND OBJECT_ID('dbo.DF_SQLServer_Inserted', 'D') IS NULL
BEGIN
    EXEC sp_rename 'dbo.DF_SQLServer_Insterted', 'DF_SQLServer_Inserted'
    PRINT '    OK  DF_SQLServer_Insterted -> DF_SQLServer_Inserted'
END
ELSE
    PRINT '    --  Constraint DF_SQLServer_Inserted bereits korrekt'

PRINT ''

-- ============================================================
-- [3] ROLLEN BEREINIGEN
-- ============================================================
PRINT '[3] Rollen bereinigen (db_owner -> granulare Rechte)...'

-- SLAReporting: db_owner -> db_datareader + db_datawriter
IF IS_ROLEMEMBER('db_owner', 'SLAReporting') = 1
BEGIN
    ALTER ROLE [db_owner]     DROP MEMBER [SLAReporting]
    PRINT '    OK  SLAReporting: db_owner entfernt'
END
IF DATABASE_PRINCIPAL_ID('SLAReporting') IS NOT NULL
   AND IS_ROLEMEMBER('db_datareader', 'SLAReporting') = 0
BEGIN
    ALTER ROLE [db_datareader] ADD MEMBER [SLAReporting]
    ALTER ROLE [db_datawriter] ADD MEMBER [SLAReporting]
    PRINT '    OK  SLAReporting: db_datareader + db_datawriter gesetzt'
END

-- ServiceNowReader: db_owner -> db_datareader
IF IS_ROLEMEMBER('db_owner', 'ServiceNowReader') = 1
BEGIN
    ALTER ROLE [db_owner]     DROP MEMBER [ServiceNowReader]
    PRINT '    OK  ServiceNowReader: db_owner entfernt'
END
IF DATABASE_PRINCIPAL_ID('ServiceNowReader') IS NOT NULL
   AND IS_ROLEMEMBER('db_datareader', 'ServiceNowReader') = 0
BEGIN
    ALTER ROLE [db_datareader] ADD MEMBER [ServiceNowReader]
    PRINT '    OK  ServiceNowReader: db_datareader gesetzt'
END

-- FITSRead: db_owner -> db_datareader
IF IS_ROLEMEMBER('db_owner', 'FITSRead') = 1
BEGIN
    ALTER ROLE [db_owner]     DROP MEMBER [FITSRead]
    PRINT '    OK  FITSRead: db_owner entfernt'
END
IF DATABASE_PRINCIPAL_ID('FITSRead') IS NOT NULL
   AND IS_ROLEMEMBER('db_datareader', 'FITSRead') = 0
BEGIN
    ALTER ROLE [db_datareader] ADD MEMBER [FITSRead]
    PRINT '    OK  FITSRead: db_datareader gesetzt'
END

PRINT ''

-- ============================================================
-- [4] FUNKTIONEN AKTUALISIEREN
-- ============================================================
PRINT '[4] Funktionen aktualisieren...'
GO

-- ── BuildPath (RETRUNVAL -> RETURNVAL) ─────────────────────
ALTER FUNCTION [dbo].[BuildPath] (@Path VARCHAR(256))
RETURNS VARCHAR(250)
AS
BEGIN
    DECLARE @RETURNVAL AS VARCHAR(250)
    SELECT @RETURNVAL = CAST([dbo].ReplaceLastOccurrence(@Path, '.', ';') AS VARCHAR(256))
    RETURN @RETURNVAL
END
GO
PRINT '    OK  BuildPath'

-- ── CutDomain (Formatierung) ───────────────────────────────
ALTER FUNCTION [dbo].[CutDomain] (@Fullname VARCHAR(255))
RETURNS VARCHAR(255)
AS
BEGIN
    SET @Fullname = REPLACE(@Fullname, ';', '.')
    DECLARE @Result AS VARCHAR(255)
    IF PATINDEX('%:%', @Fullname) > 0
        SELECT @Result = SUBSTRING(@Fullname, PATINDEX('%:%', @Fullname) + 1, 255)
    SELECT @Result = SUBSTRING(@Result, PATINDEX('%.%', @Result) + 1, 255)
    SELECT @Result = REVERSE(RIGHT(REVERSE(@Result), LEN(@Result) - CHARINDEX('.', REVERSE(@Result), 1)))
    RETURN @Result
END
GO
PRINT '    OK  CutDomain'

-- ── CutMaschine (Formatierung) ────────────────────────────
ALTER FUNCTION [dbo].[CutMaschine] (@Name VARCHAR(255))
RETURNS VARCHAR(255)
AS
BEGIN
    DECLARE @Result VARCHAR(255)
    SET @Name  = REPLACE(@Name, ';', '.')
    SELECT @Result = REVERSE(RIGHT(REVERSE(@Name), LEN(@Name) - CHARINDEX('.', REVERSE(@Name), 1)))
    RETURN @Result
END
GO
PRINT '    OK  CutMaschine'

-- ── fn_CustDomainCount: VARCHAR(255) -> INT ────────────────
ALTER FUNCTION [dbo].[fn_CustDomainCount] (@CustomerID INT)
RETURNS INT
AS
BEGIN
    DECLARE @Result AS INT
    SELECT @Result = COUNT(*) FROM [dbo].[CustomerDomain] WHERE CustomerID = @CustomerID
    RETURN @Result
END
GO
PRINT '    OK  fn_CustDomainCount (Rueckgabetyp: INT)'

-- ── GetCustomerName (RETRUNVAL -> RETURNVAL) ───────────────
ALTER FUNCTION [dbo].[GetCustomerName] (@DomainDnsName VARCHAR(100))
RETURNS NVARCHAR(256)
AS
BEGIN
    DECLARE @RETURNVAL AS NVARCHAR(256)
    SELECT @RETURNVAL = ISNULL([CustomerName], '???')
    FROM   [dbo].[CustomerDomain]
    WHERE  DomainDnsName LIKE '%' + @DomainDnsName + '%'
    RETURN @RETURNVAL
END
GO
PRINT '    OK  GetCustomerName'

-- ── GetCustomerNameLong ────────────────────────────────────
ALTER FUNCTION [dbo].[GetCustomerNameLong] (@CustomerID INT)
RETURNS NVARCHAR(256)
AS
BEGIN
    DECLARE @RETURNVAL AS NVARCHAR(256)
    SELECT @RETURNVAL = [NameLong] FROM [dbo].[Customer] WHERE CustomerID = @CustomerID
    RETURN @RETURNVAL
END
GO
PRINT '    OK  GetCustomerNameLong'

-- ── GetCustomerNameLong4Domain ─────────────────────────────
ALTER FUNCTION [dbo].[GetCustomerNameLong4Domain] (@CustomerID INT)
RETURNS NVARCHAR(256)
AS
BEGIN
    DECLARE @RETURNVAL AS NVARCHAR(256)
    SELECT @RETURNVAL = [NameLong] FROM [dbo].[Customer] WHERE CustomerID = @CustomerID
    RETURN @RETURNVAL
END
GO
PRINT '    OK  GetCustomerNameLong4Domain'

-- ── GetCustomerNameShort ───────────────────────────────────
ALTER FUNCTION [dbo].[GetCustomerNameShort] (@DomainDnsName VARCHAR(100))
RETURNS NVARCHAR(256)
AS
BEGIN
    DECLARE @RETURNVAL AS NVARCHAR(256)
    SELECT @RETURNVAL = ISNULL(CustomerShortName, '???')
    FROM   [dbo].[CustomerDomain]
    WHERE  DomainDnsName LIKE '%' + @DomainDnsName + '%'
    RETURN @RETURNVAL
END
GO
PRINT '    OK  GetCustomerNameShort'

-- ── GetCustomerNameShort4Domain ────────────────────────────
ALTER FUNCTION [dbo].[GetCustomerNameShort4Domain] (@CustomerID INT)
RETURNS NVARCHAR(256)
AS
BEGIN
    DECLARE @RETURNVAL AS NVARCHAR(256)
    SELECT @RETURNVAL = [Name] FROM [dbo].[Customer] WHERE CustomerID = @CustomerID
    RETURN @RETURNVAL
END
GO
PRINT '    OK  GetCustomerNameShort4Domain'

-- ── GetDatabaseType ────────────────────────────────────────
ALTER FUNCTION [dbo].[GetDatabaseType] (@ManagedEntityTypeRowId INT)
RETURNS NVARCHAR(256)
AS
BEGIN
    DECLARE @RETURNVAL AS NVARCHAR(256)
    SELECT @RETURNVAL = ManagedEntityTypeSystemName
    FROM   [dbo].[ManagedEntityDatabaseType]
    WHERE  ManagedEntityTypeRowId = @ManagedEntityTypeRowId
    RETURN @RETURNVAL
END
GO
PRINT '    OK  GetDatabaseType'

-- ── GetEndofExtended ───────────────────────────────────────
ALTER FUNCTION [dbo].[GetEndofExtended] (@ver VARCHAR(255))
RETURNS NVARCHAR(256)
AS
BEGIN
    DECLARE @VersionNr   NVARCHAR(10)
    DECLARE @ReturnValue NVARCHAR(256)
    SELECT @VersionNr   = sqlversion   FROM [dbo].[SQLVersion] WHERE LEFT(@ver, LEN([productversion])) = [productversion]
    SELECT @ReturnValue = EndofExtended FROM dbo.Support        WHERE [VersionNr] = @VersionNr
    RETURN @ReturnValue
END
GO
PRINT '    OK  GetEndofExtended'

-- ── GetEndOfMainstream ─────────────────────────────────────
ALTER FUNCTION [dbo].[GetEndOfMainstream] (@ver VARCHAR(255))
RETURNS NVARCHAR(256)
AS
BEGIN
    DECLARE @VersionNr   NVARCHAR(10)
    DECLARE @ReturnValue NVARCHAR(256)
    SELECT @VersionNr   = sqlversion      FROM [dbo].[SQLVersion] WHERE LEFT(@ver, LEN([productversion])) = [productversion]
    SELECT @ReturnValue = [EndOfMainstream] FROM dbo.Support      WHERE [VersionNr] = @VersionNr
    RETURN @ReturnValue
END
GO
PRINT '    OK  GetEndOfMainstream'

-- ── GetSQLVersion ──────────────────────────────────────────
ALTER FUNCTION [dbo].[GetSQLVersion] (@ver VARCHAR(255))
RETURNS NVARCHAR(256)
AS
BEGIN
    DECLARE @ReturnValue NVARCHAR(256)
    SELECT @ReturnValue = sqlversion FROM [dbo].[SQLVersion] WHERE LEFT(@ver, LEN([productversion])) = [productversion]
    RETURN @ReturnValue
END
GO
PRINT '    OK  GetSQLVersion'
PRINT ''

-- ============================================================
-- [5] PROZEDUREN UMBENENNEN
--     Muster: alten Namen droppen, neuen Namen anlegen/aendern.
--             Beide Schritte in IF-Bloecken – idempotent.
-- ============================================================
PRINT '[5] Prozeduren umbenennen...'
GO

-- ── ReadPoperties -> ReadProperties ───────────────────────
IF OBJECT_ID('dbo.ReadPoperties', 'P') IS NOT NULL
BEGIN
    DROP PROC dbo.ReadPoperties
    PRINT '    OK  ReadPoperties geloescht'
END
GO
IF OBJECT_ID('dbo.ReadProperties', 'P') IS NULL
    EXEC('CREATE PROC dbo.ReadProperties AS SELECT 1')
GO
ALTER PROC [dbo].[ReadProperties]
    @ManagedEntityRowId BIGINT,
    @Target             VARCHAR(255)
AS
SET NOCOUNT ON;

DECLARE @LOCAL_TABLEVARIABLE TABLE
(
    ID               BIGINT,
    [PropertySystemName] VARCHAR(255),
    PropertyValue    VARCHAR(255)
)

;WITH SQLProperties AS
(
    SELECT
        [ManagedEntityRowId]                             AS [Id],
        XProp.value('@Guid', 'uniqueidentifier')         AS PropertyGuid,
        XProp.value('(.)',   'varchar(100)')             AS PropertyValue
    FROM  dbo.vManagedEntityProperty (NOLOCK)
    CROSS APPLY PropertyXML.nodes('/Root/Property') AS XTbl(XProp)
    WHERE ToDateTime IS NULL
)
INSERT INTO @LOCAL_TABLEVARIABLE
SELECT LA.[Id], [PropertySystemName], PropertyValue
FROM   SQLProperties LA
INNER JOIN [OperationsManagerDW].[dbo].[ManagedEntityTypeProperty] MTP
    ON MTP.PropertyGuid = LA.PropertyGuid
WHERE  [Id] = @ManagedEntityRowId
ORDER  BY [PropertySystemName];

DECLARE @ID            BIGINT
DECLARE @PropertyName  NVARCHAR(256)
DECLARE @PropertyValue NVARCHAR(256)
DECLARE @stmt          NVARCHAR(4000)

DECLARE Property_cursor CURSOR FOR
    SELECT ID, [PropertySystemName], PropertyValue FROM @LOCAL_TABLEVARIABLE

OPEN Property_cursor
FETCH NEXT FROM Property_cursor INTO @ID, @PropertyName, @PropertyValue

WHILE @@FETCH_STATUS = 0
BEGIN
    IF EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE Table_Name = @Target AND Column_Name = @PropertyName
    )
    BEGIN
        SET @stmt = N'UPDATE dbo.' + QUOTENAME(@Target)
                  + N' SET '       + QUOTENAME(@PropertyName)
                  + N' = '         + CHAR(39) + LOWER(@PropertyValue) + CHAR(39)
                  + N', Modified = ' + CHAR(39) + CONVERT(VARCHAR(10), GETDATE(), 121) + CHAR(39)
                  + N' WHERE ManagedEntityRowId = ' + CAST(@ID AS NVARCHAR)
                  + N' AND (' + QUOTENAME(@PropertyName) + N' != ' + CHAR(39) + @PropertyValue + CHAR(39)
                  + N' OR '  + QUOTENAME(@PropertyName) + N' IS NULL)'
        EXEC sys.sp_executesql @stmt
    END
    FETCH NEXT FROM Property_cursor INTO @ID, @PropertyName, @PropertyValue
END

CLOSE Property_cursor
DEALLOCATE Property_cursor
GO
PRINT '    OK  ReadProperties (neu + TRY/CATCH via Caller)'

-- ── ShowPoperties -> ShowProperties ───────────────────────
IF OBJECT_ID('dbo.ShowPoperties', 'P') IS NOT NULL
BEGIN
    DROP PROC dbo.ShowPoperties
    PRINT '    OK  ShowPoperties geloescht'
END
GO
IF OBJECT_ID('dbo.ShowProperties', 'P') IS NULL
    EXEC('CREATE PROC dbo.ShowProperties AS SELECT 1')
GO
ALTER PROC [dbo].[ShowProperties]
    @ManagedEntityRowId BIGINT
AS
SET NOCOUNT ON;

;WITH SQLProperties AS
(
    SELECT
        [ManagedEntityRowId],
        XProp.value('@Guid', 'uniqueidentifier') AS PropertyGuid,
        XProp.value('(.)',   'varchar(100)')     AS PropertyValue
    FROM  OperationsManagerDW.dbo.ManagedEntityProperty
    CROSS APPLY PropertyXML.nodes('/Root/Property') AS XTbl(XProp)
    WHERE ToDateTime IS NULL
)
SELECT ManagedEntityRowId, LA.PropertyGuid, [PropertySystemName], PropertyValue
FROM   SQLProperties                          LA
INNER JOIN [dbo].[vManagedEntityTypeProperty] MTP ON MTP.PropertyGuid = LA.PropertyGuid
WHERE  LA.ManagedEntityRowId = @ManagedEntityRowId
ORDER  BY [PropertySystemName]
GO
PRINT '    OK  ShowProperties'

-- ── SetCaseSensitiv -> SetCaseSensitive ───────────────────
IF OBJECT_ID('dbo.SetCaseSensitiv', 'P') IS NOT NULL
BEGIN
    DROP PROC dbo.SetCaseSensitiv
    PRINT '    OK  SetCaseSensitiv geloescht'
END
GO
IF OBJECT_ID('dbo.SetCaseSensitive', 'P') IS NULL
    EXEC('CREATE PROC dbo.SetCaseSensitive AS SELECT 1')
GO
ALTER PROC [dbo].[SetCaseSensitive]
AS
SET NOCOUNT ON;

BEGIN TRY
    BEGIN TRAN

    UPDATE [dbo].[SQLDatabase]
    SET    [SQLDatabase].Path = [SQLServer].Path
    FROM   [SQLDatabase]
    INNER JOIN [dbo].[SQLServer]
        ON [SQLServer].ManagedEntityRowId = [SQLDatabase].TopLevelHostManagedEntityRowId

    COMMIT TRAN
END TRY
BEGIN CATCH
    IF @@TRANCOUNT > 0 ROLLBACK TRAN
    THROW;
END CATCH
GO
PRINT '    OK  SetCaseSensitive (+ TRY/CATCH)'

-- ── _02a_GetpropertiesForAllComputerEntries (Gro?schreibung)
-- Originalname hatte lowercase 'p' in 'properties'
IF OBJECT_ID('dbo._02a_GetpropertiesForAllComputerEntries', 'P') IS NOT NULL
   AND OBJECT_ID('dbo._02a_GetPropertiesForAllComputerEntries', 'P') IS NULL
BEGIN
    EXEC sp_rename '_02a_GetpropertiesForAllComputerEntries',
                   '_02a_GetPropertiesForAllComputerEntries'
    PRINT '    OK  _02a_: Grossschreibung korrigiert'
END
GO

-- ── _02b_GetWindowsOSForAllComputerEntrys
-- Originalname 'Entrys' (Tippfehler) -> 'Entries'
IF OBJECT_ID('dbo._02b_GetWindowsOSForAllComputerEntrys', 'P') IS NOT NULL
   AND OBJECT_ID('dbo._02b_GetWindowsOSForAllComputerEntries', 'P') IS NULL
BEGIN
    EXEC sp_rename '_02b_GetWindowsOSForAllComputerEntrys',
                   '_02b_GetWindowsOSForAllComputerEntries'
    PRINT '    OK  _02b_: Entrys -> Entries'
END
GO

-- ── 03a_ -> _03a_ (fehlendes Unterstrich-Praefix) ─────────
IF OBJECT_ID('dbo.03a_GetPropertiesForAllSQLDBS', 'P') IS NOT NULL
   AND OBJECT_ID('dbo._03a_GetPropertiesForAllSQLDBS', 'P') IS NULL
BEGIN
    EXEC sp_rename '03a_GetPropertiesForAllSQLDBS',
                   '_03a_GetPropertiesForAllSQLDBS'
    PRINT '    OK  03a_ -> _03a_ (Praefix ergaenzt)'
END
GO
PRINT ''

-- ============================================================
-- [6] PROZEDUREN AKTUALISIEREN (TRY/CATCH + Fixes)
-- ============================================================
PRINT '[6] Prozeduren aktualisieren...'
GO

-- ── _01_InsertSQLServer ────────────────────────────────────
ALTER PROC [dbo].[_01_InsertSQLServer]
AS
SET NOCOUNT ON;

WITH cte AS
(
    SELECT
        ME.[ManagedEntityRowId]
       ,ME.[TopLevelHostManagedEntityRowId]
       ,[ManagementGroupRowId]
       ,[ManagedEntityGuid]
       ,ME.[ManagedEntityTypeRowId]
       ,[FullName]
       ,REPLACE(SUBSTRING(FullName, PATINDEX('%:%', FullName) + 1, 255), ';', '.') AS [Path]
       ,[Name]
       ,dbo.[CutMaschine](Name)                           AS Maschine
       ,[DisplayName]
       ,[ManagedEntityDefaultName]
       ,CONVERT(VARCHAR(16), MP.[DWCreatedDateTime], 121) AS [DWCreatedDateTime]
       ,[dbo].[CutDomain](FullName)                       AS Domain
       ,ToDateTime
       ,(
            SELECT COUNT(*)
            FROM   [vManagedEntityProperty]
            WHERE  ManagedEntityRowId = ME.ManagedEntityRowId
        ) AS Changes
    FROM  dtcSN.[dbo].[vManagedEntity]        ME
    INNER JOIN [dbo].[vManagedEntityProperty] MP ON MP.ManagedEntityRowId     = ME.ManagedEntityRowId
    INNER JOIN [dbo].[ManagedSQLEntityType]   MT ON MT.ManagedEntityTypeRowId = ME.ManagedEntityTypeRowId
    WHERE ToDateTime IS NULL
      AND MT.[Aktiv] = 1
)
MERGE INTO dbo.SQLServer AS TARGET
USING (SELECT * FROM cte) AS SOURCE
    ON (TARGET.ManagedEntityRowId = SOURCE.[TopLevelHostManagedEntityRowId])

WHEN NOT MATCHED THEN
    INSERT (
        ManagedEntityRowId, TopLevelHostManagedEntityRowID, ManagedEntityDefaultName,
        FullName, Path, Maschine, Domain, DWCreatedDateTime, [Changes], IsSCOM
    )
    VALUES (
        SOURCE.ManagedEntityRowId, SOURCE.[TopLevelHostManagedEntityRowId],
        SOURCE.ManagedEntityDefaultName, SOURCE.[FullName], SOURCE.[Path],
        SOURCE.Maschine, SOURCE.Domain, SOURCE.DWCreatedDateTime, SOURCE.[Changes], 1
    )

WHEN MATCHED AND TARGET.NotFoundSince IS NOT NULL THEN
    UPDATE SET TARGET.NotFoundSince = NULL

WHEN NOT MATCHED BY SOURCE AND TARGET.NotFoundSince IS NULL THEN
    UPDATE SET TARGET.NotFoundSince = GETDATE();
GO
PRINT '    OK  _01_InsertSQLServer'

-- ── _01a_GetPropertiesForAllSQLEntries ─────────────────────
ALTER PROC [dbo].[_01a_GetPropertiesForAllSQLEntries]
AS
SET NOCOUNT ON;

DECLARE @ManagedEntityRowId BIGINT

DECLARE db_cursor CURSOR FOR
    SELECT ManagedEntityRowId FROM [dbo].[SQLServer]

OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @ManagedEntityRowId

BEGIN TRY
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC ReadProperties @ManagedEntityRowId, 'SQLServer'
        FETCH NEXT FROM db_cursor INTO @ManagedEntityRowId
    END
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local', 'db_cursor') >= 0
    BEGIN
        CLOSE db_cursor
        DEALLOCATE db_cursor
    END
    THROW;
END CATCH

CLOSE db_cursor
DEALLOCATE db_cursor
GO
PRINT '    OK  _01a_GetPropertiesForAllSQLEntries (+ TRY/CATCH)'

-- ── _02_InsertComputer ─────────────────────────────────────
ALTER PROC [dbo].[_02_InsertComputer]
AS
SET NOCOUNT ON;

WITH cte AS
(
    SELECT
        ME.[ManagedEntityRowId]
       ,ME.[ManagementGroupRowId]
       ,ME.[ManagedEntityGuid]
       ,ME.[ManagedEntityTypeRowId]
       ,ME.[TopLevelHostManagedEntityRowId]
       ,ME.[FullName]
       ,ME.[Path]
       ,ME.[Name]
       ,dbo.CutMaschine([Name])                           AS Maschine
       ,ME.[DisplayName]
       ,ME.[ManagedEntityDefaultName]
       ,CONVERT(VARCHAR(16), ME.[DWCreatedDateTime], 121) AS [DWCreatedDateTime]
    FROM   [dbo].[vManagedEntity]            ME
    INNER JOIN [dbo].[ManagedEntityCompType] TC ON TC.[ManagedEntityTypeRowId] = ME.[ManagedEntityTypeRowId]
    INNER JOIN [dbo].[SQLServer]             SS ON SS.Maschine = ME.Name
)
MERGE INTO [dbo].[Computer] AS DST
USING (
    SELECT ManagedEntityRowId, TopLevelHostManagedEntityRowId, Path, FullName,
           [DisplayName], Maschine, [ManagedEntityTypeRowId], [ManagedEntityDefaultName],
           [DWCreatedDateTime]
    FROM   cte
) AS SOURCE
    ON (SOURCE.ManagedEntityRowId = DST.ManagedEntityRowId)

WHEN NOT MATCHED THEN
    INSERT (
        ManagedEntityRowId, TopLevelHostManagedEntityRowId, Path, FullName,
        [DisplayName], Maschine, [ManagedEntityTypeRowId], [ManagedEntityDefaultName], [DWCreatedDateTime]
    )
    VALUES (
        SOURCE.ManagedEntityRowId, SOURCE.TopLevelHostManagedEntityRowId, SOURCE.[Path],
        SOURCE.FullName, SOURCE.[DisplayName], SOURCE.Maschine, SOURCE.[ManagedEntityTypeRowId],
        SOURCE.[ManagedEntityDefaultName], SOURCE.[DWCreatedDateTime]
    )

WHEN MATCHED AND DST.NotFoundSince IS NOT NULL THEN
    UPDATE SET DST.NotFoundSince = NULL

WHEN NOT MATCHED BY SOURCE AND DST.NotFoundSince IS NULL THEN
    UPDATE SET DST.NotFoundSince = GETDATE();

DELETE T
FROM (
    SELECT *
          ,ROW_NUMBER() OVER (PARTITION BY ManagedEntityRowId ORDER BY ID) AS DupRank
    FROM   Computer
) AS T
WHERE DupRank > 1
GO
PRINT '    OK  _02_InsertComputer'

-- ── _02a_GetPropertiesForAllComputerEntries ────────────────
IF OBJECT_ID('dbo._02a_GetPropertiesForAllComputerEntries', 'P') IS NULL
    EXEC('CREATE PROC dbo._02a_GetPropertiesForAllComputerEntries AS SELECT 1')
GO
ALTER PROC [dbo].[_02a_GetPropertiesForAllComputerEntries]
AS
SET NOCOUNT ON;

DECLARE @ManagedEntityRowId BIGINT

DECLARE db_cursor CURSOR FOR
    SELECT ManagedEntityRowId FROM [dbo].[Computer]

OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @ManagedEntityRowId

BEGIN TRY
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC ReadProperties @ManagedEntityRowId, 'Computer'
        FETCH NEXT FROM db_cursor INTO @ManagedEntityRowId
    END
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local', 'db_cursor') >= 0
    BEGIN
        CLOSE db_cursor
        DEALLOCATE db_cursor
    END
    THROW;
END CATCH

CLOSE db_cursor
DEALLOCATE db_cursor
GO
PRINT '    OK  _02a_GetPropertiesForAllComputerEntries (+ TRY/CATCH)'

-- ── _02b_GetWindowsOSForAllComputerEntries (set-basiert) ──
IF OBJECT_ID('dbo._02b_GetWindowsOSForAllComputerEntries', 'P') IS NULL
    EXEC('CREATE PROC dbo._02b_GetWindowsOSForAllComputerEntries AS SELECT 1')
GO
ALTER PROC [dbo].[_02b_GetWindowsOSForAllComputerEntries]
AS
SET NOCOUNT ON;

BEGIN TRY
    UPDATE C
    SET    C.WindowsOS = ME.ManagedEntityDefaultName
    FROM   dbo.Computer C
    INNER JOIN dbo.vManagedEntity ME
        ON  ME.TopLevelHostManagedEntityRowId = C.TopLevelHostManagedEntityRowId
        AND ME.ManagedEntityTypeRowId = 62
END TRY
BEGIN CATCH
    THROW;
END CATCH
GO
PRINT '    OK  _02b_GetWindowsOSForAllComputerEntries (Cursor -> set-basiert + TRY/CATCH)'

-- ── _03_InsertSQLDatabases ─────────────────────────────────
ALTER PROC [dbo].[_03_InsertSQLDatabases]
AS
SET NOCOUNT ON;

WITH cte AS
(
    SELECT
        PM.ManagedEntityRowId
       ,PM.TopLevelHostManagedEntityRowId
       ,PM.DisplayName
       ,PM.[FullName]
       ,REPLACE(PM.[Path], ';', ':') AS [Path]
       ,PM.ManagedEntityTypeRowId
    FROM   vManagedEntity                        AS PM
    INNER JOIN [dbo].[ManagedEntityDatabaseType] ME ON ME.ManagedEntityTypeRowId = PM.ManagedEntityTypeRowId
    INNER JOIN vManagedEntityProperty            MP ON MP.ManagedEntityRowId     = PM.ManagedEntityRowId
    WHERE  MP.ToDateTime IS NULL
      AND  PM.DisplayName NOT IN (SELECT Name FROM dbo.ExcludeDB)
      AND  ME.Aktive = 1
)
MERGE INTO dbo.SQLDatabase AS DST
USING (
    SELECT ManagedEntityRowId, TopLevelHostManagedEntityRowId,
           [Path], ManagedEntityTypeRowId, DisplayName
    FROM   cte
) AS SRC
    ON (SRC.ManagedEntityRowId = DST.ManagedEntityRowId)

WHEN NOT MATCHED THEN
    INSERT (
        ManagedEntityRowId, TopLevelHostManagedEntityRowId,
        [Path], ManagedEntityTypeRowId, DisplayName
    )
    VALUES (
        SRC.ManagedEntityRowId, SRC.TopLevelHostManagedEntityRowId,
        SRC.[Path], SRC.ManagedEntityTypeRowId, SRC.DisplayName
    )

WHEN MATCHED AND DST.NotFoundSince IS NOT NULL THEN
    UPDATE SET DST.NotFoundSince = NULL,      DST.Modified = GETDATE()

WHEN NOT MATCHED BY SOURCE AND DST.NotFoundSince IS NULL THEN
    UPDATE SET DST.NotFoundSince = GETDATE(), DST.Modified = GETDATE();
GO
PRINT '    OK  _03_InsertSQLDatabases (doppeltes ; entfernt)'

-- ── _03a_GetPropertiesForAllSQLDBS ────────────────────────
IF OBJECT_ID('dbo._03a_GetPropertiesForAllSQLDBS', 'P') IS NULL
    EXEC('CREATE PROC dbo._03a_GetPropertiesForAllSQLDBS AS SELECT 1')
GO
ALTER PROC [dbo].[_03a_GetPropertiesForAllSQLDBS]
AS
SET NOCOUNT ON;

DECLARE @ManagedEntityRowId BIGINT

DECLARE db_cursor CURSOR FOR
    SELECT ManagedEntityRowId FROM [dbo].[SQLDatabase]

OPEN db_cursor
FETCH NEXT FROM db_cursor INTO @ManagedEntityRowId

BEGIN TRY
    WHILE @@FETCH_STATUS = 0
    BEGIN
        EXEC ReadProperties @ManagedEntityRowId, 'SQLDatabase'
        FETCH NEXT FROM db_cursor INTO @ManagedEntityRowId
    END
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local', 'db_cursor') >= 0
    BEGIN
        CLOSE db_cursor
        DEALLOCATE db_cursor
    END
    THROW;
END CATCH

CLOSE db_cursor
DEALLOCATE db_cursor
GO
PRINT '    OK  _03a_GetPropertiesForAllSQLDBS (+ TRY/CATCH)'
PRINT ''

-- ============================================================
-- [7] NEUE PROZEDUR: _00_ExtendTargetTables
-- ============================================================
PRINT '[7] Neue Prozedur anlegen...'
GO

IF OBJECT_ID('dbo._00_ExtendTargetTables', 'P') IS NULL
    EXEC('CREATE PROC dbo._00_ExtendTargetTables AS SELECT 1')
GO
ALTER PROC [dbo].[_00_ExtendTargetTables]
    @WhatIf BIT = 0
AS
SET NOCOUNT ON;

CREATE TABLE #MissingColumns
(
    TableName  NVARCHAR(128) NOT NULL,
    ColumnName NVARCHAR(256) NOT NULL
)

INSERT INTO #MissingColumns (TableName, ColumnName)
SELECT DISTINCT N'SQLServer', MTP.PropertySystemName
FROM   [OperationsManagerDW].[dbo].[ManagedEntityTypeProperty] MTP
INNER JOIN [dbo].[ManagedSQLEntityType] MST ON MST.ManagedEntityTypeRowId = MTP.ManagedEntityTypeRowId
WHERE  MST.Aktiv = 1
  AND  MTP.PropertySystemName IS NOT NULL
  AND  NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE Table_Name = 'SQLServer' AND Column_Name = MTP.PropertySystemName)

INSERT INTO #MissingColumns (TableName, ColumnName)
SELECT DISTINCT N'Computer', MTP.PropertySystemName
FROM   [OperationsManagerDW].[dbo].[ManagedEntityTypeProperty] MTP
INNER JOIN [dbo].[ManagedEntityCompType] MCT ON MCT.ManagedEntityTypeRowId = MTP.ManagedEntityTypeRowId
WHERE  MTP.PropertySystemName IS NOT NULL
  AND  NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE Table_Name = 'Computer' AND Column_Name = MTP.PropertySystemName)

INSERT INTO #MissingColumns (TableName, ColumnName)
SELECT DISTINCT N'SQLDatabase', MTP.PropertySystemName
FROM   [OperationsManagerDW].[dbo].[ManagedEntityTypeProperty] MTP
INNER JOIN [dbo].[ManagedEntityDatabaseType] MDT ON MDT.ManagedEntityTypeRowId = MTP.ManagedEntityTypeRowId
WHERE  MDT.Aktive = 1
  AND  MTP.PropertySystemName IS NOT NULL
  AND  NOT EXISTS (SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
                   WHERE Table_Name = 'SQLDatabase' AND Column_Name = MTP.PropertySystemName)

IF (SELECT COUNT(*) FROM #MissingColumns) = 0
BEGIN
    PRINT 'Alle Zieltabellen sind aktuell – keine neuen Spalten erforderlich.'
    DROP TABLE #MissingColumns
    RETURN
END

SELECT
    TableName                   AS [Tabelle],
    ColumnName                  AS [Neue Spalte],
    N'NVARCHAR(256) NULL'       AS [Datentyp],
    CASE @WhatIf
        WHEN 1 THEN N'(WhatIf – keine Aenderung)'
        ELSE        N'ALTER TABLE wird ausgefuehrt'
    END                         AS [Aktion]
FROM #MissingColumns
ORDER BY TableName, ColumnName

IF @WhatIf = 1
BEGIN
    PRINT 'WhatIf-Modus: Keine Aenderungen vorgenommen.'
    DROP TABLE #MissingColumns
    RETURN
END

DECLARE @TableName  NVARCHAR(128)
DECLARE @ColumnName NVARCHAR(256)
DECLARE @stmt       NVARCHAR(500)
DECLARE @added      INT = 0
DECLARE @failed     INT = 0

DECLARE col_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT TableName, ColumnName FROM #MissingColumns ORDER BY TableName, ColumnName

OPEN col_cursor
FETCH NEXT FROM col_cursor INTO @TableName, @ColumnName

BEGIN TRY
    WHILE @@FETCH_STATUS = 0
    BEGIN
        SET @stmt = N'ALTER TABLE dbo.' + QUOTENAME(@TableName)
                  + N' ADD ' + QUOTENAME(@ColumnName) + N' NVARCHAR(256) NULL'
        BEGIN TRY
            EXEC sys.sp_executesql @stmt
            PRINT 'OK  | ' + @TableName + '.' + @ColumnName
            SET @added += 1
        END TRY
        BEGIN CATCH
            PRINT 'ERR | ' + @TableName + '.' + @ColumnName + ' -> ' + ERROR_MESSAGE()
            SET @failed += 1
        END CATCH
        FETCH NEXT FROM col_cursor INTO @TableName, @ColumnName
    END
END TRY
BEGIN CATCH
    IF CURSOR_STATUS('local', 'col_cursor') >= 0
    BEGIN
        CLOSE col_cursor
        DEALLOCATE col_cursor
    END
    DROP TABLE #MissingColumns
    THROW;
END CATCH

CLOSE col_cursor
DEALLOCATE col_cursor
DROP TABLE #MissingColumns

PRINT ''
PRINT 'Abgeschlossen: ' + CAST(@added AS VARCHAR) + ' Spalte(n) hinzugefuegt, '
                        + CAST(@failed AS VARCHAR) + ' Fehler.'
GO
PRINT '    OK  _00_ExtendTargetTables (neu)'
PRINT ''

-- ============================================================
-- ABSCHLUSS
-- ============================================================
PRINT '============================================================'
PRINT ' dtcSN Migration – Abgeschlossen'
PRINT ''
PRINT ' Pruefe auf verbleibende alte Prozedurnamen:'
SELECT
    name        AS [Alter Name (sollte leer sein)],
    create_date AS [Erstellt],
    modify_date AS [Geaendert]
FROM sys.objects
WHERE type = 'P'
  AND name IN (
        'ReadPoperties', 'ShowPoperties', 'SetCaseSensitiv',
        '03a_GetPropertiesForAllSQLDBS',
        '_02a_GetpropertiesForAllComputerEntries',
        '_02b_GetWindowsOSForAllComputerEntrys'
      )

PRINT ' Aktuelle Prozeduren nach Migration:'
SELECT
    name        AS [Prozedur],
    modify_date AS [Zuletzt geaendert]
FROM sys.objects
WHERE type = 'P'
  AND schema_id = SCHEMA_ID('dbo')
ORDER BY name
PRINT '============================================================'
GO
