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
