USE [master]
GO

-- ============================================================
-- dtcSN – SCOM Reporting Layer
-- Erstellt:  Uwe Janke, dtcSoftware
-- Geaendert: 2026-05-13  (Ueberarbeitung / Bereinigung)
-- Zweck:     Eigene Reporting-Schicht ueber OperationsManagerDW.
--            Enthaelt SQL Server-, Computer- und Datenbank-Inventar
--            angereichert mit Kundenzuordnung und Support-Lifecycle.
--
-- Aenderungen gegenueber Original:
--   - Tippfehler behoben: RETRUNVAL, Insterted, Poperties, Copmuter,
--     SetCaseSensitiv, 03a_ (fehlendes Praefix)
--   - fn_CustDomainCount: Rueckgabetyp VARCHAR(255) -> INT
--   - Rollen: db_owner fuer Leseaccounts aufgeloest
--     SLAReporting -> db_datareader + db_datawriter
--     ServiceNowReader, FITSRead -> db_datareader
--   - _02b_GetWindowsOSForAllComputerEntries: Cursor -> set-basiert
--   - _03_InsertSQLDatabases: doppeltes Semikolon entfernt
--   - SET NOCOUNT ON in allen Prozeduren
--   - Keywords durchgaengig UPPERCASE
--   - Kommentare erweitert und korrigiert
-- ============================================================

-- ── Datenbank ──────────────────────────────────────────────
-- Datei-Pfade werden automatisch aus den SQL-Server-Standardpfaden
-- ermittelt. Kein hardcodierter Laufwerksbuchstabe notwendig.
DECLARE @DataPath NVARCHAR(512)
DECLARE @LogPath  NVARCHAR(512)
DECLARE @Sql      NVARCHAR(MAX)

-- Standardpfad fuer Datendateien
SELECT @DataPath = CAST(SERVERPROPERTY('InstanceDefaultDataPath') AS NVARCHAR(512))
-- Standardpfad fuer Logdateien
SELECT @LogPath  = CAST(SERVERPROPERTY('InstanceDefaultLogPath')  AS NVARCHAR(512))

-- Trailing Backslash sicherstellen
IF RIGHT(@DataPath, 1) <> N'\' SET @DataPath = @DataPath + N'\'
IF RIGHT(@LogPath,  1) <> N'\' SET @LogPath  = @LogPath  + N'\'

SET @Sql = N'
CREATE DATABASE [dtcSN]
    CONTAINMENT = NONE
    ON PRIMARY
    ( NAME = N''dtcSN'',
      FILENAME = N''' + @DataPath + N'dtcSN.mdf'',
      SIZE = 131072KB, MAXSIZE = UNLIMITED, FILEGROWTH = 131072KB )
    LOG ON
    ( NAME = N''dtcSN_log'',
      FILENAME = N''' + @LogPath  + N'dtcSN_log.ldf'',
      SIZE = 65536KB, MAXSIZE = 2048GB, FILEGROWTH = 65536KB )
    WITH CATALOG_COLLATION = DATABASE_DEFAULT, LEDGER = OFF'

PRINT 'Erstelle dtcSN:'
PRINT '  Data : ' + @DataPath + 'dtcSN.mdf'
PRINT '  Log  : ' + @LogPath  + 'dtcSN_log.ldf'

EXEC sys.sp_executesql @Sql
GO
ALTER DATABASE [dtcSN] SET COMPATIBILITY_LEVEL = 160
GO
IF (1 = FULLTEXTSERVICEPROPERTY('IsFullTextInstalled'))
BEGIN
    EXEC [dtcSN].[dbo].[sp_fulltext_database] @action = 'enable'
END
GO
ALTER DATABASE [dtcSN] SET ANSI_NULL_DEFAULT OFF
GO
ALTER DATABASE [dtcSN] SET ANSI_NULLS OFF
GO
ALTER DATABASE [dtcSN] SET ANSI_PADDING OFF
GO
ALTER DATABASE [dtcSN] SET ANSI_WARNINGS OFF
GO
ALTER DATABASE [dtcSN] SET ARITHABORT OFF
GO
ALTER DATABASE [dtcSN] SET AUTO_CLOSE OFF
GO
ALTER DATABASE [dtcSN] SET AUTO_SHRINK OFF
GO
ALTER DATABASE [dtcSN] SET AUTO_UPDATE_STATISTICS ON
GO
ALTER DATABASE [dtcSN] SET CURSOR_CLOSE_ON_COMMIT OFF
GO
ALTER DATABASE [dtcSN] SET CURSOR_DEFAULT GLOBAL
GO
ALTER DATABASE [dtcSN] SET CONCAT_NULL_YIELDS_NULL OFF
GO
ALTER DATABASE [dtcSN] SET NUMERIC_ROUNDABORT OFF
GO
ALTER DATABASE [dtcSN] SET QUOTED_IDENTIFIER OFF
GO
ALTER DATABASE [dtcSN] SET RECURSIVE_TRIGGERS OFF
GO
ALTER DATABASE [dtcSN] SET DISABLE_BROKER
GO
ALTER DATABASE [dtcSN] SET AUTO_UPDATE_STATISTICS_ASYNC OFF
GO
ALTER DATABASE [dtcSN] SET DATE_CORRELATION_OPTIMIZATION OFF
GO
ALTER DATABASE [dtcSN] SET TRUSTWORTHY OFF
GO
ALTER DATABASE [dtcSN] SET ALLOW_SNAPSHOT_ISOLATION OFF
GO
ALTER DATABASE [dtcSN] SET PARAMETERIZATION SIMPLE
GO
ALTER DATABASE [dtcSN] SET READ_COMMITTED_SNAPSHOT OFF
GO
ALTER DATABASE [dtcSN] SET HONOR_BROKER_PRIORITY OFF
GO
ALTER DATABASE [dtcSN] SET RECOVERY FULL
GO
ALTER DATABASE [dtcSN] SET MULTI_USER
GO
ALTER DATABASE [dtcSN] SET PAGE_VERIFY CHECKSUM
GO
ALTER DATABASE [dtcSN] SET DB_CHAINING OFF
GO
ALTER DATABASE [dtcSN] SET FILESTREAM( NON_TRANSACTED_ACCESS = OFF )
GO
ALTER DATABASE [dtcSN] SET TARGET_RECOVERY_TIME = 60 SECONDS
GO
ALTER DATABASE [dtcSN] SET DELAYED_DURABILITY = DISABLED
GO
ALTER DATABASE [dtcSN] SET ACCELERATED_DATABASE_RECOVERY = OFF
GO
EXEC sys.sp_db_vardecimal_storage_format N'dtcSN', N'ON'
GO
ALTER DATABASE [dtcSN] SET QUERY_STORE = ON
GO
ALTER DATABASE [dtcSN] SET QUERY_STORE (
    OPERATION_MODE              = READ_WRITE,
    CLEANUP_POLICY              = (STALE_QUERY_THRESHOLD_DAYS = 30),
    DATA_FLUSH_INTERVAL_SECONDS = 900,
    INTERVAL_LENGTH_MINUTES     = 60,
    MAX_STORAGE_SIZE_MB         = 1000,
    QUERY_CAPTURE_MODE          = AUTO,
    SIZE_BASED_CLEANUP_MODE     = AUTO,
    MAX_PLANS_PER_QUERY         = 200,
    WAIT_STATS_CAPTURE_MODE     = ON
)
GO
USE [dtcSN]
GO

