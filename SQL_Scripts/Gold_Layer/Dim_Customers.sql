USE Global_Electronics_DW;

SELECT * FROM Silver.Customers;

CREATE OR ALTER VIEW Gold.Dim_Customers AS
SELECT
    CustomerKey,
    Name,
    Birthday,
    DATEDIFF(YEAR, CAST(Birthday AS DATE), GETDATE()) 
      - CASE 
            WHEN DATEADD(YEAR, DATEDIFF(YEAR, CAST(Birthday AS DATE), GETDATE()), CAST(Birthday AS DATE)) > GETDATE() 
            THEN 1 
            ELSE 0 
        END AS Age,
    City,
    State,
    Country,
    Continent
FROM Silver.Customers;

SELECT * FROM Gold.Dim_Customers;


