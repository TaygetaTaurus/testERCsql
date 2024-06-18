----------------------------Создание БД----------------------------
if DB_ID('Shop') is not null drop database Shop
go

create database Shop
collate Cyrillic_General_CI_AS
go

use Shop
go
--создание схем
create schema HR authorization dbo;
go
create schema Production authorization dbo;
go
create schema Sales authorization dbo;
go
--создание таблицы Goods
if OBJECT_ID('Production.Goods', 'U') IS NOT NULL
	drop table Production.Goods;

create table Production.Goods
(
	Id int not null identity
		primary key,
	Name nvarchar(20) not null 
)
--создание таблицы Colors
if OBJECT_ID('Production.Colors', 'U') IS NOT NULL
	drop table Production.Colors;

create table Production.Colors
(
	Id int not null identity
		primary key,
	Name nvarchar(20) not null 
)
--создание таблицы Agents
if OBJECT_ID('HR.Agents', 'U') IS NOT NULL
	drop table HR.Agents;

create table HR.Agents
(
	Id int identity
		primary key,
	Name nvarchar(20) not null 
)
--создание таблицы Orders
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
--создание таблицы GoodProperties
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
--создание таблицы OrderDetails
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

----------------------------Задание 1----------------------------

-- Задание 1 а)

--заполнение таблицы Agents данными
declare @i as int = 1
while @i <= 15
	begin
		insert into HR.Agents
		values
		(N'Агент' + cast(@i as nvarchar(20)))
		set @i += 1
	end

--заполнение таблицы Goods данными
set @i = 1
while @i <= 10
	begin
		insert into Production.Goods
		values
		(N'Товар' + cast(@i as nvarchar(20)))
		set @i += 1
	end

--заполнение таблицы Colors данными
insert into Production.Colors
values
(N'Цвет1'),
(N'Цвет2'),
(N'Цвет3')
go

create proc #randomNumber --создание временной процедуры для задания случайного числа в диапазоне [@min, @max]
@min as int,
@max as int,
@value as int output
as
SET NOCOUNT ON;
set @value = FLOOR(RAND(checksum(newid()))* (@max - @min + 1) + @min);
go

go
create proc #randomDate --создание временной процедуры для задания случайной даты в диапазоне [@FromDate, @ToDate]
	@FromDate as date,
	@ToDate as date,
	@targetDate as date output
as
SET NOCOUNT ON;
set @targetDate = dateadd(day, rand(checksum(newid()))*(1+datediff(day, @FromDate, @ToDate)), @FromDate)
go

--Задание 1 b)

--заполнение таблицы Orders произвольными значениями
declare @FromDate as date  = '20200101'
declare @ToDate as date = '20230331'
declare @i1 as int = 1;
declare @i2 as int = 1;
while @i1 <= (select count(*) from HR.Agents) --цикл для 15-ти агентов
	begin
		declare @maxi as int; 
		exec #randomNumber 10, 40, @maxi output  -- задание случайного количества заказов в диапазоне  [10, 40] для каждого агента
		WHILE @i2 <= @maxi 
			BEGIN
				declare @date as date
					exec #randomDate --задание случайной даты для создание заказа в диапазоне [@FromDate, @ToDate]
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

--заполнение таблицы OrderDetails
declare @g as int = 1
declare @randid as int = 1
declare @i as int = 1
set @i = 1
while @i <= (select count(Id) from Sales.Orders) --счетчик по всем заказам
	begin
		declare @maxgoods as int;
		exec #randomNumber 1, 5, @maxgoods output  --задание произвольного кол-ва разных товаров для каждого заказа
		while @g <= @maxgoods
			BEGIN
				set @randid = (select top(1) Id from Production.Goods order by NEWID()) --выбор 1 случайного товара @randid из таблицы Goods
				declare @goodsValue as int;
					exec #randomNumber 1, 10, @goodsValue output --задание произвольного кол-ва разных товаров для каждого заказа
				if (@i = (select distinct OrderId from Sales.OrderDetails where OrderId = @i) 
					AND @randid  not in (select GoodId from Sales.OrderDetails where OrderId = @i)) --проверка что сравнение происходит в рамках одного заказа и наличие случайного товара @randid в этом заказе
					begin
						insert into Sales.OrderDetails
						values
						(@i, @randid, @goodsValue) -- добавление в таблицу с произвольным кол-вом опредреленного товара в диапазоне [1, 10] шт
					end;
				else --добавление товара, если в таблице еще нет заказа с данным Id
					begin
						if (@randid  not in (select GoodId from Sales.OrderDetails where OrderId = @i)) --проверка на наличие случайного товара @randid в этом заказе
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