-- ── Benutzer ───────────────────────────────────────────────
-- Benutzer und Rollen werden hier bewusst nicht angelegt.
-- Nach der Installation haben nur SysAdmins des Zielservers Zugriff.
-- Weitere Accounts (SLAReporting, ServiceNowReader, FITSRead,
-- NT SERVICE\HealthService) muessen erst als Login auf dem
-- Zielserver vorhanden sein, bevor sie als DB-User eingerichtet
-- werden. Vorlage fuer spaetere Einrichtung:
--
--   CREATE USER [SLAReporting]    FOR LOGIN [SLAReporting]    WITH DEFAULT_SCHEMA=[dbo]
--   ALTER ROLE [db_datareader] ADD MEMBER [SLAReporting]
--   ALTER ROLE [db_datawriter] ADD MEMBER [SLAReporting]
--
--   CREATE USER [ServiceNowReader] FOR LOGIN [ServiceNowReader] WITH DEFAULT_SCHEMA=[dbo]
--   ALTER ROLE [db_datareader] ADD MEMBER [ServiceNowReader]
--
--   CREATE USER [FITSRead]         FOR LOGIN [FITSRead]         WITH DEFAULT_SCHEMA=[dbo]
--   ALTER ROLE [db_datareader] ADD MEMBER [FITSRead]
--
--   CREATE ROLE [SCOM_HealthService]
--   CREATE USER [NT SERVICE\HealthService] FOR LOGIN [NT SERVICE\HealthService] WITH DEFAULT_SCHEMA=[dbo]
--   CREATE USER [NT AUTHORITY\SYSTEM]      FOR LOGIN [NT AUTHORITY\SYSTEM]      WITH DEFAULT_SCHEMA=[dbo]
--   ALTER ROLE [SCOM_HealthService] ADD MEMBER [NT SERVICE\HealthService]
--   ALTER ROLE [SCOM_HealthService] ADD MEMBER [NT AUTHORITY\SYSTEM]

-- ── User Defined Type ──────────────────────────────────────
CREATE TYPE [dbo].[Today] FROM [date] NOT NULL
GO

-- ============================================================
-- FUNKTIONEN
-- ============================================================

-- ── BuildPath ──────────────────────────────────────────────
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[BuildPath] (@Path VARCHAR(256))
RETURNS VARCHAR(250)
AS
BEGIN
    DECLARE @RETURNVAL AS VARCHAR(250)
    SELECT @RETURNVAL = CAST([dbo].ReplaceLastOccurrence(@Path, '.', ';') AS VARCHAR(256))
    RETURN @RETURNVAL
END
GO

-- ── CutDomain ──────────────────────────────────────────────
-- Extrahiert den Domain-Teil aus einem SCOM FullName-String.
-- Beispiel: 'Microsoft.SQLServer.Windows.DBEngine:srv.domain.corp.MSSQLSERVER'
--           -> 'domain.corp'
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[CutDomain] (@Fullname VARCHAR(255))
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

-- ── CutMaschine ────────────────────────────────────────────
-- Extrahiert den Kurznamen (linker Teil vor dem ersten Punkt).
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[CutMaschine] (@Name VARCHAR(255))
RETURNS VARCHAR(255)
AS
BEGIN
    DECLARE @Result VARCHAR(255)
    SET @Name  = REPLACE(@Name, ';', '.')
    SELECT @Result = REVERSE(RIGHT(REVERSE(@Name), LEN(@Name) - CHARINDEX('.', REVERSE(@Name), 1)))
    RETURN @Result
END
GO

-- ── fn_CustDomainCount ─────────────────────────────────────
-- Gibt die Anzahl der Domains eines Kunden zurueck (INT statt VARCHAR).
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[fn_CustDomainCount] (@CustomerID INT)
RETURNS INT
AS
BEGIN
    DECLARE @Result AS INT
    SELECT @Result = COUNT(*) FROM [dbo].[CustomerDomain] WHERE CustomerID = @CustomerID
    RETURN @Result
