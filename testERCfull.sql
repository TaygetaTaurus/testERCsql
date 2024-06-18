----------------------------�������� ��----------------------------
if DB_ID('Shop') is not null drop database Shop
go

create database Shop
collate Cyrillic_General_CI_AS
go

use Shop
go
--�������� ����
create schema HR authorization dbo;
go
create schema Production authorization dbo;
go
create schema Sales authorization dbo;
go
--�������� ������� Goods
if OBJECT_ID('Production.Goods', 'U') IS NOT NULL
	drop table Production.Goods;

create table Production.Goods
(
	Id int not null identity
		primary key,
	Name nvarchar(20) not null 
)
--�������� ������� Colors
if OBJECT_ID('Production.Colors', 'U') IS NOT NULL
	drop table Production.Colors;

create table Production.Colors
(
	Id int not null identity
		primary key,
	Name nvarchar(20) not null 
)
--�������� ������� Agents
if OBJECT_ID('HR.Agents', 'U') IS NOT NULL
	drop table HR.Agents;

create table HR.Agents
(
	Id int identity
		primary key,
	Name nvarchar(20) not null 
)
--�������� ������� Orders
if OBJECT_ID('Sales.Orders', 'U') IS NOT NULL
	drop table Sales.Orders;

create table Sales.Orders
(
	Id int identity not null primary key,
	AgentId int not null 
		foreign key references HR.Agents(Id) on delete cascade,
	CreateDate smalldatetime not null
		constraint CHK_Orders_CreateDate check (CreateDate >= '20200101' AND CreateDate <= '20230331') 
)
--�������� ������� GoodProperties
if OBJECT_ID('Production.GoodProperties', 'U') IS NOT NULL
	drop table Production.GoodProperties;

create table Production.GoodProperties
(
	Id int not null identity
		primary key,
	GoodId int not null
		foreign key references Production.Goods(Id) on delete cascade,
	ColorId int not null
		foreign key references Production.Colors(id) on delete cascade,
	BDate smalldatetime not null,
	EDate smalldatetime not null
)
--�������� ������� OrderDetails
if OBJECT_ID('Sales.OrderDetails', 'U') IS NOT NULL
	drop table Sales.OrderDetails;

create table Sales.OrderDetails
(
	Id int not null identity
		primary key,
	OrderId int not null
		foreign key references Sales.Orders(id) on delete cascade,
	GoodId int not null
		foreign key references Production.Goods(Id) on delete cascade,
	GoodCount int not null
		constraint CHK_OrderDetails_GoodCount check (GoodCount >= 1 AND GoodCount <= 10)
)
go

----------------------------������� 1----------------------------

-- ������� 1 �)

--���������� ������� Agents �������
declare @i as int = 1
while @i <= 15
	begin
		insert into HR.Agents
		values
		(N'�����' + cast(@i as nvarchar(20)))
		set @i += 1
	end

--���������� ������� Goods �������
set @i = 1
while @i <= 10
	begin
		insert into Production.Goods
		values
		(N'�����' + cast(@i as nvarchar(20)))
		set @i += 1
	end

--���������� ������� Colors �������
insert into Production.Colors
values
(N'����1'),
(N'����2'),
(N'����3')
go

create proc #randomNumber --�������� ��������� ��������� ��� ������� ���������� ����� � ��������� [@min, @max]
@min as int,
@max as int,
@value as int output
as
SET NOCOUNT ON;
set @value = FLOOR(RAND(checksum(newid()))* (@max - @min + 1) + @min);
go

go
create proc #randomDate --�������� ��������� ��������� ��� ������� ��������� ���� � ��������� [@FromDate, @ToDate]
	@FromDate as date,
	@ToDate as date,
	@targetDate as date output
as
SET NOCOUNT ON;
set @targetDate = dateadd(day, rand(checksum(newid()))*(1+datediff(day, @FromDate, @ToDate)), @FromDate)
go

--������� 1 b)

