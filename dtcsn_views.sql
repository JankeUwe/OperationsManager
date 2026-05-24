USE [dtcSN]
GO

-- ============================================================
-- dtcSN – Zusaetzliche Views fuer SQLNow Web-Applikation
-- Erstellt:  Uwe Janke, dtcSoftware  2026-05-16
-- Zweck:     Stellt aggregierte und angereicherte Sichten bereit,
--            die die DHTMLX-Handler der SQLNow-App benoetigen.
--            Ersetzt die in FSQL enthaltenen Views:
--              vEdition, vSQLMandant, vVersionen,
--              vDatabases, vDatabasesList, vComputerGrid
-- ============================================================

-- ── vEdition ───────────────────────────────────────────────
-- Verteilung der SQL Server Editionen (fuer Kreisdiagramm)
IF OBJECT_ID('dbo.vEdition', 'V') IS NOT NULL DROP VIEW dbo.vEdition
GO
CREATE VIEW [dbo].[vEdition]
AS
    SELECT
        ISNULL(Edition, '(unbekannt)') AS Edition,
        COUNT(*)                       AS Anzahl
    FROM  dbo.SQLServer
    WHERE NotFoundSince IS NULL
      AND Edition IS NOT NULL
    GROUP BY Edition
GO

-- ── vSQLMandant ────────────────────────────────────────────
-- Verteilung der SQL Server je Mandant (fuer Kreisdiagramm)
IF OBJECT_ID('dbo.vSQLMandant', 'V') IS NOT NULL DROP VIEW dbo.vSQLMandant
GO
CREATE VIEW [dbo].[vSQLMandant]
AS
    SELECT
        ISNULL(SQLMandantName, '(unbekannt)') AS Mandant,
        COUNT(*)                               AS Anzahl
    FROM  dbo.SQLServer
    WHERE NotFoundSince IS NULL
    GROUP BY SQLMandantName
GO

-- ── vVersionen ─────────────────────────────────────────────
-- Verteilung der SQL Server Versionen (fuer Kreisdiagramm)
IF OBJECT_ID('dbo.vVersionen', 'V') IS NOT NULL DROP VIEW dbo.vVersionen
GO
CREATE VIEW [dbo].[vVersionen]
AS
    SELECT
        ISNULL(VersionNr, '(unbekannt)') AS VersionNr,
        COUNT(*)                          AS Anzahl
    FROM  dbo.SQLServer
    WHERE NotFoundSince IS NULL
      AND VersionNr IS NOT NULL
    GROUP BY VersionNr
GO

-- ── vComputerGrid ──────────────────────────────────────────
-- Computer-Listenansicht fuer SQLNow Grid
IF OBJECT_ID('dbo.vComputerGrid', 'V') IS NOT NULL DROP VIEW dbo.vComputerGrid
GO
CREATE VIEW [dbo].[vComputerGrid]
AS
    SELECT
        ManagedEntityRowId,
        SQLCustomer,
        DomainDnsName,
        Maschine,
        NetbiosComputerName,
        DNSName,
        IPAddress,
        PhysicalProcessors,
        LogicalProcessors,
        VirtualMachineName,
        SQLMonitoringType,
        WindowsOS,
        NotFoundSince,
        NotFoundSinceDays
    FROM dbo.Computer
GO

-- ── vDatabases ─────────────────────────────────────────────
-- Datenbankansicht gefiltert nach SQL Server (fuer Detail-Grid)
IF OBJECT_ID('dbo.vDatabases', 'V') IS NOT NULL DROP VIEW dbo.vDatabases
GO
CREATE VIEW [dbo].[vDatabases]
AS
    SELECT
        DB.ManagedEntityRowId,
        DB.TopLevelHostManagedEntityRowId,
        DB.DisplayName                          AS DatabaseName,
        DB.Owner,
        DB.RecoveryModel,
        DB.Collation,
        DB.DatabaseAutogrow,
        DB.LogAutogrow,
        DB.Updateability,
        DB.UserAccess,
        DB.NotFoundSince,
        DB.NotFoundSinceDays,
        DB.Modified,
        DB.Inserted,
        DB.DatabaseType
    FROM dbo.SQLDatabase DB
