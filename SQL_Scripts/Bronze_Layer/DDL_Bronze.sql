-- =============================================================================
--                 DDL: CREATE TABLES FOR BRONZE LAYER
-- =============================================================================

-- Bronze.Customers
IF OBJECT_ID('Bronze.Customers', 'U') IS NOT NULL
    DROP TABLE Bronze.Customers;

CREATE TABLE Bronze.Customers (
    CustomerKey INT,
    Gender NVARCHAR(100),
    Name NVARCHAR(100),  
    City NVARCHAR(100),
    State_Code NVARCHAR(100),
    State NVARCHAR(100), 
    Zip_Code NVARCHAR(100), 
    Country NVARCHAR(100),
    Continent NVARCHAR(100), 
    Birthday DATE
);

-- Bronze.Exchange_Rates
IF OBJECT_ID('Bronze.Exchange_Rates', 'U') IS NOT NULL
    DROP TABLE Bronze.Exchange_Rates;

CREATE TABLE Bronze.Exchange_Rates (
    Date DATE,   
    Currency NVARCHAR(100),
    Exchange DECIMAL(10,2)
);

-- Bronze.Products
IF OBJECT_ID('Bronze.Products', 'U') IS NOT NULL
    DROP TABLE Bronze.Products;

CREATE TABLE Bronze.Products (
    ProductKey INT,
    Product_Name NVARCHAR(500),
    Brand NVARCHAR(50),
    Color NVARCHAR(50),  
    Unit_Cost_USD NVARCHAR(50), 
    Unit_Price_USD NVARCHAR(50),    
    SubcategoryKey INT,
    Subcategory NVARCHAR(50),
    CategoryKey INT,
    Category NVARCHAR(50)
);

-- Bronze.Sales
IF OBJECT_ID('Bronze.Sales', 'U') IS NOT NULL
    DROP TABLE Bronze.Sales;

CREATE TABLE Bronze.Sales ( 
    Order_Number NVARCHAR(50),
    Line_Item INT,
    Order_Date DATE,
    Delivery_Date DATE,
    CustomerKey INT,
    StoreKey INT,
    ProductKey INT,
    Quantity INT,
    Currency_Code NVARCHAR(50)
);

-- Bronze.Stores
IF OBJECT_ID('Bronze.Stores', 'U') IS NOT NULL
    DROP TABLE Bronze.Stores;

CREATE TABLE Bronze.Stores (
    StoreKey INT,   
    Country NVARCHAR(50),
    State NVARCHAR(50),
    Square_Meters INT,
    Open_Date DATE
);
GO





















