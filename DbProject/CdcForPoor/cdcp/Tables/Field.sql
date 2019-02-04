CREATE TABLE [cdcp].[Field] (
    [Id]              INT           IDENTITY (1, 1) NOT NULL,
    [TableSchema]     VARCHAR (128) NOT NULL,
    [TableName]       VARCHAR (128) NOT NULL,
    [Field]           VARCHAR (128) NOT NULL,
    [Log]             BIT           NOT NULL,
    [CreateDate]      DATETIME2 (7) DEFAULT (getdate()) NOT NULL,
    [StarInsteadData] BIT           NOT NULL,
    [NotShow]         BIT           NOT NULL,
    CONSTRAINT [PK_Field_Id] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [KEY_Field] UNIQUE NONCLUSTERED ([TableName] ASC, [CreateDate] ASC)
);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Показывать звезды вместо данных в процедуре получения данных лога', @level0type = N'SCHEMA', @level0name = N'cdcp', @level1type = N'TABLE', @level1name = N'Field', @level2type = N'COLUMN', @level2name = N'StarInsteadData';


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Не показывать изменения в процедуре получения данных лога', @level0type = N'SCHEMA', @level0name = N'cdcp', @level1type = N'TABLE', @level1name = N'Field', @level2type = N'COLUMN', @level2name = N'NotShow';