GO

-- ── vDatabasesList ─────────────────────────────────────────
-- Alle Datenbanken angereichert mit SQL Server Infos (fuer Gesamt-Grid)
IF OBJECT_ID('dbo.vDatabasesList', 'V') IS NOT NULL DROP VIEW dbo.vDatabasesList
GO
CREATE VIEW [dbo].[vDatabasesList]
AS
    SELECT
        DB.ManagedEntityRowId                          AS ID,
        DB.ManagedEntityRowId,
        DB.TopLevelHostManagedEntityRowId,
        DB.DisplayName                                 AS DatabaseName,
        SS.PrincipalName,
        SS.InstanceName,
        DB.Owner,
        DB.RecoveryModel,
        DB.Collation,
        DB.DatabaseAutogrow,
        DB.LogAutogrow,
        DB.Updateability,
        DB.UserAccess,
        DB.NotFoundSince,
        DB.NotFoundSinceDays,
        SS.SQLMandantName,
        SS.SQLMandantNameShort,
        SS.Domain,
        SS.Edition,
        SS.VersionNr
    FROM  dbo.SQLDatabase DB
    LEFT JOIN dbo.SQLServer SS
        ON SS.ManagedEntityRowId = DB.TopLevelHostManagedEntityRowId
GO

PRINT 'Views angelegt: vEdition, vSQLMandant, vVersionen, vComputerGrid, vDatabases, vDatabasesList'
GO

-- ============================================================
-- Tabellenwertfunktionen fuer Property-Detailanzeige
-- Ersetzt SQLPropList / ComputerPropList aus FSQL.
-- Gibt alle gesetzten Spalten als (Property, Wert)-Paare zurueck.
-- ============================================================

-- ── SQLPropList ────────────────────────────────────────────
IF OBJECT_ID('dbo.SQLPropList', 'IF') IS NOT NULL DROP FUNCTION dbo.SQLPropList
GO
CREATE FUNCTION [dbo].[SQLPropList] (@ManagedEntityRowId BIGINT)
RETURNS TABLE AS RETURN
(
    SELECT p.Property, p.Wert
    FROM   dbo.SQLServer s
    CROSS APPLY (VALUES
        ('Maschine',                        s.Maschine),
        ('Domain',                          s.Domain),
        ('InstanceName',                    s.InstanceName),
        ('PrincipalName',                   s.PrincipalName),
        ('DisplayName',                     s.DisplayName),
        ('Version',                         s.Version),
        ('VersionNr',                       s.VersionNr),
        ('Edition',                         s.Edition),
        ('ServicePackVersion',              s.ServicePackVersion),
        ('AuthenticationMode',              s.AuthenticationMode),
        ('AuditLevel',                      s.AuditLevel),
        ('Account',                         s.Account),
        ('AgentName',                       s.AgentName),
        ('AgentClusterName',                s.AgentClusterName),
        ('Cluster',                         s.Cluster),
        ('TcpPorts',                        s.TcpPorts),
        ('ConnectionString',                s.ConnectionString),
        ('InstallPath',                     s.InstallPath),
        ('ToolsPath',                       s.ToolsPath),
        ('MasterDatabaseLocation',          s.MasterDatabaseLocation),
        ('MasterDatabaseLogLocation',       s.MasterDatabaseLogLocation),
        ('ErrorLogLocation',                s.ErrorLogLocation),
        ('ServiceName',                     s.ServiceName),
        ('ServiceClusterName',              s.ServiceClusterName),
        ('Language',                        s.Language),
        ('InstanceID',                      s.InstanceID),
        ('Type',                            s.Type),
        ('EnableErrorReporting',            s.EnableErrorReporting),
        ('FullTextSearchServiceName',       s.FullTextSearchServiceName),
        ('FullTextSearchServiceClusterName',s.FullTextSearchServiceClusterName),
        ('ReplicationDistributionDatabase', s.ReplicationDistributionDatabase),
        ('ReplicationWorkingDirectory',     s.ReplicationWorkingDirectory),
        ('EndOfMainstream',                 CAST(s.EndOfMainstream AS VARCHAR(50))),
        ('EndofExtended',                   CAST(s.EndofExtended   AS VARCHAR(50)))
    ) AS p(Property, Wert)
    WHERE  s.ManagedEntityRowId = @ManagedEntityRowId
      AND  p.Wert IS NOT NULL
      AND  p.Wert <> ''
)
GO