END
GO

-- ── GetCustomerName ────────────────────────────────────────
-- Wird in dbo.SQLServer als berechnete Spalte [SQLMandantName] verwendet.
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[GetCustomerName] (@DomainDnsName VARCHAR(100))
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

-- ── GetCustomerNameLong ────────────────────────────────────
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[GetCustomerNameLong] (@CustomerID INT)
RETURNS NVARCHAR(256)
AS
BEGIN
    DECLARE @RETURNVAL AS NVARCHAR(256)
    SELECT @RETURNVAL = [NameLong] FROM [dbo].[Customer] WHERE CustomerID = @CustomerID
    RETURN @RETURNVAL
END
GO

-- ── GetCustomerNameLong4Domain ─────────────────────────────
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[GetCustomerNameLong4Domain] (@CustomerID INT)
RETURNS NVARCHAR(256)
AS
BEGIN
    DECLARE @RETURNVAL AS NVARCHAR(256)
    SELECT @RETURNVAL = [NameLong] FROM [dbo].[Customer] WHERE CustomerID = @CustomerID
    RETURN @RETURNVAL
END
GO

-- ── GetCustomerNameShort ───────────────────────────────────
-- Wird in dbo.SQLServer als berechnete Spalte [SQLMandantNameShort] verwendet.
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[GetCustomerNameShort] (@DomainDnsName VARCHAR(100))
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

-- ── GetCustomerNameShort4Domain ────────────────────────────
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[GetCustomerNameShort4Domain] (@CustomerID INT)
RETURNS NVARCHAR(256)
AS
BEGIN
    DECLARE @RETURNVAL AS NVARCHAR(256)
    SELECT @RETURNVAL = [Name] FROM [dbo].[Customer] WHERE CustomerID = @CustomerID
    RETURN @RETURNVAL
END
GO

-- ── GetDatabaseType ────────────────────────────────────────
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[GetDatabaseType] (@ManagedEntityTypeRowId INT)
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

-- ── GetEndofExtended ───────────────────────────────────────
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[GetEndofExtended] (@ver VARCHAR(255))
RETURNS NVARCHAR(256)
AS
BEGIN
    DECLARE @VersionNr   NVARCHAR(10)
    DECLARE @ReturnValue NVARCHAR(256)

    SELECT @VersionNr   = sqlversion
    FROM   [dbo].[SQLVersion]
    WHERE  LEFT(@ver, LEN([productversion])) = [productversion]

    SELECT @ReturnValue = EndofExtended
    FROM   dbo.Support
    WHERE  [VersionNr] = @VersionNr

    RETURN @ReturnValue
END
GO

-- ── GetEndOfMainstream ─────────────────────────────────────
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[GetEndOfMainstream] (@ver VARCHAR(255))
RETURNS NVARCHAR(256)
AS
BEGIN
    DECLARE @VersionNr   NVARCHAR(10)
    DECLARE @ReturnValue NVARCHAR(256)

    SELECT @VersionNr   = sqlversion
    FROM   [dbo].[SQLVersion]
    WHERE  LEFT(@ver, LEN([productversion])) = [productversion]

    SELECT @ReturnValue = [EndOfMainstream]
    FROM   dbo.Support
    WHERE  [VersionNr] = @VersionNr

    RETURN @ReturnValue
END
GO

-- ── GetSQLVersion ──────────────────────────────────────────
-- Wird in dbo.SQLServer als berechnete Spalte [VersionNr] verwendet.
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[GetSQLVersion] (@ver VARCHAR(255))
RETURNS NVARCHAR(256)
AS
BEGIN
    DECLARE @ReturnValue NVARCHAR(256)
    SELECT @ReturnValue = sqlversion
    FROM   [dbo].[SQLVersion]
    WHERE  LEFT(@ver, LEN([productversion])) = [productversion]
    RETURN @ReturnValue
END
GO

-- ── ReplaceLastOccurrence ──────────────────────────────────
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE FUNCTION [dbo].[ReplaceLastOccurrence]
(
    @Input       NVARCHAR(MAX),
    @SearchChar  NCHAR(1),
    @ReplaceChar NCHAR(1)
)
RETURNS NVARCHAR(MAX)
AS
BEGIN
    RETURN
        CASE
            WHEN @Input IS NULL OR @Input = ''      THEN @Input
            WHEN CHARINDEX(@SearchChar, @Input) = 0 THEN @Input
            ELSE
                STUFF(
                    @Input,
                    LEN(@Input) - CHARINDEX(@SearchChar, REVERSE(@Input)) + 1,
                    1,
                    @ReplaceChar
                )
        END
END
GO

-- ============================================================
-- VIEWS  (Passthrough auf OperationsManagerDW)
-- ============================================================
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vManagedEntity]
AS
    SELECT * FROM [OperationsManagerDW].dbo.vManagedEntity
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vManagedEntityProperty]
AS
    SELECT * FROM [OperationsManagerDW].dbo.ManagedEntityProperty
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vManagedEntityTypeAll]
AS
    SELECT [ManagedEntityTypeRowId]
          ,[ManagedEntityTypeGuid]
          ,[ManagementPackRowId]
          ,[ManagedEntityTypeSystemName]
          ,[ManagedEntityTypeDefaultName]
          ,[ManagedEntityTypeDefaultDescription]
    FROM   [OperationsManagerDW].[dbo].[ManagedEntityType]
GO

SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE VIEW [dbo].[vManagedEntityTypeProperty]
AS
    SELECT * FROM OperationsManagerDW.[dbo].[ManagedEntityTypeProperty]
