/*
-- Clean up script
DELETE FROM dbo.DefaultSchedule;
DELETE FROM dbo.DefaultArchiveOffsets;
DELETE FROM dbo.ArchiveWatermarks;
DELETE FROM dbo.Metrics;
DELETE FROM dbo.MetricMultiRowKeys;
DELETE FROM dbo.MetricGroups;
DELETE FROM dbo.Targets;
*/

DECLARE @metricGroupId int;

INSERT INTO [dbo].[MetricGroups]
	(Name, ProbeCode, ChangeSpeed, IsMultiRow, IsCumulative, MultiRowKeyAttributesChangeSpeed)
VALUES
	('SQL Server Configuration', 'SqlServer', 'Slow', 'FALSE', 'FALSE', NULL);

SELECT @metricGroupId = Id
FROM [dbo].[MetricGroups]
WHERE Name = 'SQL Server Configuration';

SET QUOTED_IDENTIFIER OFF;

UPDATE [dbo].[MetricGroups]
SET Script = "SELECT
    CAST(SERVERPROPERTY('Edition') as varchar(128)) as [Edition],
	CAST(SERVERPROPERTY('ProductVersion') as varchar(128)) as [Version],
	CAST(SERVERPROPERTY('ProductLevel') as varchar(128)) as [Level],
	(SELECT CAST(value_in_use as float(53)) FROM sys.configurations WHERE name = 'max server memory (MB)') as [Max_Server_Memory],
	(SELECT CAST(COUNT(*) as smallint) FROM sys.databases WHERE name NOT IN ('master','model','tempdb','msdb')) as [Number_of_User_Databases]"
WHERE Id = @metricGroupId;

SET QUOTED_IDENTIFIER ON;

INSERT INTO [dbo].[Metrics]
(MetricGroupId, Name, DataType)
VALUES
	(@metricGroupId, 'Edition', 'Ansi'),
	(@metricGroupId, 'Version', 'Ansi'),
	(@metricGroupId, 'Level', 'Ansi'),
	(@metricGroupId, 'Max Server Memory', 'Double'),
	(@metricGroupId, 'Number of User Databases', 'SmallInt');

INSERT INTO [dbo].[DefaultSchedule]
	(MetricGroupId, OffsetInSecondsFromMidnight, IntervalInSeconds, RetentionPeriodInHours)
VALUES
	(@metricGroupId, 45, 2.5*60, 28*24);

INSERT INTO [dbo].[DefaultArchiveOffsets]
	(MetricGroupId, OffsetInMinutes, IntervalInSeconds)
VALUES
	(@metricGroupId, 48*60, 5*60);

GO

DECLARE @metricGroupId int;

INSERT INTO [dbo].[MetricGroups]
	(Name, ProbeCode, ChangeSpeed, IsMultiRow, IsCumulative, MultiRowKeyAttributesChangeSpeed)
VALUES
	('SQL Server Wait Stats', 'SqlServer', 'Fast', 'TRUE', 'TRUE', 'Static');

SELECT @metricGroupId = Id
FROM [dbo].[MetricGroups]
WHERE Name = 'SQL Server Wait Stats';

UPDATE [dbo].[MetricGroups]
SET Script = 'SELECT
    wait_type,
    CAST(waiting_tasks_count as float(53)) as [Waiting_Tasks_Count],
    CAST(wait_time_ms as float(53)) as [Wait_Time_ms],
    CAST(signal_wait_time_ms as float(53)) as [Signal_Wait_Time_ms]
FROM sys.dm_os_wait_stats
WHERE waiting_tasks_count > 0
  and wait_type not in (''LAZYWRITER_SLEEP'', ''XE_TIMER_EVENT'', ''XE_DISPATCHER_WAIT'',
    ''FT_IFTS_SCHEDULER_IDLE_WAIT'', ''DIRTY_PAGE_POLL'', ''REQUEST_FOR_DEADLOCK_SEARCH'',
	''SP_SERVER_DIAGNOSTICS_SLEEP'', ''BROKER_TO_FLUSH'', ''SQLTRACE_INCREMENTAL_FLUSH_SLEEP'',
	''HADR_FILESTREAM_IOMGR_IOCOMPLETION'', ''LOGMGR_QUEUE'', ''CHECKPOINT_QUEUE'',
    ''SLEEP_TASK'', ''BROKER_TASK_STOP'')'
