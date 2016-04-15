
/****** Object:  StoredProcedure [dbo].[sp_GetExtMessage]    Script Date: 14/04/2016 6:27:59 a.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_GetExtMessage]
	@PrevMessageID varchar(50) = null
AS
BEGIN
	SET NOCOUNT ON;

	declare @MessageID int
	if (@PrevMessageID is NULL)
	begin
		select @MessageID = min(mailboxMsgId) from JBMSExtMessage
	end
	else
	begin
		select @MessageID = min(mailboxMsgId) from JBMSExtMessage where mailboxMsgId > @PrevMessageID
	end

	select * from JBMSExtMessage where mailboxMsgId = @MessageID

	return @MessageID
END
GO
/****** Object:  StoredProcedure [dbo].[Sp_GetNextEmail]    Script Date: 14/04/2016 6:27:59 a.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[Sp_GetNextEmail]
	@Submitter varchar(50)
AS
BEGIN
	set nocount on

	declare	@busyMessageID int
	SELECT  @busyMessageID = min (TSWMessageID)
	from	JBMSMessage
	where	[Status] = 'InProgress'
	and		Submitter = @Submitter

	if (not @busyMessageID is null)
	Begin
		update	JBMSMessage
		set		[Status] = 'Processed'
		where	TSWMessageID = @busyMessageID
	End

	declare @nextMessageID int
	SELECT  @nextMessageID = min (TSWMessageID)
	from	JBMSMessage
	where	[Status] = 'New'
	and		Submitter = @Submitter

	if (@NextMessageID is null)
		begin
			RETURN	0
		end
	else
		begin
			update  JBMSMessage 
			set		[Status] = 'InProgress'
			where	TSWMessageID = @nextMessageID

			select	*
			from	JBMSMessage M
			left join JBMSAttachment A on A.TSWMessageID = M.TSWMessageID
			where	M.TSWMessageID = @nextMessageID

			RETURN	@nextMessageID
		end
	
	RETURN 0

END
GO
/****** Object:  StoredProcedure [dbo].[sp_PollingJBMS]    Script Date: 14/04/2016 6:27:59 a.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_PollingJBMS]
	@Submitter varchar(50)
AS

	declare @JBMSPollingID int
	declare @JBMSStatus varchar(50)
	select	@JBMSPollingID = JBMSPollingID,
		    @JBMSStatus = [Status] 
	from	JBMSPolling
	where	Submitter = @Submitter

	if @JBMSPollingID is null
	begin
		insert into JBMSPolling
			(Submitter, [Status], LastUpdatedDateTime)
		values
			(@Submitter, 'InProgress', getdate())
		set @JBMSPollingID = @@IDENTITY
	end
	else
	begin
		if(@JBMSStatus) = 'InProgress'
		begin
			set @JBMSPollingID = 0
		end
		else
		begin
			update	JBMSPolling
			set		[Status] = 'InProgress'
			where	Submitter = @Submitter
		end
	end

	select	JBMSPollingID,
			Submitter,
			EntryID,
			SenderReference,
			isnull(MessageID, '0') as MessageID,
			[Status],
			LastUpdatedDateTime,
			getdate() as CurrentDateTime
	from	JBMSPolling
	where	JBMSPollingID = @JBMSPollingID

	RETURN @JBMSPollingID
GO
/****** Object:  StoredProcedure [dbo].[sp_SaveJBMSMessage]    Script Date: 14/04/2016 6:27:59 a.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_SaveJBMSMessage]
	@MessageID VARCHAR(50), 
    @CustomerReference VARCHAR(MAX), 
    @DocumentID VARCHAR(50), 
    @Mailbox VARCHAR(MAX), 
    @MessageName VARCHAR(MAX), 
    @PartnerID VARCHAR(50), 
    @ReceivedDateTime VARCHAR(50),
	@Submitter VARCHAR(50),
	@href VARCHAR(50),
	@AttachmentDocument NVARCHAR(MAX)
AS

	declare @TSWMessageID int

	INSERT into JBMSMessage
	(	
		MessageID, 
		CustomerReference, 
		DocumentID, 
		Mailbox, 
		MessageName, 
		PartnerID,
		ReceivedDateTime,
		[Status], 
		LastUpdatedDateTime,
		ErrorCount,
		Submitter
	)
	values
	(	
		@MessageID, 
		@CustomerReference, 
		@DocumentID, 
		@Mailbox, 
		@MessageName, 
		@PartnerID,
		@ReceivedDateTime,
		'New',  
		getdate(),
		0,
		@Submitter
	)

	set @TSWMessageID = @@IDENTITY

	insert into JBMSAttachment
	(TSWMessageID, href, AttachmentDocument)
	values
	(@TSWMessageID, @href, @AttachmentDocument)

RETURN 0
GO
/****** Object:  StoredProcedure [dbo].[sp_UpdatePolling]    Script Date: 14/04/2016 6:27:59 a.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
CREATE PROCEDURE [dbo].[sp_UpdatePolling]
	@EntryID varchar(50),
	@SenderReference varchar(50),
	@MessageID varchar(50),
	@Status varchar(50),
	@JBMSPollingID int
AS
BEGIN
	Update	Polling
	set		EntryID = @EntryID,
			SenderReference = @SenderReference,
			MessageID = @MessageID,
			[Status] = @Status,
			LastUpdatedDateTime = getdate()
	where	JBMSPollingID = @JBMSPollingID

	RETURN 0
END
GO
/****** Object:  Table [dbo].[JBMSAttachment]    Script Date: 14/04/2016 6:27:59 a.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[JBMSAttachment](
	[TWSAttachmentID] [int] IDENTITY(1,1) NOT NULL,
	[TSWMessageID] [int] NOT NULL,
	[href] [varchar](50) NOT NULL,
	[AttachmentDocument] [nvarchar](max) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[TWSAttachmentID] ASC
) 
)  

GO
SET ANSI_PADDING ON
GO
/****** Object:  Table [dbo].[JBMSConfiguration]    Script Date: 14/04/2016 6:27:59 a.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[JBMSConfiguration](
	[JBMSConfigurationID] [int] IDENTITY(1,1) NOT NULL,
	[ConfigurationName] [varchar](50) NOT NULL,
	[ConfigurationValue] [varchar](max) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[JBMSConfigurationID] ASC
) 
)  

GO
SET ANSI_PADDING ON
GO
/****** Object:  Table [dbo].[JBMSExtMessage]    Script Date: 14/04/2016 6:27:59 a.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[JBMSExtMessage](
	[Id] [int] IDENTITY(1,1) NOT NULL,
	[customerReference] [varchar](max) NOT NULL,
	[docId] [varchar](50) NULL,
	[documentSize] [varchar](50) NULL,
	[mailbox] [varchar](50) NOT NULL,
	[mailboxMsgId] [varchar](50) NOT NULL,
	[messageName] [varchar](50) NOT NULL,
	[partner] [varchar](50) NULL,
	[receivedDate] [datetime] NOT NULL,
	[Status] [varchar](50) NOT NULL,
	[href] [varchar](150) NULL,
	[value] [nvarchar](max) NULL,
PRIMARY KEY CLUSTERED 
(
	[Id] ASC
) 
)  

GO
SET ANSI_PADDING ON
GO
/****** Object:  Table [dbo].[JBMSMessage]    Script Date: 14/04/2016 6:27:59 a.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[JBMSMessage](
	[TSWMessageID] [int] IDENTITY(1,1) NOT NULL,
	[MessageID] [varchar](50) NOT NULL,
	[CustomerReference] [varchar](max) NOT NULL,
	[DocumentID] [varchar](50) NOT NULL,
	[Mailbox] [varchar](max) NOT NULL,
	[MessageName] [varchar](max) NOT NULL,
	[PartnerID] [varchar](50) NULL,
	[ReceivedDateTime] [datetime] NOT NULL,
	[Status] [varchar](50) NOT NULL,
	[LastUpdatedDateTime] [datetime] NOT NULL,
	[ErrorCount] [int] NOT NULL,
	[Submitter] [varchar](50) NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[TSWMessageID] ASC
) 
)  

GO
SET ANSI_PADDING ON
GO
/****** Object:  Table [dbo].[JBMSPolling]    Script Date: 14/04/2016 6:27:59 a.m. ******/
SET ANSI_NULLS ON
GO
SET QUOTED_IDENTIFIER ON
GO
SET ANSI_PADDING ON
GO
CREATE TABLE [dbo].[JBMSPolling](
	[JBMSPollingID] [int] IDENTITY(1,1) NOT NULL,
	[Submitter] [varchar](50) NOT NULL,
	[EntryID] [varchar](50) NULL,
	[SenderReference] [varchar](50) NULL,
	[MessageID] [varchar](50) NULL,
	[Status] [varchar](50) NOT NULL,
	[LastUpdatedDateTime] [datetime] NOT NULL,
PRIMARY KEY CLUSTERED 
(
	[JBMSPollingID] ASC
) 
) 