GO

-- ============================================================
-- TABELLEN
-- ============================================================

-- ── Computer ───────────────────────────────────────────────
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Computer]
(
    [ID]                             BIGINT        IDENTITY(1,1) NOT NULL,
    [ManagedEntityRowId]             BIGINT        NULL,
    [TopLevelHostManagedEntityRowId] BIGINT        NULL,
    [ManagedEntityTypeRowId]         BIGINT        NULL,
    [ManagedEntityDefaultName]       NVARCHAR(256) NULL,
    [Path]                           NVARCHAR(256) NULL,
    [FullName]                       NVARCHAR(256) NULL,
    [DisplayName]                    NVARCHAR(256) NULL,
    [Maschine]                       NVARCHAR(256) NULL,
    [DNSName]                        NVARCHAR(256) NULL,
    [DomainDnsName]                  NVARCHAR(256) NULL,
    [IPAddress]                      NVARCHAR(256) NULL,
    [LogicalProcessors]              NVARCHAR(256) NULL,
    [NetbiosComputerName]            NVARCHAR(256) NULL,
    [NetworkName]                    NVARCHAR(256) NULL,
    [OrganizationalUnit]             NVARCHAR(256) NULL,
    [PhysicalProcessors]             NVARCHAR(256) NULL,
    [PrincipalName]                  NVARCHAR(256) NULL,
    [SQLCustomer]    AS ([dbo].[GetCustomerName]([DomainDnsName])),
    [SQLMandant]                     NVARCHAR(256) NULL,
    [SQLMonitoringType]              NVARCHAR(256) NULL,
    [Virtual_Server_Type]            NVARCHAR(256) NULL,
    [VirtualMachineName]             NVARCHAR(256) NULL,
    [Modified]                       DATE          NULL,
    [Inserted]                       DATE          NOT NULL,
    [IsSCOM]                         BIT           NOT NULL,
    [DWCreatedDateTime]              DATE          NULL,
    [NotFoundSince]                  DATE          NULL,
    [NotFoundSinceDays] AS (DATEDIFF(DAY, [NotFoundSince], GETDATE())),
    [WindowsOS]                      NVARCHAR(256) NULL,
    CONSTRAINT [PK_Computer] PRIMARY KEY CLUSTERED ([ID] ASC)
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
              ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON,
              OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF, DATA_COMPRESSION = PAGE)
        ON [PRIMARY]
) ON [PRIMARY]
GO

-- ── Customer ───────────────────────────────────────────────
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Customer]
(
    [CustomerId]    INT          IDENTITY(1,1) NOT NULL,
    [Name]          VARCHAR(50)  NOT NULL,
    [NameLong]      VARCHAR(120) NULL,
    [Address]       VARCHAR(120) NULL,
    [Zip]           VARCHAR(50)  NULL,
    [City]          VARCHAR(120) NULL,
    [Notes]         VARCHAR(1024) NULL,
    [Domains]       AS ([dbo].[fn_CustDomainCount]([CustomerId])),
    [Computers]     INT          NULL,
    [Installations] INT          NULL,
    CONSTRAINT [PK_Customer] PRIMARY KEY CLUSTERED ([CustomerId] ASC)
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
              ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
        ON [PRIMARY]
) ON [PRIMARY]
GO

-- ── CustomerDomain ─────────────────────────────────────────
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[CustomerDomain]
(
    [DomainId]          INT           IDENTITY(1,1) NOT NULL,
    [CustomerId]        INT           NULL,
    [CustomerName]      AS ([dbo].[GetCustomerNameLong4Domain]([CustomerID])),
    [CustomerShortName] AS ([dbo].[GetCustomerNameShort4Domain]([CustomerID])),
    [DomainDnsName]     NVARCHAR(256) NOT NULL,
    [JumpServer1]       NVARCHAR(256) NULL,
    [JumpServer2]       NVARCHAR(256) NULL,
    [JumpServer3]       NVARCHAR(256) NULL,
    [JumpServer4]       NVARCHAR(256) NULL,
    [Notes]             NVARCHAR(1024) NULL,
    CONSTRAINT [PK_CustomerDomain] PRIMARY KEY CLUSTERED ([DomainId] ASC)
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
              ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
        ON [PRIMARY]
) ON [PRIMARY]
GO

-- ── ExcludeDB ──────────────────────────────────────────────
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ExcludeDB]
(
    [Name] VARCHAR(50) NOT NULL,
    CONSTRAINT [PK_ExcludeDB] PRIMARY KEY CLUSTERED ([Name] ASC)
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
              ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
        ON [PRIMARY]
) ON [PRIMARY]
GO

-- ── ManagedEntityCompType ──────────────────────────────────
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ManagedEntityCompType]
(
    [ManagedEntityTypeRowId]      INT          NOT NULL,
    [ManagedEntityTypeSystemName] VARCHAR(255) NOT NULL
) ON [PRIMARY]
GO

