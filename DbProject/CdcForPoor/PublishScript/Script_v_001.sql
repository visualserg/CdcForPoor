use ...
/* 04.02.2019 */

GO
CREATE SCHEMA [cdcp]
    AUTHORIZATION [dbo];


GO
PRINT N'Выполняется создание [cdcp].[Detail]...';


GO
CREATE TABLE [cdcp].[Detail] (
    [Id]         BIGINT         IDENTITY (1, 1) NOT NULL,
    [Type]       CHAR (1)       NOT NULL,
    [TableId]    INT            NOT NULL,
    [PKValue]    VARCHAR (1000) NULL,
    [FieldId]    INT            NOT NULL,
    [OldValue]   VARCHAR (1000) NULL,
    [NewValue]   VARCHAR (1000) NULL,
    [UpdateDate] DATETIME2 (7)  NOT NULL,
    [UserId]     INT            NULL,
    [HostId]     INT            NOT NULL,
    CONSTRAINT [PK_Detail_Id] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO
PRINT N'Выполняется создание [cdcp].[Field]...';


GO
CREATE TABLE [cdcp].[Field] (
    [Id]              INT           IDENTITY (1, 1) NOT NULL,
    [TableSchema]     VARCHAR (128) NOT NULL,
    [TableName]       VARCHAR (128) NOT NULL,
    [Field]           VARCHAR (128) NOT NULL,
    [Log]             BIT           NOT NULL,
    [CreateDate]      DATETIME2 (7) NOT NULL,
    [StarInsteadData] BIT           NOT NULL,
    [NotShow]         BIT           NOT NULL,
    CONSTRAINT [PK_Field_Id] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [KEY_Field] UNIQUE NONCLUSTERED ([TableName] ASC, [CreateDate] ASC)
);


GO
PRINT N'Выполняется создание [cdcp].[Host]...';


GO
CREATE TABLE [cdcp].[Host] (
    [Id]         INT           IDENTITY (1, 1) NOT NULL,
    [HostName]   VARCHAR (128) NULL,
    [CreateDate] DATETIME2 (7) NOT NULL,
    CONSTRAINT [PK_Host_Id] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO
PRINT N'Выполняется создание [cdcp].[Table]...';


GO
CREATE TABLE [cdcp].[Table] (
    [Id]          INT            IDENTITY (1, 1) NOT NULL,
    [TableSchema] VARCHAR (128)  NOT NULL,
    [TableName]   VARCHAR (128)  NOT NULL,
    [PK]          VARCHAR (4000) NOT NULL,
    [CreateDate]  DATETIME2 (7)  NOT NULL,
    CONSTRAINT [PK_Table_Id] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO
PRINT N'Выполняется создание [cdcp].[User]...';


GO
CREATE TABLE [cdcp].[User] (
    [Id]         INT           IDENTITY (1, 1) NOT NULL,
    [UserName]   VARCHAR (128) NOT NULL,
    [CreateDate] DATETIME2 (7) NOT NULL,
    CONSTRAINT [PK_User_Id] PRIMARY KEY CLUSTERED ([Id] ASC)
);


GO
PRINT N'Выполняется создание [cdcp].[TriggerTemplate]...';


GO
CREATE TABLE [cdcp].[TriggerTemplate] (
    [Trigger] VARCHAR (51) NOT NULL,
    CONSTRAINT [PK_TriggerTemplate_Trigger] PRIMARY KEY CLUSTERED ([Trigger] ASC)
);


GO
PRINT N'Выполняется создание ограничение без названия для [cdcp].[Field]...';


GO
ALTER TABLE [cdcp].[Field]
    ADD DEFAULT (getdate()) FOR [CreateDate];


GO
PRINT N'Выполняется создание ограничение без названия для [cdcp].[Host]...';


GO
ALTER TABLE [cdcp].[Host]
    ADD DEFAULT (getdate()) FOR [CreateDate];


GO
PRINT N'Выполняется создание ограничение без названия для [cdcp].[Table]...';


GO
ALTER TABLE [cdcp].[Table]
    ADD DEFAULT (getdate()) FOR [CreateDate];


GO
PRINT N'Выполняется создание ограничение без названия для [cdcp].[User]...';


GO
ALTER TABLE [cdcp].[User]
    ADD DEFAULT (getdate()) FOR [CreateDate];


GO
PRINT N'Выполняется создание [cdcp].[FK_Detail_FieldId]...';


GO
ALTER TABLE [cdcp].[Detail] WITH NOCHECK
    ADD CONSTRAINT [FK_Detail_FieldId] FOREIGN KEY ([FieldId]) REFERENCES [cdcp].[Field] ([Id]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Выполняется создание [cdcp].[FK_Detail_HostId]...';


GO
ALTER TABLE [cdcp].[Detail] WITH NOCHECK
    ADD CONSTRAINT [FK_Detail_HostId] FOREIGN KEY ([HostId]) REFERENCES [cdcp].[Host] ([Id]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Выполняется создание [cdcp].[FK_Detail_TableId]...';


GO
ALTER TABLE [cdcp].[Detail] WITH NOCHECK
    ADD CONSTRAINT [FK_Detail_TableId] FOREIGN KEY ([TableId]) REFERENCES [cdcp].[Table] ([Id]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Выполняется создание [cdcp].[FK_Detail_UserId]...';


GO
ALTER TABLE [cdcp].[Detail] WITH NOCHECK
    ADD CONSTRAINT [FK_Detail_UserId] FOREIGN KEY ([UserId]) REFERENCES [cdcp].[User] ([Id]) ON DELETE CASCADE ON UPDATE CASCADE;


GO
PRINT N'Выполняется создание [cdcp].[ufn_StringToStringTableId]...';


GO
/* Функция преобразует строку @pLIST в таблицу строк */
/* параметр @pDelem (разделитель) по умолчанию принимает значение ',' */

create function cdcp.ufn_StringToStringTableId (
  @StringInput varchar(max)
 ,@pDelem nvarchar(10) = ',')
returns @OutputTable table (
  Id int
 ,[Value] varchar(max))
as
begin
  declare @StringValue varchar(100)
  set @StringInput = rtrim(ltrim(@StringInput))
  declare @I int = 0;
  while len(@StringInput) > 0
  begin
    set @I = @I + 1
    set @StringValue = left(@StringInput, isnull(nullif(charindex(@pDelem, @StringInput) - 1, -1), len(@StringInput)))
    set @StringInput = substring(@StringInput, isnull(nullif(charindex(@pDelem, @StringInput), 0), len(@StringInput)) + 1, len(@StringInput))
    set @StringInput = rtrim(ltrim(@StringInput))
    insert @OutputTable (Id, [Value])
    values (@I, @StringValue)
  end
  return
end

/*Helper    
  select * from cdcp.ufn_StringToStringTableId('мама мыла  раму: а, папа, - не мыл',':')
  select * from cdcp.ufn_StringToStringTableId('рококо, кукуку,мме',',')
*/
GO
PRINT N'Выполняется создание [cdcp].[usp_GetMergeField]...';


GO
/* Процедура возвращает Id колонки (если ее нет, то создает) */
/* @ResultId - FieldId */
/* @ResultLog - нужно ли логировать */

create procedure [cdcp].[usp_GetMergeField]
  @TableSchema varchar(128)
 ,@TableName varchar(128)
 ,@FieldName varchar(128)
 ,@ResultId int out
 ,@ResultLog bit out
as
begin
  set nocount on

  select @ResultId = Id
        ,@ResultLog = [Log]
  from [cdcp].Field
  where TableName = @TableName
    and Field = @FieldName

  if @ResultId is null
  begin
    declare @Out table(Id int,[Log] bit)
    insert [cdcp].Field (TableSchema, TableName, Field, [Log], StarInsteadData, NotShow)
    output inserted.Id, inserted.[Log] into @Out (Id, [Log])
    values (@TableSchema, @TableName, @FieldName, 1, 0, 0);

    select top 1 @ResultId = Id
                ,@ResultLog = [Log]
    from @Out
  end

  return
end

/*Helper  
  begin tran  
    declare @ResultId int  
           ,@ResultLog bit  
    exec [cdcp].usp_GetMergeField @TableSchema='dbo'
                                 ,@TableName='_User'  
                                 ,@FieldName='UserId'  
                                 ,@ResultId=@ResultId out  
                                 ,@ResultLog=@ResultLog out  
    select @ResultId  
    select @ResultLog  
    select * from [cdcp].Field  
  
    --delete from [cdcp].Field where id=0  
  rollback tran  
*/
GO
PRINT N'Выполняется создание [cdcp].[usp_GetMergeHost]...';


GO
/* Процедура возвращает Id host (если его нет, то создает) */

create procedure [cdcp].[usp_GetMergeHost]
  @HostName varchar(128)
 ,@ResultId int out
as
begin
  set nocount on

  select @ResultId = Id
  from [cdcp].Host
  where HostName = @HostName

  if @ResultId is null
  begin
    insert [cdcp].Host (HostName)
    values (@HostName);
    set @ResultId = scope_identity()
  end

  return
end

/*Helper
  begin tran
    declare @ResultId int
    exec [cdcp].usp_GetMergeHost @HostName='host1'
                                ,@ResultId=@ResultId out
    select @ResultId
    select * from [cdcp].[Host]

    --delete from [cdcp].[Host] where id=0
  rollback tran
*/
GO
PRINT N'Выполняется создание [cdcp].[usp_GetMergeTable]...';


GO
/* Процедура возвращает Id связки (если ее нет, то создает) */
/* Принимает схему, название таблицы */
/* @ColumnNameDelimeter - строка названия колонок, отсортированная asc с разделителем "," без пробелов */ 

create procedure [cdcp].[usp_GetMergeTable]
  @TableSchema varchar(128)
 ,@TableName varchar(128)
 ,@ColumnNameDelimeter varchar(4000)
 ,@ResultId int out
as
begin
  set nocount on

  --- Получаем последний ключ по дате
  declare @LastPK varchar(4000)

  ;with cte
  as (select * from [cdcp].[Table] where TableName = @TableName)
  select @ResultId = Id
        ,@LastPK = PK
  from cte
  where CreateDate = (select max(CreateDate) from cte group by TableName)

  if @ResultId is null
    or @LastPK != @ColumnNameDelimeter
  begin
    insert [cdcp].[Table] (TableSchema, TableName, PK)
    values (@TableSchema, @TableName, @ColumnNameDelimeter);
    set @ResultId = scope_identity()
  end

  return
end

/*Helper  
  begin tran  
    declare @ResultId int  
    exec [cdcp].usp_GetMergeTable @TableSchema='dbo' 
                                ,@TableName='table1'  
                                ,@ColumnNameDelimeter='UserId:LocalId'  
                                ,@ResultId=@ResultId out  
    select @ResultId  
    select * from [cdcp].[Table]
  
    --delete from [cdcp].[Table] where id=32
  rollback tran  
*/
GO
PRINT N'Выполняется создание [cdcp].[usp_GetMergeUser]...';


GO
/* Процедура возвращает Id user (если его нет, то создает) */

create procedure [cdcp].[usp_GetMergeUser]
  @UserName varchar(128)
 ,@ResultId int out
as
begin
  set nocount on

  select @ResultId = Id
  from [cdcp].[User]
  where UserName = @UserName

  if @ResultId is null
  begin
    insert [cdcp].[user] (UserName)
    values (@UserName);
    set @ResultId = scope_identity()
  end

  return
end

/*Helper
  begin tran
    declare @ResultId int
    exec [cdcp].usp_GetMergeUser @UserName='loc\m.urdun'
                               ,@ResultId=@ResultId out
    select @ResultId
    select * from [cdcp].[User]

    --delete from [cdcp].[User] where id=0
  rollback tran
*/
GO
PRINT N'Выполняется создание [cdcp].[usp_GetLogInfo]...';


GO
SET ANSI_NULLS ON;

SET QUOTED_IDENTIFIER OFF;


GO
/* Получение логов по аудиту */

/* Аргументы */
/* @ShemaName - схема таблицы, логи которой нужны. Default=dbo */
/* @TableName - таблица, логи которой нужны */
/* @PK - столбец или несколько столбцов через знак : отсортированных на названию столбца в порядке возрастания (asc), который является primary key у таблицы, логи которой нужны. Default=id */
/* @PKValue - значение или несколько значений через знак : отсортированных на названию столбца в порядке возрастания (asc), которое является значением primary key у таблицы, логи которой нужны */
/* @PKValue может содержать знак %, вследствие чего поиск будет работать через оператор like. Например '236:%:1' или '%:10' */
/* @FieldInclude - если указано, то будут выводиться только эти столбцы в результирующей таблице, если не указано, то будут выводиться все. Разделитель , */
/* @FieldExclude - если указано, то из результирующей таблице будут исключены эти столбцы, если не указано, то будут выводиться все. Разделитель , */

/* @MailRecipients - получатель письма ошибок и предупреждений (для нескольких получателей разделитель ",") */
/* @Dbg - режим отладки */
/* @DbgNoSendEmail - не отправлять (информационные/об ошибках) письма */

create proc [cdcp].[usp_GetLogInfo]
  @ShemaName varchar(128) = 'dbo'
 ,@TableName varchar(128)
 ,@PK varchar(4000) = 'id'
 ,@PKValue varchar(1000)
 ,@FieldInclude varchar(max) = ''
 ,@FieldExclude varchar(max) = ''
 ,@MailRecipients varchar(max) = ''
 ,@Dbg bit = 0
 ,@DbgNoSendEmail bit = 0
as
begin
  begin try

    set quoted_identifier off
    set nocount on

    /*Result table*/
    declare @Result table(
      id int
     ,[Type] char(1)
     ,UpdateDate datetime
     ,PK varchar(max)
     ,PKValue varchar(max)
     ,Field varchar(max)
     ,descr varchar(max)
     ,RTable varchar(max)
     ,OldValue varchar(max)
     ,NewValue varchar(max)
     ,RunDsql bit
     ,DsqlOld nvarchar(max)
     ,DsqlNew nvarchar(max)
     ,OldResult varchar(max)
     ,NewResult varchar(max)
     ,DsqlDescr nvarchar(max)
     ,DescrSearchInPk nvarchar(max))

    declare @TableId int
    select @TableId = t.id
    from [cdcp].[Table] t
    where t.TableSchema = @ShemaName
      and t.TableName = @TableName
      and t.PK = @PK

    declare @PercentExist bit = 0
    if @PKValue like '%[%]%'
      set @PercentExist = 1

    if object_id('tempdb..#detail') is not null
      drop table #detail
    create table #detail(
      DetailId bigint)
    create clustered index jhskdjfhsjkfh on #detail (DetailId)
    insert #detail (DetailId)
    select d.id as DetailId
    from [cdcp].Detail d
    where d.TableId = @TableId
      and ((@PercentExist = 0
      and d.PKValue = @PKValue)
      or (@PercentExist = 1
      and d.PKValue like @PKValue))

    /*Mail*/
    declare @MailBody nvarchar(4000)
           ,@MailSubject nvarchar(126)

    /*Field include and/or exclude*/
    declare @TableInExclude table(
      FieldName varchar(max)
     ,Ttype bit) /*0 - include, 1-exclude*/
    declare @ExistInclude bit = 0
    if isnull(@FieldInclude, '') != ''
    begin
      set @ExistInclude = 1
      insert @TableInExclude (FieldName, Ttype)
      select [Value]
            ,0
      from cdcp.ufn_StringToStringTableId(@FieldInclude, ',')
    end
    declare @ExistExclude bit = 0
    if isnull(@FieldExclude, '') != ''
    begin
      set @ExistExclude = 1
      insert @TableInExclude (FieldName, Ttype)
      select [Value]
            ,1
      from cdcp.ufn_StringToStringTableId(@FieldExclude, ',')
    end

    /*All type ()*/
    declare @ListType table(
      TypeName varchar(100)
     ,NeedApostr bit)
    insert @ListType (TypeName, NeedApostr)
    values ('bigint', 0)
          ,('binary', 0)
          ,('bit', 0)
          ,('char', 1)
          ,('date', 1)
          ,('datetime', 1)
          ,('datetime2', 1)
          ,('datetimeoffset', 1)
          ,('decimal', 0)
          ,('float', 0)
          ,('geography', 0)
          ,('geometry', 0)
          ,('hierarchyid', 0)
          ,('image', 0)
          ,('int', 0)
          ,('money', 0)
          ,('nchar', 1)
          ,('ntext', 1)
          ,('numeric', 0)
          ,('nvarchar', 1)
          ,('real', 0)
          ,('smalldatetime', 1)
          ,('smallint', 0)
          ,('smallmoney', 0)
          ,('sql_variant', 1)
          ,('sysname', 1)
          ,('text', 1)
          ,('time', 0)
          ,('timestamp', 0)

    declare @allDescr table(
      class tinyint
     ,major_id int
     ,minor_id int
     ,[Value] varchar(max))

    insert @allDescr (class, major_id, minor_id, Value)
    select class
          ,major_id
          ,minor_id
          ,cast([value] as varchar(max)) as [value]
    from sys.extended_properties
    where [name] = 'MS_Description'
      and class = 1

    declare @allColumn table(
      ObjectId int
     ,SchemaName sysname
     ,TableName sysname
     ,ColumnName sysname
     ,ColumnDescr varchar(max)
     ,TableDescr varchar(max))
    insert @allColumn (ObjectId, SchemaName, TableName, ColumnName, ColumnDescr, TableDescr)
    select o.object_id as ObjectId
          ,schema_name(o.schema_id) as SchemaName
          ,o.[name] as TableName
          ,c.[name] as ColumnName
          ,p.[Value] as ColumnDescr
          ,t.[Value] as TableDescr
    from sys.objects o
      join sys.columns c on c.object_id = o.object_id
      left join @allDescr as p on p.major_id = o.object_id
        and c.column_id = p.minor_id
      left join @allDescr t on t.major_id = o.object_id
        and t.minor_id = 0
    where o.[Type] in ('U', 'V')

    declare @allFk table(
      FkName sysname
     ,SObject int
     ,SSchema sysname
     ,STable sysname
     ,SColumn sysname
     ,RObject int
     ,RSchema sysname
     ,RTable sysname
     ,RColumn sysname
     ,RType sysname)

    insert @allFk (FkName, SObject, SSchema, STable, SColumn, RObject, RSchema, RTable, RColumn, RType)
    select obj.[name] as FkName
          ,tab1.object_id as SObject
          ,sch1.[name] as SSchema
          ,tab1.[name] as STable
          ,col1.[name] as SColumn
          ,tab2.object_id as RObject
          ,sch2.[name] as RSchema
          ,tab2.[name] as RTable
          ,col2.[name] as RColumn
          ,typ2.[name] as RType
    from sys.foreign_key_columns fkc
      join sys.objects obj on obj.object_id = fkc.constraint_object_id
      join sys.tables tab1 on tab1.object_id = fkc.parent_object_id
      join sys.schemas sch1 on tab1.schema_id = sch1.schema_id
      join sys.columns col1 on col1.column_id = parent_column_id
        and col1.object_id = tab1.object_id
      --left join sys.types typ1 on typ1.user_type_id = col1.system_type_id                
      join sys.tables tab2 on tab2.object_id = fkc.referenced_object_id
      join sys.schemas sch2 on tab2.schema_id = sch2.schema_id
      join sys.columns col2 on col2.column_id = referenced_column_id
        and col2.object_id = tab2.object_id
      join sys.types typ2 on typ2.user_type_id = col2.system_type_id

    ;
    with allRecursion
    as (select substring(c.ColumnDescr, charindex('>', c.ColumnDescr) + 1, charindex('>', c.ColumnDescr, charindex('>', c.ColumnDescr) + 1) - 1 - charindex('>', c.ColumnDescr, charindex('>', c.ColumnDescr))) as SearchInPk
              ,c.SchemaName
              ,c.TableName
              ,c.ColumnName as SearchColumnValue
              ,cc.ColumnName as SelectSql
              ,f.RSchema as SchemaSql
              ,f.RTable as TableSql
              ,f.RColumn as WhereSql
          from @allColumn c
            join @allFk f on c.ObjectId = f.SObject
              and f.SColumn = substring(c.ColumnDescr, charindex('>', c.ColumnDescr) + 1, charindex('>', c.ColumnDescr, charindex('>', c.ColumnDescr) + 1) - 1 - charindex('>', c.ColumnDescr, charindex('>', c.ColumnDescr)))
              and c.ColumnDescr like '%<recursion>%'
            join @allColumn cc on f.RSchema = cc.SchemaName
              and f.RTable = cc.TableName
              and cc.ColumnDescr like '%<logname>%'),
    allData
    as (select c.SchemaName
              ,c.TableName
              ,c.ColumnName
              ,c.ColumnDescr
              ,c.TableDescr
              ,f.RSchema
              ,f.RTable
              ,f.RColumn
              ,f.RType
              ,c1.ColumnName as RColumnSelect
              ,c1.ColumnDescr as RColumnDescr
              ,"select @resultOut=cast(" + coalesce(b.ColumnNamePlus, c1.ColumnName) + " as varchar(max)) from " + RTable + " where " + RColumn + " = " as DsqlOld
              ,"select @resultOut=cast(" + coalesce(b.ColumnNamePlus, c1.ColumnName) + " as varchar(max)) from " + RTable + " where " + RColumn + " = " as DsqlNew
          from @allColumn c
            left join (select *      
                  from @allFk f
                  where SObject not in (select SObject
                          from @allFk
                          group by SObject
                                  ,FkName
                          having count(*) > 1)
            /*убираем fk с кол-вом полей > 1*/
            ) f on c.ObjectId = f.SObject
              and c.SchemaName = f.SSchema
              and c.TableName = f.STable
              and f.SColumn = c.ColumnName
            left join @allColumn c1 on c1.ObjectId = f.RObject
              and c1.SchemaName = f.RSchema
              and c1.TableName = f.RTable
              and c1.ColumnDescr like '%<logname>%'
            /*For split <logname>*/
            left join (select cc.SchemaName
                             ,cc.TableName
                             ,cc.ObjectId
                             ,(select stuff((select '+' + '''' + ' ' + '''' + '+cast(isnull(' + ColumnName + ',' + '''' + '''' + ') as varchar(max))'
                                          from @allColumn a
                                          where a.SchemaName = cc.SchemaName
                                            and a.TableName = cc.TableName
                                            and a.ColumnDescr like '%<logname>%'
                                          for xml path ('')), 1, 5, '')) as ColumnNamePlus
                  from @allColumn cc
                  where cc.ColumnDescr like '%<logname>%'
                  group by cc.SchemaName
                          ,cc.TableName
                          ,cc.ObjectId
                  having count(*) > 1) b on b.ObjectId = f.RObject)
    insert @Result (id, Type, UpdateDate, PK, PKValue, Field, descr, RTable, OldValue, NewValue, RunDsql, DsqlOld, DsqlNew, OldResult, NewResult, DsqlDescr, DescrSearchInPk)
    select b.id
          ,b.[Type]
          ,b.UpdateDate
          ,b.PK
          ,b.PKValue
          ,b.Field
          ,b.descr
          ,b.RTable
          ,b.OldValue
          ,b.NewValue
          ,b.RunDsql
          ,b.DsqlOld
          ,b.DsqlNew
          ,case
             when b.RunDsql is null then b.OldValue
             when b.RunDsql is not null
               and DsqlOld is null then b.OldValue
           end as OldResult
          ,case
             when b.RunDsql is null then b.NewValue
             when b.RunDsql is not null
               and DsqlNew is null then b.NewValue
           end as NewResult
          ,b.DsqlDescr
          ,SearchInPk
    from (select d.id
                ,d.[Type]
                ,d.UpdateDate
                ,@PK as PK
                ,d.PKValue
                ,f.Field
                ,ltrim(rtrim(replace(a.ColumnDescr, '<fk>', ''))) as Descr
                ,a.RTable
                 --,a.RColumn                
                 --,a.RType                
                ,case
                   when f.StarInsteadData = 1 and d.OldValue is not null then '***'
                   else OldValue
                 end as OldValue
                ,case
                   when f.StarInsteadData = 1 and d.NewValue is not null then '***'
                   else NewValue
                 end as NewValue
                ,case
                   when a.ColumnDescr like '%<fk>%' then 1
                 end as RunDsql
                ,a.DsqlOld + case
                              when t.NeedApostr = 1 then '''' + d.OldValue + ''''
                              else d.OldValue
                            end as DsqlOld
                ,a.DsqlNew + case
                              when t.NeedApostr = 1 then '''' + d.NewValue + ''''
                              else d.NewValue
                            end as DsqlNew
                ,'select ' + r.SelectSql + ' from ' + r.SchemaName + '.' + r.TableSql + ' where ' + r.WhereSql + '=' as DsqlDescr
                ,r.SearchInPk
            from [cdcp].Detail d
              join #detail d1 on d1.DetailId = d.id
              join [cdcp].Field f on d.FieldId = f.id
                and isnull(f.NotShow, 0) = 0
              join allData a on a.SchemaName = f.TableSchema
                and a.TableName = f.TableName
                and a.ColumnName = f.Field
              left join @ListType t on t.TypeName = a.RType
              left join allRecursion r on a.SchemaName = r.SchemaName
                and a.TableName = r.TableName
                and a.ColumnName = r.SearchColumnValue) b

    declare @DsqlQuery table(
      id int
     ,Dsql nvarchar(max)
     ,Ttype tinyint
     ,PKt varchar(max)
     ,PKValuet varchar(max)
     ,DescrSearchInPk nvarchar(max))
    insert @DsqlQuery (id, Dsql, Ttype, PKt, PKValuet, DescrSearchInPk)
    select id
          ,DsqlOld
          ,cast(0 as tinyint) as ttype
          ,null as PKt
          ,null as PKValuet
          ,null as DescrSearchInPk
    from @Result
    where RunDsql = 1
      and isnull(DsqlOld, '') != ''
    union /*NewValue*/
    select id
          ,DsqlNew
          ,cast(1 as tinyint) as ttype
          ,null as PKt
          ,null as PKValuet
          ,null as DescrSearchInPk
    from @Result
    where RunDsql = 1
      and isnull(DsqlNew, '') != ''
    union /*Description*/
    select distinct -1 as Id
                   ,DsqlDescr
                   ,cast(2 as tinyint) as ttype
                   ,PK
                   ,PKValue
                   ,DescrSearchInPk
    from @Result
    where isnull(DsqlDescr, '') != ''

    /*Execute value*/
    declare @cacheDsql table(
      SourceSql varchar(800) primary key
     ,ResultSql varchar(max))
    declare @cacheOut varchar(max)
    declare @Id int
           ,@Dsql nvarchar(max)
           ,@Ttype tinyint
           ,@PKt varchar(max)
           ,@PKValuet varchar(max)
           ,@DescrSearchInPk nvarchar(max)
    declare db_cursor cursor for /*OldValue*/
      select id
            ,Dsql
            ,Ttype
            ,PKt
            ,PKValuet
            ,DescrSearchInPk
      from @DsqlQuery
    open db_cursor
    fetch next from db_cursor into @Id, @Dsql, @Ttype, @PKt, @PKValuet, @DescrSearchInPk
    while @@fetch_status = 0
    begin

      --- Calc description        
      if (@Ttype = 2)
      begin
        declare @IdPk int
               ,@PkValueResult varchar(max)
        select @IdPk = id
        from cdcp.cdcp.ufn_StringToStringTableId(@PKt, ':')
        where [Value] = @DescrSearchInPk
        select @PkValueResult = [Value]
        from cdcp.cdcp.ufn_StringToStringTableId(@PKValuet, ':')
        where id = @IdPk
        set @Dsql = 'select @resultOut=cast((' + @Dsql + '''' + @PkValueResult + '''' + ') as varchar(max))'
      end

      set @cacheOut = null
      select @cacheOut = ResultSql
      from @cacheDsql
      where SourceSql = @Dsql

      declare @resultOut varchar(max)
      if @cacheOut is null
      begin
      begin try

        exec sp_executesql @Dsql
                          ,N'@resultOut varchar(max) out'
                          ,@resultOut out
        if (isnull(@Dsql, '') = '')
        begin
          if @Dbg = 1
            print 'error @Dsql=   '+@Dsql
        end
        else
          insert @cacheDsql (SourceSql, ResultSql)
          values (@Dsql, @resultOut);
      end try
      begin catch
        print 'error @cacheOut='+@cacheOut
      end catch
      end
      else
      begin
        if @Dbg = 1
          print 'запрос ' + @Dsql + ' в кэше есть'
        set @resultOut = @cacheOut
      end

      if @Ttype = 0
        update @Result
        set OldResult = @resultOut
        where id = @Id
      if @Ttype = 1
        update @Result
        set NewResult = @resultOut
        where id = @Id
      if @Ttype = 2
        update r
        set descr = @resultOut
        from @Result r
        where DescrSearchInPk = @DescrSearchInPk
          and @PKValuet = r.PKValue

      fetch next from db_cursor into @Id, @Dsql, @Ttype, @PKt, @PKValuet, @DescrSearchInPk
    end
    close db_cursor
    deallocate db_cursor

    --- Update other descr        
    update @Result
    set descr = Field
    where isnull(descr, '') = ''
      and DescrSearchInPk is null

    if @Dbg = 1
    begin
      select id
            ,PK
            ,PKValue
            ,Field
            ,RTable
            ,RunDsql
            ,descr
            ,OldValue
            ,NewValue
            ,OldResult
            ,NewResult
            ,DsqlOld
            ,DsqlNew
            ,DsqlDescr
            ,DescrSearchInPk
      from @Result
      order by UpdateDate

    --select * from @cdcpTime      
    end
    else
    begin
      if exists (select null from @Result where descr is null)
      begin
        declare @FieldWithOutDescr varchar(max)
        select @FieldWithOutDescr = stuff((select ', ' + cast(Field as varchar(max))
                from (select distinct Field
                                     ,descr
                        from @Result
                        where descr is null) h
                for xml path ('')), 1, 2, '')
        set @MailSubject = 'Предупреждение из процедуры ' + (select object_name(@@procid))
        set @MailBody = case
                         when @FieldWithOutDescr like '%,%' then 'Поля'
                         else 'Поле'
                       end + ': <b>' + @FieldWithOutDescr + '</b><br/>В таблице: <b>' + @TableName + '</b><br/>' + case
                                                                                                                    when @FieldWithOutDescr like '%,%' then 'Не имеют'
                                                                                                                    else 'Не имеет'
                                                                                                                  end + ' description'

        if @DbgNoSendEmail = 0
          exec msdb.dbo.sp_send_dbmail @Recipients = @MailRecipients
                                      ,@Subject = @MailSubject
                                      ,@Body = @MailBody
                                      ,@Body_format = 'html'
      end

      select distinct r.descr
                     ,r.OldResult
                     ,r.NewResult
                     ,r.UpdateDate
                     ,case r.[Type]
                        when 'I' then 'Вставка'
                        when 'U' then 'Обновление'
                        when 'D' then 'Удаление'
                        when 'N' then ''
                      end as [Type] /*, t0.Ttype, t1.Ttype*/
      from @Result r
        left join @TableInExclude t0 on r.Field = t0.FieldName
          and t0.Ttype = 0
          and @ExistInclude = 1
        left join @TableInExclude t1 on r.Field = t1.FieldName
          and t1.Ttype = 1
          and @ExistExclude = 1
      where (@ExistInclude = 0
        or (@ExistInclude = 1
        and t0.Ttype = 0))
        and (@ExistExclude = 0
        or (@ExistExclude = 1
        and t1.Ttype is null))
      order by UpdateDate
    end
  end try
  begin catch

    begin try
      close db_cursor
      deallocate db_cursor
    end try
    begin catch
    end catch

    declare @ErrorNumber int = error_number();
    declare @ErrorLine int = error_line();
    declare @ErrorMessage nvarchar(4000) = error_message();
    declare @ErrorSeverity int = error_severity();
    declare @ErrorState int = error_state();
    raiserror (@ErrorMessage, @ErrorSeverity, @ErrorState)

    if @DbgNoSendEmail = 0
    begin
      declare @ErrorMessageCommon varchar(max)
      set @ErrorMessageCommon = formatmessage('Error Number: %d, Line: %d, Severity: %d, State: %d, Message: %s', @ErrorNumber, @ErrorLine, @ErrorSeverity, @ErrorState, @ErrorMessage)
      set @MailBody = 'Server: ' + @@servername + char(10) + char(13) + 'Db: ' + db_name() + char(10) + char(13) + 'Procedure: ' + error_procedure() + char(10) + char(13) + 'Message: ' + @ErrorMessageCommon + char(10) + char(13)
      set @MailSubject = 'Ошибка в процедуре ' + error_procedure()
      exec msdb.dbo.sp_send_dbmail @Recipients = @MailRecipients
                                  ,@Subject = @MailSubject
                                  ,@Body = @MailBody
    end
  end catch
end

/*Helper                
  exec cdcp.usp_GetLogInfo @TableName = 'Users'
                          ,@PKValue = '31069:4'
                          ,@Pk = 'IdUser:Property'

  exec cdcp.usp_GetLogInfo @TableName = 'Users'
                          ,@PKValue = '31069:4'
                          ,@Pk = 'IdUser:Property'
                          ,@Dbg = 1

  exec cdcp.usp_GetLogInfo @TableName = 'ContractsProperties'
                          ,@PKValue = '1197741:35'
                          ,@Pk = 'ContractsId:PropertyId'
                          ,@Dbg = 0

  exec cdcp.usp_GetLogInfo @TableName = 'ContractsProperties'
                          ,@PKValue = '1197741:35'
                          ,@Pk = 'ContractsId:PropertyId'
                          ,@Dbg = 1

  exec cdcp.usp_GetLogInfo @TableName = 'Users'
                          ,@PKValue = '884176'
                          ,@Dbg = 0

  exec cdcp.usp_GetLogInfo @TableName = 'Contracts'
                          ,@PKValue = '1177393'
                          ,@Dbg = 1

  exec cdcp.usp_GetLogInfo @TableName = N'ContractsProperties'
                          ,@PK = N'ContractsId:PropertyId'
                          ,@PKValue = N'%:203'
                          ,@Dbg = 1

  exec cdcp.usp_GetLogInfo @TableName = 'Users'
                          ,@PKValue = '1200033'
                          ,@Dbg = 1

  exec cdcp.usp_GetLogInfo @TableName = 'Users'
                          ,@PKValue = '1175163'
                          ,@Dbg = 1

  exec cdcp.usp_GetLogInfo @TableName = 'Users'
                          ,@PKValue = '1112050'
                          ,@Dbg = 0
*/
GO
SET ANSI_NULLS, QUOTED_IDENTIFIER ON;


GO
PRINT N'Выполняется создание [cdcp].[usp_ManageTrigger]...';


GO
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
GO
PRINT N'Выполняется создание [cdcp].[tr_TriggerTemplate_v1]...';


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
GO
PRINT N'Выполняется создание [cdcp].[Detail].[MS_Description]...';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Данные лога', @level0type = N'SCHEMA', @level0name = N'cdcp', @level1type = N'TABLE', @level1name = N'Detail';


GO
PRINT N'Выполняется создание [cdcp].[Field].[StarInsteadData].[MS_Description]...';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Показывать звезды вместо данных в процедуре получения данных лога', @level0type = N'SCHEMA', @level0name = N'cdcp', @level1type = N'TABLE', @level1name = N'Field', @level2type = N'COLUMN', @level2name = N'StarInsteadData';


GO
PRINT N'Выполняется создание [cdcp].[Field].[NotShow].[MS_Description]...';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Не показывать изменения в процедуре получения данных лога', @level0type = N'SCHEMA', @level0name = N'cdcp', @level1type = N'TABLE', @level1name = N'Field', @level2type = N'COLUMN', @level2name = N'NotShow';


GO
PRINT N'Существующие данные проверяются относительно вновь созданных ограничений';


GO
ALTER TABLE [cdcp].[Detail] WITH CHECK CHECK CONSTRAINT [FK_Detail_FieldId];

ALTER TABLE [cdcp].[Detail] WITH CHECK CHECK CONSTRAINT [FK_Detail_HostId];

ALTER TABLE [cdcp].[Detail] WITH CHECK CHECK CONSTRAINT [FK_Detail_TableId];

ALTER TABLE [cdcp].[Detail] WITH CHECK CHECK CONSTRAINT [FK_Detail_UserId];


GO
PRINT N'Обновление завершено.';


GO
