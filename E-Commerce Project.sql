


select * from cust_dimen

select * from orders_dimen

select * from shipping_dimen

---ORDERS_DIMEN TABLOSUNU DÜZENLEME---
select SUBSTRING(Ord_id, 5,6) order_id 
from orders_dimen

ALTER TABLE orders_dimen
ADD order_id int identity primary key

ALTER TABLE orders_dimen
DROP COLUMN Ord_id


---SHIPPING_DIMEN TABLOSUNU DÜZENLEME---
select SUBSTRING(Ship_id,5,6) Ship_ID
from shipping_dimen

alter table shipping_dimen
add Ship_ID int identity 

alter table shipping_dimen
drop column Ship_id

ALTER TABLE shipping_dimen
ADD CONSTRAINT PK PRIMARY KEY ( Ship_ID)

---CUST_DIMEN TABLOSUNU DÜZENLEME---
select SUBSTRING(Cust_id,6,7) Customer_id
from cust_dimen

alter table cust_dimen
add Customer_id int identity 

alter table cust_dimen
drop column Cust_id

select * from shipping_dimen
ORDER BY Order_ID

select * from cust_dimen

---PROD_DIMEN TABLOSUNU DÜZENLEME---
select SUBSTRING(Prod_id, 6,6) Product_id 
from prod_dimen

ALTER TABLE prod_dimen
ADD Product_id int identity (1,1) primary key not null

ALTER TABLE prod_dimen
DROP COLUMN Prod_id

select * from prod_dimen


---MARKET_FACT TABLOSUNU DÜZENLEME---
update market_fact
set Ord_id = SUBSTRING(Ord_id, 5,6)

update market_fact
set Prod_id = SUBSTRING(Prod_id, 6,6)

update market_fact
set Ship_id = SUBSTRING(Ship_id, 5,6)

update market_fact
set Cust_id = SUBSTRING(Cust_id, 6,6)

select * from market_fact

------Analyze the data by finding the answers to the questions below:------

---1. Using the columns of “market_fact”, “cust_dimen”, “orders_dimen”, 
---“prod_dimen”, “shipping_dimen”, Create a new table, named as
---“combined_table”. 

select mf.Order_id ,mf.Customer_id,mf.Product_id,mf.Ship_id,mf.Sales,mf.Discount,mf.Order_Quantity,mf.Product_Base_Margin,
		od.Order_Date,od.Order_Priority,
		cd.Customer_Name,cd.Province,cd.Region,cd.Customer_Segment,
		pd.Product_Category,pd.Product_Sub_Category,
		sd.Ship_Mode,sd.Ship_Date
---into combined_table
from market_fact mf, cust_dimen cd, orders_dimen od, prod_dimen pd, shipping_dimen sd
where sd.Ship_id = mf.Ship_id
	  and od.Order_id = mf.Order_id
	  and cd.Customer_id = mf.Customer_id
	  and pd.Product_id = mf.Product_id

select * from combined_table

---2. Find the top 3 customers who have the maximum count of orders.

select top 3 Customer_id, Customer_Name, sum(Order_Quantity) Sum_order_quantity
from combined_table
group by Customer_id, Order_Quantity, Customer_Name
order by Sum_order_quantity desc


---3. Create a new column at combined_table as DaysTakenForDelivery that 
---contains the date difference of Order_Date and Ship_Date.

select *, DATEDIFF(day, Order_Date, Ship_Date) DaysTakenForDelivery
from combined_table

alter table combined_table add DaysTakenForDelivery int null

update combined_table
set DaysTakenForDelivery= DATEDIFF(day, Order_Date, Ship_Date)

select * from combined_table

---4. Find the customer whose order took the maximum time to get delivered.

select top 1 Customer_id,Customer_Name, DaysTakenForDelivery
from combined_table
group by Customer_id,Customer_Name, DaysTakenForDelivery
order by DaysTakenForDelivery desc


---5. Count the total number of unique customers in January and how many of them 
---came back every month over the entire year in 2011.

select distinct month(Order_date) as [Month], 
		count(*) over(partition by month(Order_date)) Count_of_Customer
from combined_table
where year(Order_Date) = 2011 
			and Customer_id in (
								select distinct Customer_id
								from combined_table
								where month(Order_Date ) = 01)
order by month(Order_date)

---6. Write a query to return for each user the time elapsed between the first 
---purchasing and the third purchasing, in ascending order by Customer ID.

with t1 as(
select Customer_id,Order_Date,count(*) Over(partition by Customer_id) OrderCountOfTheCustomers
from combined_table
)
select *, ROW_NUMBER() OVER(Partition By Customer_id Order BY Customer_id, Order_Date) as [Row Number]
into #MoreThanThreeOrders
from t1
where OrderCountOfTheCustomers > 3


Select Customer_id,Order_Date as First_Date
into #First_Date
from #MoreThanThreeOrders
where  [Row Number] =1


Select Customer_id,Order_Date as Third_Date
into #Third_Date
from #MoreThanThreeOrders
where  [Row Number] =3 

select * from #MoreThanThreeOrders


select F.Customer_id, DATEDIFF(DAY,First_Date,Third_Date) DateDiffOfPurchasing 
from #First_Date F, #Third_Date T
where F.Customer_id =T.Customer_id

---7. Write a query that returns customers who purchased both product 11 and 
---product 14, as well as the ratio of these products to the total number of 
---products purchased by the customer.


