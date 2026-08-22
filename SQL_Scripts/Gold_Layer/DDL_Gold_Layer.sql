USE Global_Electronics_DW;
GO

/*==============================================================================
  GOLD LAYER: DIMENSION VIEWS
==============================================================================*/

-- 1. Dim_Products
-- Purpose: Conformed product dimension storing product catalog attributes.
CREATE OR ALTER VIEW Gold.Dim_Products AS
SELECT
    ProductKey,                         -- Primary Surrogate Key
    Product_Name,                       -- Product Name
    Brand,                              -- Brand Name
    Category,                           -- High-level Product Category
    Subcategory,                        -- Detailed Subcategory
    Unit_Cost_USD,                      -- Base Manufacturing/Acquisition Cost in USD
    Unit_Price_USD                       -- Standard Retail Sales Price in USD
FROM Silver.Products;
GO

-- 2. Dim_Stores
-- Purpose: Store hierarchy dimension storing physical and online store metadata.
CREATE OR ALTER VIEW Gold.Dim_Stores AS
SELECT
    StoreKey,                           -- Primary Surrogate Key
    Open_Date,                          -- Store Opening Date
    Country,                            -- Physical Store Country
    State,                              -- Physical Store State
    Square_Meters                       -- Store Footprint Size (NULL for online stores)
FROM Silver.Stores;
GO

-- 3. Dim_Customers
-- Purpose: Customer profile dimension including calculated demographics.
CREATE OR ALTER VIEW Gold.Dim_Customers AS
SELECT
    CustomerKey,                        -- Primary Surrogate Key
    Name,                               -- Full Customer Name
    Birthday,                           -- Date of Birth
    -- Dynamically calculated exact age in years
    DATEDIFF(YEAR, CAST(Birthday AS DATE), GETDATE()) 
      - CASE 
            WHEN DATEADD(YEAR, DATEDIFF(YEAR, CAST(Birthday AS DATE), GETDATE()), CAST(Birthday AS DATE)) > GETDATE() 
            THEN 1 
            ELSE 0 
        END AS Age,
    City,                               -- Customer City
    State,                              -- Customer State/Province
    Country,                            -- Customer Country
    Continent                           -- Customer Geographic Region
FROM Silver.Customers;
GO

-- 4. Dim_Date
-- Purpose: Conformed date dimension providing a contiguous calendar grain.
CREATE OR ALTER VIEW Gold.Dim_Date AS 
SELECT DISTINCT
    CONVERT(INT, CONVERT(CHAR(8), CAST(Order_Date AS DATE), 112)) AS Date_Key, -- FK Key: YYYYMMDD
    CAST(Order_Date AS DATE) AS Full_Date,                                     -- Standard Date Format
    YEAR(Order_Date) AS Year,                                                   -- Calendar Year
    DATEPART(QUARTER, Order_Date) AS Quarter,                                  -- Calendar Quarter (1-4)
    MONTH(Order_Date) AS Month,                                                 -- Month Number (1-12)
    DATENAME(MONTH, Order_Date) AS Month_Name,                                  -- Full Month Name (e.g., January)
    DATEPART(WEEK, Order_Date) AS Week,                                         -- ISO Week Number
    DAY(Order_Date) AS Day,                                                     -- Day of Month
    DATENAME(WEEKDAY, Order_Date) AS Day_of_Week                                -- Day Name (e.g., Monday)
FROM Silver.Sales;
GO


/*==============================================================================
  GOLD LAYER: FACT & AUXILIARY TABLES
==============================================================================*/

-- 5. Fact_Exchange_Rates
-- Purpose: Auxiliary fact table containing daily floating currency conversion rates.
CREATE OR ALTER VIEW Gold.Fact_Exchange_Rates AS
SELECT 
    CONVERT(INT, CONVERT(CHAR(8), CAST(Rate_Date AS DATE), 112)) AS Date_Key, -- FK to Dim_Date (YYYYMMDD)
    CAST(Rate_Date AS DATE) AS Rate_Date,                                     -- Calendar Date of Exchange Rate
    Currency_Code,                                                            -- 3-Letter ISO Code (e.g., EUR, GBP)
    Exchange_Rate                                                             -- Rate Multiplier to USD
FROM Silver.Exchange_Rates;
GO

-- 6. Fact_Sales
-- Purpose: Central transactional fact table modeling line-item sales metrics in USD.
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
GO