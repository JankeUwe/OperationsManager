# OperationsManager / dtcSN — Changelog

## [Unreleased] — 2026-05-24

### Added AlertHistory + MaintenanceHistory import pipeline

New tables (`AlertHistory`, deduplicated by `AlertGuid`, 90-day retention; `MaintenanceHistory`,
365-day retention) with performance indexes on `ManagedEntityRowId`. New import steps
`_04_ImportAlerts`/`_05_ImportMaintenance` (MERGE from `OperationsManagerDW`, filtered to entities
known in dtcSN), wired into the SQL Agent job as steps 9 and 10. Added
`vAlertsOperationsManagerDW`/`vMaintenanceHistory` views under the same names as the former
`OperationsManagerDW` views so SQLNow's handlers need no code changes.

### Fix: SQL scripts cleaned up and made portable

`dtcsn_improved.sql`: hardcoded `CREATE DATABASE` filename paths (`V:\`, `W:\`) replaced with
dynamic `SERVERPROPERTY('InstanceDefaultDataPath/LogPath')`; `THROW;` corrected to `;THROW;`
(T-SQL parser requirement, also on SQL Server 2022) in six places, same fix applied to
`dtcsn_migrate.sql`. `dtcsn_agentjob.sql`: hardcoded `@owner_login_name 'sa'` replaced with a
configurable `@OwnerLogin` variable, with a comment for environments without an active `sa`
account.

### Added test data scripts

`dtcsn_testdata_mssql.sql` (T-SQL) and `dtcsn_testdata_mysql.sql` (MySQL/IONOS PHP demo), covering
all 11 dtcSN tables (5 customers, 13 SQL Server instances, 13 computers, 35 databases, all lookup
tables), idempotent. Fixed afterward: an FK violation (`CustomerDomain` must delete before
`Customer` — restructured to delete all tables in FK-safe order, then insert in dependency order)
and a datetime conversion error on German-locale SQL Server (date literals switched from
`YYYY-MM-DD` to `YYYYMMDD`, locale-independent).

### Added symbol column to database views

For icon support in SQLNow grids.

## [1.0] — 2026-05-18

### Initial release

T-SQL reporting layer over SCOM `OperationsManagerDW`: SQL Server, computer, and database
inventory with customer assignment. Developed by dtcSoftware (Uwe Janke), MIT-licensed.
