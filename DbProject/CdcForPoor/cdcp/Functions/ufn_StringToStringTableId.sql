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

