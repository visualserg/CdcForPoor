# CdcForPoor

Аудит изменений данных в Microsoft SQL Server на основе триггеров - для тех, у кого редакция SQL Server не поддерживает Change Data Capture (CDC).

Лог пишется построчно и поколоночно: для каждой изменённой ячейки сохраняются старое и новое значение, тип операции (`I`/`U`/`D`), значение PK, пользователь и хост.

## Возможности

- Логирование `INSERT` / `UPDATE` / `DELETE` (любая комбинация - настраивается на каждом триггере).
- Поддержка составных первичных ключей.
- Гибкая выборка логов по PK с поддержкой `LIKE` (`%`).
- Включение/исключение колонок в результате (`@FieldInclude` / `@FieldExclude`).
- Маскирование значений (`StarInsteadData`) и скрытие отдельных колонок (`NotShow`) в выдаче.
- Отключение логирования отдельной колонки без пересоздания триггера (флаг `Log` в `cdcp.Field`).
- Автогенерация триггеров из единого шаблона (`cdcp.tr_TriggerTemplate_v1`) - все триггеры одинаковые и обновляются централизованно.

## Требования

- Microsoft SQL Server (любая редакция, включая Express/Standard).
- Права на создание схемы, таблиц, процедур и триггеров в целевой БД.
- На каждой логируемой таблице обязательно должен быть `PRIMARY KEY`.

## Установка

Самый простой путь - выполнить готовый publish-скрипт в целевой БД:

```
DbProject/CdcForPoor/PublishScript/Script_v_001.sql
```

Скрипт создаёт схему `cdcp` и все её объекты (таблицы, функции, процедуры, шаблон триггера).

Альтернативно можно открыть solution `DbProject/CdcForPoor/CdcForPoor.sln` в Visual Studio (SSDT) и опубликовать проект штатным способом.

## Структура схемы `cdcp`

Метаданные:

- `cdcp.Host` - хосты, с которых пришли изменения.
- `cdcp.User` - пользователи БД, выполнившие изменения.
- `cdcp.Table` - таблицы, поставленные на аудит, и их PK.
- `cdcp.Field` - колонки и флаги их обработки (`Log`, `StarInsteadData`, `NotShow`).
- `cdcp.TriggerTemplate` - служебная таблица, на которой висит триггер-шаблон `tr_TriggerTemplate_v1`. Из его текста генерируются все остальные триггеры.

Данные лога:

- `cdcp.Detail` - собственно журнал: `Type`, `TableId`, `PKValue`, `FieldId`, `OldValue`, `NewValue`, `UpdateDate`, `UserId`, `HostId`.

## Использование

### 1. Поставить таблицу на аудит

Процедура `cdcp.usp_ManageTrigger` генерирует SQL-скрипт триггера для целевой таблицы (сама не выполняет - возвращает текст в OUT-параметре, чтобы его можно было просмотреть и применить вручную).

```sql
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
print @ResultSql

exec (@ResultSql)   -- применить
```

Параметры:

| Параметр              | По умолч. | Описание                                                   |
| --------------------- | --------- | ---------------------------------------------------------- |
| `@SchemaName`         | `dbo`     | Схема целевой таблицы.                                     |
| `@TableName`          | -         | Имя целевой таблицы (обязателен).                          |
| `@Insert`             | `0`       | Логировать вставки.                                        |
| `@Update`             | `1`       | Логировать обновления.                                     |
| `@Delete`             | `0`       | Логировать удаления.                                       |
| `@Disabled`           | `0`       | Создать триггер сразу выключенным.                         |
| `@Exist`              | `0`       | `0` - `CREATE TRIGGER`, `1` - `ALTER TRIGGER`.             |
| `@DbgUseOut`          | `0`       | Вывести текст триггера и таблицу подстановок для отладки.  |
| `@ResultSql` (out)    | -         | Готовый к выполнению скрипт.                               |

Ограничение SQL Server: динамический SQL не выполняет `GO`, поэтому результат собирается в виде последовательности `EXEC('...'); EXEC('...');`. Длина результирующего скрипта не должна превышать 8000 символов - иначе процедура поднимет ошибку.

### 2. Получить логи по строке

```sql
exec cdcp.usp_GetLogInfo
     @ShemaName    = 'dbo'
    ,@TableName    = '_User'
    ,@PK           = 'id'           -- для составного PK: 'col1:col2' (по алфавиту, asc)
    ,@PKValue      = '42'           -- поддерживает LIKE: '236:%:1', '%:10'
    ,@FieldInclude = ''             -- список через запятую; пусто = все колонки
    ,@FieldExclude = ''             -- список через запятую
```

### 3. Управлять поведением колонок

```sql
-- Перестать логировать колонку (без пересоздания триггера)
update cdcp.Field set [Log] = 0
where TableSchema = 'dbo' and TableName = '_User' and Field = 'PasswordHash'

-- Маскировать значение в выдаче usp_GetLogInfo
update cdcp.Field set StarInsteadData = 1
where TableSchema = 'dbo' and TableName = '_User' and Field = 'PasswordHash'

-- Полностью скрыть колонку из выдачи usp_GetLogInfo
update cdcp.Field set NotShow = 1
where TableSchema = 'dbo' and TableName = '_User' and Field = 'InternalFlag'
```

Записи в `cdcp.Field` создаются автоматически при первом срабатывании триггера на колонке.

## Как это работает

Все сгенерированные триггеры - это копии тела `cdcp.tr_TriggerTemplate_v1`, в котором при генерации заменяются только метки `/*#block_*/` (имя триггера, перечень событий, дата). За счёт этого:

- Логика логирования живёт в одном месте.
- Чтобы обновить поведение всех триггеров, достаточно поменять шаблон и пересоздать триггеры через `usp_ManageTrigger` с `@Exist = 1`.

Внутри триггера:

1. По `INFORMATION_SCHEMA` определяется PK таблицы и список колонок.
2. По `COLUMNS_UPDATED()` определяется, какие колонки реально изменились (для `INSERT`/`DELETE` пишутся все).
3. Для каждой изменённой колонки:
   - вызывается `usp_GetMergeTable` / `usp_GetMergeField` / `usp_GetMergeUser` / `usp_GetMergeHost` - они находят/создают запись в справочниках и возвращают Id;
   - если у колонки `Log = 1`, в `cdcp.Detail` пишется одна строка со старым и новым значением.

## Идея и источники вдохновения

- <https://stackoverflow.com/questions/19737723/log-record-changes-in-sql-server-in-an-audit-table>
- <https://www.red-gate.com/simple-talk/sql/database-administration/pop-rivetts-sql-server-faq-no.5-pop-on-the-audit-trail/>

## Ограничения

- Значения `OldValue` / `NewValue` хранятся как `varchar(1000)` - длинные `nvarchar(max)` / `varbinary` будут обрезаны.
- Тело сгенерированного триггера ограничено 8000 символами (ограничение динамического SQL).
- Триггеры - это синхронная нагрузка на DML; на горячих таблицах нужно оценивать накладные расходы.
- Решение не претендует на замену настоящего CDC/Change Tracking - это утилитарный аудит.

## Лицензия

[Unlicense](LICENSE) - public domain.
