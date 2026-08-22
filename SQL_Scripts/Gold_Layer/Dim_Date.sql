USE Global_Electronics_DW;

SELECT * FROM Silver.Sales;

CREATE OR ALTER VIEW Gold.Dim_Date AS 
SELECT DISTINCT
    CONVERT(INT, CONVERT(CHAR(8), CAST(Order_Date AS DATE), 112)) AS Date_Key,
    CAST(Order_Date AS DATE) AS Full_Date,
    YEAR(Order_Date) AS Year,
    DATEPART(QUARTER, Order_Date) AS Quarter,
    MONTH(Order_Date) AS Month,
    DATENAME(MONTH, Order_Date) AS Month_Name,
    DATEPART(WEEK, Order_Date) AS Week,
    DAY(Order_Date) AS Day,
    DATENAME(WEEKDAY, Order_Date) AS Day_of_Week
FROM Silver.Sales;

SELECT * FROM Gold.Dim_Date;
