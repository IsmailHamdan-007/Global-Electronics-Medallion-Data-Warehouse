USE Global_Electronics_DW;

SELECT * FROM Silver.Stores;

CREATE VIEW Gold.Dim_Stores AS(
SELECT
	StoreKey,
	Open_Date,
	Country, 
	State, 
	Square_Meters
FROM Silver.Stores);

SELECT * FROM Gold.Dim_Stores;






