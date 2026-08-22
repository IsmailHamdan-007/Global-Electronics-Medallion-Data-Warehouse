# Global Electronics Medallion Data Warehouse

**End-to-End SQL Server Data Warehouse | T-SQL | Medallion Architecture | Star Schema**

An enterprise-grade **Medallion Data Warehouse** built on Microsoft SQL Server using T-SQL. This project transforms multi-source, multi-currency retail CSV datasets into clean, standardized, and analytics-ready dimensional models.

---

## 📌 Executive Summary

This project implements a complete Data Engineering lifecycle: raw data ingestion into a **Bronze** staging area, idempotent data quality transformations in **Silver**, and Kimball Star Schema dimensional modeling in **Gold**. 

### Core Capabilities
* **Data Quality Engineering:** Advanced string parsing, special character encoding fixes (`Île-de-France`), sanitization of currency strings (`$`, `,`), and composite key deduplication.
* **Idempotent Pipelines:** Fully transactional stored procedures featuring automated logging, execution tracking, and `TRY...CATCH` rollback handling.
* **Dimensional Modeling:** Gold Star Schema (`Fact_Sales`, 4 Dimensions, `Fact_Exchange_Rates`) with pre-calculated revenue, cost, and profit metrics in base USD.
* **Fan-Out Prevention:** Integrated multi-currency rates using composite date-currency join conditions (`Order_Date` + `Currency_Code`).

---

## 🏗️ Architecture & Data Flow

text
               CSV Source Files
  (Customers, Products, Stores, Sales, Exchange Rates)
                       │
                       ▼
            ┌─────────────────────┐
            │   BRONZE LAYER      │  • BULK INSERT / UTF-8
            │   Raw Staging       │  • Minimal Modifications
            └──────────┬──────────┘
                       │
                       │ T-SQL Stored Procedure
                       ▼
            ┌─────────────────────┐
            │   SILVER LAYER      │  • Data Cleansing & Deduplication
            │   Cleansed & Enriched   │  • Encoding Repairs & Types
            └──────────┬──────────┘
                       │
                       │ Gold Views / Star Schema
                       ▼
            ┌─────────────────────┐
            │    GOLD LAYER       │  • Fact & Dimension Views
            │   Analytics Ready   │  • Pre-Calculated Metrics
            └──────────┬──────────┘
                       │
                       ▼
            Downstream BI / Power BI
---

## 🥉 Layer Breakdown

### 🥉 Bronze Layer (Raw Ingestion)

Preserves source data structures with zero business logic applying fast ingestion mechanisms.

* **Ingestion:** High-performance `BULK INSERT` configured for UTF-8 (`CODEPAGE = '65001'`), semicolon delimiters (`FIELDTERMINATOR = ';'`), and quote parsing.
* **Error Control:** Encapsulated in `Bronze.Load_Bronze` with `TRY...CATCH` exception logging and performance duration metrics.

### 🥈 Silver Layer (Cleansing & Transformation)

Managed via `Silver.usp_Load_Silver_Layer`, executing comprehensive data quality operations:

* **String Parsing & Standardization:** Standardizes names/cities to Title Case using `STRING_SPLIT` and trims whitespace via `TRIM()`.
* **Encoding & Special Characters:** Replaces corrupted multi-byte characters with accurate Unicode (e.g., `╬le-de-France` $\rightarrow$ `Île-de-France`, `Midi-PyrΘnΘes` $\rightarrow$ `Midi-Pyrénées`).
* **Currency Sanitization:** Removes non-numeric symbols (`$`, `,`) and applies safe casting using `TRY_CAST(... AS DECIMAL(10,2))`.
* **Lead Time Calculations:** Computes `Delivery_Days` (`Delivery_Date - Order_Date`) and assigns `Fulfillment_Status` (`Delivered` vs. `In-Transit / Pending`).
* **Deduplication:** Applies `ROW_NUMBER() OVER (PARTITION BY ...)` across primary/composite business keys.
* **Postal Code Integrity:** Preserved strictly as alphanumeric strings to keep international formats, spaces, and leading zeros.

### 🥇 Gold Layer (Dimensional Model)

Exposes business-friendly views structured as a classic Kimball Star Schema.

                  Gold.Dim_Date
                        │
                        ▼
Gold.Dim_Customers ──► Gold.Fact_Sales ◄── Gold.Dim_Products
                        ▲
                        │
                  Gold.Dim_Stores

             Gold.Fact_Exchange_Rates

#### Dimensions & Facts Summary

