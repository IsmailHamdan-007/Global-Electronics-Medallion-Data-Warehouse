# Global Electronics Medallion Data Warehouse

## End-to-End SQL Server Data Warehouse | T-SQL | Medallion Architecture | Star Schema

An end-to-end **Medallion Data Warehouse built using Microsoft SQL Server and T-SQL** to transform raw global retail data into clean, standardized, and analytics-ready datasets.

The project implements a three-layer architecture:

**Bronze → Silver → Gold**

The pipeline processes customer, product, store, sales, and currency-exchange data and applies data-quality transformations, standardization, deduplication, derived business calculations, and dimensional modeling.

---

## 📌 Project Overview

The goal of this project is to simulate a real-world Data Engineering workflow where raw retail data from multiple source files is ingested into SQL Server, cleansed and transformed through a Silver layer, and finally exposed through a Gold analytical model.

The warehouse is designed around a **Star Schema**, with:

* Customer Dimension
* Product Dimension
* Store Dimension
* Date Dimension
* Sales Fact
* Exchange Rate Fact

The final Gold layer provides analytics-ready data for business reporting and downstream tools such as Power BI.

---

## 🏗️ Architecture

```text
                    SOURCE DATA
                         │
        ┌────────────────┼────────────────┐
        │                │                │
   Customers.csv    Products.csv     Stores.csv
   Sales.csv        Exchange_Rates.csv
        │                │                │
        └────────────────┼────────────────┘
                         ▼
                 ┌───────────────┐
                 │    BRONZE     │
                 │   RAW LAYER   │
                 │               │
                 │ Customers     │
                 │ Products      │
                 │ Stores        │
                 │ Sales         │
                 │ Exchange Rate │
                 └───────┬───────┘
                         │
                         │ T-SQL ETL
                         ▼
                 ┌───────────────┐
                 │    SILVER     │
                 │ CLEANSED LAYER│
                 │               │
                 │ Data Cleaning │
                 │ Standardizing │
                 │ Deduplication │
                 │ Validation    │
                 │ Derivations   │
                 └───────┬───────┘
                         │
                         ▼
                 ┌───────────────┐
                 │     GOLD      │
                 │ ANALYTICAL    │
                 │     LAYER     │
                 │               │
                 │ Dimensions    │
                 │ Facts         │
                 │ Business      │
                 │ Metrics       │
                 └───────┬───────┘
                         │
                         ▼
                  Analytics / BI
                     Power BI
```

---

# 🥉 Bronze Layer

The Bronze layer acts as the **raw ingestion layer**.

Source CSV files are loaded into SQL Server tables while preserving the original source structure as much as possible.

### Source datasets

* Customers
* Products
* Stores
* Sales
* Exchange Rates

### Bronze ingestion process

The project uses a stored procedure:

```sql
Bronze.Load_Bronze
```

The procedure:

1. Truncates the existing Bronze table.
2. Loads the corresponding CSV file using `BULK INSERT`.
3. Uses UTF-8 encoding.
4. Handles semicolon-delimited source files.
5. Uses CSV quoting for the Products file.
6. Records load duration through `PRINT` statements.
7. Uses `TRY...CATCH` for error reporting.

The Bronze procedure uses UTF-8 `CODEPAGE = '65001'` and semicolon field delimiters for the source files.

### Example

```sql
BULK INSERT Bronze.Customers
FROM '...\Customers.csv'
WITH
(
    FIRSTROW = 2,
    FIELDTERMINATOR = ';',
    ROWTERMINATOR = '\n',
    CODEPAGE = '65001',
    TABLOCK
);
```

This approach allows the raw source data to be loaded before applying business transformations.

---

# 🥈 Silver Layer

The Silver layer is responsible for converting raw source data into **cleaned and standardized datasets**.

The transformation process focuses on improving data quality while maintaining the business meaning of the source data.

### Key transformations

#### Data Cleaning

* Removed leading and trailing whitespace using `TRIM()`.
* Standardized inconsistent text casing.
* Standardized state and currency codes.
* Preserved alphanumeric postal codes.
* Converted source values into appropriate SQL Server data types.
* Handled invalid or missing values.
* Validated date fields.

#### Character and Encoding Cleanup

The project contains international customer and geographic data where encoding inconsistencies can occur.

Examples of corrupted values identified during profiling included:

```text
╬le-de-France
Midi-PyrΘnΘes
Rh⌠ne-Alpes
```

