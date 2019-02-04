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



















