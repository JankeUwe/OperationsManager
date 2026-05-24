USE [dtcSN]
GO
SET NOCOUNT ON;

-- ============================================================
-- dtcSN -- Testdaten fuer lokale .NET-Entwicklung
-- Erstellt:  Uwe Janke, dtcSoftware  2026-05-24
-- Zweck:     Realistische Phantasiedaten fuer alle 11 Tabellen.
--            Konsistent verknuepft, keine echten Kundendaten.
--
-- Ausfuehren: einmalig auf der lokalen dtcSN-Instanz
-- Idempotent: DELETE + INSERT, kann wiederholt werden
-- ============================================================

PRINT 'dtcSN Testdaten -- Start'
PRINT ''

-- ============================================================
-- Reihenfolge: Lookup-Tabellen zuerst, dann Stammdaten,
-- dann abhaengige Tabellen
-- ============================================================

-- ── 1. SQLVersion ──────────────────────────────────────────
PRINT '[1] SQLVersion...'
DELETE FROM [dbo].[SQLVersion]

INSERT INTO [dbo].[SQLVersion] ([productversion], [sqlversion]) VALUES
('16.', '2022'),
('15.', '2019'),
('14.', '2017'),
('13.', '2016'),
('12.', '2014'),
('11.', '2012')
GO

-- ── 2. Support ─────────────────────────────────────────────
PRINT '[2] Support...'
DELETE FROM [dbo].[Support]

INSERT INTO [dbo].[Support] ([VersionNr], [ReleaseDate], [EndOfMainstream], [EndofExtended]) VALUES
(2022, '2022-11-16', '2028-01-11', '2033-01-11'),
(2019, '2019-11-04', '2025-02-28', '2030-01-08'),
(2017, '2017-10-02', '2022-10-11', '2027-10-12'),
(2016, '2016-06-01', '2021-07-13', '2026-07-14'),
(2014, '2014-04-01', '2019-07-09', '2024-07-09'),
(2012, '2012-03-06', '2017-07-11', '2022-07-12')
GO

-- ── 3. ManagedSQLEntityType ────────────────────────────────
PRINT '[3] ManagedSQLEntityType...'
DELETE FROM [dbo].[ManagedSQLEntityType]

INSERT INTO [dbo].[ManagedSQLEntityType]
    ([ManagedEntityTypeRowId], [ManagedEntityTypeSystemName], [Description], [ManagedEntityTypeSQLId], [Aktiv])
VALUES
(100, 'Microsoft.SQLServer.2022.DBEngine',       'SQL Server 2022 Engine',      2022, 1),
(101, 'Microsoft.SQLServer.2019.DBEngine',       'SQL Server 2019 Engine',      2019, 1),
(102, 'Microsoft.SQLServer.2017.DBEngine',       'SQL Server 2017 Engine',      2017, 1),
(103, 'Microsoft.SQLServer.2016.DBEngine',       'SQL Server 2016 Engine',      2016, 1),
(104, 'Microsoft.SQLServer.2014.DBEngine',       'SQL Server 2014 Engine',      2014, 0),
(105, 'Microsoft.SQLServer.2012.DBEngine',       'SQL Server 2012 Engine',      2012, 0)
GO

-- ── 4. ManagedEntityCompType ───────────────────────────────
PRINT '[4] ManagedEntityCompType...'
DELETE FROM [dbo].[ManagedEntityCompType]

INSERT INTO [dbo].[ManagedEntityCompType] ([ManagedEntityTypeRowId], [ManagedEntityTypeSystemName]) VALUES
(200, 'Microsoft.Windows.Computer'),
(201, 'Microsoft.Windows.Server.Computer'),
(202, 'Microsoft.Windows.Cluster.VirtualServer')
GO

-- ── 5. ManagedEntityDatabaseType ──────────────────────────
PRINT '[5] ManagedEntityDatabaseType...'
DELETE FROM [dbo].[ManagedEntityDatabaseType]