These were investigated and corrected to their intended Unicode representations:

```text
Île-de-France
Midi-Pyrénées
Rhône-Alpes
```

The same data-quality approach can be applied to city, customer-name, and other international text attributes.

---

## Customer Data Standardization

Customer attributes were cleaned and standardized, including:

* Customer key validation
* Name standardization
* City standardization
* State/state-code standardization
* Postal-code trimming
* Country and continent standardization
* Birthday validation

The source `CustomerKey` is preserved as the customer identifier because the source dataset does not provide a separate `Customer_ID`.

The project also validates customer-key uniqueness and NULL conditions before using the key downstream.

---

## Name Standardization

Customer names can contain inconsistent casing and punctuation.

Examples:

```text
ISABELLA HOBBS
Isabella hobbs
isabella hobbs
```

can be standardized toward:

```text
Isabella Hobbs
```

Names containing apostrophes such as:

```text
NICHOLAS O'NEILL
```

require special handling so that the apostrophe is preserved correctly.

---

## Geographic Data Cleaning

Geographic attributes are preserved as separate fields:

```text
City
State_Code
State
Country
Continent
Zip_Code
```

The project distinguishes between:

* Formatting problems
* Encoding corruption
* Legitimate international characters
* Actual geographic inconsistencies

For example, accented characters such as:

```text
Î
é
ô
ü
```

are legitimate Unicode characters and should not automatically be removed.

---

## Postal Code Handling

Postal codes are treated as **text rather than numeric values**.

This is important because international postal codes may contain:

* Letters
* Numbers
* Spaces
* Leading zeros

Examples:

```text
5751 BL
FK4 8UY
00123
```

Therefore, the pipeline avoids forcing postal codes into integer formats.

---

## Date Validation

Customer birthday and transaction dates are validated for:

* NULL values
* Future dates
* Suspicious historical dates
* Placeholder dates

Example validation:

```sql
SELECT *
FROM Bronze.Customers
WHERE Birthday > CAST(GETDATE() AS DATE);
```

---

# 🔄 Deduplication

Duplicate records are handled using SQL Server window functions.

`ROW_NUMBER()` is used to identify duplicate records within their business-key grain.

For example, customer records can be evaluated by:

```sql
ROW_NUMBER() OVER
(
    PARTITION BY CustomerKey
    ORDER BY Birthday DESC
)
```

Sales records can be evaluated using their transaction grain, such as:

```text
Order_Number + Line_Item
```

This allows the pipeline to retain a single valid record while identifying duplicate source records.

---

# 🥇 Gold Layer

The Gold layer contains the **analytics-ready dimensional model**.

The project uses a Star Schema-oriented structure consisting of dimensions and facts.

## Dimensions

### 1. Dim_Customers

Contains customer profile and geographic attributes.

```text
CustomerKey
Name
Birthday
Age
City
State
Country
Continent
```

Age is calculated dynamically from the customer's birthday.

---

### 2. Dim_Products

Contains product master data:

```text
ProductKey
Product_Name
Brand
Category
Subcategory
Unit_Cost_USD
Unit_Price_USD
```

The product dimension is sourced from the cleansed Silver product dataset.

---

### 3. Dim_Stores

Contains store-related attributes:

```text
StoreKey
Open_Date
Country
State
Square_Meters
```

The model also supports online stores where physical store size may be NULL.

---

### 4. Dim_Date

The Date Dimension provides calendar attributes derived from sales dates.

```text
Date_Key
Full_Date
Year
Quarter
Month
Month_Name
Week
Day
Day_of_Week
```

The `Date_Key` follows the common `YYYYMMDD` integer format.

Example:

```text
2016-01-01
      ↓
20160101
```

The Gold view derives these attributes using SQL Server date functions such as `YEAR()`, `MONTH()`, `DATEPART()`, `DATENAME()`, and `DAY()`.

---

# 📊 Fact Tables

## Fact_Sales

`Fact_Sales` represents the central transactional fact at the sales line-item level.

Key attributes include:

```text
Order_Number
Line_Item
Date_Key
CustomerKey
ProductKey
StoreKey
Quantity
Unit_Cost_USD
Unit_Price_USD
Exchange_Rate
Fulfillment_Status
```

The fact view calculates important financial measures:

```text
Total Revenue
Total Cost
Total Profit
```

The project calculates:

```text
Total_Revenue_USD
Total_Cost_USD
Total_Profit_USD
```

