USE Global_Electronics_DW;
GO

CREATE OR ALTER VIEW Gold.Fact_Exchange_Rates AS
SELECT 
    CONVERT(INT, CONVERT(CHAR(8), CAST(Rate_Date AS DATE), 112)) AS Date_Key,
    CAST(Rate_Date AS DATE) AS Rate_Date,
    Currency_Code,
    Exchange_Rate
FROM Silver.Exchange_Rates;
GO

SELECT * FROM Gold.Fact_Exchange_Rates;