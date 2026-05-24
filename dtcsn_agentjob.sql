USE [msdb]
GO

-- ============================================================
-- dtcSN – SQL Server Agent Job
-- Erstellt:  Uwe Janke, dtcSoftware
-- Zweck:     Steuert den zyklischen Import aus OperationsManagerDW
--            in die dtcSN-Berichtsdatenbank.
--
-- Ausfuehrungsreihenfolge:
--   Step 1  _00_ExtendTargetTables          Neue SCOM-Properties -> neue Spalten
--   Step 2  _01_InsertSQLServer             SQL Server synchronisieren
--   Step 3  _01a_GetPropertiesForAllSQLEntries  Properties SQL Server einlesen
--   Step 4  _02_InsertComputer              Computer synchronisieren
--   Step 5  _02a_GetPropertiesForAllComputerEntries  Properties Computer einlesen
--   Step 6  _02b_GetWindowsOSForAllComputerEntries   Windows OS ermitteln
--   Step 7  _03_InsertSQLDatabases          Datenbanken synchronisieren
--   Step 8  _03a_GetPropertiesForAllSQLDBS  Properties Datenbanken einlesen
--
-- Zeitplan:  Taeglich, alle 60 Minuten  (anpassbar)
-- Anpassung: @JobName, @DBName, @ScheduleStartTime, @FreqInterval
-- ============================================================

SET NOCOUNT ON;

-- ── Konfiguration ──────────────────────────────────────────
DECLARE @JobName            SYSNAME      = N'dtcSN – SCOM Import'
DECLARE @DBName             SYSNAME      = N'dtcSN'
DECLARE @JobCategory        NVARCHAR(100)= N'Database Maintenance'
DECLARE @JobDescription     NVARCHAR(512)= N'Zyklischer Import aus OperationsManagerDW in dtcSN. Synchronisiert SQL Server, Computer und Datenbanken.'
DECLARE @ScheduleName       SYSNAME      = N'dtcSN – stuendlich'
DECLARE @ScheduleStartTime  INT          = 060000   -- 06:00:00 Uhr
DECLARE @ScheduleEndTime    INT          = 220000   -- 22:00:00 Uhr
DECLARE @FreqInterval       INT          = 60       -- Minuten zwischen den Laeufen
DECLARE @OwnerLogin         SYSNAME      = N'sa'    -- Job-Owner Login (anpassen falls sa deaktiviert ist)
DECLARE @OperatorName       SYSNAME      = N''      -- Operator fuer Fehlerbenachrichtigung (leer = keine)

