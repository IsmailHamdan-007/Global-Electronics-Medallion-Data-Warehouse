USE Global_Electronics_DW;
GO

-- =============================================================================
--                 DDL: CREATE TABLES FOR SILVER LAYER
-- =============================================================================

-- 1. Silver.Customers
IF OBJECT_ID('Silver.Customers', 'U') IS NOT NULL
    DROP TABLE Silver.Customers;

CREATE TABLE Silver.Customers (
    CustomerKey INT,
    Gender NVARCHAR(100),
    Name NVARCHAR(100),  
    City NVARCHAR(100),
    State_Code NVARCHAR(100),
    State NVARCHAR(100), 
    Zip_Code NVARCHAR(100), 
    Country NVARCHAR(100),
    Continent NVARCHAR(100), 
	Age INT,
    Birthday DATE,
    DWH_Create_Date DATETIME2 DEFAULT GETDATE()
);

-- 2. Silver.Exchange_Rates
IF OBJECT_ID('Silver.Exchange_Rates', 'U') IS NOT NULL
    DROP TABLE Silver.Exchange_Rates;

CREATE TABLE Silver.Exchange_Rates (
    Rate_Date DATE,   
    Currency_Code NVARCHAR(100),
    Exchange_Rate DECIMAL(18, 4),
    DWH_Create_Date DATETIME2 DEFAULT GETDATE()
);

-- 3. Silver.Products
IF OBJECT_ID('Silver.Products', 'U') IS NOT NULL
    DROP TABLE Silver.Products;

CREATE TABLE Silver.Products (
    ProductKey INT,
    Product_Name NVARCHAR(500),
    Brand NVARCHAR(50),
    Color NVARCHAR(50),  
    Unit_Cost_USD DECIMAL(18, 2), 
    Unit_Price_USD DECIMAL(18, 2),    
    SubcategoryKey INT,
    Subcategory NVARCHAR(50),
    CategoryKey INT,
    Category NVARCHAR(50),
    DWH_Create_Date DATETIME2 DEFAULT GETDATE()
);

-- 4. Silver.Sales
IF OBJECT_ID('Silver.Sales', 'U') IS NOT NULL
    DROP TABLE Silver.Sales;

CREATE TABLE Silver.Sales ( 
    Order_Number INT,
    Line_Item INT,
    CustomerKey INT,
    StoreKey INT,
    ProductKey INT,
    Order_Date DATE,
    Delivery_Date DATE,
    Quantity INT,
    Currency_Code NVARCHAR(50),
    Delivery_Days INT,
    Fulfillment_Status NVARCHAR(100),
    DWH_Create_Date DATETIME2 DEFAULT GETDATE()
);

-- 5. Silver.Stores
IF OBJECT_ID('Silver.Stores', 'U') IS NOT NULL
    DROP TABLE Silver.Stores;

CREATE TABLE Silver.Stores (
    StoreKey INT,   
    Country NVARCHAR(50),
    State NVARCHAR(50),
    Square_Meters INT,
    Open_Date DATE,
    DWH_Create_Date DATETIME2 DEFAULT GETDATE()
);
GO