WHERE Id = @metricGroupId;

INSERT INTO [dbo].[MetricMultiRowKeys]
(MetricGroupId, IsKeyAttribute, Name, DataType)
VALUES
	(@metricGroupId, 'FALSE', 'Wait Type', 'Ansi');

INSERT INTO [dbo].[Metrics]
(MetricGroupId, Name, DataType)
VALUES
	(@metricGroupId, 'Waiting Tasks Count', 'Double'),
	(@metricGroupId, 'Wait Time ms', 'Double'),
	(@metricGroupId, 'Signal Wait Time ms', 'Double');

INSERT INTO [dbo].[DefaultSchedule]
	(MetricGroupId, OffsetInSecondsFromMidnight, IntervalInSeconds, RetentionPeriodInHours)
VALUES
	(@metricGroupId, 0, 30, 28*24);

INSERT INTO [dbo].[DefaultArchiveOffsets]
	(MetricGroupId, OffsetInMinutes, IntervalInSeconds)
VALUES
	(@metricGroupId, 30, 60),
	(@metricGroupId, 48*60, 5*60);

GO

DECLARE @metricGroupId int;

INSERT INTO [dbo].[MetricGroups]
(Name, ProbeCode, ChangeSpeed, IsMultiRow, IsCumulative, MultiRowKeyAttributesChangeSpeed)
VALUES
	('SQL Server File Stats', 'SqlServer', 'Fast', 'TRUE', 'TRUE', 'Slow');

SELECT @metricGroupId = Id
FROM [dbo].[MetricGroups]
WHERE Name = 'SQL Server File Stats';

UPDATE [dbo].[MetricGroups]
SET Script = 'SELECT
    COALESCE(CONVERT(nvarchar(36), mf.file_guid), mf.name) as [FileGuid],
    DB_NAME(vfs.database_id) as [Database_Name],
    mf.name as [Logical_File_Name],
    mf.physical_name as [Physical_File_Name],
    CAST(mf.size as float(53)) as [File_Size],
    CAST(vfs.num_of_reads as float(53)) as [Number_of_reads],
    CAST(vfs.num_of_bytes_read as float(53)) as [Number_of_bytes_read],
    CAST(vfs.num_of_writes as float(53)) as [Number_of_writes],
    CAST(vfs.num_of_bytes_written as float(53)) as [Number_of_bytes_written],
    CAST(vfs.io_stall_read_ms as float(53)) as [IO_stall_read_ms],
    CAST(vfs.io_stall_write_ms as float(53)) as [IO_stall_write_ms]
FROM sys.dm_io_virtual_file_stats(NULL, NULL) vfs
	INNER JOIN master.sys.master_files mf
		ON vfs.database_id = mf.database_id AND vfs.file_id = mf.file_id'
WHERE Id = @metricGroupId;

INSERT INTO [dbo].[MetricMultiRowKeys]
(MetricGroupId, IsKeyAttribute, Name, DataType)
VALUES
    (@metricGroupId, 'FALSE', 'FileGuid', 'Ansi'),
    (@metricGroupId, 'FALSE', 'Database Name', 'Unicode'),
    (@metricGroupId, 'TRUE', 'Logical File Name', 'Unicode'),
    (@metricGroupId, 'TRUE', 'Physical File Name', 'Unicode'),
    (@metricGroupId, 'TRUE', 'File Size', 'Double');

