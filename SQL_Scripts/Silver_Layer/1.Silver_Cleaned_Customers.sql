USE Global_Electronics_DW;
GO

/*=========================================================
SILVER LAYER - CUSTOMER DIMENSION CLEANING
Source Table   : Bronze.Customers
Target Table   : Silver.Customers
Purpose        : Clean, standardize, repair encoding issues,
and deduplicate customer data before loading
into the Silver layer.
=========================================================*/

/*=========================================================
STEP 1: Preview Source Data
Purpose:

* Verify that the Bronze table contains expected records and columns.
=========================================================*/
SELECT TOP 1000 *
FROM Bronze.Customers;

/*=========================================================
STEP 2: Check for Duplicate or NULL Customer Keys
Purpose:

* CustomerKey is the primary entity identifier.
* Ensure uniqueness and check for NULL primary keys.
=========================================================*/
SELECT
CustomerKey,
COUNT(*) AS duplicate_count
FROM Bronze.Customers
GROUP BY CustomerKey
HAVING COUNT(*) > 1
OR CustomerKey IS NULL;

/*=========================================================
STEP 3: Check Deduplication Strategy
Purpose:

* Use ROW_NUMBER() to identify duplicate records.
* Retain the latest active record based on Birthday/Metadata.
=========================================================*/
SELECT *
FROM
(
SELECT *,
ROW_NUMBER() OVER (
PARTITION BY CustomerKey
ORDER BY Birthday DESC
) AS flag_last
FROM Bronze.Customers
) T
WHERE flag_last = 1
AND CustomerKey = 2099937;

/*=========================================================
STEP 4: Check for Unwanted Spaces Across Text Fields
Purpose:

* Identify leading/trailing white space issues across text columns.
=========================================================*/
SELECT Name FROM Bronze.Customers WHERE Name <> TRIM(Name) OR Name IS NULL;
SELECT City FROM Bronze.Customers WHERE City <> TRIM(City) OR City IS NULL;
SELECT State_Code FROM Bronze.Customers WHERE State_Code <> TRIM(State_Code) OR State_Code IS NULL;
SELECT Zip_Code FROM Bronze.Customers WHERE Zip_Code <> TRIM(Zip_Code) OR Zip_Code IS NULL;
SELECT Country FROM Bronze.Customers WHERE Country <> TRIM(Country) OR Country IS NULL;
SELECT Continent FROM Bronze.Customers WHERE Continent <> TRIM(Continent) OR Continent IS NULL;

/*=========================================================
STEP 5: Check Categorical Column Values
Purpose:

* Verify current distinct values in Gender and State_Code.
=========================================================*/
SELECT DISTINCT Gender FROM Bronze.Customers;
SELECT DISTINCT State_Code FROM Bronze.Customers;

/*=========================================================
STEP 6: Test Multi-Word Title Case Transformations
Purpose:

* Test string-splitting logic on multi-word City names.
=========================================================*/
SELECT
(SELECT STRING_AGG(UPPER(LEFT(value, 1)) + LOWER(SUBSTRING(value, 2, LEN(value))), ' ')
WITHIN GROUP(ORDER BY ordinal)
FROM STRING_SPLIT(TRIM(City), ' ', 1)) AS Standardized_City
FROM Bronze.Customers;

/*=========================================================
STEP 7: Identify Encoding Issues in Special Characters
Purpose:

* Detect corrupted unicode characters in State names.
=========================================================*/
SELECT DISTINCT State
FROM Bronze.Customers
WHERE State COLLATE Latin1_General_100_BIN2 LIKE '%[^A-Za-z0-9 .''-]%'
ORDER BY State;

/*=========================================================
STEP 8: Test Encoding Fixes for Affected States
Purpose:

* Validate CASE mapping for corrupted unicode strings.
=========================================================*/
SELECT DISTINCT
CASE
WHEN State = N'╬le-de-France' THEN N'Île-de-France'
WHEN State = N'Baden-Wŕttemberg' THEN N'Baden-Württemberg'
WHEN State = N'Franche-ComtΘ' THEN N'Franche-Comté'
WHEN State = N'Freistaat Thuringen' THEN N'Freistaat Thüringen'
WHEN State = N'Midi-PyrΘnΘes' THEN N'Midi-Pyrénées'
WHEN State = N'Nuneaton & Bedworth' THEN N'Nuneaton & Bedworth'
WHEN State = N'Provence-Alpes-C⌠te d''Azur' THEN N'Provence-Alpes-Côte d''Azur'
WHEN State = N'Redcar & Cleveland' THEN N'Redcar & Cleveland'
WHEN State = N'Rh⌠ne-Alpes' THEN N'Rhône-Alpes'
ELSE State
END AS Cleaned_State
FROM Bronze.Customers;

/*=========================================================
STEP 9: Check Date Range Outliers
Purpose:

* Inspect MIN/MAX birth years to ensure valid dates.
=========================================================*/
SELECT
MIN(YEAR(Birthday)) AS Min_Birth_Year,
MAX(YEAR(Birthday)) AS Max_Birth_Year
FROM Bronze.Customers;

/*=========================================================
STEP 10: Load Cleaned and Standardized Data into Silver Layer
Purpose:

* Remove duplicates via ROW_NUMBER().
* Clean and title-case strings.
* Standardize Gender and State_Code values.
* Repair corrupted text encodings.
* Enrich with Age and DWH_Create_Date metadata columns.
=========================================================*/
WITH Cleaned_Data AS (
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
FROM Cleaned_Data
WHERE Row_Num = 1;

/*=========================================================
STEP 11: Validate Loaded Silver Data
Purpose:

* Confirm row counts and data transformations in Silver.
=========================================================*/
SELECT TOP 1000 *
FROM Silver.Customers;

/*=========================================================
STEP 12: Validate Primary Key Integrity in Silver
Purpose:

* Ensure zero duplicate keys or NULL values exist.
=========================================================*/
SELECT
CustomerKey,
COUNT(*) AS record_count
FROM Silver.Customers
GROUP BY CustomerKey
HAVING COUNT(*) > 1
OR CustomerKey IS NULL;

/*=========================================================
STEP 13: Validate Text Field Cleaning in Silver
Purpose:

* Confirm trailing and leading spaces were completely removed.
=========================================================*/
SELECT Name FROM Silver.Customers WHERE Name <> TRIM(Name);
SELECT City FROM Silver.Customers WHERE City <> TRIM(City);

/*=========================================================
STEP 14: Validate Categorical Standardization in Silver
Purpose:

* Confirm expected unique values for standardized fields.
=========================================================*/
SELECT DISTINCT Gender FROM Silver.Customers;
SELECT DISTINCT State_Code FROM Silver.Customers;