-- ── ManagedEntityDatabaseType ──────────────────────────────
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ManagedEntityDatabaseType]
(
    [ManagedEntityTypeRowId]              INT              NOT NULL,
    [ManagedEntityTypeGuid]               UNIQUEIDENTIFIER NOT NULL,
    [ManagementPackRowId]                 INT              NOT NULL,
    [ManagedEntityTypeSystemName]         NVARCHAR(256)    NOT NULL,
    [ManagedEntityTypeDefaultName]        NVARCHAR(256)    NOT NULL,
    [ManagedEntityTypeDefaultDescription] NVARCHAR(MAX)    NULL,
    [Aktive]                              BIT              NOT NULL,
    CONSTRAINT [PK_ManagedEntityDatabaseType] PRIMARY KEY CLUSTERED ([ManagedEntityTypeRowId] ASC)
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
              ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
        ON [PRIMARY]
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

-- ── ManagedSQLEntityType ───────────────────────────────────
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[ManagedSQLEntityType]
(
    [ManagedEntityTypeRowId]      INT           NOT NULL,
    [ManagedEntityTypeSystemName] NVARCHAR(255) NOT NULL,
    [Description]                 NVARCHAR(255) NULL,
    [ManagedEntityTypeSQLId]      INT           NULL,
    [Aktiv]                       BIT           NOT NULL,
    CONSTRAINT [PK_ManagedSQLEntityType] PRIMARY KEY CLUSTERED ([ManagedEntityTypeRowId] ASC)
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
              ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
        ON [PRIMARY]
) ON [PRIMARY]
GO

-- ── SQLDatabase ────────────────────────────────────────────
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SQLDatabase]
(
    [ID]                             BIGINT       IDENTITY(1,1) NOT NULL,
    [ManagedEntityRowId]             BIGINT       NULL,
    [TopLevelHostManagedEntityRowId] BIGINT       NULL,
    [Path]                           VARCHAR(255) NULL,
    [DisplayName]                    VARCHAR(255) NULL,
    [ManagedEntityTypeRowId]         BIGINT       NULL,
    [DatabaseType]   AS ([dbo].[GetDatabaseType]([ManagedEntityTypeRowId])),
    [Collation]                      VARCHAR(255) NULL,
    [DatabaseAutogrow]               VARCHAR(255) NULL,
    [DatabaseName]                   VARCHAR(255) NULL,
    [LogAutogrow]                    VARCHAR(255) NULL,
    [Owner]                          VARCHAR(255) NULL,
    [RecoveryModel]                  VARCHAR(255) NULL,
    [Updateability]                  VARCHAR(255) NULL,
    [UserAccess]                     VARCHAR(255) NULL,
    [NotFoundSince]                  DATETIME     NULL,
    [NotFoundSinceDays] AS (DATEDIFF(DAY, [NotFoundSince], GETDATE())),
    [Modified]                       DATETIME     NULL,
    [Inserted]                       DATETIME     NOT NULL,
    [tempPath]       AS ([dbo].[BuildPath]([Path])),
    CONSTRAINT [PK_SQLDatabases] PRIMARY KEY CLUSTERED ([ID] ASC)
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
              ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
        ON [PRIMARY]
) ON [PRIMARY]
GO

-- ── SQLServer ──────────────────────────────────────────────
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SQLServer]
(
    [ID]                                BIGINT       IDENTITY(1,1) NOT NULL,
    [ManagedEntityRowId]                BIGINT       NOT NULL,
    [TopLevelHostManagedEntityRowId]    BIGINT       NULL,
    [ManagedEntityDefaultName]          VARCHAR(256) NULL,
    [DWCreatedDateTime]                 DATETIME     NULL,
    [Changes]                           INT          NULL,
    [SQLMandantNameShort] AS ([dbo].[GetCustomerNameShort]([Domain])),
    [SQLMandantName]      AS ([dbo].[GetCustomerName]([Domain])),
    [Maschine]                          VARCHAR(256) NULL,
    [Path]                              VARCHAR(256) NULL,
    [Account]                           VARCHAR(256) NULL,
    [AgentClusterName]                  VARCHAR(256) NULL,
    [AgentName]                         VARCHAR(256) NULL,
    [AuditLevel]                        VARCHAR(256) NULL,
    [AuthenticationMode]                VARCHAR(256) NULL,
    [Cluster]                           VARCHAR(256) NULL,
    [ConnectionString]                  VARCHAR(256) NULL,
    [DisplayName]                       VARCHAR(256) NULL,
    [Domain]                            VARCHAR(256) NULL,
    [Edition]                           VARCHAR(256) NULL,
    [EnableErrorReporting]              VARCHAR(256) NULL,
    [ErrorLogLocation]                  VARCHAR(256) NULL,
    [FullName]                          VARCHAR(256) NULL,
    [FullTextSearchServiceClusterName]  VARCHAR(256) NULL,
    [FullTextSearchServiceName]         VARCHAR(256) NULL,
    [InstallPath]                       VARCHAR(256) NULL,
    [InstanceID]                        VARCHAR(256) NULL,
    [InstanceName]                      VARCHAR(256) NULL,
    [Language]                          VARCHAR(256) NULL,
    [MasterDatabaseLocation]            VARCHAR(256) NULL,
    [MasterDatabaseLogLocation]         VARCHAR(256) NULL,
    [PrincipalName]                     VARCHAR(256) NULL,
    [ReplicationDistributionDatabase]   VARCHAR(256) NULL,
    [ReplicationWorkingDirectory]       VARCHAR(256) NULL,
    [ServiceClusterName]                VARCHAR(256) NULL,
    [ServiceName]                       VARCHAR(256) NULL,
    [ServicePackVersion]                VARCHAR(256) NULL,
    [TcpPorts]                          VARCHAR(256) NULL,
    [ToolsPath]                         VARCHAR(256) NULL,
    [Type]                              VARCHAR(256) NULL,
    [Version]                           VARCHAR(256) NULL,
    [VersionNr]       AS ([dbo].[GetSQLVersion]([Version])),
    [Modified]                          DATETIME     NULL,
    [Inserted]                          DATETIME     NOT NULL,
    [IsSCOM]                            BIT          NOT NULL,
    [NotFoundSince]                     DATETIME     NULL,
    [NotFoundSinceDay] AS (DATEDIFF(DAY, [NotFoundSince], GETDATE())),
    [EndOfMainstream]  AS ([dbo].[GetEndOfMainstream]([Version])),
    [EndofExtended]    AS ([dbo].[GetEndofExtended]([Version])),
    [tempPath]         AS ([dbo].[BuildPath]([Path])),
    CONSTRAINT [PK_SQLServers] PRIMARY KEY CLUSTERED ([ID] ASC)
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
              ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
        ON [PRIMARY]
) ON [PRIMARY]
GO

