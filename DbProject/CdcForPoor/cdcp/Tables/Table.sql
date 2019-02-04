CREATE TABLE [cdcp].[Table] (
    [Id]          INT            IDENTITY (1, 1) NOT NULL,
    [TableSchema] VARCHAR (128)  NOT NULL,
    [TableName]   VARCHAR (128)  NOT NULL,
    [PK]          VARCHAR (4000) NOT NULL,
    [CreateDate]  DATETIME2 (7)  DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_Table_Id] PRIMARY KEY CLUSTERED ([Id] ASC)
);