-- ── ComputerPropList ───────────────────────────────────────
IF OBJECT_ID('dbo.ComputerPropList', 'IF') IS NOT NULL DROP FUNCTION dbo.ComputerPropList
GO
CREATE FUNCTION [dbo].[ComputerPropList] (@Maschine NVARCHAR(256))
RETURNS TABLE AS RETURN
(
    SELECT p.Property, p.Wert
    FROM   dbo.Computer c
    CROSS APPLY (VALUES
        ('Maschine',            c.Maschine),
        ('NetbiosComputerName', c.NetbiosComputerName),
        ('DNSName',             c.DNSName),
        ('DomainDnsName',       c.DomainDnsName),
        ('PrincipalName',       c.PrincipalName),
        ('NetworkName',         c.NetworkName),
        ('IPAddress',           c.IPAddress),
        ('PhysicalProcessors',  c.PhysicalProcessors),
        ('LogicalProcessors',   c.LogicalProcessors),
        ('VirtualMachineName',  c.VirtualMachineName),
        ('Virtual_Server_Type', c.Virtual_Server_Type),
        ('SQLMonitoringType',   c.SQLMonitoringType),
        ('SQLMandant',          c.SQLMandant),
        ('SQLCustomer',         c.SQLCustomer),
        ('OrganizationalUnit',  c.OrganizationalUnit),
        ('WindowsOS',           c.WindowsOS)
    ) AS p(Property, Wert)
    WHERE  c.Maschine = @Maschine
      AND  p.Wert IS NOT NULL
      AND  p.Wert <> ''
)
GO

PRINT 'Funktionen angelegt: SQLPropList, ComputerPropList'
GO

-- ============================================================
-- Alert- und Maintenance-Views
-- Gleiche Namen wie die ehemaligen OperationsManagerDW-Views,
-- damit die SQLNow-Handler (AlertsOperationsManagerDW.ashx,
-- Maintain.ashx) unveraendert weiterarbeiten.
-- ============================================================

-- ── vAlertsOperationsManagerDW ─────────────────────────────
-- Ersetzt die gleichnamige View aus der OperationsManagerDW-DB.
-- Liefert importierte Alerts aus dbo.AlertHistory.
IF OBJECT_ID('dbo.vAlertsOperationsManagerDW', 'V') IS NOT NULL
    DROP VIEW dbo.vAlertsOperationsManagerDW
GO
CREATE VIEW [dbo].[vAlertsOperationsManagerDW]
AS
    SELECT
        [ID]                 AS AlertGuid,        -- Handler erwartet AlertGuid als PK
        [ManagedEntityRowId],
        [Category],
        [DisplayName],
        [Alertname],
        [AlertDescription],
        [RaisedDateTime],
        [Severity],
        [Priority]           AS priority,
        [RepeatCount]
    FROM [dbo].[AlertHistory]
GO

-- ── vMaintenanceHistory ────────────────────────────────────
-- Ersetzt die gleichnamige View aus der OperationsManagerDW-DB.
-- Liefert importierte Wartungsfenster aus dbo.MaintenanceHistory.
IF OBJECT_ID('dbo.vMaintenanceHistory', 'V') IS NOT NULL
    DROP VIEW dbo.vMaintenanceHistory
GO
CREATE VIEW [dbo].[vMaintenanceHistory]
AS
    SELECT
        [ID],
        [ManagedEntityRowId],
        [DisplayName],
        [StartDateTime],
        [EndDateTime],
        [ScheduledEndDateTime],
        [UserId],
        [Comment]            AS comment
    FROM [dbo].[MaintenanceHistory]
GO

PRINT 'Views angelegt: vAlertsOperationsManagerDW, vMaintenanceHistory'
GO
