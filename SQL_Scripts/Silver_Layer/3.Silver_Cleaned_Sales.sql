USE Global_Electronics_DW;
GO

/*=========================================================
SILVER LAYER - SALES FACT CLEANING & LOAD
Source Table   : Bronze.Sales
Target Table   : Silver.Sales
Purpose        : Profile, validate foreign keys, clean date logic,
derive delivery KPIs, and load cleansed sales facts
into the Silver layer.
=========================================================*/

/*=========================================================
STEP 1: Preview Source Data
Purpose:

* Inspect raw data types, sample values, and initial field alignment.
=========================================================*/
SELECT TOP 1000 *
FROM Bronze.Sales;

/*=========================================================
STEP 2: Check Primary Key Granularity & Duplicates
Purpose:

* Sales fact grain is composite (Order_Number + Line_Item).
* Ensure composite key is unique and non-null.
=========================================================*/
SELECT
Order_Number,
Line_Item,
COUNT(*) AS Duplicate_Count
FROM Bronze.Sales
GROUP BY Order_Number, Line_Item
HAVING COUNT(*) > 1
OR Order_Number IS NULL
OR Line_Item IS NULL;

/*=========================================================
STEP 3: Profile Date Fields & Check Range Boundaries
Purpose:

* Verify minimum and maximum order dates to establish data domain.
=========================================================*/
SELECT
MIN(Order_Date) AS Min_Order_Date,
MAX(Order_Date) AS Max_Order_Date
FROM Bronze.Sales;

/*=========================================================
STEP 4: Test Delivery Lead Time & Fulfillment Logic
Purpose:

* Preview DATEDIFF logic, handle NULL delivery dates (in-transit),
* and flag delivery dates preceding order dates (data corruption).
=========================================================*/
SELECT DISTINCT
Order_Date,
Delivery_Date,
CASE
WHEN Delivery_Date IS NULL THEN NULL
WHEN Delivery_Date < Order_Date THEN NULL
ELSE DATEDIFF(DAY, Order_Date, Delivery_Date)
END AS Calculated_Delivery_Days,
CASE
WHEN Delivery_Date IS NOT NULL THEN 'Delivered'
ELSE 'In-Transit / Pending'
END AS Fulfillment_Status
FROM Bronze.Sales;

/*=========================================================
STEP 5: Validate Foreign Key Integrity Against Silver Dimensions
Purpose:

* Ensure all customer and product keys exist in Silver dimension tables.
* Returns 0 rows if foreign key integrity is 100% clean.
=========================================================*/
-- Customer Foreign Key Integrity
SELECT S.CustomerKey
FROM Bronze.Sales S
LEFT JOIN Silver.Customers C ON S.CustomerKey = C.CustomerKey
WHERE C.CustomerKey IS NULL;

-- Product Foreign Key Integrity
SELECT S.ProductKey
FROM Bronze.Sales S
LEFT JOIN Silver.Products P ON S.ProductKey = P.ProductKey
WHERE P.ProductKey IS NULL;

/*=========================================================
STEP 6: Validate Measure Range Bounds
Purpose:

* Ensure no negative or zero quantities exist.
=========================================================*/
SELECT Quantity
FROM Bronze.Sales
WHERE Quantity <= 0 OR Quantity IS NULL;

/*=========================================================
STEP 7: Load Cleaned & Enriched Sales Facts into Silver Layer
Purpose:

* Apply data type casting (INT, DATE).
* Standardize Currency_Code string formatting.
* Compute derived KPIs (Delivery_Days, Fulfillment_Status).
* Deduplicate composite key via ROW_NUMBER().
* Enrich with DWH_Create_Date load timestamp.
=========================================================*/
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

/*=========================================================
STEP 8: Validate Loaded Silver Facts
Purpose:

* Confirm successful row load and verify transformed schema.
=========================================================*/
SELECT TOP 1000 *
FROM Silver.Sales;

/*=========================================================
STEP 9: Post-Load Primary Key Uniqueness Check
Purpose:

* Confirm zero duplicate composite keys exist in Silver.Sales.
=========================================================*/
SELECT
Order_Number,
Line_Item,
COUNT(*) AS Duplicate_Count
FROM Silver.Sales
GROUP BY Order_Number, Line_Item
HAVING COUNT(*) > 1;