INSERT INTO [dbo].[ManagedEntityDatabaseType]
    ([ManagedEntityTypeRowId], [ManagedEntityTypeGuid], [ManagementPackRowId],
     [ManagedEntityTypeSystemName], [ManagedEntityTypeDefaultName],
     [ManagedEntityTypeDefaultDescription], [Aktive])
VALUES
(300, NEWID(), 1, 'Microsoft.SQLServer.2022.Database', 'SQL Server 2022 Datenbank', 'SQL Server 2022 User Database', 1),
(301, NEWID(), 1, 'Microsoft.SQLServer.2019.Database', 'SQL Server 2019 Datenbank', 'SQL Server 2019 User Database', 1),
(302, NEWID(), 1, 'Microsoft.SQLServer.2017.Database', 'SQL Server 2017 Datenbank', 'SQL Server 2017 User Database', 1),
(303, NEWID(), 1, 'Microsoft.SQLServer.2016.Database', 'SQL Server 2016 Datenbank', 'SQL Server 2016 User Database', 1)
GO

-- ── 6. ExcludeDB ───────────────────────────────────────────
PRINT '[6] ExcludeDB...'
DELETE FROM [dbo].[ExcludeDB]

INSERT INTO [dbo].[ExcludeDB] ([Name]) VALUES
('master'), ('model'), ('msdb'), ('tempdb'), ('ReportServer'), ('ReportServerTempDB')
GO

-- ── 7. Customer ────────────────────────────────────────────
PRINT '[7] Customer...'
DELETE FROM [dbo].[Customer]

-- IDENTITY muss zurueckgesetzt werden (CustomerDomain FK)
DBCC CHECKIDENT ('dbo.Customer', RESEED, 0)

INSERT INTO [dbo].[Customer] ([Name], [NameLong], [Address], [Zip], [City], [Notes]) VALUES
('Metallwerk',   'Metallwerk Rheintal AG',          'Industriestr. 12',   '47229', 'Duisburg',  'Produktion, 3-Schicht'),
('Stadtwerke',   'Stadtwerke Nord GmbH',            'Am Stadttor 3',      '24103', 'Kiel',      'Versorgung, kritische Infrastruktur'),
('Logistik',     'Schnell & Sicher Logistik GmbH',  'Hafenring 77',       '20457', 'Hamburg',   'Spedition, 24/7'),
('Pharma',       'BioMed Pharma GmbH',              'Forschungsallee 5',  '69120', 'Heidelberg','GxP-Umgebung'),
('Handel',       'Euro-Handel AG',                  'Kaufhausring 1',     '80331', 'Muenchen',  'ERP-Betrieb')
GO

-- ── 8. CustomerDomain ──────────────────────────────────────
PRINT '[8] CustomerDomain...'
DELETE FROM [dbo].[CustomerDomain]

INSERT INTO [dbo].[CustomerDomain] ([CustomerId], [DomainDnsName], [JumpServer1], [JumpServer2], [Notes]) VALUES
(1, 'metallwerk.local',     'js01.metallwerk.local',  NULL,                    'Produktionsnetz'),
(1, 'metallwerk-prod.de',   'js02.metallwerk.local',  NULL,                    'DMZ'),
(2, 'stadtwerke-nord.lan',  'jump01.swn.intern',      'jump02.swn.intern',     'HA-Jumper'),
(3, 'ssl-logistik.intern',  'jslogistik.intern',      NULL,                    NULL),
(4, 'biomed.corp',          'jumpgxp01.biomed.corp',  'jumpgxp02.biomed.corp', 'GxP-Segment'),
(5, 'eurohandel.local',     'js-erp.eurohandel.local',NULL,                    'ERP-Segment')
GO

-- ── 9. SQLServer ───────────────────────────────────────────
PRINT '[9] SQLServer...'
DELETE FROM [dbo].[SQLDatabase]   -- FK-Abhaengigkeit
DELETE FROM [dbo].[Computer]      -- FK-Abhaengigkeit
DELETE FROM [dbo].[SQLServer]

DBCC CHECKIDENT ('dbo.SQLServer',   RESEED, 0)
DBCC CHECKIDENT ('dbo.Computer',    RESEED, 0)
DBCC CHECKIDENT ('dbo.SQLDatabase', RESEED, 0)

