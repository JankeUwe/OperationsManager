# OperationsManager

T-SQL Reporting-Schicht über Microsoft System Center Operations Manager (SCOM) — entwickelt von [dtcSoftware](https://www.powershelldba.de) (Uwe Janke).

## Übersicht

`dtcSN` ist eine eigene Reporting-Datenbank über `OperationsManagerDW`. Sie enthält SQL Server-, Computer- und Datenbank-Inventar, angereichert mit Kundenzuordnung und Support-Lifecycle-Informationen.

**Status:** In Entwicklung

## Inhalt

| Datei | Beschreibung |
|-------|-------------|
| `dtcsn.sql` | Datenbank-Setup (Erstversion) |
| `dtcsn_improved.sql` | Überarbeitete Version mit Bugfixes und Optimierungen |
| `dtcsn_views.sql` | Views für Reporting |
| `dtcsn_agentjob.sql` | SQL Agent Job für automatische Datenaktualisierung |
| `dtcsn_migrate.sql` | Migrationsskript |

## Verbesserungen in dtcsn_improved.sql

- Tippfehler behoben (`RETRUNVAL`, `Insterted`, `Poperties` etc.)
- `fn_CustDomainCount`: Rückgabetyp `VARCHAR(255)` → `INT`
- Rollen aufgelöst: `db_owner` für Leseaccounts → `db_datareader` / `db_datawriter`
- Cursor-basierte Prozeduren auf set-basierte Logik umgestellt
- `SET NOCOUNT ON` in allen Prozeduren
- Keywords durchgängig UPPERCASE

## Mehr Informationen

- Website: [www.powershelldba.de](https://www.powershelldba.de)
- Entwickler: Uwe Janke, Senior IT-Spezialist / SQL Server DBA