select Customer_id, Order_Quantity
into #11and14_purchased
from combined_table
where Product_id=14 
and Customer_id in(
					select Customer_id
					from combined_table
					where Product_id=11 )


select round (
(select sum(Order_Quantity) as sum_quantity
from #11and14_purchased) 
/ 
(select sum(Order_Quantity)
from combined_table
where Product_id=14 or Product_id=11 ), 3) as Purchased_ratio



------Customer Segmentation----
----Categorize customers based on their frequency of visits. The following steps will guide you. If you want, you can track your own way.

---1. Create a “view” that keeps visit logs of customers on a monthly basis. 
---(For each log, three field is kept: Cust_id, Year, Month)

create view Monthly_log as
select Customer_id, YEAR(Order_Date) as [Year], month(Order_Date) as [Month]
from combined_table

select *
from Monthly_log
order by [Year] desc, [Month] desc

---2. Create a “view” that keeps the number of monthly visits by users. 
---(Show separately all months from the beginning business).

create view Visitors_of_Month as
select distinct count(Customer_id) over(partition by month(order_date)) CountofVisitors, Month(Order_Date) [Months]
from combined_table

select * from Visitors_of_Month order by Months

---3. For each visit of customers, create the next month of the visit as a separate column.

SELECT *
FROM
			(
			SELECT Customer_id,Order_id, MONTH(Order_Date) [MONTH]
			FROM combined_table
			) A
PIVOT
(
	count(Order_id)
	FOR [MONTH] IN
	(
	[1] , [2], [3], [4],[5],[6],[7],[8],[9],[10],[11],[12]
	)
) AS PIVOT_TABLE
ORDER BY Customer_id

---4. Calculate the monthly time gap between two consecutive visits by each customer.

select Customer_id, Order_id,Order_Date,
		DATEDIFF(month,lag(Order_Date,1)over(partition by Customer_id order by Order_Date), Order_Date) as Order_DateDiff
into #Order_DateDiff
from combined_table
order by Customer_id, Order_Date

select * from #Order_DateDiff

---5. Categorise customers using average time gaps. Choose the most fitted labeling model for you.
---For example: 
---o Labeled as churn if the customer hasn't made another purchase in the months since they made their first purchase.
---o Labeled as regular if the customer has made a purchase every month. Etc.


select distinct Order_id,Customer_id,Order_Date
into #OrderDate
from combined_table
order by Customer_id, Order_Date

select distinct Customer_id,Order_id,Order_Date, LAG(Order_Date,1) OVER(PARTITION BY Customer_id ORDER BY Order_Date) Previous_Visit, 
			DATEDIFF(MONTH,LAG(Order_Date,1) OVER(PARTITION BY Customer_id ORDER BY Order_Date),Order_Date) [OrderDateDiff]
into #OrderDateDiff
from #OrderDate
order by Customer_id, Order_Date


select distinct Customer_id, Order_date ,
		avg(OrderDateDiff) over(partition by Customer_id) as  avg_Order_Datediff
into #avgOrderDatediff
from #OrderDateDiff

select avg(avg_Order_Datediff) avg
from #avgOrderDatediff


---Irregular Customer
select distinct Customer_id
into #IrregularCustomer
from #avgOrderDatediff
where avg_Order_Datediff > (select avg(avg_Order_Datediff) avg
					   from #avgOrderDatediff
					   )

ALTER TABLE #IrregularCustomer
ADD Customer_Status nvarchar(50);

update #IrregularCustomer
set Customer_Status='Irregular'

select * from #IrregularCustomer

---- Lost Customer

select distinct Customer_id,count(Order_Date) OVER(PARTITION BY Customer_id) CountofOrder
into #LostCustomer
from #avgOrderDatediff
order by Customer_id
;

select Customer_id
into #Lost
from #LostCustomer
where CountofOrder = 1

ALTER TABLE #lost
ADD Customer_Status nvarchar(50);

update #Lost
set Customer_Status='Lost'

select * from #Lost


---- Regular Customer

select distinct Customer_id,avg_Order_Datediff as CustomerStatus
into #regularStatus
from #avgOrderDateDiff
where avg_Order_Datediff <= (select avg(avg_Order_Datediff) avg
					   from #avgOrderDateDiff
					   )

ALTER TABLE #regularStatus
ADD Customer_Status nvarchar(50);

update #regularStatus
set Customer_Status='Regular'

alter table #regularStatus
drop column CustomerStatus

select* from #regularStatus



---Month-Wise Retention Rate---

--Find month-by-month customer retention ratei since the start of the business.
--There are many different variations in the calculation of Retention Rate. But we will try to calculate the month-wise retention rate in this project.
--So, we will be interested in how many of the customers in the previous month could be retained in the next month.
--Proceed step by step by creating “views”. You can use the view you got at the end of the Customer Segmentation section as a source.

--1. Find the number of customers retained month-wise. (You can use time gaps)

select distinct *,
		count(Customer_id) over(partition by Previous_visit order by Customer_id) RetentionMonthWise
into #RetentionMonthWise
from #OrderDateDiff
where OrderDateDiff=1

--2. Calculate the month-wise retention rate.
--NOTE : Month-Wise Retention Rate = 1.0 * Number of Customers Retained in The Current Month / Total Number of Customers in the Current Month








