INSERT INTO [dbo].[SQLServer]
    ([ManagedEntityRowId], [TopLevelHostManagedEntityRowId],
     [ManagedEntityDefaultName], [Domain],
     [Maschine], [InstanceName], [PrincipalName], [Type],
     [Version], [ServicePackVersion], [Edition],
     [TcpPorts], [Account], [AuthenticationMode], [AuditLevel],
     [InstallPath], [MasterDatabaseLocation], [ToolsPath],
     [IsSCOM], [DWCreatedDateTime], [Changes])
VALUES
-- Metallwerk: 3 SQL Server
(1001, 2001, 'MWSQL01',       'metallwerk.local',    'MWSQL01',    'MSSQLSERVER', 'MWSQL01',           'Standalone',  '16.0.4120.1', 'RTM',  'Developer Edition (64-bit)',    '1433', 'metallwerk\sqlsvc',    'Windows', '2',  'C:\Program Files\Microsoft SQL Server', 'C:\MSSQL\DATA', 'C:\Program Files\Microsoft SQL Server', 1, '2024-01-15', 42),
(1002, 2002, 'MWSQL02',       'metallwerk.local',    'MWSQL02',    'MSSQLSERVER', 'MWSQL02',           'Standalone',  '15.0.4355.3', 'CU',   'Standard Edition (64-bit)',      '1433', 'metallwerk\sqlsvc',    'Windows', '2',  'C:\Program Files\Microsoft SQL Server', 'D:\MSSQL\DATA', 'C:\Program Files\Microsoft SQL Server', 1, '2023-06-01', 18),
(1003, 2003, 'MWSQL03\PROD',  'metallwerk-prod.de',  'MWSQL03',    'PROD',        'MWSQL03\PROD',      'Standalone',  '14.0.3465.1', 'CU',   'Enterprise Edition (64-bit)',    '1433', 'METALLWERK-PROD\sqlsvc','Windows', '3',  'E:\SQL\Binn',                           'E:\SQL\DATA',   'E:\SQL\Tools',                          1, '2022-11-01', 97),
-- Stadtwerke: 2 SQL Server
(1004, 2004, 'SWN-SQL01',     'stadtwerke-nord.lan', 'SWN-SQL01',  'MSSQLSERVER', 'SWN-SQL01',         'Standalone',  '15.0.4355.3', 'CU',   'Standard Edition (64-bit)',      '1433', 'swn\sqlservice',       'Windows', '2',  'C:\Program Files\Microsoft SQL Server', 'C:\MSSQL\DATA', 'C:\Program Files\Microsoft SQL Server', 1, '2023-09-10', 55),
(1005, 2005, 'SWN-SQL02',     'stadtwerke-nord.lan', 'SWN-SQL02',  'MSSQLSERVER', 'SWN-SQL02',         'Standalone',  '16.0.4120.1', 'RTM',  'Enterprise Edition (64-bit)',    '1433', 'swn\sqlservice',       'Windows', '2',  'C:\Program Files\Microsoft SQL Server', 'D:\SQL\DATA',   'C:\Program Files\Microsoft SQL Server', 1, '2024-03-01', 12),
-- Logistik: 2 SQL Server
(1006, 2006, 'SSL-DB01',      'ssl-logistik.intern', 'SSL-DB01',   'MSSQLSERVER', 'SSL-DB01',          'Standalone',  '16.0.4120.1', 'RTM',  'Standard Edition (64-bit)',      '1433', 'ssl\sqlsvc',           'Windows', '2',  'C:\Program Files\Microsoft SQL Server', 'F:\DATA',       'C:\Program Files\Microsoft SQL Server', 1, '2024-02-14', 8),
(1007, 2007, 'SSL-DB02',      'ssl-logistik.intern', 'SSL-DB02',   'MSSQLSERVER', 'SSL-DB02',          'Standalone',  '13.0.6441.1', 'SP3',  'Standard Edition (64-bit)',      '1433', 'ssl\sqlsvc',           'Windows', '2',  'C:\Program Files\Microsoft SQL Server', 'G:\DATA',       'C:\Program Files\Microsoft SQL Server', 1, '2021-07-01', 201),
-- Pharma: 3 SQL Server (GxP, daher Enterprise)
(1008, 2008, 'BMP-SQLGXP01',  'biomed.corp',         'BMP-SQLGXP01','MSSQLSERVER','BMP-SQLGXP01',      'Standalone',  '15.0.4355.3', 'CU',   'Enterprise Edition (64-bit)',    '1433', 'biomed\sqlservice',    'Mixed',   '3',  'D:\MSSQL\Binn',                         'D:\MSSQL\DATA', 'D:\MSSQL\Tools',                        1, '2023-04-01', 33),
(1009, 2009, 'BMP-SQLGXP02',  'biomed.corp',         'BMP-SQLGXP02','MSSQLSERVER','BMP-SQLGXP02',      'Standalone',  '15.0.4355.3', 'CU',   'Enterprise Edition (64-bit)',    '1433', 'biomed\sqlservice',    'Mixed',   '3',  'D:\MSSQL\Binn',                         'D:\MSSQL\DATA', 'D:\MSSQL\Tools',                        1, '2023-04-01', 29),
(1010, 2010, 'BMP-SQLREP01',  'biomed.corp',         'BMP-SQLREP01','REPORT',     'BMP-SQLREP01\REPORT','Standalone',  '16.0.4120.1', 'RTM',  'Standard Edition (64-bit)',      '1433', 'biomed\sqlsvc',        'Windows', '2',  'C:\Program Files\Microsoft SQL Server', 'C:\SQL\DATA',   'C:\Program Files\Microsoft SQL Server', 1, '2024-01-20', 5),
-- Handel: 3 SQL Server
(1011, 2011, 'EH-ERPDB01',    'eurohandel.local',    'EH-ERPDB01', 'MSSQLSERVER', 'EH-ERPDB01',        'Standalone',  '16.0.4120.1', 'RTM',  'Enterprise Edition (64-bit)',    '1433', 'eurohandel\sqlsvc',    'Windows', '2',  'C:\Program Files\Microsoft SQL Server', 'E:\MSSQL\DATA', 'C:\Program Files\Microsoft SQL Server', 1, '2024-01-10', 67),
(1012, 2012, 'EH-ERPDB02',    'eurohandel.local',    'EH-ERPDB02', 'MSSQLSERVER', 'EH-ERPDB02',        'Standalone',  '14.0.3465.1', 'CU',   'Standard Edition (64-bit)',      '1433', 'eurohandel\sqlsvc',    'Windows', '2',  'C:\Program Files\Microsoft SQL Server', 'F:\MSSQL\DATA', 'C:\Program Files\Microsoft SQL Server', 1, '2022-05-15', 144),
(1013, 2013, 'EH-RPTSQL01',   'eurohandel.local',    'EH-RPTSQL01','MSSQLSERVER', 'EH-RPTSQL01',       'Standalone',  '15.0.4355.3', 'CU',   'Standard Edition (64-bit)',      '1433', 'eurohandel\sqlsvc',    'Windows', '2',  'C:\Program Files\Microsoft SQL Server', 'G:\MSSQL\DATA', 'C:\Program Files\Microsoft SQL Server', 1, '2023-08-01', 22)
GO