using quantity, unit price, and unit cost.

---

# 💱 Fact_Exchange_Rates

The Exchange Rate fact stores daily currency conversion information.

```text
Date_Key
Rate_Date
Currency_Code
Exchange_Rate
```

The date key uses the same `YYYYMMDD` convention as the Date Dimension.

---

# 💰 Currency Conversion

The Sales Fact integrates exchange rates using:

```text
Order Date
+
Currency Code
```

The join condition is:

```sql
ON S.Currency_Code = E.Currency_Code
AND S.Order_Date = E.Rate_Date
```

This is important because joining only by currency could produce multiple exchange-rate matches across different dates.

Using both date and currency constrains the relationship to the appropriate daily exchange rate.

The model also uses:

```sql
COALESCE(E.Exchange_Rate, 1.0)
```

to provide a fallback rate where an exchange-rate record is unavailable.

---

# ⭐ Star Schema

The Gold model can be represented conceptually as:

```text
                     Dim_Date
                         │
                         │
                         ▼
Dim_Customers ────── Fact_Sales ────── Dim_Products
                         │
                         │
                         ▼
                    Dim_Stores


                Fact_Exchange_Rates
                         │
                         │
                  Date + Currency
```

### Central Fact

```text
Fact_Sales
```

### Dimensions

```text
Dim_Customers
Dim_Products
Dim_Stores
Dim_Date
```

### Supporting Fact

```text
Fact_Exchange_Rates
```

---

# 🛠️ Technologies Used

| Technology       | Purpose                             |
| ---------------- | ----------------------------------- |
| SQL Server       | Data Warehouse Platform             |
| T-SQL            | ETL and Transformation              |
| SSMS             | Development and Database Management |
| BULK INSERT      | CSV Ingestion                       |
| CTEs             | Transformation Logic                |
| CASE             | Conditional Transformations         |
| STRING_SPLIT     | String Processing                   |
| TRIM             | Whitespace Standardization          |
| TRY_CAST         | Safe Data Type Conversion           |
| ROW_NUMBER       | Deduplication                       |
| Window Functions | Analytical/Data Quality Processing  |
| Star Schema      | Dimensional Modeling                |
| Power BI         | Downstream Analytics                |

---

# 📁 Repository Structure

```text
global-electronics-medallion-dw/
│
├── 01_DDL/
│   ├── 01_Bronze_Tables.sql
│   ├── 02_Silver_Tables.sql
│   └── 03_Gold_Views.sql
│
├── 02_ETL_Procedures/
│   ├── 01_Load_Bronze.sql
│   └── 02_Load_Silver_Layer.sql
│
├── 03_Analytics/
│   └── Business_KPI_Queries.sql
│
├── 04_Documentation/
│   ├── Architecture.png
│   └── Data_Model.png
│
└── README.md
```

### Current SQL files

```text
PROC_Load_Bronze.sql
PROC_Load_Silver_Layer.sql
DDL_Gold_Layer.sql
```

These can be renamed to follow the repository structure above.

---

# ▶️ How to Run the Project

## Step 1 — Create the Database

Create the SQL Server database:

```sql
CREATE DATABASE Global_Electronics_DW;
```

Then select the database:

```sql
USE Global_Electronics_DW;
GO
```

---

## Step 2 — Create Schemas

Create the Medallion schemas:

```sql
CREATE SCHEMA Bronze;
GO

CREATE SCHEMA Silver;
GO

CREATE SCHEMA Gold;
GO
```

---

## Step 3 — Create Bronze and Silver Tables

Run the Bronze and Silver table DDL scripts before executing the ETL procedures.

Expected tables:

```text
Bronze.Customers
Bronze.Products
Bronze.Stores
Bronze.Sales
Bronze.Exchange_Rates
```

and corresponding Silver tables.

---

## Step 4 — Configure Source File Paths

The Bronze loading procedure currently uses local Windows paths such as:

```text
D:\DataBricks\Global_Electronic_Retailers\Data\Customers.csv
```

Update these paths according to your local environment before executing the procedure.

For example:

```text
C:\Data\Global_Electronics\Customers.csv
```

## The current Bronze procedure contains local file paths for Customers, Exchange Rates, Products, Sales, and Stores.

## Step 5 — Load Bronze

Execute:

```sql
EXEC Bronze.Load_Bronze;
```

This loads the raw CSV datasets into the Bronze layer.

---

## Step 6 — Load Silver

