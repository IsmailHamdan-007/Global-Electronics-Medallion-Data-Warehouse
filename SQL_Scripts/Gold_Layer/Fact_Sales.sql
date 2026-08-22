USE Global_Electronics_DW;

SELECT * FROM Silver.Sales;

CREATE OR ALTER VIEW Gold.Fact_Sales AS
SELECT 
    S.Order_Number,
    S.Line_Item,
    CONVERT(INT, CONVERT(CHAR(8), CAST(S.Order_Date AS DATE), 112)) AS Date_Key,
    S.Order_Date, 
    C.CustomerKey, 
    P.ProductKey, 
    St.StoreKey, 
    S.Quantity,
    P.Unit_Cost_USD,
    P.Unit_Price_USD,
    COALESCE(E.Exchange_Rate, 1.0) AS Exchange_Rate,
    
    -- Calculated Financial Metrics
    CAST((S.Quantity * P.Unit_Price_USD) AS DECIMAL(18,2)) AS Total_Revenue_USD,
    CAST((S.Quantity * P.Unit_Cost_USD) AS DECIMAL(18,2)) AS Total_Cost_USD,
    CAST((S.Quantity * (P.Unit_Price_USD - P.Unit_Cost_USD)) AS DECIMAL(18,2)) AS Total_Profit_USD,
    
    S.Fulfillment_Status
FROM Silver.Sales S 
INNER JOIN Gold.Dim_Products P
    ON S.ProductKey = P.ProductKey 
LEFT JOIN Gold.Dim_Stores St
    ON S.StoreKey = St.StoreKey
LEFT JOIN Gold.Dim_Customers C
    ON S.CustomerKey = C.CustomerKey
LEFT JOIN Gold.Fact_Exchange_Rates E
    ON S.Currency_Code = E.Currency_Code
   AND S.Order_Date = E.Rate_Date;

SELECT * FROM Gold.Fact_Sales;