-- ── 10. Computer ───────────────────────────────────────────
PRINT '[10] Computer...'

INSERT INTO [dbo].[Computer]
    ([ManagedEntityRowId], [TopLevelHostManagedEntityRowId], [ManagedEntityTypeRowId],
     [ManagedEntityDefaultName], [Maschine], [DNSName], [DomainDnsName],
     [NetbiosComputerName], [IPAddress], [PhysicalProcessors], [LogicalProcessors],
     [VirtualMachineName], [SQLMonitoringType], [WindowsOS], [IsSCOM])
VALUES
-- Metallwerk
(2001, NULL, 200, 'MWSQL01.metallwerk.local',    'MWSQL01',     'MWSQL01.metallwerk.local',    'metallwerk.local',    'MWSQL01',    '10.10.1.11', '2', '16', NULL,             '1', 'Windows Server 2022 Datacenter', 1),
(2002, NULL, 200, 'MWSQL02.metallwerk.local',    'MWSQL02',     'MWSQL02.metallwerk.local',    'metallwerk.local',    'MWSQL02',    '10.10.1.12', '2', '8',  NULL,             '1', 'Windows Server 2022 Standard',   1),
(2003, NULL, 200, 'MWSQL03.metallwerk-prod.de',  'MWSQL03',     'MWSQL03.metallwerk-prod.de',  'metallwerk-prod.de',  'MWSQL03',    '10.10.2.11', '4', '32', NULL,             '1', 'Windows Server 2019 Datacenter', 1),
-- Stadtwerke
(2004, NULL, 200, 'SWN-SQL01.stadtwerke-nord.lan','SWN-SQL01',  'SWN-SQL01.stadtwerke-nord.lan','stadtwerke-nord.lan', 'SWN-SQL01',  '192.168.10.20','2','16', NULL,             '1', 'Windows Server 2019 Standard',   1),
(2005, NULL, 200, 'SWN-SQL02.stadtwerke-nord.lan','SWN-SQL02',  'SWN-SQL02.stadtwerke-nord.lan','stadtwerke-nord.lan', 'SWN-SQL02',  '192.168.10.21','4','32', NULL,             '1', 'Windows Server 2022 Datacenter', 1),
-- Logistik
(2006, NULL, 200, 'SSL-DB01.ssl-logistik.intern', 'SSL-DB01',   'SSL-DB01.ssl-logistik.intern', 'ssl-logistik.intern', 'SSL-DB01',   '172.16.5.10',  '2','16', 'ESX-MW-Pool01',  '1', 'Windows Server 2022 Standard',   1),
(2007, NULL, 200, 'SSL-DB02.ssl-logistik.intern', 'SSL-DB02',   'SSL-DB02.ssl-logistik.intern', 'ssl-logistik.intern', 'SSL-DB02',   '172.16.5.11',  '2','8',  NULL,             '1', 'Windows Server 2016 Standard',   1),
-- Pharma
(2008, NULL, 200, 'BMP-SQLGXP01.biomed.corp',    'BMP-SQLGXP01','BMP-SQLGXP01.biomed.corp',    'biomed.corp',         'BMP-SQLGXP01','10.20.1.10',  '4','32', NULL,             '1', 'Windows Server 2019 Datacenter', 1),
(2009, NULL, 200, 'BMP-SQLGXP02.biomed.corp',    'BMP-SQLGXP02','BMP-SQLGXP02.biomed.corp',    'biomed.corp',         'BMP-SQLGXP02','10.20.1.11',  '4','32', NULL,             '1', 'Windows Server 2019 Datacenter', 1),
(2010, NULL, 200, 'BMP-SQLREP01.biomed.corp',    'BMP-SQLREP01','BMP-SQLREP01.biomed.corp',    'biomed.corp',         'BMP-SQLREP01','10.20.1.20',  '2','16', 'ESX-GXP-Pool01', '1', 'Windows Server 2022 Standard',   1),
-- Handel
(2011, NULL, 200, 'EH-ERPDB01.eurohandel.local', 'EH-ERPDB01', 'EH-ERPDB01.eurohandel.local', 'eurohandel.local',    'EH-ERPDB01', '10.30.1.10',  '4','32', NULL,             '1', 'Windows Server 2022 Datacenter', 1),
(2012, NULL, 200, 'EH-ERPDB02.eurohandel.local', 'EH-ERPDB02', 'EH-ERPDB02.eurohandel.local', 'eurohandel.local',    'EH-ERPDB02', '10.30.1.11',  '2','16', NULL,             '1', 'Windows Server 2019 Standard',   1),
(2013, NULL, 200, 'EH-RPTSQL01.eurohandel.local','EH-RPTSQL01','EH-RPTSQL01.eurohandel.local', 'eurohandel.local',    'EH-RPTSQL01','10.30.1.20',  '2','16', 'ESX-EH-Pool02',  '1', 'Windows Server 2022 Standard',   1)
GO