-- ── SQLVersion ─────────────────────────────────────────────
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[SQLVersion]
(
    [productversion] VARCHAR(15) NOT NULL,
    [sqlversion]     VARCHAR(15) NOT NULL,
    CONSTRAINT [PK_ProductVersion] PRIMARY KEY CLUSTERED ([productversion] ASC)
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
              ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON, OPTIMIZE_FOR_SEQUENTIAL_KEY = OFF)
        ON [PRIMARY]
) ON [PRIMARY]
GO

-- ── Support ────────────────────────────────────────────────
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[Support]
(
    [VersionNr]       INT  NOT NULL,
    [ReleaseDate]     DATE NOT NULL,
    [EndOfMainstream] DATE NOT NULL,
    [EndofExtended]   DATE NOT NULL
) ON [PRIMARY]
GO

-- ── AlertHistory ───────────────────────────────────────────
-- Importierte SCOM-Alerts, gefiltert auf SQL-relevante Objekte.
-- Retention: konfigurierbar in _04_ImportAlerts (Standard 90 Tage).
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[AlertHistory]
(
    [ID]                    BIGINT        IDENTITY(1,1) NOT NULL,
    [AlertGuid]             NVARCHAR(50)  NOT NULL,           -- SCOM Alert-GUID (Deduplizierung)
    [ManagedEntityRowId]    BIGINT        NOT NULL,           -- FK -> SQLServer / Computer
    [Category]              NVARCHAR(256) NULL,
    [DisplayName]           NVARCHAR(256) NULL,               -- Managed Entity Display Name
    [Alertname]             NVARCHAR(256) NULL,
    [AlertDescription]      NVARCHAR(MAX) NULL,
    [RaisedDateTime]        DATETIME      NULL,
    [Severity]              NVARCHAR(50)  NULL,               -- Error / Warning / Information
    [Priority]              NVARCHAR(50)  NULL,
    [RepeatCount]           INT           NULL,
    [Imported]              DATETIME      NOT NULL,
    CONSTRAINT [PK_AlertHistory] PRIMARY KEY CLUSTERED ([ID] ASC)
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
              ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
        ON [PRIMARY],
    CONSTRAINT [UQ_AlertHistory_Guid] UNIQUE NONCLUSTERED ([AlertGuid])
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

-- ── MaintenanceHistory ─────────────────────────────────────
-- Importierte SCOM-Wartungsfenster, gefiltert auf SQL-Hosts.
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE TABLE [dbo].[MaintenanceHistory]
(
    [ID]                    BIGINT        IDENTITY(1,1) NOT NULL,
    [MaintenanceRowId]      BIGINT        NOT NULL,           -- SCOM MaintenanceModeHistory PK
    [ManagedEntityRowId]    BIGINT        NOT NULL,           -- FK -> Computer
    [DisplayName]           NVARCHAR(256) NULL,
    [StartDateTime]         DATETIME      NULL,
    [EndDateTime]           DATETIME      NULL,
    [ScheduledEndDateTime]  DATETIME      NULL,
    [UserId]                NVARCHAR(256) NULL,
    [Comment]               NVARCHAR(MAX) NULL,
    [Imported]              DATETIME      NOT NULL,
    CONSTRAINT [PK_MaintenanceHistory] PRIMARY KEY CLUSTERED ([ID] ASC)
        WITH (PAD_INDEX = OFF, STATISTICS_NORECOMPUTE = OFF, IGNORE_DUP_KEY = OFF,
              ALLOW_ROW_LOCKS = ON, ALLOW_PAGE_LOCKS = ON)
        ON [PRIMARY],
    CONSTRAINT [UQ_MaintenanceHistory_RowId] UNIQUE NONCLUSTERED ([MaintenanceRowId])
) ON [PRIMARY] TEXTIMAGE_ON [PRIMARY]
GO

-- ── Default-Constraints ────────────────────────────────────
ALTER TABLE [dbo].[Computer]    ADD CONSTRAINT [DF_Computer_Inserted]                DEFAULT (GETDATE()) FOR [Inserted]
GO
ALTER TABLE [dbo].[Computer]    ADD CONSTRAINT [DF_Computer_IsSCOM]                  DEFAULT ((0))       FOR [IsSCOM]
GO
ALTER TABLE [dbo].[ManagedEntityDatabaseType] ADD CONSTRAINT [DF_ManagedEntityDatabaseType_Aktive] DEFAULT ((1)) FOR [Aktive]
GO
ALTER TABLE [dbo].[SQLDatabase] ADD CONSTRAINT [DF_SQLDatabase_Inserted]             DEFAULT (GETDATE()) FOR [Inserted]
GO
ALTER TABLE [dbo].[SQLServer]      ADD CONSTRAINT [DF_SQLServer_Inserted]      DEFAULT (GETDATE()) FOR [Inserted]
GO
ALTER TABLE [dbo].[AlertHistory]   ADD CONSTRAINT [DF_AlertHistory_Imported]   DEFAULT (GETDATE()) FOR [Imported]
GO
ALTER TABLE [dbo].[MaintenanceHistory] ADD CONSTRAINT [DF_MaintenanceHistory_Imported] DEFAULT (GETDATE()) FOR [Imported]
GO

-- Performance-Indizes fuer Alert/Maintenance-Abfragen
CREATE NONCLUSTERED INDEX [IX_AlertHistory_ManagedEntityRowId]
    ON [dbo].[AlertHistory] ([ManagedEntityRowId]) INCLUDE ([RaisedDateTime], [Severity])
GO
CREATE NONCLUSTERED INDEX [IX_MaintenanceHistory_ManagedEntityRowId]
    ON [dbo].[MaintenanceHistory] ([ManagedEntityRowId]) INCLUDE ([StartDateTime])
GO

-- ── Foreign Keys ───────────────────────────────────────────
ALTER TABLE [dbo].[CustomerDomain] WITH CHECK
    ADD CONSTRAINT [FK_CustomerDomain_Customer] FOREIGN KEY ([CustomerId])
    REFERENCES [dbo].[Customer] ([CustomerId])
GO
ALTER TABLE [dbo].[CustomerDomain] CHECK CONSTRAINT [FK_CustomerDomain_Customer]
GO

-- ============================================================
-- STORED PROCEDURES
-- ============================================================

-- ── _00_ExtendTargetTables ─────────────────────────────────
-- Vergleicht die Properties aus OperationsManagerDW mit den Spalten
-- der drei Zieltabellen (SQLServer, Computer, SQLDatabase).
-- Fehlende Spalten werden als NVARCHAR(256) NULL hinzugefuegt,
-- sodass ReadProperties neue Properties beim naechsten Lauf
-- automatisch einlesen kann.
--
-- @WhatIf = 1 : Nur anzeigen, was geaendert wuerde (kein ALTER TABLE).
-- @WhatIf = 0 : Aenderungen durchfuehren (Standard).
--
-- Aufruf:
--   EXEC _00_ExtendTargetTables              -- Aenderungen ausfuehren
--   EXEC _00_ExtendTargetTables @WhatIf = 1 -- Vorschau
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[_00_ExtendTargetTables]
    @WhatIf BIT = 0
AS
SET NOCOUNT ON;

-- ── Fehlende Spalten ermitteln ─────────────────────────────
CREATE TABLE #MissingColumns
(
    TableName  NVARCHAR(128) NOT NULL,
    ColumnName NVARCHAR(256) NOT NULL
)

-- SQLServer: Properties aus ManagedSQLEntityType (Aktiv = 1)
INSERT INTO #MissingColumns (TableName, ColumnName)
SELECT DISTINCT
    N'SQLServer'          AS TableName,
    MTP.PropertySystemName AS ColumnName
FROM   [OperationsManagerDW].[dbo].[ManagedEntityTypeProperty] MTP
INNER JOIN [dbo].[ManagedSQLEntityType] MST
    ON MST.ManagedEntityTypeRowId = MTP.ManagedEntityTypeRowId
WHERE  MST.Aktiv = 1
  AND  MTP.PropertySystemName IS NOT NULL
  AND  NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE  Table_Name  = 'SQLServer'
          AND  Column_Name = MTP.PropertySystemName
       )

