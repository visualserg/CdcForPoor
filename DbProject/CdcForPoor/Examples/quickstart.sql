/* Примеры использования объектов схемы [cdcp]. */
/* Файл не входит в SSDT-сборку (отсутствует в .sqlproj) - это шпаргалка для ручных запусков. */

----------------------------------------------------------------------
-- 1. Поставить таблицу на аудит: получить и применить текст триггера.
----------------------------------------------------------------------

declare @ResultSql varchar(8000)
declare @DbgSqloutWithOutGo varchar(8000)

exec cdcp.usp_ManageTrigger
     @SchemaName         = 'dbo'
    ,@TableName          = '_User'
    ,@Insert             = 1
    ,@Update             = 1
    ,@Delete             = 1
    ,@Disabled           = 0
    ,@Exist              = 0   -- 0 = create trigger, 1 = alter trigger
    ,@DbgUseOut          = 1
    ,@DbgSqloutWithOutGo = @DbgSqloutWithOutGo out
    ,@ResultSql          = @ResultSql out

print @DbgSqloutWithOutGo
print '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
print @ResultSql

exec (@ResultSql);

----------------------------------------------------------------------
-- 2. Получить логи по строке (с разными PK и режимами).
----------------------------------------------------------------------

-- Простой PK
exec cdcp.usp_GetLogInfo
     @TableName      = 'Users'
    ,@PKValue        = '884176'
    ,@DbgNoSendEmail = 1

-- Составной PK
exec cdcp.usp_GetLogInfo
     @TableName      = 'ContractsProperties'
    ,@PK             = 'ContractsId:PropertyId'
    ,@PKValue        = '1197741:35'
    ,@DbgNoSendEmail = 1

-- Поиск по шаблону (LIKE)
exec cdcp.usp_GetLogInfo
     @TableName      = N'ContractsProperties'
    ,@PK             = N'ContractsId:PropertyId'
    ,@PKValue        = N'%:203'
    ,@Dbg            = 1
    ,@DbgNoSendEmail = 1

----------------------------------------------------------------------
-- 3. Справочные процедуры (find-or-create по ключу).
----------------------------------------------------------------------

-- usp_GetMergeUser
begin tran
  declare @UserId int
  exec [cdcp].usp_GetMergeUser
       @UserName = 'loc\m.urdun'
      ,@ResultId = @UserId out
  select @UserId
  select * from [cdcp].[User]
rollback tran

-- usp_GetMergeHost
begin tran
  declare @HostId int
  exec [cdcp].usp_GetMergeHost
       @HostName = 'host1'
      ,@ResultId = @HostId out
  select @HostId
  select * from [cdcp].[Host]
rollback tran

-- usp_GetMergeTable
begin tran
  declare @TableId int
  exec [cdcp].usp_GetMergeTable
       @TableSchema         = 'dbo'
      ,@TableName           = 'table1'
      ,@ColumnNameDelimeter = 'UserId:LocalId'
      ,@ResultId            = @TableId out
  select @TableId
  select * from [cdcp].[Table]
rollback tran

-- usp_GetMergeField
begin tran
  declare @FieldId int
         ,@FieldLog bit
  exec [cdcp].usp_GetMergeField
       @TableSchema = 'dbo'
      ,@TableName   = '_User'
      ,@FieldName   = 'UserId'
      ,@ResultId    = @FieldId out
      ,@ResultLog   = @FieldLog out
  select @FieldId, @FieldLog
  select * from [cdcp].Field
rollback tran

----------------------------------------------------------------------
-- 4. Утилитарная функция-разбиение строки.
----------------------------------------------------------------------

select * from cdcp.ufn_StringToStringTableId('мама мыла  раму: а, папа, - не мыл', ':')
select * from cdcp.ufn_StringToStringTableId('рококо, кукуку,мме', ',')
