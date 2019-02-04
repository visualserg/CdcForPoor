CREATE TABLE [cdcp].[Host] (
    [Id]         INT           IDENTITY (1, 1) NOT NULL,
    [HostName]   VARCHAR (128) NULL,
    [CreateDate] DATETIME2 (7) DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_Host_Id] PRIMARY KEY CLUSTERED ([Id] ASC)
);