INSERT INTO [dbo].[Metrics]
(MetricGroupId, Name, DataType)
VALUES
	(@metricGroupId, 'Number of reads', 'Double'),
	(@metricGroupId, 'Number of bytes read', 'Double'),
	(@metricGroupId, 'Number of writes', 'Double'),
	(@metricGroupId, 'Number of bytes written', 'Double'),
	(@metricGroupId, 'IO stall read ms', 'Double'),
	(@metricGroupId, 'IO stall write ms', 'Double');

INSERT INTO [dbo].[DefaultSchedule]
	(MetricGroupId, OffsetInSecondsFromMidnight, IntervalInSeconds, RetentionPeriodInHours)
VALUES
	(@metricGroupId, 5, 30, 28*24);

INSERT INTO [dbo].[DefaultArchiveOffsets]
	(MetricGroupId, OffsetInMinutes, IntervalInSeconds)
VALUES
	(@metricGroupId, 30, 60),
	(@metricGroupId, 48*60, 5*60);

GO

DECLARE @metricGroupId int;

INSERT INTO [dbo].[MetricGroups]
(Name, ProbeCode, ChangeSpeed, IsMultiRow, IsCumulative, MultiRowKeyAttributesChangeSpeed)
VALUES
	('SQL Server Physical Memory Stats', 'SqlServer', 'Fast', 'FALSE', 'FALSE', NULL);

SELECT @metricGroupId = Id
FROM [dbo].[MetricGroups]
WHERE Name = 'SQL Server Physical Memory Stats';

UPDATE [dbo].[MetricGroups]
SET Script = 'SELECT CAST(physical_memory_kb as float(53)) as [Physical_Memory_KB] FROM sys.dm_os_sys_info'
WHERE Id = @metricGroupId;

INSERT INTO [dbo].[Metrics]
(MetricGroupId, Name, DataType)
VALUES
	(@metricGroupId, 'Physical Memory KB', 'Double');

INSERT INTO [dbo].[DefaultSchedule]
	(MetricGroupId, OffsetInSecondsFromMidnight, IntervalInSeconds, RetentionPeriodInHours)
VALUES
	(@metricGroupId, 30, 60, 28*24);

INSERT INTO [dbo].[DefaultArchiveOffsets]
	(MetricGroupId, OffsetInMinutes, IntervalInSeconds)
VALUES
	(@metricGroupId, 30, 60),
	(@metricGroupId, 48*60, 5*60);

GO

DECLARE @metricGroupId int;

INSERT INTO [dbo].[MetricGroups]
(Name, ProbeCode, ChangeSpeed, IsMultiRow, IsCumulative, MultiRowKeyAttributesChangeSpeed)
VALUES
	('SQL Server Activity', 'SqlServer', 'Fast', 'FALSE', 'TRUE', NULL);

SELECT @metricGroupId = Id
FROM [dbo].[MetricGroups]
WHERE Name = 'SQL Server Activity';

UPDATE [dbo].[MetricGroups]
SET Script = 'SELECT
    (@@CPU_BUSY*CAST(@@TIMETICKS/1000 as float(53))/1000) as [CPU_mils],
    CAST(@@TOTAL_READ as float(53)) as [Physical_Reads],
    CAST(@@TOTAL_WRITE as float(53)) as [Physical_Writes]'
WHERE Id = @metricGroupId;

INSERT INTO [dbo].[Metrics]
(MetricGroupId, Name, DataType)
VALUES
	(@metricGroupId, 'CPU mils', 'Double'),
	(@metricGroupId, 'Physical Reads', 'Double'),
	(@metricGroupId, 'Physical Writes', 'Double');

INSERT INTO [dbo].[DefaultSchedule]
	(MetricGroupId, OffsetInSecondsFromMidnight, IntervalInSeconds, RetentionPeriodInHours)
VALUES
	(@metricGroupId, 10, 15, 28*24);

INSERT INTO [dbo].[DefaultArchiveOffsets]
	(MetricGroupId, OffsetInMinutes, IntervalInSeconds)
VALUES
	(@metricGroupId, 30, 60),
	(@metricGroupId, 48*60, 5*60);

GO

