CREATE TABLE [cdcp].[Detail] (
    [Id]         BIGINT         IDENTITY (1, 1) NOT NULL,
    [Type]       CHAR (1)       NOT NULL,
    [TableId]    INT            NOT NULL,
    [PKValue]    VARCHAR (1000) NULL,
    [FieldId]    INT            NOT NULL,
    [OldValue]   VARCHAR (1000) NULL,
    [NewValue]   VARCHAR (1000) NULL,
    [UpdateDate] DATETIME2 (7)  NOT NULL,
    [UserId]     INT            NULL,
    [HostId]     INT            NOT NULL,
    CONSTRAINT [PK_Detail_Id] PRIMARY KEY CLUSTERED ([Id] ASC),
    CONSTRAINT [FK_Detail_FieldId] FOREIGN KEY ([FieldId]) REFERENCES [cdcp].[Field] ([Id]) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT [FK_Detail_HostId] FOREIGN KEY ([HostId]) REFERENCES [cdcp].[Host] ([Id]) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT [FK_Detail_TableId] FOREIGN KEY ([TableId]) REFERENCES [cdcp].[Table] ([Id]) ON DELETE CASCADE ON UPDATE CASCADE,
    CONSTRAINT [FK_Detail_UserId] FOREIGN KEY ([UserId]) REFERENCES [cdcp].[User] ([Id]) ON DELETE CASCADE ON UPDATE CASCADE
);


GO
EXECUTE sp_addextendedproperty @name = N'MS_Description', @value = N'Данные лога', @level0type = N'SCHEMA', @level0name = N'cdcp', @level1type = N'TABLE', @level1name = N'Detail';