--Задание 1 c) заполнение таблицы GoodProperties
set @i = 1
set @i1 = 1
while @i <= 4
	BEGIN
		while @i1 <= 2
			begin -- здесь всегда начало цвета будет меньше конца в рамках одного товара одного цвета, но пересекаться интервалы действия цвета в рамках одного товара могут (для задания 2b)
				declare @BDate as date --задание произвольной даты начала цвета
					exec #randomDate @FromDate, @ToDate, @BDate output
				declare @EDate as date --задание произвольной даты конца цвета (начало всегда < конца, т.к. минимальная дата конца считается от даты начала цвета)
					exec #randomDate @FromDate = @BDate, @ToDate = '20230331', @targetDate = @EDate output
				insert into Production.GoodProperties
				values
				(@i, @i1, @BDate, @EDate)
				set @i1 += 1
			end
		set @i += 1
		set @i1 = 1
	END

----------------------------Задание 2----------------------------

--Задание 2 а)
declare @newDate as smalldatetime = '20220513' --задается желаемая дата
select g.Name 
from
	(select gp1.GoodId --выбираются товары, у которых хотя бы 1 цвет не использутся в заданную дату
	from Production.GoodProperties as gp1
	where (@newDate not between  gp1.BDate AND gp1.EDate)
	except --отсечение товаров, у которых есть цвет в заданную дату
	select gp2.GoodId
	from Production.GoodProperties as gp2
	where (@newDate between  gp2.BDate AND gp2.EDate)) as t
	join Production.Goods as g
		on t.GoodId = g.Id
order by t.GoodId

--Задание 2 b)
select distinct gp1.GoodId
from Production.GoodProperties as gp1
	join Production.GoodProperties as gp2
		on gp1.GoodId = gp2.GoodId AND gp1.ColorId != gp2.ColorId
where gp1.BDate <= gp2.EDate AND gp1.EDate >= gp2.BDate
order by gp1.GoodId

--Задание 2 с)
select o.AgentId
from Sales.Orders as o
	join HR.Agents as a
		on o.AgentId = a.Id
group by o.AgentId, YEAR(o.CreateDate)
having YEAR(o.CreateDate) = 2022 AND COUNT(YEAR(o.CreateDate)) > 10

--Задание 2d)
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
	where g.Name = N'Товар1' AND c.Name = N'Цвет2'
		AND o.CreateDate = (select MAX(o2.CreateDate) 
						  from Sales.Orders as o2
						  where o2.AgentId = o.AgentId)) as t
join Sales.OrderDetails as od
		on t.OrderId = od.OrderId
group by t.AgentId, t.OrderId

--Задание 2 e)
--Сделал два варианта решения - с использованием оконных функций и без них, оставил оба варианта

--без оконных функций
;with t as
(
select EOMONTH(o.CreateDate) as Дата, SUM(od.GoodCount) as [Кол-во в месяце], g.Id as GoodId
from Sales.OrderDetails as od
	left join Production.Goods as g
		on od.GoodId = g.Id
	left join Sales.Orders as o
		on od.OrderId = o.Id
where YEAR(o.CreateDate) = 2023
group by g.Id, EOMONTH(o.CreateDate)
)
select [Дата], g.Name as [Наименование], [Кол-во в месяце],
	(select SUM([Кол-во в месяце]) from t as t2
	 where t2.Дата <= t.Дата
	 and t.GoodId = t2.GoodId) as [Итог]
from t
	left join Production.Goods as g
		on t.GoodId = g.Id
order by t.GoodId, [Дата]
------------------------------------

-- с использованием оконных функций
select t.Дата, t.Наименование, t.[Кол-во в месяце], t.Итог
from
	(
	select distinct EOMONTH(o.CreateDate) as Дата
		,g.Name as [Наименование]
		,SUM(od.GoodCount) over (partition by od.GoodId, EOMONTH(o.CreateDate)) as [Кол-во в месяце]
		,SUM(od.GoodCount) over (partition by od.GoodId order by EOMONTH(o.CreateDate)) as [Итог]
		,g.Id as GoodId 
	from Sales.OrderDetails as od
		left join Production.Goods as g
			on od.GoodId = g.Id
		left join Sales.Orders as o
			on od.OrderId = o.Id
	where YEAR(o.CreateDate) = 2023
	) as t
order by t.GoodId


---------удаление БД---------

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