* **`Gold.Dim_Customers`**: Profile metadata including dynamic age computation (`DATEDIFF`).
* **`Gold.Dim_Products`**: Master catalog including product categories, subcategories, cost, and pricing.
* **`Gold.Dim_Stores`**: Physical footprint metadata including state, country, and footprint size in square meters.
* **`Gold.Dim_Date`**: Conformed date dimension with `YYYYMMDD` integer primary keys (`Date_Key`).
* **`Gold.Fact_Exchange_Rates`**: Auxiliary daily currency exchange rates for dynamic multi-currency analytics.
* **`Gold.Fact_Sales`**: Central fact table at line-item grain containing pre-computed metrics:

$$\text{Total Revenue USD} = \text{Quantity} \times \text{Unit Price USD}$$


$$\text{Total Cost USD} = \text{Quantity} \times \text{Unit Cost USD}$$


$$\text{Total Profit USD} = \text{Total Revenue USD} - \text{Total Cost USD}$$



---

## 🛠️ Technologies Used

| Category | Tools & Techniques |
| --- | --- |
| **Platform** | Microsoft SQL Server, SSMS |
| **Language** | T-SQL |
| **Ingestion** | `BULK INSERT`, UTF-8 Codepage 65001 |
| **Transformation** | CTEs, `TRY_CAST`, `STRING_SPLIT`, `TRIM`, `DATEDIFF`, `CASE` |
| **Data Quality** | Window Functions (`ROW_NUMBER`), Unicode character repair |
| **Architecture** | Medallion (Bronze/Silver/Gold), Kimball Star Schema |
| **Pipeline Control** | Idempotent Stored Procedures, `BEGIN TRAN` / `COMMIT` / `ROLLBACK`, `TRY...CATCH` |

---

## 📁 Repository Structure

global-electronics-medallion-dw/
│
├── 01_DDL/
│   ├── 01_Bronze_Tables.sql       # Bronze staging tables
│   ├── 02_Silver_Tables.sql       # Cleansed Silver tables
│   └── 03_Gold_Views.sql          # Gold Fact and Dimension views
│
├── 02_ETL_Procedures/
│   ├── 01_Load_Bronze.sql         # Bulk ingestion procedure
│   └── 02_Load_Silver_Layer.sql   # Complete Silver ETL procedure
│
├── 03_Analytics/
│   └── Business_KPI_Queries.sql   # Analytics engineering queries
│
├── 04_Documentation/
│   ├── Architecture.png           # Architecture diagram
│   └── Data_Model.png             # ERD / Star schema diagram
│
└── README.md                      # Project documentation

---

## 🚀 Execution Guide

### 1. Database Setup

CREATE DATABASE Global_Electronics_DW;
GO
USE Global_Electronics_DW;
GO

CREATE SCHEMA Bronze; GO
CREATE SCHEMA Silver; GO
CREATE SCHEMA Gold;   GO

```

### 2. Execute DDL Scripts

Run `01_Bronze_Tables.sql` and `02_Silver_Tables.sql` to generate base table structures.

### 3. Load Layers

```sql
-- Step A: Ingest Raw Data into Bronze
EXEC Bronze.Load_Bronze;

-- Step B: Cleanse and Transform into Silver
EXEC Silver.usp_Load_Silver_Layer;

-- Step C: Create Gold Analytical Layer
-- Execute 03_Gold_Views.sql

---

## 📈 Supported Business Analytics

* **Financial Metrics:** Revenue, Cost, and Profit Margins aggregated by Product, Brand, Category, and Store.
* **Geographic Trends:** Regional store efficiency (Revenue per Square Meter) and international customer distribution.
* **Customer Demographics:** Lifetime Value (LTV), age cohort performance, and Pareto (80/20) segmentation.
* **Time-Series Analysis:** Month-over-Month (MoM) growth and Year-to-Date (YTD) cumulative revenue tracking.
* **Multi-Currency Analytics:** Dynamic dynamic conversion using `Fact_Exchange_Rates` for local currency reporting.

---

## 🔮 Future Enhancements

* Implement incremental loading using CDC or Delta `MERGE` statements.
* Add automated Data Quality Audit logging tables.
* Migrate processing pipeline to Databricks / PySpark and Delta Lake.
* Connect Gold models directly to an interactive Power BI dashboard.

---

## 👨‍💻 Author

Ismail Hamdan

Aspiring Data Engineer

LinkedIn: https://www.linkedin.com/in/ismailnhamdan?utm_source=share_via&utm_content=profile&utm_medium=member_android

GitHub: https://github.com/IsmailHamdan-007/

