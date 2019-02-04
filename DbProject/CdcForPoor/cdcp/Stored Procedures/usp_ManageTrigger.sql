/* Управление триггерами логирования */

/* Аргументы */
/* @SchemaName - схема таблицы триггера. По умолчанию dbo */
/* @TableName - таблица триггера */
/* @Insert - логирование вставки значений. По умолчанию 0 */
/* @Update - логирование обновления значений. По умолчанию 1 */
/* @Delete - логирование удаления значений. По умолчанию 0 */
/* @Disabled - триггер выключен при 1. По умолчанию 0 */
/* @Exist - если триггер уже есть на таблице, то 1 (инструкция сформирует Alter trigger), иначе 0 (инструкция сформирует Create trigger). По умолчанию 0 */
/* @DbgUseOut - при 1 в параметр ниже будет передаваться dsql код и выводится таблица исправления текста триггера, при 0 нет. По умолчанию 0 */
/* @DbgSqloutWithOutGo - вывод результирующих скриптов без go (см. ниже) */
/* @ResultSql () - вывод результирующих скриптов с учетом go (см. ниже) (Это основной код, который нужно выполнять) */

/* Notice: в sql сервере нельзя выполнить dynamic sql с инструкцией go */

create proc [cdcp].[usp_ManageTrigger]
  @SchemaName varchar(128) = 'dbo'
 ,@TableName varchar(128)
 ,@Insert bit = 0
 ,@Update bit = 1
 ,@Delete bit = 0
 ,@Disabled bit = 0
 ,@Exist bit = 0
 ,@DbgUseOut bit = 0
 ,@DbgSqloutWithOutGo varchar(8000) = '' out
 ,@ResultSql varchar(8000) out