-- Computer: Properties aus ManagedEntityCompType
INSERT INTO #MissingColumns (TableName, ColumnName)
SELECT DISTINCT
    N'Computer'           AS TableName,
    MTP.PropertySystemName AS ColumnName
FROM   [OperationsManagerDW].[dbo].[ManagedEntityTypeProperty] MTP
INNER JOIN [dbo].[ManagedEntityCompType] MCT
    ON MCT.ManagedEntityTypeRowId = MTP.ManagedEntityTypeRowId
WHERE  MTP.PropertySystemName IS NOT NULL
  AND  NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE  Table_Name  = 'Computer'
          AND  Column_Name = MTP.PropertySystemName
       )

-- SQLDatabase: Properties aus ManagedEntityDatabaseType (Aktive = 1)
INSERT INTO #MissingColumns (TableName, ColumnName)
SELECT DISTINCT
    N'SQLDatabase'        AS TableName,
    MTP.PropertySystemName AS ColumnName
FROM   [OperationsManagerDW].[dbo].[ManagedEntityTypeProperty] MTP
INNER JOIN [dbo].[ManagedEntityDatabaseType] MDT
    ON MDT.ManagedEntityTypeRowId = MTP.ManagedEntityTypeRowId
WHERE  MDT.Aktive = 1
  AND  MTP.PropertySystemName IS NOT NULL
  AND  NOT EXISTS (
        SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS
        WHERE  Table_Name  = 'SQLDatabase'
          AND  Column_Name = MTP.PropertySystemName
       )

-- ── Ergebnis / WhatIf-Ausgabe ──────────────────────────────
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

-- ── Spalten hinzufuegen ────────────────────────────────────
DECLARE @TableName  NVARCHAR(128)
DECLARE @ColumnName NVARCHAR(256)
DECLARE @stmt       NVARCHAR(500)
DECLARE @added      INT = 0
DECLARE @failed     INT = 0

DECLARE col_cursor CURSOR LOCAL FAST_FORWARD FOR
    SELECT TableName, ColumnName
    FROM   #MissingColumns
    ORDER  BY TableName, ColumnName

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
    ;THROW;
END CATCH

CLOSE col_cursor
DEALLOCATE col_cursor
DROP TABLE #MissingColumns

PRINT ''
PRINT 'Abgeschlossen: ' + CAST(@added AS VARCHAR) + ' Spalte(n) hinzugefuegt, '
                        + CAST(@failed AS VARCHAR) + ' Fehler.'
GO