Execute the Silver ETL procedure:

```sql
EXEC Silver.usp_Load_Silver_Layer;
```

This applies the cleansing, transformation, standardization, and deduplication logic.

---

## Step 7 — Create Gold Views

Run:

```text
DDL_Gold_Layer.sql
```

This creates:

```text
Gold.Dim_Customers
Gold.Dim_Products
Gold.Dim_Stores
Gold.Dim_Date
Gold.Fact_Exchange_Rates
Gold.Fact_Sales
```

---

# 🔎 Data Quality Checks

The project includes data-quality profiling and validation concepts such as:

### Duplicate Customer Keys

```sql
SELECT
    CustomerKey,
    COUNT(*) AS Record_Count
FROM Bronze.Customers
GROUP BY CustomerKey
HAVING COUNT(*) > 1;
```

### NULL Customer Keys

```sql
SELECT *
FROM Bronze.Customers
WHERE CustomerKey IS NULL;
```

### Future Birthdays

```sql
SELECT *
FROM Bronze.Customers
WHERE Birthday > CAST(GETDATE() AS DATE);
```

### Leading/Trailing Spaces

```sql
SELECT *
FROM Bronze.Customers
WHERE City <> TRIM(City);
```

### Suspicious Characters

```sql
SELECT DISTINCT City
FROM Bronze.Customers
WHERE City COLLATE Latin1_General_100_BIN2
      LIKE '%[^A-Za-z0-9 .''-]%';
```

These checks help identify source-data quality issues before the data reaches the analytical layer.

---

# 📈 Example Business Questions

The Gold layer can support questions such as:

### Sales Performance

* What is total revenue?
* What is total profit?
* Which products generate the highest revenue?
* Which stores have the highest sales?
* How does sales performance change over time?

### Customer Analytics

* Which countries generate the most customers?
* What is the customer distribution by continent?
* Which customer segments generate the highest revenue?
* How does customer age distribution vary?

### Product Analytics

* Which categories generate the highest revenue?
* Which brands have the highest profit?
* What products have the highest margins?

### Geographic Analytics

* Which countries generate the highest sales?
* Which states or regions contribute the most revenue?
* How does store performance vary by geography?

### Time-Based Analytics

* Which months have the highest sales?
* Which days of the week perform best?
* What are the quarterly revenue trends?
* How does profitability change over time?

### Currency Analytics

* How do exchange rates vary by currency?
* How does currency conversion affect international sales?
* What is the USD-equivalent revenue by country?

---

# 📊 Potential Power BI Dashboard

The Gold layer can be connected to Power BI to build dashboards such as:

```text
┌──────────────────────────────────────────────┐
│          GLOBAL ELECTRONICS SALES            │
├────────────┬────────────┬────────────────────┤
│ Revenue    │ Profit     │ Orders             │
├────────────┴────────────┴────────────────────┤
│                                              │
│ Revenue Trend Over Time                      │
│                                              │
├─────────────────────┬────────────────────────┤
│ Sales by Country    │ Sales by Category      │
│                     │                        │
├─────────────────────┴────────────────────────┤
│ Top Products / Brands                        │
│                                              │
└──────────────────────────────────────────────┘
```

---

# 🚀 Key Engineering Concepts Demonstrated

This project demonstrates practical understanding of:

* Medallion Architecture
* ETL Development
* SQL Server
* T-SQL
* Data Profiling
* Data Quality
* Data Cleansing
* String Standardization
* Unicode/Encoding Handling
* Data Type Conversion
* Deduplication
* Window Functions
* CTEs
* Conditional Transformations
* Transactional ETL
* Error Handling
* Dimensional Modeling
* Star Schema
* Fact Tables
* Dimension Tables
* Date Dimensions
* Currency Conversion
* Analytical SQL

---

# 🧠 Key Design Decisions

### Why Bronze?

To preserve the raw source data before transformation.

### Why Silver?

To separate data-quality and transformation logic from analytical modeling.

### Why Gold?

To provide business-friendly, analytics-ready datasets.

### Why Star Schema?

To simplify analytical queries and provide clear relationships between business dimensions and transactional facts.

### Why `YYYYMMDD` Date Keys?

The integer format:

```text
YYYYMMDD
```

is compact, readable, and commonly used for dimensional date keys.

### Why preserve postal codes as text?

Because international postal codes can contain letters, spaces, and leading zeros.

### Why use composite date + currency matching?

