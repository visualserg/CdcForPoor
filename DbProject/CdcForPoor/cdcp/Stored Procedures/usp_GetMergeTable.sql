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