-- ── Existenz pruefen ───────────────────────────────────────
IF EXISTS (SELECT 1 FROM msdb.dbo.sysjobs WHERE name = @JobName)
BEGIN
    PRINT 'Job ''' + @JobName + ''' existiert bereits – wird geloescht und neu erstellt.'
    EXEC msdb.dbo.sp_delete_job @job_name = @JobName, @delete_unused_schedule = 1
END

-- ── Job anlegen ────────────────────────────────────────────
DECLARE @JobID UNIQUEIDENTIFIER

EXEC msdb.dbo.sp_add_job
    @job_name             = @JobName,
    @enabled              = 1,
    @description          = @JobDescription,
    @category_name        = @JobCategory,
    @owner_login_name     = @OwnerLogin,
    @notify_level_eventlog= 2,   -- Bei Fehler ins Windows Event Log schreiben
    @job_id               = @JobID OUTPUT

PRINT 'Job angelegt: ' + @JobName + '  (' + CAST(@JobID AS VARCHAR(36)) + ')'

-- ── Step 1: Tabellen erweitern ─────────────────────────────
EXEC msdb.dbo.sp_add_jobstep
    @job_id               = @JobID,
    @step_name            = N'01 – Zieltabellen erweitern',
    @step_id              = 1,
    @subsystem            = N'TSQL',
    @database_name        = @DBName,
    @command              = N'EXEC [dbo].[_00_ExtendTargetTables]',
    @on_success_action    = 3,   -- Weiter mit naechstem Step
    @on_fail_action       = 2,   -- Abbrechen mit Fehler
    @retry_attempts       = 1,
    @retry_interval       = 1

-- ── Step 2: SQL Server synchronisieren ────────────────────
EXEC msdb.dbo.sp_add_jobstep
    @job_id               = @JobID,
    @step_name            = N'02 – SQL Server synchronisieren',
    @step_id              = 2,
    @subsystem            = N'TSQL',
    @database_name        = @DBName,
    @command              = N'EXEC [dbo].[_01_InsertSQLServer]',
    @on_success_action    = 3,
    @on_fail_action       = 2,
    @retry_attempts       = 1,
    @retry_interval       = 2

-- ── Step 3: Properties SQL Server einlesen ────────────────
EXEC msdb.dbo.sp_add_jobstep
    @job_id               = @JobID,
    @step_name            = N'03 – Properties SQL Server einlesen',
    @step_id              = 3,
    @subsystem            = N'TSQL',
    @database_name        = @DBName,
    @command              = N'EXEC [dbo].[_01a_GetPropertiesForAllSQLEntries]',
    @on_success_action    = 3,
    @on_fail_action       = 2,
    @retry_attempts       = 0,
    @retry_interval       = 0

-- ── Step 4: Computer synchronisieren ──────────────────────
EXEC msdb.dbo.sp_add_jobstep
    @job_id               = @JobID,
    @step_name            = N'04 – Computer synchronisieren',
    @step_id              = 4,
    @subsystem            = N'TSQL',
    @database_name        = @DBName,
    @command              = N'EXEC [dbo].[_02_InsertComputer]',
    @on_success_action    = 3,
    @on_fail_action       = 2,
    @retry_attempts       = 1,
    @retry_interval       = 2

-- ── Step 5: Properties Computer einlesen ──────────────────
EXEC msdb.dbo.sp_add_jobstep
    @job_id               = @JobID,
    @step_name            = N'05 – Properties Computer einlesen',
    @step_id              = 5,
    @subsystem            = N'TSQL',
    @database_name        = @DBName,
    @command              = N'EXEC [dbo].[_02a_GetPropertiesForAllComputerEntries]',
    @on_success_action    = 3,
    @on_fail_action       = 2,
    @retry_attempts       = 0,
    @retry_interval       = 0

-- ── Step 6: Windows OS ermitteln ──────────────────────────
EXEC msdb.dbo.sp_add_jobstep
    @job_id               = @JobID,
    @step_name            = N'06 – Windows OS ermitteln',
    @step_id              = 6,
    @subsystem            = N'TSQL',
    @database_name        = @DBName,
    @command              = N'EXEC [dbo].[_02b_GetWindowsOSForAllComputerEntries]',
    @on_success_action    = 3,
    @on_fail_action       = 2,
    @retry_attempts       = 1,
    @retry_interval       = 2

-- ── Step 7: Datenbanken synchronisieren ───────────────────
EXEC msdb.dbo.sp_add_jobstep
    @job_id               = @JobID,
    @step_name            = N'07 – SQL-Datenbanken synchronisieren',
    @step_id              = 7,
    @subsystem            = N'TSQL',
    @database_name        = @DBName,
    @command              = N'EXEC [dbo].[_03_InsertSQLDatabases]',
    @on_success_action    = 3,
    @on_fail_action       = 2,
    @retry_attempts       = 1,
    @retry_interval       = 2

-- ── Step 8: Properties Datenbanken einlesen ───────────────
EXEC msdb.dbo.sp_add_jobstep
    @job_id               = @JobID,
    @step_name            = N'08 – Properties Datenbanken einlesen',
    @step_id              = 8,
    @subsystem            = N'TSQL',
    @database_name        = @DBName,
    @command              = N'EXEC [dbo].[_03a_GetPropertiesForAllSQLDBS]',
    @on_success_action    = 3,   -- Weiter mit naechstem Step
    @on_fail_action       = 2,   -- Abbrechen mit Fehler
    @retry_attempts       = 0,
    @retry_interval       = 0

-- ── Step 9: Alert-History importieren ─────────────────────
EXEC msdb.dbo.sp_add_jobstep
    @job_id               = @JobID,
    @step_name            = N'09 – Alert-History importieren',
    @step_id              = 9,
    @subsystem            = N'TSQL',
    @database_name        = @DBName,
    @command              = N'EXEC [dbo].[_04_ImportAlerts] @RetentionDays = 90',
    @on_success_action    = 3,   -- Weiter mit naechstem Step
    @on_fail_action       = 2,   -- Abbrechen mit Fehler
    @retry_attempts       = 1,
    @retry_interval       = 2

-- ── Step 10: Maintenance-History importieren ───────────────
EXEC msdb.dbo.sp_add_jobstep
    @job_id               = @JobID,
    @step_name            = N'10 – Maintenance-History importieren',
    @step_id              = 10,
    @subsystem            = N'TSQL',
    @database_name        = @DBName,
    @command              = N'EXEC [dbo].[_05_ImportMaintenance] @RetentionDays = 365',
    @on_success_action    = 1,   -- Erfolgreich beenden
    @on_fail_action       = 2,   -- Abbrechen mit Fehler
    @retry_attempts       = 1,
    @retry_interval       = 2

-- ── Startstep setzen ──────────────────────────────────────
EXEC msdb.dbo.sp_update_job
    @job_id        = @JobID,
    @start_step_id = 1

-- ── Zeitplan anlegen ──────────────────────────────────────
-- Taeglich wiederholen, alle @FreqInterval Minuten
-- zwischen @ScheduleStartTime und @ScheduleEndTime.
DECLARE @ScheduleID INT

EXEC msdb.dbo.sp_add_schedule
    @schedule_name          = @ScheduleName,
    @enabled                = 1,
    @freq_type              = 4,        -- Taeglich
    @freq_interval          = 1,        -- Jeden Tag
    @freq_subday_type       = 4,        -- Minuten-Intervall
    @freq_subday_interval   = @FreqInterval,
    @active_start_time      = @ScheduleStartTime,
    @active_end_time        = @ScheduleEndTime,
    @active_start_date      = 20260101,
    @schedule_id            = @ScheduleID OUTPUT

EXEC msdb.dbo.sp_attach_schedule
    @job_id       = @JobID,
    @schedule_id  = @ScheduleID

PRINT 'Zeitplan angelegt: ' + @ScheduleName
PRINT '  Intervall : alle ' + CAST(@FreqInterval AS VARCHAR) + ' Minuten'
PRINT '  Fenster   : '
    + STUFF(STUFF(RIGHT('000000' + CAST(@ScheduleStartTime AS VARCHAR), 6), 5, 0, ':'), 3, 0, ':')
    + ' – '
    + STUFF(STUFF(RIGHT('000000' + CAST(@ScheduleEndTime   AS VARCHAR), 6), 5, 0, ':'), 3, 0, ':')

-- ── Job dem lokalen Server zuweisen ───────────────────────
EXEC msdb.dbo.sp_add_jobserver
    @job_id        = @JobID,
    @server_name   = N'(local)'

PRINT ''
PRINT '====================================================='
PRINT 'Job erfolgreich erstellt.'
PRINT 'Name     : ' + @JobName
PRINT 'Datenbank: ' + @DBName
PRINT 'Steps    : 10'
PRINT ''
PRINT 'Hinweis: Job laeuft als SQL Agent Service Account.'
PRINT 'Sicherstellen, dass dieser Account Lesezugriff auf'
PRINT '[OperationsManagerDW] hat.'
PRINT '====================================================='
GO