--���������� ������� Orders ������������� ����������
declare @FromDate as date  = '20200101'
declare @ToDate as date = '20230331'
declare @i1 as int = 1;
declare @i2 as int = 1;
while @i1 <= (select count(*) from HR.Agents) --���� ��� 15-�� �������
	begin
		declare @maxi as int; 
		exec #randomNumber 10, 40, @maxi output  -- ������� ���������� ���������� ������� � ���������  [10, 40] ��� ������� ������
		WHILE @i2 <= @maxi 
			BEGIN
				declare @date as date
					exec #randomDate --������� ��������� ���� ��� �������� ������ � ��������� [@FromDate, @ToDate]
						@FromDate,
						@ToDate,
						@targetDate = @date output

				insert into Sales.Orders
				values
				(@i1, @date)

				set @i2 += 1
			END;
		set @i2 = 1
		set @i1 += 1

	end;

--���������� ������� OrderDetails
declare @g as int = 1
declare @randid as int = 1
declare @i as int = 1
set @i = 1
while @i <= (select count(Id) from Sales.Orders) --������� �� ���� �������
	begin
		declare @maxgoods as int;
		exec #randomNumber 1, 5, @maxgoods output  --������� ������������� ���-�� ������ ������� ��� ������� ������
		while @g <= @maxgoods
			BEGIN
				set @randid = (select top(1) Id from Production.Goods order by NEWID()) --����� 1 ���������� ������ @randid �� ������� Goods
				declare @goodsValue as int;
					exec #randomNumber 1, 10, @goodsValue output --������� ������������� ���-�� ������ ������� ��� ������� ������
				if (@i = (select distinct OrderId from Sales.OrderDetails where OrderId = @i) 
					AND @randid  not in (select GoodId from Sales.OrderDetails where OrderId = @i)) --�������� ��� ��������� ���������� � ������ ������ ������ � ������� ���������� ������ @randid � ���� ������
					begin
						insert into Sales.OrderDetails
						values
						(@i, @randid, @goodsValue) -- ���������� � ������� � ������������ ���-��� �������������� ������ � ��������� [1, 10] ��
					end;
				else --���������� ������, ���� � ������� ��� ��� ������ � ������ Id
					begin
						if (@randid  not in (select GoodId from Sales.OrderDetails where OrderId = @i)) --�������� �� ������� ���������� ������ @randid � ���� ������
							begin
								
								insert into Sales.OrderDetails
								values
								(@i, @randid, @goodsValue)
							end
					end
				set @g += 1
			END;
		set @g = 1
		set @i += 1
	end;

--������� 1 c) ���������� ������� GoodProperties
set @i = 1
set @i1 = 1
while @i <= 4
	BEGIN
		while @i1 <= 2
			begin -- ����� ������ ������ ����� ����� ������ ����� � ������ ������ ������ ������ �����, �� ������������ ��������� �������� ����� � ������ ������ ������ ����� (��� ������� 2b)
				declare @BDate as date --������� ������������ ���� ������ �����
					exec #randomDate @FromDate, @ToDate, @BDate output
				declare @EDate as date --������� ������������ ���� ����� ����� (������ ������ < �����, �.�. ����������� ���� ����� ��������� �� ���� ������ �����)
					exec #randomDate @FromDate = @BDate, @ToDate = '20230331', @targetDate = @EDate output
				insert into Production.GoodProperties
				values
				(@i, @i1, @BDate, @EDate)
				set @i1 += 1
			end
		set @i += 1
		set @i1 = 1
	END

----------------------------������� 2----------------------------

--������� 2 �)
declare @newDate as smalldatetime = '20220513' --�������� �������� ����
select g.Name 
from
	(select gp1.GoodId --���������� ������, � ������� ���� �� 1 ���� �� ����������� � �������� ����
	from Production.GoodProperties as gp1
	where (@newDate not between  gp1.BDate AND gp1.EDate)
	except --��������� �������, � ������� ���� ���� � �������� ����
	select gp2.GoodId
	from Production.GoodProperties as gp2
	where (@newDate between  gp2.BDate AND gp2.EDate)) as t
	join Production.Goods as g
		on t.GoodId = g.Id
