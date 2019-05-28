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
		   ,@resultOut varchar(max)
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

      set @resultOut = null
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