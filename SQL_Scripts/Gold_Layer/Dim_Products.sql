USE Global_Electronics_DW;

SELECT * FROM Silver.Products;

CREATE OR ALTER VIEW Gold.Dim_Products AS
SELECT
    ProductKey, 
    Product_Name, 
    Brand, 
    Category,
    Subcategory,
    Unit_Cost_USD, 
    Unit_Price_USD
FROM Silver.Products;
GO

SELECT * FROM Gold.Dim_Products;

SELECT * FROM Silver.Exchange_Rates;