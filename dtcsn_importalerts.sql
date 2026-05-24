USE [dtcSN]
GO

-- ============================================================
-- dtcSN – Import-Stored-Procedures fuer Alert- und
--          Maintenance-History aus OperationsManagerDW
-- Erstellt:  Uwe Janke, dtcSoftware  2026-05-24
--
-- Ausfuehrungsreihenfolge (Agent Job):
--   Step 9  _04_ImportAlerts        Alert-History importieren
--   Step 10 _05_ImportMaintenance   Maintenance-History importieren
--
-- Voraussetzung:
--   Der SQL Agent Service Account benoetigt Lesezugriff auf
--   [OperationsManagerDW].[Alert].[vAlertDetail] und
--   [OperationsManagerDW].[MaintenanceModeHistory]
-- ============================================================

-- ── _04_ImportAlerts ───────────────────────────────────────
-- Importiert SCOM-Alerts aus OperationsManagerDW.
-- Nur Alerts fuer Objekte, die in dtcSN.SQLServer bekannt sind.
-- Deduplizierung per AlertGuid (MERGE).
-- Retention: @RetentionDays (Standard 90 Tage).
-- ============================================================

IF OBJECT_ID('[dbo].[_04_ImportAlerts]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[_04_ImportAlerts]
GO

CREATE PROCEDURE [dbo].[_04_ImportAlerts]
    @RetentionDays INT = 90
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Imported   INT = 0
    DECLARE @Deleted    INT = 0
    DECLARE @CutoffDate DATETIME = DATEADD(DAY, -@RetentionDays, GETDATE())

    -- ── 1. Alte Eintraege loeschen (Retention) ────────────────
    DELETE FROM [dbo].[AlertHistory]
    WHERE  [RaisedDateTime] < @CutoffDate
    SET @Deleted = @@ROWCOUNT

    -- ── 2. Neue/geaenderte Alerts importieren ─────────────────
    -- Quelle: OperationsManagerDW.Alert.vAlertDetail
    -- Filter: nur Managed Entities die in dtcSN.SQLServer oder
    --         dtcSN.Computer bekannt sind (via ManagedEntityRowId)
    -- AlertGuid als natuerlicher Schluessel (Deduplizierung)
    ;MERGE [dbo].[AlertHistory] AS tgt
    USING (
        SELECT
            CAST(a.AlertGuid           AS NVARCHAR(50))  AS AlertGuid,
            a.ManagedEntityRowId,
            a.Category,
            a.MonitoringObjectDisplayName                AS DisplayName,
            a.AlertName                                  AS Alertname,
            a.AlertDescription,
            a.RaisedDateTime,
            CASE a.Severity
                WHEN 0 THEN 'Information'
                WHEN 1 THEN 'Warning'
                WHEN 2 THEN 'Error'
                ELSE CAST(a.Severity AS NVARCHAR(20))
            END                                          AS Severity,
            CASE a.Priority
                WHEN 0 THEN 'Low'
                WHEN 1 THEN 'Medium'
                WHEN 2 THEN 'High'
                ELSE CAST(a.Priority AS NVARCHAR(20))
            END                                          AS Priority,
            a.RepeatCount
        FROM   [OperationsManagerDW].[Alert].[vAlertDetail] a
        WHERE  a.RaisedDateTime >= @CutoffDate
          AND  a.ManagedEntityRowId IN (
                   SELECT ManagedEntityRowId FROM [dbo].[SQLServer]
                   UNION
                   SELECT ManagedEntityRowId FROM [dbo].[Computer]
               )
    ) AS src ON tgt.[AlertGuid] = src.[AlertGuid]

    WHEN MATCHED AND tgt.[RepeatCount] <> src.[RepeatCount] THEN
        -- RepeatCount kann sich erhoehen wenn derselbe Alert erneut auftritt
        UPDATE SET
            tgt.[RepeatCount]  = src.[RepeatCount],
            tgt.[Imported]     = GETDATE()

    WHEN NOT MATCHED BY TARGET THEN
        INSERT ([AlertGuid], [ManagedEntityRowId], [Category], [DisplayName],
                [Alertname], [AlertDescription], [RaisedDateTime],
                [Severity], [Priority], [RepeatCount])
        VALUES (src.[AlertGuid], src.[ManagedEntityRowId], src.[Category], src.[DisplayName],
                src.[Alertname], src.[AlertDescription], src.[RaisedDateTime],
                src.[Severity], src.[Priority], src.[RepeatCount]);

    SET @Imported = @@ROWCOUNT

    PRINT '_04_ImportAlerts: ' + CAST(@Imported AS VARCHAR) + ' Saetze importiert/aktualisiert, '
        + CAST(@Deleted AS VARCHAR) + ' Saetze geloescht (aelter als '
        + CAST(@RetentionDays AS VARCHAR) + ' Tage)'
END
GO

-- ── _05_ImportMaintenance ──────────────────────────────────
-- Importiert SCOM-Wartungsfenster aus OperationsManagerDW.
-- Nur Fenster fuer Computer die in dtcSN bekannt sind.
-- Deduplizierung per MaintenanceRowId (MERGE).
-- Retention: @RetentionDays (Standard 365 Tage).
-- ============================================================

IF OBJECT_ID('[dbo].[_05_ImportMaintenance]', 'P') IS NOT NULL
    DROP PROCEDURE [dbo].[_05_ImportMaintenance]
GO

CREATE PROCEDURE [dbo].[_05_ImportMaintenance]
    @RetentionDays INT = 365
AS
BEGIN
    SET NOCOUNT ON;

    DECLARE @Imported   INT = 0
    DECLARE @Deleted    INT = 0
    DECLARE @CutoffDate DATETIME = DATEADD(DAY, -@RetentionDays, GETDATE())

    -- ── 1. Alte Eintraege loeschen (Retention) ────────────────
    DELETE FROM [dbo].[MaintenanceHistory]
    WHERE  [StartDateTime] < @CutoffDate
    SET @Deleted = @@ROWCOUNT

    -- ── 2. Wartungsfenster importieren ────────────────────────
    -- Quelle: OperationsManagerDW.dbo.MaintenanceModeHistory
    -- Filter: nur Computer die in dtcSN bekannt sind
    ;MERGE [dbo].[MaintenanceHistory] AS tgt
    USING (
        SELECT
            m.MaintenanceModeRowId                       AS MaintenanceRowId,
            m.ManagedEntityRowId,
            me.ManagedEntityDefaultName                  AS DisplayName,
            m.StartDateTime,
            m.EndDateTime,
            m.ScheduledEndDateTime,
            m.UserId,
            m.Comments                                   AS Comment
        FROM   [OperationsManagerDW].[dbo].[MaintenanceModeHistory]   m
        JOIN   [OperationsManagerDW].[dbo].[ManagedEntity]            me
               ON me.ManagedEntityRowId = m.ManagedEntityRowId
        WHERE  m.StartDateTime >= @CutoffDate
          AND  m.ManagedEntityRowId IN (
                   SELECT ManagedEntityRowId FROM [dbo].[Computer]
               )
    ) AS src ON tgt.[MaintenanceRowId] = src.[MaintenanceRowId]

    WHEN MATCHED AND (
        tgt.[EndDateTime]           <> src.[EndDateTime]  OR
        tgt.[ScheduledEndDateTime]  <> src.[ScheduledEndDateTime]
    ) THEN
        -- Fenster koennen verlaengert werden
        UPDATE SET
            tgt.[EndDateTime]          = src.[EndDateTime],
            tgt.[ScheduledEndDateTime] = src.[ScheduledEndDateTime],
            tgt.[Comment]              = src.[Comment],
            tgt.[Imported]             = GETDATE()

    WHEN NOT MATCHED BY TARGET THEN
        INSERT ([MaintenanceRowId], [ManagedEntityRowId], [DisplayName],
                [StartDateTime], [EndDateTime], [ScheduledEndDateTime],
                [UserId], [Comment])
        VALUES (src.[MaintenanceRowId], src.[ManagedEntityRowId], src.[DisplayName],
                src.[StartDateTime], src.[EndDateTime], src.[ScheduledEndDateTime],
                src.[UserId], src.[Comment]);

    SET @Imported = @@ROWCOUNT

    PRINT '_05_ImportMaintenance: ' + CAST(@Imported AS VARCHAR) + ' Saetze importiert/aktualisiert, '
        + CAST(@Deleted AS VARCHAR) + ' Saetze geloescht (aelter als '
        + CAST(@RetentionDays AS VARCHAR) + ' Tage)'
END
GO

PRINT ''
PRINT '====================================================='
PRINT 'Import-SPs angelegt:'
PRINT '  _04_ImportAlerts      (Retention: 90 Tage)'
PRINT '  _05_ImportMaintenance (Retention: 365 Tage)'
PRINT '====================================================='
GO