-- ── 11. SQLDatabase ────────────────────────────────────────
PRINT '[11] SQLDatabase...'

INSERT INTO [dbo].[SQLDatabase]
    ([ManagedEntityRowId], [TopLevelHostManagedEntityRowId], [ManagedEntityTypeRowId],
     [Path], [DisplayName],
     [Collation], [DatabaseAutogrow], [LogAutogrow],
     [Owner], [RecoveryModel], [Updateability], [UserAccess])
VALUES
-- MWSQL01 (ManagedEntityRowId=1001)
(3001, 1001, 300, '16.0.4120.1:MWSQL01:Produktion',      'Produktion',      'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
(3002, 1001, 300, '16.0.4120.1:MWSQL01:MES',             'MES',             'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
(3003, 1001, 300, '16.0.4120.1:MWSQL01:Qualitaet',       'Qualitaet',       'Latin1_General_CI_AS', 'true',  'false', 'sa',  'SIMPLE', 'READ_WRITE', 'MULTI_USER'),
(3004, 1001, 300, '16.0.4120.1:MWSQL01:Archiv2022',      'Archiv2022',      'Latin1_General_CI_AS', 'false', 'false', 'sa',  'SIMPLE', 'READ_ONLY',  'MULTI_USER'),
-- MWSQL02 (1002)
(3005, 1002, 301, '15.0.4355.3:MWSQL02:Warenwirtschaft', 'Warenwirtschaft', 'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
(3006, 1002, 301, '15.0.4355.3:MWSQL02:Einkauf',         'Einkauf',         'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
(3007, 1002, 301, '15.0.4355.3:MWSQL02:Personal',        'Personal',        'German_PhoneBook_CI_AS','true', 'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
-- MWSQL03\PROD (1003)
(3008, 1003, 302, '14.0.3465.1:MWSQL03:Fertigung',       'Fertigung',       'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
(3009, 1003, 302, '14.0.3465.1:MWSQL03:PPS',             'PPS',             'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
(3010, 1003, 302, '14.0.3465.1:MWSQL03:Instandhaltung',  'Instandhaltung',  'Latin1_General_CI_AS', 'true',  'false', 'sa',  'SIMPLE', 'READ_WRITE', 'MULTI_USER'),
-- SWN-SQL01 (1004)
(3011, 1004, 301, '15.0.4355.3:SWN-SQL01:Kundendaten',   'Kundendaten',     'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
(3012, 1004, 301, '15.0.4355.3:SWN-SQL01:Abrechnung',    'Abrechnung',      'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
(3013, 1004, 301, '15.0.4355.3:SWN-SQL01:Netz',          'Netz',            'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
(3014, 1004, 301, '15.0.4355.3:SWN-SQL01:SCADA',         'SCADA',           'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
-- SWN-SQL02 (1005)
(3015, 1005, 300, '16.0.4120.1:SWN-SQL02:DWH',           'DWH',             'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
(3016, 1005, 300, '16.0.4120.1:SWN-SQL02:Reporting',     'Reporting',       'Latin1_General_CI_AS', 'true',  'false', 'sa',  'SIMPLE', 'READ_ONLY',  'MULTI_USER'),
-- SSL-DB01 (1006)
(3017, 1006, 300, '16.0.4120.1:SSL-DB01:Transport',      'Transport',       'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
(3018, 1006, 300, '16.0.4120.1:SSL-DB01:Disposition',    'Disposition',     'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
(3019, 1006, 300, '16.0.4120.1:SSL-DB01:Fahrer',         'Fahrer',          'Latin1_General_CI_AS', 'true',  'false', 'sa',  'SIMPLE', 'READ_WRITE', 'MULTI_USER'),
-- SSL-DB02 (1007)
(3020, 1007, 303, '13.0.6441.1:SSL-DB02:Archiv',         'Archiv',          'Latin1_General_CI_AS', 'false', 'false', 'sa',  'SIMPLE', 'READ_ONLY',  'MULTI_USER'),
(3021, 1007, 303, '13.0.6441.1:SSL-DB02:Lager',          'Lager',           'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
-- BMP-SQLGXP01 (1008)
(3022, 1008, 301, '15.0.4355.3:BMP-SQLGXP01:LIMS',       'LIMS',            'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
(3023, 1008, 301, '15.0.4355.3:BMP-SQLGXP01:QMS',        'QMS',             'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
(3024, 1008, 301, '15.0.4355.3:BMP-SQLGXP01:Validierung','Validierung',     'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
-- BMP-SQLGXP02 (1009)
(3025, 1009, 301, '15.0.4355.3:BMP-SQLGXP02:Produktion', 'Produktion',      'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
(3026, 1009, 301, '15.0.4355.3:BMP-SQLGXP02:Forschung',  'Forschung',       'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
-- BMP-SQLREP01 (1010)
(3027, 1010, 300, '16.0.4120.1:BMP-SQLREP01:Reports',    'Reports',         'Latin1_General_CI_AS', 'true',  'false', 'sa',  'SIMPLE', 'READ_ONLY',  'MULTI_USER'),
-- EH-ERPDB01 (1011)
(3028, 1011, 300, '16.0.4120.1:EH-ERPDB01:ERP',          'ERP',             'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
(3029, 1011, 300, '16.0.4120.1:EH-ERPDB01:CRM',          'CRM',             'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
(3030, 1011, 300, '16.0.4120.1:EH-ERPDB01:Einkauf',      'Einkauf',         'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
(3031, 1011, 300, '16.0.4120.1:EH-ERPDB01:Vertrieb',     'Vertrieb',        'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
-- EH-ERPDB02 (1012)
(3032, 1012, 302, '14.0.3465.1:EH-ERPDB02:ERP_Archiv',   'ERP_Archiv',      'Latin1_General_CI_AS', 'false', 'false', 'sa',  'SIMPLE', 'READ_ONLY',  'MULTI_USER'),
(3033, 1012, 302, '14.0.3465.1:EH-ERPDB02:Fibu',         'Fibu',            'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
-- EH-RPTSQL01 (1013)
(3034, 1013, 301, '15.0.4355.3:EH-RPTSQL01:DWH',         'DWH',             'Latin1_General_CI_AS', 'true',  'true',  'sa',  'FULL',   'READ_WRITE', 'MULTI_USER'),
(3035, 1013, 301, '15.0.4355.3:EH-RPTSQL01:Analyse',     'Analyse',         'Latin1_General_CI_AS', 'true',  'false', 'sa',  'SIMPLE', 'READ_ONLY',  'MULTI_USER')
GO

PRINT ''
PRINT '============================================================'
PRINT 'Testdaten eingefuegt:'
SELECT 'Customer'              AS Tabelle, COUNT(*) AS Zeilen FROM Customer              UNION ALL
SELECT 'CustomerDomain',                   COUNT(*)           FROM CustomerDomain         UNION ALL
SELECT 'SQLVersion',                       COUNT(*)           FROM SQLVersion             UNION ALL
SELECT 'Support',                          COUNT(*)           FROM Support                UNION ALL
SELECT 'ManagedSQLEntityType',             COUNT(*)           FROM ManagedSQLEntityType   UNION ALL
SELECT 'ManagedEntityCompType',            COUNT(*)           FROM ManagedEntityCompType  UNION ALL
SELECT 'ManagedEntityDatabaseType',        COUNT(*)           FROM ManagedEntityDatabaseType UNION ALL
SELECT 'ExcludeDB',                        COUNT(*)           FROM ExcludeDB              UNION ALL
SELECT 'SQLServer',                        COUNT(*)           FROM SQLServer              UNION ALL
SELECT 'Computer',                         COUNT(*)           FROM Computer               UNION ALL
SELECT 'SQLDatabase',                      COUNT(*)           FROM SQLDatabase
ORDER BY 1
PRINT '============================================================'
GO