To ensure an exchange rate is associated with the correct transaction date and currency and to reduce the risk of duplicate matches.

---

# ⚠️ Project Considerations

This project is designed as a **portfolio Data Engineering implementation** and can be further enhanced for production environments.

Potential future improvements include:

* Parameterizing source file paths
* Implementing incremental loading instead of full refreshes
* Adding centralized ETL logging tables
* Adding automated data-quality audit tables
* Creating a fully contiguous Date Dimension
* Adding Slowly Changing Dimension Type 2 logic
* Adding orchestration using Azure Data Factory or Databricks
* Moving source files to cloud object storage such as Azure Data Lake or Amazon S3
* Implementing automated CI/CD deployment
* Adding automated testing and validation
* Adding source-to-target reconciliation checks

---

# 🔮 Future Roadmap

## Phase 1 — SQL Data Warehouse

```text
Bronze
  ↓
Silver
  ↓
Gold
  ↓
Power BI
```

## Phase 2 — Analytics Engineering

Add:

* Business KPI SQL models
* Analytical views
* Customer segmentation
* Revenue analysis
* Profitability analysis
* Cohort analysis
* Contribution analysis
* Pareto analysis

## Phase 3 — Cloud Data Engineering

Potential migration to:

```text
CSV / Source Systems
        ↓
Cloud Storage
        ↓
Databricks / Spark
        ↓
Delta Lake
        ↓
Gold Analytics
        ↓
Power BI
```

---

# 👨‍💻 Skills Demonstrated

**SQL & Database**

* SQL Server
* T-SQL
* Joins
* CTEs
* Subqueries
* Window Functions
* Aggregations
* CASE expressions
* Date Functions
* String Functions

**Data Engineering**

* ETL
* Medallion Architecture
* Data Quality
* Data Cleansing
* Deduplication
* Dimensional Modeling
* Star Schema
* Fact & Dimension Design

**Analytics**

* Revenue Analysis
* Cost Analysis
* Profit Analysis
* Customer Analysis
* Product Analysis
* Geographic Analysis
* Time-Series Analysis
* Currency Analysis

---

# 📌 Project Status

**Current Status:** Core SQL Server Medallion Data Warehouse implemented.

### Completed

* [x] Bronze raw ingestion
* [x] Customer data cleansing
* [x] Product data cleansing
* [x] Store data cleansing
* [x] Sales data transformation
* [x] Exchange-rate processing
* [x] Data standardization
* [x] Deduplication
* [x] Data-quality validation
* [x] Gold dimensions
* [x] Gold facts
* [x] Revenue calculation
* [x] Cost calculation
* [x] Profit calculation
* [x] Currency-rate integration
* [x] Star Schema-oriented analytical model

### Planned Enhancements

* [ ] Fully contiguous calendar dimension
* [ ] Incremental loading
* [ ] Centralized ETL logging
* [ ] Automated data-quality framework
* [ ] Cloud-based ingestion
* [ ] Orchestration
* [ ] CI/CD
* [ ] Power BI analytics layer

---

# 📄 SQL Scripts

The repository contains the core SQL implementation for:

```text
01_DDL/
    Bronze table definitions
    Silver table definitions
    Gold analytical views

02_ETL_Procedures/
    Bronze ingestion procedure
    Silver transformation procedure

03_Analytics/
    Business KPI queries
```

---

# 🎯 Portfolio Objective

This project demonstrates the complete lifecycle of transforming raw retail data into an analytics-ready data warehouse using SQL Server.

The primary focus is on:

```text
Raw Data
   ↓
Reliable Ingestion
   ↓
Data Quality
   ↓
Transformation
   ↓
Deduplication
   ↓
Dimensional Modeling
   ↓
Business Metrics
   ↓
Analytics
```

It serves as a practical demonstration of SQL-based Data Engineering and provides a foundation for extending the solution into modern cloud-based platforms such as **Databricks, Azure Data Lake, Amazon S3, and Power BI**.

---

## Author

**Ismail Hamdan**

Data Engineering | SQL Server | T-SQL | Python | PySpark | Databricks

LinkedIn: https://www.linkedin.com/in/ismailnhamdan?utm_source=share_via&utm_content=profile&utm_medium=member_android

GitHub: https://github.com/IsmailHamdan-007/

---

## ⭐ If you find this project useful

Feel free to explore the SQL scripts, review the transformation logic, and use the architecture as a reference for building your own Data Warehouse projects.