as
begin
  set nocount on

  set @DbgSqloutWithOutGo = '';

  if not exists (select * from INFORMATION_SCHEMA.TABLES t where t.TABLE_SCHEMA = @SchemaName and t.table_name = @TableName and t.TABLE_TYPE = 'BASE TABLE')
  begin
    raiserror ('Такой таблицы не существует', 16, 2)
    return
  end

  if not exists (select null from INFORMATION_SCHEMA.KEY_COLUMN_USAGE where objectproperty(object_id(CONSTRAINT_SCHEMA + '.' + quotename(CONSTRAINT_NAME)), 'IsPrimaryKey') = 1 and table_name = @TableName and TABLE_SCHEMA = @SchemaName)
  begin
    declare @errorMessage varchar(max)
    set @errorMessage = 'Таблица '+@TableName+' не имеет PK'
    raiserror (@errorMessage, 16, 2)
    return
  end

  if object_id('tempdb..#Text') is not null
    drop table #Text
  create table #Text([Text] varchar(max))
  declare @startMessage varchar(100) = 'Триггер сгенерирован автоматически'
  insert #Text ([Text])
  select @startMessage+' /*#block_date*/'
  insert #Text
  exec sp_helptext 'cdcp.tr_TriggerTemplate_v1'
  alter table #Text add Id int identity primary key

  declare @TriggerNameWithSchema varchar(128)
         ,@TableNameWithSchema varchar(128)
  set @TableNameWithSchema = '['+@SchemaName+'].['+@TableName+']'
  set @TriggerNameWithSchema = '['+@SchemaName+'].['+'tr_'+@TableName+'_cdcp_v1]'

  declare @TriggerExist bit = 0
  declare @AllTrigger table(
    TriggerName varchar(256)
   ,SchemaName varchar(128)
   ,TableName varchar(128))

  ;with cte
  as (select o.[name] as trigger_name
            ,user_name(o.[uid]) as trigger_owner
            ,s.[name] as table_schema
            ,object_name(parent_obj) as table_name
            ,objectproperty(Id, 'ExecIsUpdateTrigger') as isupdate
            ,objectproperty(Id, 'ExecIsDeleteTrigger') as isdelete
            ,objectproperty(Id, 'ExecIsInsertTrigger') as isinsert
            ,objectproperty(Id, 'ExecIsAfterTrigger') as isafter
            ,objectproperty(Id, 'ExecIsInsteadOfTrigger') as isinsteadof
            ,objectproperty(Id, 'ExecIsTriggerDisabled') as [disabled]
        from sysobjects o
          join sys.tables t on o.parent_obj = t.object_id

          join sys.schemas s on t.schema_id = s.schema_id
        where o.[type] = 'TR')
  insert @AllTrigger (TriggerName, SchemaName, TableName)
  select trigger_name
        ,table_schema
        ,table_name
  from cte
  where table_schema = @SchemaName
    and table_name = @TableName


  if exists (select null from @AllTrigger where '['+SchemaName+'].['+TriggerName+']' = @TriggerNameWithSchema)
  begin
    set @TriggerExist = 1
  end

  if @Exist = 1 and @TriggerExist = 0
  begin
    raiserror ('Trigger not exist. Change value argument @Exist = 0', 16, 2)
    return
  end

  if @Exist = 0 and @TriggerExist = 1
  begin
    raiserror ('Trigger already exist. Change value argument @Exist = 1', 16, 2)
    return
  end

  insert #Text ([Text])
  select 'go;'
  insert #Text ([Text])
  select char(13)+char(10)
  insert #Text ([Text])
  select 'begin tran;'
  insert #Text ([Text])
  select 'disable trigger '+@TriggerNameWithSchema+' on '+@TableNameWithSchema+'; /*#block_disable*/ '
  insert #Text ([Text])
  select (case 
            when @Disabled = 1 then '/*'
            else ''
          end)+'enable trigger '+@TriggerNameWithSchema+' on '+@TableNameWithSchema+';'+(case
                                                                                           when @Disabled = 1 then '*/'
                                                                                           else ''
                                                                                         end)+' /*#block_enable*/ '
  insert #Text ([Text])
  select 'commit tran;'

  declare @forstr varchar(100)
  declare @for table([event] varchar(10))
  if @Insert = 1
    insert @for ([event])
    values ('insert');
  if @Update = 1
    insert @for ([event])
    values ('update');
  if @Delete = 1
    insert @for ([event])
    values ('delete');
  select @forstr = isnull(stuff((select ',' + cast([event] as varchar(max))
                                 from @for
                                 for xml path ('')), 1, 1, ''), 'insert,update,delete')
  -----------------------------------------------------------------------------    

  declare @createOrUpdate varchar(10)
  set @createOrUpdate = case
                         when isnull(@exist, 0) = 0 then 'create'
                         when isnull(@exist, 0) = 1 then 'alter'
                       end

  --- Check count template    
  declare @CntTemplate int
  select @CntTemplate = count(*)
  from #Text t
  where t.[Text] like '%/*#block_date*/%'
    or t.[Text] like '%/*#block_nameon*/%'
    or t.[Text] like '%/*#block_for*/%'
    or t.[Text] like '%/*#block_disable*/%'
  declare @CntTemlateOk int = 4
  if @CntTemplate <> @CntTemlateOk
  begin
    declare @mes varchar(100) = 'Cnt template != '
    set @mes += cast(@CntTemlateOk as varchar(10))
    raiserror (@mes, 16, 2)
    return
  end
  -----------------------------------------------------------------------------    

  select *
        ,case
           when t.[Text] like '%/*#block_date*/%' then '/* '+@startMessage+' '+convert(varchar(10), getdate(), 104)+' */'+char(13)+char(10)
           when t.[Text] like '%/*#block_nameon*/%' then @createOrUpdate+' trigger '+@TriggerNameWithSchema+' on '+@TableNameWithSchema+char(13)+char(10)
           when t.[Text] like '%/*#block_for*/%' then 'for '+@forstr+char(13)+char(10)
           when t.[Text] like '%/*#block_disable*/%' then t.[Text]
           when t.[Text] like '%/*#block_enable*/%' then t.[Text]
           when t.[Text] like '%/*#block_hide*/%' then ''
           else t.[Text]
         end as [sql_source]
  into #concat
  from #Text t

  if @DbgUseOut = 1
  begin
    select [Text] as BeforeLine
          ,'=>' as '=>'
          ,sql_source as AfterLine
    from #concat
    order by id
  end

  declare @curentLenSql int
  select @curentLenSql = len(stuff((select ' ' + c.sql_source
                                    from #concat c
                                    for xml path (''), type).value('text()[1]', 'nvarchar(max)'), 1, 1, N''))

  if @curentLenSql >= 8000
  begin
    raiserror ('Sql len >= 8000', 16, 2)
    return
  end

  if @DbgUseOut = 1
    set @DbgSqloutWithOutGo = @DbgSqloutWithOutGo + '/* sql len = '+cast(@curentLenSql as varchar(10))+' */'+char(10)+char(10)

  select @ResultSql = stuff((select c.sql_source
                             from #concat c
                             for xml path (''), type).value('.', 'nvarchar(max)'), 1, 0, N'')

  if @DbgUseOut = 1
    set @DbgSqloutWithOutGo = @DbgSqloutWithOutGo + @ResultSql

  set @ResultSql = 'EXEC (''' + replace(replace(@ResultSql, '''', ''''''), 'GO;', '''); EXEC(''') + ''');'

  if len(@ResultSql) >= 8000
  begin
    if @DbgUseOut = 0
      set @ResultSql = ''

    declare @errmes varchar(max)
    set @errmes = 'Sql len go >= 8000 ('+cast(len(@ResultSql) as varchar(10))+')'
    print @errmes

    raiserror (@errmes, 16, 2)
    return
  end
    
end

/*Helper    
    
  declare @ResultSql varchar(8000)    
  declare @DbgSqloutWithOutGo varchar(8000)  
  exec cdcp.usp_ManageTrigger @SchemaName = 'dbo'    
                             ,@TableName = '_User'    
                             ,@Insert = 1    
                             ,@Update = 1    
                             ,@Delete = 1    
                             ,@Disabled = 0    
                             ,@Exist = 0 
                             ,@DbgUseOut = 1    
                             ,@DbgSqloutWithOutGo = @DbgSqloutWithOutGo out    
                             ,@ResultSql = @ResultSql out

  print @DbgSqloutWithOutGo 
  print '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
  print '>>>>>>>>>>>>>>>>>>>>>>>>>>'
  print '>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>>'
  print @ResultSql 

  exec (@ResultSql);  
*/