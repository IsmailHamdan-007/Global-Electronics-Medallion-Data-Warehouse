USE Global_Electronics_DW;
GO

/*=========================================================
SILVER LAYER - EXCHANGE RATES CLEANING & LOAD
Source Table   : Bronze.Exchange_Rates
Target Table   : Silver.Exchange_Rates
Purpose        : Profile composite key grain, validate non-zero 
                 rates, standardize ISO codes, and load into Silver.
=========================================================*/

/*=========================================================
STEP 1: Data Profiling & Quality Checks
=========================================================*/
-- Preview raw source rows
SELECT TOP 1000 * 
FROM Bronze.Exchange_Rates;

-- Check date domain range boundaries
SELECT 
    MIN([Date]) AS Earliest_Rate_Date,
    MAX([Date]) AS Latest_Rate_Date
FROM Bronze.Exchange_Rates;

-- Check composite key uniqueness (Date + Currency)
SELECT 
    [Date], 
    Currency, 
    COUNT(*) AS Duplicate_Count
FROM Bronze.Exchange_Rates
GROUP BY [Date], Currency
HAVING COUNT(*) > 1 
   OR [Date] IS NULL 
   OR Currency IS NULL;

-- Validate measure bounds (Rates must be > 0)
SELECT * 
FROM Bronze.Exchange_Rates 
WHERE Exchange <= 0 OR Exchange IS NULL;

-- Inspect unformatted ISO string values
SELECT DISTINCT Currency 
FROM Bronze.Exchange_Rates 
WHERE Currency <> UPPER(TRIM(Currency));

/*=========================================================
STEP 2: Load Cleaned Exchange Rates into Silver Layer
=========================================================*/
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

/*=========================================================
STEP 3: Post-Load Verification
=========================================================*/
SELECT TOP 1000 * 
FROM Silver.Exchange_Rates;