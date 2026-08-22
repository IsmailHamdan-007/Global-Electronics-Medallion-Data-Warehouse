-- =============================================================================
--       STORED PROCEDURE: STORED PROCEDURE FOR LOADING BRONZE LAYER
-- =============================================================================

CREATE OR ALTER PROCEDURE Bronze.Load_Bronze AS
BEGIN 
    SET NOCOUNT ON;
    DECLARE @start_time DATETIME, @end_time DATETIME;

    BEGIN TRY

        -- ---------------------------------------------------------------------
        -- Loading Customers
        -- ---------------------------------------------------------------------
        PRINT '=============================================================';
        PRINT 'Loading Customers Table';
        PRINT '=============================================================';

        SET @start_time = GETDATE();
        PRINT '>> Truncating Table Bronze.Customers';
        TRUNCATE TABLE Bronze.Customers;

        BULK INSERT Bronze.Customers
        FROM 'D:\DataBricks\Global_Electronic_Retailers\Data\Customers.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ';',
            ROWTERMINATOR = '\n',
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';

        -- ---------------------------------------------------------------------
        -- Loading Exchange_Rates
        -- ---------------------------------------------------------------------
        PRINT '=============================================================';
        PRINT 'Loading Exchange_Rates Table';
        PRINT '=============================================================';

        SET @start_time = GETDATE();
        PRINT '>> Truncating Table Bronze.Exchange_Rates';
        TRUNCATE TABLE Bronze.Exchange_Rates;

        BULK INSERT Bronze.Exchange_Rates
        FROM 'D:\DataBricks\Global_Electronic_Retailers\Data\Exchange_Rates.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ';',
            ROWTERMINATOR = '\n',
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';

        -- ---------------------------------------------------------------------
        -- Loading Products
        -- ---------------------------------------------------------------------
        PRINT '=============================================================';
        PRINT 'Loading Products Table';
        PRINT '=============================================================';

        SET @start_time = GETDATE();
        PRINT '>> Truncating Table Bronze.Products';
        TRUNCATE TABLE Bronze.Products;

        BULK INSERT Bronze.Products
        FROM 'D:\DataBricks\Global_Electronic_Retailers\Data\Products.csv'
        WITH (
            FORMAT = 'CSV',
            FIELDQUOTE = '"',
            FIELDTERMINATOR = ';',
            ROWTERMINATOR = '\n',
            FIRSTROW = 2,
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';

        -- ---------------------------------------------------------------------
        -- Loading Sales
        -- ---------------------------------------------------------------------
        PRINT '=============================================================';
        PRINT 'Loading Sales Table';
        PRINT '=============================================================';

        SET @start_time = GETDATE();
        PRINT '>> Truncating Table Bronze.Sales';
        TRUNCATE TABLE Bronze.Sales;

        BULK INSERT Bronze.Sales
        FROM 'D:\DataBricks\Global_Electronic_Retailers\Data\Sales.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ';',
            ROWTERMINATOR = '\n',
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';

        -- ---------------------------------------------------------------------
        -- Loading Stores
        -- ---------------------------------------------------------------------
        PRINT '=============================================================';
        PRINT 'Loading Stores Table';
        PRINT '=============================================================';

        SET @start_time = GETDATE();
        PRINT '>> Truncating Table Bronze.Stores';
        TRUNCATE TABLE Bronze.Stores;

        BULK INSERT Bronze.Stores
        FROM 'D:\DataBricks\Global_Electronic_Retailers\Data\Stores.csv'
        WITH (
            FIRSTROW = 2,
            FIELDTERMINATOR = ';',
            ROWTERMINATOR = '\n',
            CODEPAGE = '65001',
            TABLOCK
        );

        SET @end_time = GETDATE();
        PRINT '>> Load Duration: ' + CAST(DATEDIFF(second, @start_time, @end_time) AS NVARCHAR) + ' seconds';

    END TRY
    BEGIN CATCH
        PRINT '=================================================';
        PRINT 'ERROR OCCURRED DURING LOADING BRONZE LAYER';
        PRINT 'Error Message: ' + ERROR_MESSAGE();
        PRINT 'Error Number:  ' + CAST(ERROR_NUMBER() AS NVARCHAR);
        PRINT 'Error State:   ' + CAST(ERROR_STATE() AS NVARCHAR);
        PRINT '=================================================';
    END CATCH
END;
GO

-- =============================================================================
-- 3. EXECUTE PROCEDURE
-- =============================================================================
EXEC Bronze.Load_Bronze;