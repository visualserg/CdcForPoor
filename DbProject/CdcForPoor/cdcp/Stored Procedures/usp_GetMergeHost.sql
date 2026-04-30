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