/*

insert into [dbo].[JBMSExtMessage]
([customerReference], [documentSize], [mailbox], [mailboxMsgId], [messageName], [partner], [receivedDate], [Status], [href], [value])
values 
('SEAIMPT', '3578', '/TSW/PORTCONNECT/outbound', '1045409', '51358610J_72643043.xml', '51358610J', '2015-04-16 13:49:29.684', 'New', 'cid:attachment=139069514_1456874869199@sterlingcommerce.com', 'PERvY3VtZW50TWV0YWRhdGEgeG1sbnM9J3Vybjp3Y286ZGF0YW1vZGVsOldDTzpETToxJyB4bWxuczp4c2k9J2h0dHA6Ly93d3cudzMub3JnLzIwMDEvWE1MU2NoZW1hLWluc3RhbmNlJz4KICA8V0NPRGF0YU1vZGVsVmVyc2lvbj4zLjI8L1dDT0RhdGFNb2RlbFZlcnNpb24+CiAgPFdDT0RvY3VtZW50TmFtZT5SRVM8L1dDT0RvY3VtZW50TmFtZT4KICA8Q291bnRyeUNvZGU+Tlo8L0NvdW50cnlDb2RlPgogIDxBZ2VuY3lBc3NpZ25lZEN1c3RvbWl6ZWREb2N1bWVudE5hbWU+UkVTSU0xPC9BZ2VuY3lBc3NpZ25lZEN1c3RvbWl6ZWREb2N1bWVudE5hbWU+CiAgPEFnZW5jeUFzc2lnbmVkQ3VzdG9taXplZERvY3VtZW50VmVyc2lvbj5WMS4wPC9BZ2VuY3lBc3NpZ25lZEN1c3RvbWl6ZWREb2N1bWVudFZlcnNpb24+CiAgPFJlc3BvbnNlIHhtbG5zPSd1cm46d2NvOmRhdGFtb2RlbDpXQ086UmVzcG9uc2VNb2RlbDoxJz4KICAgIDxJc3N1ZURhdGVUaW1lIGZvcm1hdENvZGU9IjIwNCIgPjIwMTUwNDE2MTM0ODU1PC9Jc3N1ZURhdGVUaW1lPgogICAgPEZ1bmN0aW9uYWxSZWZlcmVuY2VJRD43PC9GdW5jdGlvbmFsUmVmZXJlbmNlSUQ+CiAgICA8RnVuY3Rpb25Db2RlPjI0PC9GdW5jdGlvbkNvZGU+CiAgICA8T3ZlcmFsbERlY2xhcmF0aW9uPgogICAgICA8RGVjbGFyYXRpb24+CiAgICAgICAgPElEPjcyNjQzMDQzPC9JRD4KICAgICAgICA8QWNjZXB0YW5jZURhdGVUaW1lIGZvcm1hdENvZGU9IjIwNCIgPjIwMTUwNDE2MTM0ODU1PC9BY2NlcHRhbmNlRGF0ZVRpbWU+CiAgICAgICAgPEZ1bmN0aW9uYWxSZWZlcmVuY2VJRD5TRUFJTVBUPC9GdW5jdGlvbmFsUmVmZXJlbmNlSUQ+CiAgICAgICAgPFRvdGFsR3Jvc3NNYXNzTWVhc3VyZSB1bml0Q29kZT0iS0dNIiA+MTAwMDA8L1RvdGFsR3Jvc3NNYXNzTWVhc3VyZT4KICAgICAgICA8SnVyaXNkaWN0aW9uRGF0ZVRpbWUgZm9ybWF0Q29kZT0iMTAyIiA+MjAxNTA0MTg8L0p1cmlzZGljdGlvbkRhdGVUaW1lPgogICAgICAgIDxTdWJtaXR0ZXI+CiAgICAgICAgICA8TmFtZT5Dcm93biBSZWxvY2F0aW9uIC0gRUNUPC9OYW1lPgogICAgICAgIDwvU3VibWl0dGVyPgogICAgICAgIDxBZ2VudD4KICAgICAgICAgIDxOYW1lPkNyb3duIFJlbG9jYXRpb24gLSBFQ1Q8L05hbWU+CiAgICAgICAgPC9BZ2VudD4KICAgICAgICA8Qm9yZGVyVHJhbnNwb3J0TWVhbnM+CiAgICAgICAgICA8TmFtZT5BRFJJQU4gTUFFUlNLPC9OYW1lPgogICAgICAgICAgPFR5cGVDb2RlPjE8L1R5cGVDb2RlPgogICAgICAgICAgPEpvdXJuZXlJRD4zSzQwMTwvSm91cm5leUlEPgogICAgICAgIDwvQm9yZGVyVHJhbnNwb3J0TWVhbnM+CiAgICAgICAgPEdvb2RzU2hpcG1lbnQ+CiAgICAgICAgICA8Q29uc2lnbm1lbnQ+CiAgICAgICAgICAgIDxUcmFuc3BvcnRDb250cmFjdERvY3VtZW50PgogICAgICAgICAgICAgIDxJRD4xMjQzMjU2NDY8L0lEPgogICAgICAgICAgICAgIDxUeXBlQ29kZT5CTTwvVHlwZUNvZGU+CiAgICAgICAgICAgICAgPFBvaW50ZXI+CiAgICAgICAgICAgICAgICA8RG9jdW1lbnRTZWN0aW9uQ29kZT40MkE8L0RvY3VtZW50U2VjdGlvbkNvZGU+CiAgICAgICAgICAgICAgPC9Qb2ludGVyPgogICAgICAgICAgICAgIDxQb2ludGVyPgogICAgICAgICAgICAgICAgPERvY3VtZW50U2VjdGlvbkNvZGU+NjdBPC9Eb2N1bWVudFNlY3Rpb25Db2RlPgogICAgICAgICAgICAgIDwvUG9pbnRlcj4KICAgICAgICAgICAgICA8UG9pbnRlcj4KICAgICAgICAgICAgICAgIDxEb2N1bWVudFNlY3Rpb25Db2RlPjI4QTwvRG9jdW1lbnRTZWN0aW9uQ29kZT4KICAgICAgICAgICAgICA8L1BvaW50ZXI+CiAgICAgICAgICAgICAgPFBvaW50ZXI+CiAgICAgICAgICAgICAgICA8U2VxdWVuY2VOdW1lcmljPjE8L1NlcXVlbmNlTnVtZXJpYz4KICAgICAgICAgICAgICAgIDxEb2N1bWVudFNlY3Rpb25Db2RlPjMxQjwvRG9jdW1lbnRTZWN0aW9uQ29kZT4KICAgICAgICAgICAgICA8L1BvaW50ZXI+CiAgICAgICAgICAgIDwvVHJhbnNwb3J0Q29udHJhY3REb2N1bWVudD4KICAgICAgICAgICAgPFRyYW5zcG9ydEVxdWlwbWVudD4KICAgICAgICAgICAgICA8U2VxdWVuY2VOdW1lcmljPjE8L1NlcXVlbmNlTnVtZXJpYz4KICAgICAgICAgICAgICA8RnVsbG5lc3NDb2RlPjU8L0Z1bGxuZXNzQ29kZT4KICAgICAgICAgICAgICA8SUQ+QUJDVTEyMzQ1NjA8L0lEPgogICAgICAgICAgICAgIDxQb2ludGVyPgogICAgICAgICAgICAgICAgPERvY3VtZW50U2VjdGlvbkNvZGU+NDJBPC9Eb2N1bWVudFNlY3Rpb25Db2RlPgogICAgICAgICAgICAgIDwvUG9pbnRlcj4KICAgICAgICAgICAgICA8UG9pbnRlcj4KICAgICAgICAgICAgICAgIDxTZXF1ZW5jZU51bWVyaWM+MTwvU2VxdWVuY2VOdW1lcmljPgogICAgICAgICAgICAgICAgPERvY3VtZW50U2VjdGlvbkNvZGU+OTNBPC9Eb2N1bWVudFNlY3Rpb25Db2RlPgogICAgICAgICAgICAgIDwvUG9pbnRlcj4KICAgICAgICAgICAgPC9UcmFuc3BvcnRFcXVpcG1lbnQ+CiAgICAgICAgICA8L0NvbnNpZ25tZW50PgogICAgICAgIDwvR29vZHNTaGlwbWVudD4KICAgICAgICA8SW1wb3J0ZXI+CiAgICAgICAgICA8TmFtZT5JbXBvcnRlciBmb3IgRUNUPC9OYW1lPgogICAgICAgIDwvSW1wb3J0ZXI+CiAgICAgICAgPFBhY2thZ2luZz4KICAgICAgICAgIDxTZXF1ZW5jZU51bWVyaWM+MTwvU2VxdWVuY2VOdW1lcmljPgogICAgICAgICAgPE1hcmtzTnVtYmVyc0lELz4KICAgICAgICAgIDxRdWFudGl0eVF1YW50aXR5PjEwMDAwPC9RdWFudGl0eVF1YW50aXR5PgogICAgICAgICAgPFR5cGVDb2RlPkJHPC9UeXBlQ29kZT4KICAgICAgICA8L1BhY2thZ2luZz4KICAgICAgICA8UmVzcG9uc2libGVHb3Zlcm5tZW50QWdlbmN5PgogICAgICAgICAgPElEPk5aQ1M8L0lEPgogICAgICAgIDwvUmVzcG9uc2libGVHb3Zlcm5tZW50QWdlbmN5PgogICAgICAgIDxVbmxvYWRpbmdMb2NhdGlvbj4KICAgICAgICAgIDxJRD5OWlRSRzwvSUQ+CiAgICAgICAgPC9VbmxvYWRpbmdMb2NhdGlvbj4KICAgICAgPC9EZWNsYXJhdGlvbj4KICAgIDwvT3ZlcmFsbERlY2xhcmF0aW9uPgogICAgPFN0YXR1cz4KICAgICAgPEVmZmVjdGl2ZURhdGVUaW1lIGZvcm1hdENvZGU9IjIwNCIgPjIwMTUwNDE2MTM0ODU1PC9FZmZlY3RpdmVEYXRlVGltZT4KICAgICAgPE5hbWVDb2RlPjgyMjwvTmFtZUNvZGU+CiAgICAgIDxQb2ludGVyPgogICAgICAgIDxEb2N1bWVudFNlY3Rpb25Db2RlPjA3QjwvRG9jdW1lbnRTZWN0aW9uQ29kZT4KICAgICAgPC9Qb2ludGVyPgogICAgICA8UG9pbnRlcj4KICAgICAgICA8RG9jdW1lbnRTZWN0aW9uQ29kZT40MkE8L0RvY3VtZW50U2VjdGlvbkNvZGU+CiAgICAgIDwvUG9pbnRlcj4KICAgICAgPFBvaW50ZXI+CiAgICAgICAgPFNlcXVlbmNlTnVtZXJpYz4xPC9TZXF1ZW5jZU51bWVyaWM+CiAgICAgICAgPERvY3VtZW50U2VjdGlvbkNvZGU+MDhCPC9Eb2N1bWVudFNlY3Rpb25Db2RlPgogICAgICAgIDxUYWdJRD5HMDA3PC9UYWdJRD4KICAgICAgPC9Qb2ludGVyPgogICAgPC9TdGF0dXM+CiAgPC9SZXNwb25zZT4KPC9Eb2N1bWVudE1ldGFkYXRhPgo=')

select * from [JBMSExtMessage]

*/
