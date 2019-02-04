CREATE TABLE [cdcp].[TriggerTemplate] (
    [Trigger] VARCHAR (51) NOT NULL,
    CONSTRAINT [PK_TriggerTemplate_Trigger] PRIMARY KEY CLUSTERED ([Trigger] ASC)
);


GO
/* Комментарии только такие! */
/* Логирование всех данных в cdcp */
/* Шаблон триггера для логирования */ /*#block_hide*/
/* Длина этого запроса не должна превышать 8000*/
/* Версия - 1.04 */
/*#block_...*/ /*нужен для поиска блоков при создании триггеров */ /*#block_hide*/

create trigger [cdcp].[tr_TriggerTemplate_v1] on [cdcp].[TriggerTemplate] /*#block_nameon*/ /*В одну строку !!!*/
for update, insert, delete /*#block_for*/
as
begin
  set nocount on
  declare @bit int
         ,@field int
         ,@maxfield int
         ,@char int
         ,@fieldname varchar(128)
         ,@SchemaName varchar(128)
         ,@TableName varchar(128)
         ,@PKCols varchar(1000)
         ,@sql varchar(2000)
         ,@UpdateDate varchar(21)
         ,@UserName varchar(128)
         ,@Type char(1)
         ,@PKSelect varchar(1000)
         ,@PKSelectValue varchar(1000)
         ,@PKSelectOnly varchar(1000)

  /* Get tableName */
  select @TableName = object_name(parent_id)
        ,@SchemaName = object_schema_name(parent_id)
  from sys.triggers
  where object_id = @@procid
  /* ----------------------------------------------------------------------- */

  /* date and user */
  select @UserName = system_user
        ,@UpdateDate = convert(nvarchar(30), getdate(), 126)
  /* ----------------------------------------------------------------------- */

  /* Action */
  if exists (select * from INSERTED)
    if exists (select * from DELETED)
      select @Type = 'U'
    else
      select @Type = 'I'
  else
    select @Type = 'D'

  /* get list of columns */
  select *  
  into #ins
  from INSERTED
  select *  
  into #del
  from DELETED

  select @PKCols = coalesce(@PKCols + ' and', ' on') + ' i.' + c.COLUMN_NAME + ' = d.' + c.COLUMN_NAME
  from INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk
      ,INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
  where pk.table_name = @TableName
    and CONSTRAINT_TYPE = 'PRIMARY KEY'
    and c.table_name = pk.table_name
    and c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME

  /* Get primary key select for insert */
  declare @Pk table(
    COLUMN_NAME varchar(128))

  ;with cte
  as (select c.COLUMN_NAME
        from INFORMATION_SCHEMA.TABLE_CONSTRAINTS pk
          , INFORMATION_SCHEMA.KEY_COLUMN_USAGE c
        where pk.table_name = @TableName
          and CONSTRAINT_TYPE = 'PRIMARY KEY'
          and c.table_name = pk.table_name
          and c.CONSTRAINT_NAME = pk.CONSTRAINT_NAME)
  insert @Pk (COLUMN_NAME)
  select COLUMN_NAME
  from cte

  select @PKSelect = coalesce(@PKSelect + '+', '')
    + '''<' + COLUMN_NAME
    + '=''+convert(varchar(100),coalesce(i.' + COLUMN_NAME + ',d.' + COLUMN_NAME + '))+''>'''
  from @Pk

  select @PKSelectValue = stuff((select '+''' + ':' + '''' + cast('+convert(varchar(100),coalesce(i.' + COLUMN_NAME + ',d.' + COLUMN_NAME + '))' as varchar(max))
          from @Pk
          order by COLUMN_NAME
          for xml path ('')), 1, 4, '')

  select @PKSelectOnly = stuff((select ':' + cast(COLUMN_NAME as varchar(max))
          from @Pk
          order by COLUMN_NAME
          for xml path ('')), 1, 1, '')

  if @PKCols is null
  begin
    raiserror ('no PK on table %s', 16,-1, @TableName)
    return
  end

  select @field = 0
        ,@maxfield = max(ORDINAL_POSITION)
  from INFORMATION_SCHEMA.COLUMNS
  where table_name = @TableName
  while @field < @maxfield
  begin
    select @field = min(ORDINAL_POSITION)
    from INFORMATION_SCHEMA.COLUMNS
    where table_name = @TableName
      and ORDINAL_POSITION > @field
    select @bit = (@field - 1) % 8 + 1
    select @bit = power(2, @bit - 1)
    select @char = ((@field - 1) / 8) + 1
    if substring(columns_updated(), @char, 1) & @bit > 0
      or @Type in ('I', 'D')
    begin
      declare @typeColumn varchar(100) = ''
      select @fieldname = COLUMN_NAME
            ,@typeColumn = data_type
      from INFORMATION_SCHEMA.COLUMNS
      where table_name = @TableName
        and ORDINAL_POSITION = @field

      begin tran
      /* GetSet PK */
      declare @ResultTableId int = null
      exec cdcp.usp_GetMergeTable @TableSchema = @SchemaName
                                    ,@TableName = @TableName
                                    ,@ColumnNameDelimeter = @PKSelectOnly
                                    ,@ResultId = @ResultTableId out
      /* ----------------------------------------------------------------- */
      
      /* GetSet Field */
      declare @ResultFieldId int = null
             ,@ResultLog bit = null
      exec cdcp.usp_GetMergeField @TableSchema = @SchemaName
                                    ,@TableName = @TableName
                                    ,@fieldname = @fieldname
                                    ,@ResultId = @ResultFieldId out
                                    ,@ResultLog = @ResultLog out
      declare @ResultUserId int = null
      exec cdcp.usp_GetMergeUser @UserName = @UserName
                                   ,@ResultId = @ResultUserId out
      /* ----------------------------------------------------------------- */
      
      /* GetSet host */
      declare @shost varchar(128)
      set @shost = (select top 1 isnull(HostName, '') from [master].[dbo].[sysprocesses] where spid = @@spid)
      declare @ResultHostId int = null
      exec cdcp.usp_GetMergeHost @HostName = @shost
                               ,@ResultId = @ResultHostId out
      /* ----------------------------------------------------------------- */
      
      if @ResultLog = 1
      begin
        declare @ValueD varchar(max) = 'convert(varchar(1000),d.' + @fieldname + ')'
        declare @ValueI varchar(max) = 'convert(varchar(1000),i.' + @fieldname + ')'
      
        if @typeColumn in ('datetime', 'datetime2')
        begin
          set @ValueD = 'convert(varchar,d.' + @fieldname + ',121)'
          set @ValueI = 'convert(varchar,i.' + @fieldname + ',121)'
        end
        select @sql = 'insert [cdcp].[Detail] (Type,TableId,PKValue,FieldId,OldValue,NewValue,UpdateDate,UserId,HostId)
            select ''' + @Type + ''','
          + cast(@ResultTableId as varchar(10))
          + ',' + @PKSelectValue
          + ',' + cast(@ResultFieldId as varchar(10))
          + ',' + @ValueD
          + ',' + @ValueI
          + ',' + '''' + @UpdateDate + ''''
          + ',' + cast(@ResultUserId as varchar(10))
          + ',' + cast(@ResultHostId as varchar(10))
          + ' from #ins i '
          + 'full join #del d'
          + @PKCols
          + ' where i.' + @fieldname + ' <> d.' + @fieldname
          + ' or (i.' + @fieldname + ' is null and d.' + @fieldname + ' is not null)'
          + ' or (i.' + @fieldname + ' is not null and d.' + @fieldname + ' is null)'
      
        exec (@sql)
      end
      commit tran
    end
  end
end;