USE Global_Electronics_DW;
GO

/*=========================================================
SILVER LAYER - STORES DIMENSION CLEANING & LOAD
Source Table   : Bronze.Stores
Target Table   : Silver.Stores
Purpose        : Profile, validate store keys, clean locations,
                 and load store dimension data into Silver.
=========================================================*/

/*=========================================================
STEP 1: Data Profiling & Quality Checks
=========================================================*/
-- Preview raw source rows
SELECT TOP 1000 * 
FROM Bronze.Stores;

-- Check for missing primary keys
SELECT DISTINCT StoreKey
FROM Bronze.Stores
WHERE StoreKey IS NULL;

-- Check for untrimmed location strings or missing countries
SELECT DISTINCT Country
FROM Bronze.Stores
WHERE Country <> TRIM(Country) OR Country IS NULL;

-- Check primary key uniqueness
SELECT StoreKey, COUNT(*) AS Duplicate_Count
FROM Bronze.Stores
GROUP BY StoreKey
HAVING COUNT(*) > 1 OR StoreKey IS NULL;

-- Profile physical vs. non-physical store metrics
SELECT StoreKey, Square_Meters
FROM Bronze.Stores
WHERE Square_Meters <= 0 OR Square_Meters IS NULL;

-- Check date domain range boundaries
SELECT 
    MIN(Open_Date) AS First_Open_Date,
    MAX(Open_Date) AS Latest_Open_Date
FROM Bronze.Stores;

/*=========================================================
STEP 2: Load Cleaned Stores Dimension into Silver Layer
=========================================================*/
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

/*=========================================================
STEP 3: Post-Load Verification
=========================================================*/
SELECT TOP 1000 * 
FROM Silver.Stores;