-- ── _01_InsertSQLServer ────────────────────────────────────
-- Synchronisiert SQL Server-Eintraege aus SCOM (OperationsManagerDW)
-- in dbo.SQLServer per MERGE.
--   INSERT : Neue Eintraege werden angelegt.
--   UPDATE1: Wiedergefundene Eintraege -> NotFoundSince = NULL.
--   UPDATE2: Verschwundene Eintraege   -> NotFoundSince = GETDATE().
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[_01_InsertSQLServer]
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
    INNER JOIN [dbo].[vManagedEntityProperty] MP ON MP.ManagedEntityRowId    = ME.ManagedEntityRowId
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

-- ── _01a_GetPropertiesForAllSQLEntries ─────────────────────
-- Holt alle ManagedEntityRowIds aus dbo.SQLServer und uebergibt
-- diese an ReadProperties, das die SCOM-Properties per XML
-- zurueck in die Zieltabelle schreibt.
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[_01a_GetPropertiesForAllSQLEntries]
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
    ;THROW;
END CATCH

CLOSE db_cursor
DEALLOCATE db_cursor
GO

-- ── _02_InsertComputer ─────────────────────────────────────
-- Synchronisiert Computer-Eintraege aus SCOM in dbo.Computer per MERGE.
-- Nur Computer, die einem bekannten SQL Server (dbo.SQLServer) zugeordnet sind.
-- Duplikate (gleiche ManagedEntityRowId) werden am Ende bereinigt.
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[_02_InsertComputer]
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

-- Duplikate bereinigen (gleiche ManagedEntityRowId, niedrigste ID behalten)
DELETE T
FROM (
    SELECT *
          ,ROW_NUMBER() OVER (PARTITION BY ManagedEntityRowId ORDER BY ID) AS DupRank
    FROM   Computer
) AS T
WHERE DupRank > 1
GO

-- ── _02a_GetPropertiesForAllComputerEntries ────────────────
-- Ermittelt die ManagedEntityRowId fuer jeden Computer-Eintrag
-- und uebergibt diese an ReadProperties.
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[_02a_GetPropertiesForAllComputerEntries]
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
    ;THROW;
END CATCH

CLOSE db_cursor
DEALLOCATE db_cursor
GO

-- ── _02b_GetWindowsOSForAllComputerEntries ─────────────────
-- Setzt das Windows-OS fuer alle Computer-Eintraege (set-basiert).
-- ManagedEntityTypeRowId = 62 entspricht dem Windows OS-Typ in SCOM.
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[_02b_GetWindowsOSForAllComputerEntries]
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
    ;THROW;
END CATCH
GO

-- ── _03_InsertSQLDatabases ─────────────────────────────────
-- Synchronisiert SQL-Datenbank-Eintraege aus SCOM in dbo.SQLDatabase per MERGE.
-- Systemdatenbanken (ExcludeDB) und inaktive Typen werden ausgeschlossen.
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[_03_InsertSQLDatabases]
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

-- ── _03a_GetPropertiesForAllSQLDBS ────────────────────────
-- Ermittelt die ManagedEntityRowId fuer jede SQL-Datenbank
-- und uebergibt diese an ReadProperties.
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[_03a_GetPropertiesForAllSQLDBS]
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
    ;THROW;
END CATCH

CLOSE db_cursor
DEALLOCATE db_cursor
GO

-- ── ReadProperties ─────────────────────────────────────────
-- Liest SCOM-Properties eines ManagedEntity aus dem XML-Feld
-- (OperationsManagerDW.dbo.ManagedEntityProperty) und schreibt
-- die Werte per dynamischem UPDATE in die Zieltabelle (@Target).
-- Nur Spalten, die in INFORMATION_SCHEMA.COLUMNS existieren,
-- werden aktualisiert. QUOTENAME schuetzt Spaltennamen vor Injection.
-- Janke 2022
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[ReadProperties]
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
FROM   SQLProperties                                    LA
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

-- ── SetCaseSensitive ───────────────────────────────────────
-- Uebertraegt den Path-Wert vom SQL Server auf die zugehoerigen
-- Datenbank-Eintraege (Case-Sensitive-Korrektur fuer Pfadvergleiche).
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[SetCaseSensitive]
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
    ;THROW;
END CATCH
GO

-- ── ShowProperties ─────────────────────────────────────────
-- Hilfsprozedur: Zeigt alle Properties eines ManagedEntity an.
-- Verwendung: EXEC ShowProperties <ManagedEntityRowId>
-- Janke 2022
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROC [dbo].[ShowProperties]
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

-- ============================================================
-- EXTENDED PROPERTIES
-- ============================================================
EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Beinhaltet die Namen der Kunden (Mandanten)',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'Customer'
GO
EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Beinhaltet die DNS-Domains der jeweiligen Kunden. Anhand der Domain wird entschieden, um welchen Kunden es sich handelt.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'CustomerDomain'
GO
EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'1 = Eintrag wird gelesen  |  0 = Eintrag wird ignoriert',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'ManagedSQLEntityType',
    @level2type = N'COLUMN', @level2name = N'Aktiv'
GO
EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Beinhaltet die passenden Eintraege aus SCOM, die als SQL-Systeme erkannt werden.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'ManagedSQLEntityType'
GO
EXEC sys.sp_addextendedproperty
    @name = N'MS_Description',
    @value = N'Berechneter Kurzname des Kunden (Mandant) anhand der Domain.',
    @level0type = N'SCHEMA', @level0name = N'dbo',
    @level1type = N'TABLE',  @level1name = N'SQLServer',
    @level2type = N'COLUMN', @level2name = N'SQLMandantName'
GO

USE [master]
GO
ALTER DATABASE [dtcSN] SET READ_WRITE
GO
