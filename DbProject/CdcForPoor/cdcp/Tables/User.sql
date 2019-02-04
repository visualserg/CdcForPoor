CREATE TABLE [cdcp].[User] (
    [Id]         INT           IDENTITY (1, 1) NOT NULL,
    [UserName]   VARCHAR (128) NOT NULL,
    [CreateDate] DATETIME2 (7) DEFAULT (getdate()) NOT NULL,
    CONSTRAINT [PK_User_Id] PRIMARY KEY CLUSTERED ([Id] ASC)
);

