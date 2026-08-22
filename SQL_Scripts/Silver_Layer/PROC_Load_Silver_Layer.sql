USE Global_Electronics_DW;
GO

IF OBJECT_ID('Silver.usp_Load_Silver_Layer', 'P') IS NOT NULL
    DROP PROCEDURE Silver.usp_Load_Silver_Layer;
GO

CREATE PROCEDURE Silver.usp_Load_Silver_Layer
AS
/*===============================================================================
  PROCEDURE: Silver.usp_Load_Silver_Layer
  PURPOSE:   Executes Silver Layer transformation pipeline.
             Applies title-casing, special character fixes, string sanitization, 
             type casting, and composite-key deduplication across all 5 entities.
  USAGE:     EXEC Silver.usp_Load_Silver_Layer;
===============================================================================*/
BEGIN
    SET NOCOUNT ON;
    
    DECLARE @StartTime DATETIME2 = GETDATE();

    PRINT '=================================================================';
    PRINT 'STARTING SILVER LAYER ETL PIPELINE: ' + CONVERT(VARCHAR, @StartTime, 120);
    PRINT '=================================================================';

    BEGIN TRY
        BEGIN TRANSACTION;

        -------------------------------------------------------------------------
        -- 1. LOAD SILVER.CUSTOMERS
        -- Transformations: Title-case Name & City, repair State character encoding,
        --                  standardize Gender, compute exact Age.
        -------------------------------------------------------------------------
        PRINT '-> Truncating and loading Silver.Customers...';
        
        TRUNCATE TABLE Silver.Customers;

        WITH Cleaned_Customers AS (
            SELECT
                CAST(CustomerKey AS INT) AS CustomerKey,
                
                -- Standardize Gender
                CASE 
                    WHEN Gender IS NULL OR TRIM(Gender) = '' THEN 'Unknown'
                    ELSE UPPER(LEFT(TRIM(Gender), 1)) + LOWER(SUBSTRING(TRIM(Gender), 2, 20))
                END AS Gender,

                -- Standardize Name to Title Case
                (SELECT STRING_AGG(UPPER(LEFT(value, 1)) + LOWER(SUBSTRING(value, 2, LEN(value))), ' ')
                 WITHIN GROUP(ORDER BY ordinal)
                 FROM STRING_SPLIT(TRIM(Name), ' ', 1)) AS Name,

                -- Standardize City to Title Case
                (SELECT STRING_AGG(UPPER(LEFT(value, 1)) + LOWER(SUBSTRING(value, 2, LEN(value))), ' ')
                 WITHIN GROUP(ORDER BY ordinal)
                 FROM STRING_SPLIT(TRIM(City), ' ', 1)) AS City,

                UPPER(TRIM(State_Code)) AS State_Code,

                -- Repair Special Character Encodings for State
                CASE 
                    WHEN State = N'╬le-de-France' THEN N'Île-de-France'      
                    WHEN State = N'Baden-Wŕttemberg' THEN N'Baden-Württemberg'           
                    WHEN State = N'Franche-ComtΘ' THEN N'Franche-Comté'
                    WHEN State = N'Freistaat Thuringen' THEN N'Freistaat Thüringen'
                    WHEN State = N'Midi-PyrΘnΘes' THEN N'Midi-Pyrénées'
                    WHEN State = N'Provence-Alpes-C⌠te d''Azur' THEN N'Provence-Alpes-Côte d''Azur'
                    WHEN State = N'Redcar & Cleveland' THEN N'Redcar & Cleveland'
                    WHEN State = N'Rh⌠ne-Alpes' THEN N'Rhône-Alpes'
                    ELSE TRIM(State)
                END AS State,

                TRIM(Zip_Code) AS Zip_Code,
                TRIM(Country) AS Country,
                TRIM(Continent) AS Continent,
                CAST(Birthday AS DATE) AS Birthday,

                -- Deduplication Window
                ROW_NUMBER() OVER (
                    PARTITION BY CustomerKey 
                    ORDER BY Birthday DESC
                ) AS Row_Num

            FROM Bronze.Customers
            WHERE CustomerKey IS NOT NULL
        )
        INSERT INTO Silver.Customers (
            CustomerKey,
            Gender,
            Name,
            City,
            State_Code,
            State,
            Zip_Code,
            Country,
            Continent,
            Birthday,
            Age,
            DWH_Create_Date
        )
        SELECT
            CustomerKey,
            Gender,
            Name,
            City,
            State_Code,
            State,
            Zip_Code,
            Country,
            Continent,
            Birthday,
            DATEDIFF(YEAR, Birthday, GETDATE()) AS Age,
            GETDATE() AS DWH_Create_Date
        FROM Cleaned_Customers
        WHERE Row_Num = 1;


        -------------------------------------------------------------------------
        -- 2. LOAD SILVER.PRODUCTS
        -- Transformations: Strip currency symbols ('$', ','), TRY_CAST to DECIMAL,
        --                  deduplicate on ProductKey.
        -------------------------------------------------------------------------
        PRINT '-> Truncating and loading Silver.Products...';

        TRUNCATE TABLE Silver.Products;

        WITH Cleaned_Products AS (
            SELECT
                CAST(ProductKey AS INT) AS ProductKey,
                TRIM(Product_Name) AS Product_Name,
                TRIM(Brand) AS Brand,
                TRIM(Color) AS Color,

                -- Strip '$' and ',' replacing with empty string '' for proper DECIMAL conversion
                ISNULL(
                    TRY_CAST(
                        REPLACE(REPLACE(TRIM(Unit_Cost_USD), '$', ''), ',', '')
                        AS DECIMAL(10, 2)
                    ),
                    0.00
                ) AS Unit_Cost_USD,

                ISNULL(
                    TRY_CAST(
                        REPLACE(REPLACE(TRIM(Unit_Price_USD), '$', ''), ',', '')
                        AS DECIMAL(10, 2)
                    ),
                    0.00
                ) AS Unit_Price_USD,

                CAST(SubcategoryKey AS INT) AS SubcategoryKey,
                TRIM(Subcategory) AS Subcategory,
                CAST(CategoryKey AS INT) AS CategoryKey,
                TRIM(Category) AS Category,

                -- Deduplication Window
                ROW_NUMBER() OVER (
                    PARTITION BY ProductKey 
                    ORDER BY ProductKey
                ) AS Row_Num

            FROM Bronze.Products
            WHERE ProductKey IS NOT NULL
        )
        INSERT INTO Silver.Products (
            ProductKey,
            Product_Name,
            Brand,
            Color,
            Unit_Cost_USD,
            Unit_Price_USD,
            SubcategoryKey,
            Subcategory,
            CategoryKey,
            Category,
            DWH_Create_Date
        )
        SELECT
            ProductKey,
            Product_Name,
            Brand,
            Color,
            Unit_Cost_USD,
            Unit_Price_USD,
            SubcategoryKey,
            Subcategory,
            CategoryKey,
            Category,
            GETDATE() AS DWH_Create_Date
        FROM Cleaned_Products
        WHERE Row_Num = 1;


        -------------------------------------------------------------------------
        -- 3. LOAD SILVER.STORES
        -- Transformations: Clean strings, cast dates/integers, deduplicate on StoreKey.
        -------------------------------------------------------------------------
        PRINT '-> Truncating and loading Silver.Stores...';

        TRUNCATE TABLE Silver.Stores;

        WITH Cleaned_Stores AS (
            SELECT 
                CAST(StoreKey AS INT) AS StoreKey,
                TRIM(Country) AS Country,
                TRIM(State) AS State,
                CAST(Square_Meters AS INT) AS Square_Meters,
                CAST(Open_Date AS DATE) AS Open_Date,
                
                -- Primary Key Deduplication
                ROW_NUMBER() OVER (
                    PARTITION BY StoreKey 
                    ORDER BY Open_Date ASC
                ) AS Row_Num
            FROM Bronze.Stores
            WHERE StoreKey IS NOT NULL
        )
        INSERT INTO Silver.Stores (
            StoreKey,
            Country,
            State,
            Square_Meters,
            Open_Date,
            DWH_Create_Date
        )
        SELECT 
            StoreKey,
            Country,
            State,
            Square_Meters,
            Open_Date,
            GETDATE() AS DWH_Create_Date
        FROM Cleaned_Stores
        WHERE Row_Num = 1;


        -------------------------------------------------------------------------
        -- 4. LOAD SILVER.EXCHANGE_RATES
        -- Transformations: Format date/currency, deduplicate on (Date, Currency).
        -------------------------------------------------------------------------
        PRINT '-> Truncating and loading Silver.Exchange_Rates...';

        TRUNCATE TABLE Silver.Exchange_Rates;

        WITH Cleaned_Exchange_Rates AS (
            SELECT
                CAST([Date] AS DATE) AS Rate_Date,
                UPPER(TRIM(Currency)) AS Currency_Code,
                CAST(Exchange AS DECIMAL(18, 4)) AS Exchange_Rate,
                
                -- Primary Composite Key Deduplication
                ROW_NUMBER() OVER (
                    PARTITION BY [Date], UPPER(TRIM(Currency))
                    ORDER BY [Date] ASC
                ) AS Row_Num
            FROM Bronze.Exchange_Rates
            WHERE [Date] IS NOT NULL 
              AND Currency IS NOT NULL
        )
        INSERT INTO Silver.Exchange_Rates (
            Rate_Date,
            Currency_Code,
            Exchange_Rate,
            DWH_Create_Date
        )
        SELECT 
            Rate_Date,
            Currency_Code,
            Exchange_Rate,
            GETDATE() AS DWH_Create_Date
        FROM Cleaned_Exchange_Rates
        WHERE Row_Num = 1;


        -------------------------------------------------------------------------
        -- 5. LOAD SILVER.SALES
        -- Transformations: Compute Delivery_Days lead time, set Fulfillment Status,
        --                  deduplicate on composite key (Order_Number, Line_Item).
        -------------------------------------------------------------------------
        PRINT '-> Truncating and loading Silver.Sales...';

        TRUNCATE TABLE Silver.Sales;

        WITH Cleaned_Sales AS (
            SELECT
                CAST(Order_Number AS INT) AS Order_Number,
                CAST(Line_Item AS INT) AS Line_Item,
                CAST(CustomerKey AS INT) AS CustomerKey,
                CAST(StoreKey AS INT) AS StoreKey,
                CAST(ProductKey AS INT) AS ProductKey,
                CAST(Order_Date AS DATE) AS Order_Date,
                CAST(Delivery_Date AS DATE) AS Delivery_Date,
                CAST(Quantity AS INT) AS Quantity,
                UPPER(TRIM(Currency_Code)) AS Currency_Code,

                -- Derived Metric: Delivery Lead Time in Days
                CASE 
                    WHEN Delivery_Date IS NULL THEN NULL
                    WHEN Delivery_Date < Order_Date THEN NULL
                    ELSE DATEDIFF(DAY, Order_Date, Delivery_Date) 
                END AS Delivery_Days,

                -- Derived Attribute: Fulfillment Status Flag
                CASE 
                    WHEN Delivery_Date IS NOT NULL THEN 'Delivered'
                    ELSE 'In-Transit / Pending'
                END AS Fulfillment_Status,

                -- Composite Key Deduplication Window
                ROW_NUMBER() OVER(
                    PARTITION BY Order_Number, Line_Item
                    ORDER BY Order_Date
                ) AS Row_Num
            FROM Bronze.Sales
            WHERE Order_Number IS NOT NULL
              AND Line_Item IS NOT NULL
        )
        INSERT INTO Silver.Sales (
            Order_Number,
            Line_Item,
            CustomerKey,
            StoreKey,
            ProductKey,
            Order_Date,
            Delivery_Date,
            Quantity,
            Currency_Code,
            Delivery_Days,
            Fulfillment_Status,
            DWH_Create_Date
        )
        SELECT
            Order_Number,
            Line_Item,
            CustomerKey,
            StoreKey,
            ProductKey,
            Order_Date,
            Delivery_Date,
            Quantity,
            Currency_Code,
            Delivery_Days,
            Fulfillment_Status,
            GETDATE() AS DWH_Create_Date
        FROM Cleaned_Sales
        WHERE Row_Num = 1;

        -- Commit Transaction if all steps complete successfully
        COMMIT TRANSACTION;

        DECLARE @EndTime DATETIME2 = GETDATE();
        PRINT '=================================================================';
        PRINT 'SILVER LAYER SUCCESSFUL. Total Execution Time: ' 
              + CAST(DATEDIFF(SECOND, @StartTime, @EndTime) AS VARCHAR) + ' seconds.';
        PRINT '=================================================================';

    END TRY
    BEGIN CATCH
        -- Rollback on failure to prevent half-loaded states
        IF @@TRANCOUNT > 0
            ROLLBACK TRANSACTION;

        PRINT '=================================================================';
        PRINT 'ERROR OCCURRED DURING SILVER LAYER LOADING!';
        PRINT 'Error Message:  ' + ERROR_MESSAGE();
        PRINT 'Error Number:   ' + CAST(ERROR_NUMBER() AS VARCHAR);
        PRINT 'Error Line:     ' + CAST(ERROR_LINE() AS VARCHAR);
        PRINT '=================================================================';
        
        THROW;
    END CATCH
END;
GO

EXEC Silver.usp_Load_Silver_Layer;