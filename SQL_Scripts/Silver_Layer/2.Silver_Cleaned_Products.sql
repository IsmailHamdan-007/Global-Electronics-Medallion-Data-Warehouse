USE Global_Electronics_DW;
GO

/*=========================================================
SILVER LAYER - PRODUCT DIMENSION CLEANING & LOAD
Source Table   : Bronze.Products
Target Table   : Silver.Products
Purpose        : Validate, clean, cast data types, strip symbols,
and deduplicate product master data before loading
into the Silver layer.
=========================================================*/

/*=========================================================
STEP 1: Preview Source Data
Purpose:

* Verify that the Bronze table contains expected records and columns.
=========================================================*/
SELECT TOP 1000 *
FROM Bronze.Products;

/*=========================================================
STEP 2: Check for Duplicate or NULL Product Keys
Purpose:

* ProductKey is the primary entity identifier.
* Ensure uniqueness and check for NULL primary keys.
=========================================================*/
SELECT
ProductKey,
COUNT(*) AS Duplicate_Count
FROM Bronze.Products
GROUP BY ProductKey
HAVING COUNT(*) > 1
OR ProductKey IS NULL;

/*=========================================================
STEP 3: Check for Unwanted Spaces Across Text Fields
Purpose:

* Identify leading/trailing white space issues across text columns.
=========================================================*/
SELECT DISTINCT Product_Name 
FROM Bronze.Products 
WHERE Product_Name <> TRIM(Product_Name) OR Product_Name IS NULL;

SELECT DISTINCT Brand 
FROM Bronze.Products 
WHERE Brand <> TRIM(Brand) OR Brand IS NULL;

SELECT DISTINCT Color 
FROM Bronze.Products 
WHERE Color <> TRIM(Color) OR Color IS NULL;

SELECT DISTINCT Subcategory 
FROM Bronze.Products 
WHERE Subcategory <> TRIM(Subcategory) OR Subcategory IS NULL;

SELECT DISTINCT Category 
FROM Bronze.Products 
WHERE Category <> TRIM(Category) OR Category IS NULL;

/*=========================================================
STEP 4: Check for Invalid, Negative, or Dirty Monetary Values
Purpose:

* Inspect non-numeric characters (e.g., '$', ',') and zero/negative costs.
* Note: Keep Bronze raw as NVARCHAR; do NOT alter Bronze table schemas directly.
=========================================================*/
SELECT
ProductKey,
Unit_Cost_USD,
Unit_Price_USD
FROM Bronze.Products
WHERE TRY_CAST(REPLACE(REPLACE(TRIM(Unit_Cost_USD), '$', ''), ',', '') AS DECIMAL(10, 2)) <= 0
OR TRY_CAST(REPLACE(REPLACE(TRIM(Unit_Price_USD), '$', ''), ',', '') AS DECIMAL(10, 2)) <= 0
OR Unit_Cost_USD IS NULL
OR Unit_Price_USD IS NULL;

/*=========================================================
STEP 5: Load Cleaned and Standardized Data into Silver Layer
Purpose:

* Remove duplicates via ROW_NUMBER().
* Clean and trim text attributes.
* Strip '$' and ',' from monetary strings using REPLACE(..., '$', '') [empty string, not space].
* Cast numeric and monetary columns to correct types (INT, DECIMAL).
* Enrich with DWH_Create_Date metadata timestamp.
=========================================================*/
WITH Cleaned_Products AS (
SELECT
CAST(ProductKey AS INT) AS ProductKey,
TRIM(Product_Name) AS Product_Name,
TRIM(Brand) AS Brand,
TRIM(Color) AS Color,

  -- Strip '$' and ',' replacing with empty string '' to ensure proper DECIMAL conversion
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

/*=========================================================
STEP 6: Validate Loaded Silver Data
Purpose:

* Confirm row counts and data transformations in Silver.
=========================================================*/
SELECT TOP 1000 *
FROM Silver.Products;

/*=========================================================
STEP 7: Validate Primary Key Integrity in Silver
Purpose:

* Ensure zero duplicate keys or NULL values exist.
=========================================================*/
SELECT
ProductKey,
COUNT(*) AS Record_Count
FROM Silver.Products
GROUP BY ProductKey
HAVING COUNT(*) > 1
OR ProductKey IS NULL;

/*=========================================================
STEP 8: Validate Numeric Types and Calculations in Silver
Purpose:

* Confirm profit margins can be computed without conversion errors.
=========================================================*/
SELECT
ProductKey,
Product_Name,
Unit_Cost_USD,
Unit_Price_USD,
(Unit_Price_USD - Unit_Cost_USD) AS Profit_Margin
FROM Silver.Products;