order by t.GoodId

--������� 2 b)
select distinct gp1.GoodId
from Production.GoodProperties as gp1
	join Production.GoodProperties as gp2
		on gp1.GoodId = gp2.GoodId AND gp1.ColorId != gp2.ColorId
where gp1.BDate <= gp2.EDate AND gp1.EDate >= gp2.BDate
order by gp1.GoodId

--������� 2 �)
select o.AgentId
from Sales.Orders as o
	join HR.Agents as a
		on o.AgentId = a.Id
group by o.AgentId, YEAR(o.CreateDate)
having YEAR(o.CreateDate) = 2022 AND COUNT(YEAR(o.CreateDate)) > 10

--������� 2d)
select t.AgentId, sum(od.GoodCount) as GoodsCount
from
	(select o.AgentId, od.OrderId 
	from Sales.OrderDetails as od
		left join Sales.Orders as o
			on od.OrderId = o.Id
		left join HR.Agents as a
			on o.AgentId = a.Id
		left join Production.Goods as g
			on g.Id = od.GoodId
		left join Production.GoodProperties as gp
			on g.Id = gp.GoodId
		left join Production.Colors as c
			on gp.ColorId = c.Id
	where g.Name = N'�����1' AND c.Name = N'����2'
		AND o.CreateDate = (select MAX(o2.CreateDate) 
						  from Sales.Orders as o2
						  where o2.AgentId = o.AgentId)) as t
join Sales.OrderDetails as od
		on t.OrderId = od.OrderId
group by t.AgentId, t.OrderId

--������� 2 e)
--������ ��� �������� ������� - � �������������� ������� ������� � ��� ���, ������� ��� ��������

--��� ������� �������
;with t as
(
select EOMONTH(o.CreateDate) as ����, SUM(od.GoodCount) as [���-�� � ������], g.Id as GoodId
from Sales.OrderDetails as od
	left join Production.Goods as g
		on od.GoodId = g.Id
	left join Sales.Orders as o
		on od.OrderId = o.Id
where YEAR(o.CreateDate) = 2023
group by g.Id, EOMONTH(o.CreateDate)
)
select [����], g.Name as [������������], [���-�� � ������],
	(select SUM([���-�� � ������]) from t as t2
	 where t2.���� <= t.����
	 and t.GoodId = t2.GoodId) as [����]
from t
	left join Production.Goods as g
		on t.GoodId = g.Id
order by t.GoodId, [����]
------------------------------------

-- � �������������� ������� �������
select t.����, t.������������, t.[���-�� � ������], t.����
from
	(
	select distinct EOMONTH(o.CreateDate) as ����
		,g.Name as [������������]
		,SUM(od.GoodCount) over (partition by od.GoodId, EOMONTH(o.CreateDate)) as [���-�� � ������]
		,SUM(od.GoodCount) over (partition by od.GoodId order by EOMONTH(o.CreateDate)) as [����]
		,g.Id as GoodId 
	from Sales.OrderDetails as od
		left join Production.Goods as g
			on od.GoodId = g.Id
		left join Sales.Orders as o
			on od.OrderId = o.Id
	where YEAR(o.CreateDate) = 2023
	) as t
order by t.GoodId


---------�������� ��---------

--USE tempdb;
--GO
--DECLARE @SQL nvarchar(1000);
--IF EXISTS (SELECT 1 FROM sys.databases WHERE [name] = N'Shop')
--BEGIN
--    SET @SQL = N'USE [Shop];

--                 ALTER DATABASE Shop SET SINGLE_USER WITH ROLLBACK IMMEDIATE;
--                 USE [tempdb];

--                 DROP DATABASE Shop;';
--    EXEC (@SQL);
--END;