
--Cleaning the weekly sales table

CREATE TABLE data_mart.clean_weekly_sales AS
SELECT
  -- 1. Convert week_date to a DATE format
  TO_DATE(week_date, 'DD/MM/YY') AS week_date,
  
  -- 2. Add a week_number
  EXTRACT(WEEK FROM TO_DATE(week_date, 'DD/MM/YY')) AS week_number,
  
  -- 3. Add a month_number
  EXTRACT(MONTH FROM TO_DATE(week_date, 'DD/MM/YY')) AS month_number,
  
  -- 4. Add a calendar_year
  EXTRACT(YEAR FROM TO_DATE(week_date, 'DD/MM/YY')) AS calendar_year,
  
  region,
  platform,
  
  -- 7. Ensure nulls in segment are replaced with 'Unknown'
  CASE
    WHEN segment = 'null' OR segment IS NULL THEN 'Unknown'
    ELSE segment
  END AS segment,
  
  -- 5. Add age_band column
  CASE
    WHEN segment LIKE '%1' THEN 'Young Adults'
    WHEN segment LIKE '%2' THEN 'Middle Aged'
    WHEN segment LIKE '%3' OR segment LIKE '%4' THEN 'Retirees'
    ELSE 'Unknown'
  END AS age_band,
  
  -- 6. Add demographic column
  CASE
    WHEN segment LIKE 'C%' THEN 'Couples'
    WHEN segment LIKE 'F%' THEN 'Families'
    ELSE 'Unknown'
  END AS demographic,
  
  customer_type,
  transactions,
  sales,
  
  -- 8. Generate avg_transaction column
  ROUND(sales::NUMERIC / transactions, 2) AS avg_transaction
FROM
  data_mart.weekly_sales;

-- You can verify the new table with a simple SELECT statement
SELECT * FROM data_mart.clean_weekly_sales 
LIMIT 10;

--Data Exploration

--1.What day of the week is used for each week_date value?
SELECT DISTINCT
  TO_CHAR(week_date, 'Day') AS day_of_week
FROM
  data_mart.clean_weekly_sales;
--2.What range of week numbers are missing from the dataset?
-- First, create a CTE that generates a series of all 52 weeks
WITH all_weeks AS (
  SELECT generate_series(1, 52) AS week_num
)

-- Then, select the weeks from that series which are NOT IN our sales data
SELECT 
  week_num AS missing_week_number
FROM 
  all_weeks
WHERE 
  week_num NOT IN (
    SELECT DISTINCT week_number 
    FROM data_mart.clean_weekly_sales
  );
--3.How many total transactions were there for each year in the dataset?
SELECT
  calendar_year,
  SUM(transactions) AS total_transactions
FROM
  data_mart.clean_weekly_sales
GROUP BY
  calendar_year
ORDER BY
  calendar_year;
--4.What is the total sales for each region for each month?
SELECT
  region,
  month_number,
  SUM(sales) AS total_sales
FROM
  data_mart.clean_weekly_sales
GROUP BY
  region,
  month_number
ORDER BY
  region,
  month_number;
--5.What is the total count of transactions for each platform?
SELECT
  platform,
  SUM(transactions) AS total_transactions
FROM
  data_mart.clean_weekly_sales
GROUP BY
  platform
ORDER BY
  platform;
--6.What is the percentage of sales for Retail vs Shopify for each month?
WITH monthly_platform_sales AS (
  SELECT
    month_number,
    platform,
    SUM(sales) AS platform_sales
  FROM
    data_mart.clean_weekly_sales
  GROUP BY
    month_number,
    platform
)

SELECT
  month_number,
  platform,
  ROUND(
    (platform_sales * 100.0) / SUM(platform_sales) OVER (PARTITION BY month_number),
    2
  ) AS sales_percentage
FROM
  monthly_platform_sales
ORDER BY
  month_number,
  platform;
--7.What is the percentage of sales by demographic for each year in the dataset?
WITH yearly_demographic_sales AS (
  SELECT
    calendar_year,
    demographic,
    SUM(sales) AS demographic_sales
  FROM
    data_mart.clean_weekly_sales
  GROUP BY
    calendar_year,
    demographic
)

SELECT
  calendar_year,
  demographic,
  ROUND(
    (demographic_sales * 100.0) / SUM(demographic_sales) OVER (PARTITION BY calendar_year),
    2
  ) AS sales_percentage
FROM
  yearly_demographic_sales
ORDER BY
  calendar_year,
  demographic;
--8.Which age_band and demographic values contribute the most to Retail sales?
SELECT
  age_band,
  demographic,
  SUM(sales) AS total_retail_sales
FROM
  data_mart.clean_weekly_sales
WHERE
  platform = 'Retail'
GROUP BY
  age_band,
  demographic
ORDER BY
  total_retail_sales DESC;
--9.Can we use the avg_transaction column to find the average transaction size for each year for Retail vs Shopify? If not - how would you calculate it instead?
SELECT
  calendar_year,
  platform,
  ROUND(AVG(avg_transaction), 2) AS incorrect_average,
  ROUND(SUM(sales)::NUMERIC / SUM(transactions), 2) AS correct_average
FROM
  data_mart.clean_weekly_sales
GROUP BY
  calendar_year,
  platform
ORDER BY
  calendar_year,
  platform;

--C. Before & After Analysis


--1.What is the total sales for the 4 weeks before and after 2020-06-15? What is the growth or reduction rate in actual values and percentage of sales?
WITH date_details AS (
  -- Find the baseline week number for the event date
  SELECT 
    DISTINCT week_number
  FROM data_mart.clean_weekly_sales
  WHERE week_date = '2020-06-15'
),

sales_comparison AS (
  -- Calculate total sales in the 4 weeks before and after
  SELECT
    SUM(CASE 
          WHEN cs.week_number BETWEEN dd.week_number - 4 AND dd.week_number - 1 THEN cs.sales
          ELSE 0 
        END) AS before_change_sales,
    SUM(CASE 
          WHEN cs.week_number BETWEEN dd.week_number AND dd.week_number + 3 THEN cs.sales
          ELSE 0 
        END) AS after_change_sales
  FROM data_mart.clean_weekly_sales AS cs
  CROSS JOIN date_details AS dd
  WHERE cs.calendar_year = 2020
)

-- Calculate the final growth and percentage metrics
SELECT
  before_change_sales,
  after_change_sales,
  (after_change_sales - before_change_sales) AS sales_difference,
  ROUND(
    (after_change_sales - before_change_sales)::NUMERIC * 100 / before_change_sales, 
    2
  ) AS percentage_change
FROM sales_comparison;


--2.What about the entire 12 weeks before and after?
WITH date_details AS (
  -- Find the baseline week number for the event date
  SELECT 
    DISTINCT week_number
  FROM data_mart.clean_weekly_sales
  WHERE week_date = '2020-06-15'
),

sales_comparison AS (
  -- Calculate total sales in the 12 weeks before and after
  SELECT
    SUM(CASE 
          WHEN cs.week_number BETWEEN dd.week_number - 12 AND dd.week_number - 1 THEN cs.sales
          ELSE 0 
        END) AS before_change_sales,
    SUM(CASE 
          WHEN cs.week_number BETWEEN dd.week_number AND dd.week_number + 11 THEN cs.sales
          ELSE 0 
        END) AS after_change_sales
  FROM data_mart.clean_weekly_sales AS cs
  CROSS JOIN date_details AS dd
  WHERE cs.calendar_year = 2020
)

-- Calculate the final growth and percentage metrics
SELECT
  before_change_sales,
  after_change_sales,
  (after_change_sales - before_change_sales) AS sales_difference,
  ROUND(
    (after_change_sales - before_change_sales)::NUMERIC * 100 / before_change_sales, 
    2
  ) AS percentage_change
FROM sales_comparison;
--3.How do the sale metrics for these 2 periods before and after compare with the previous years in 2018 and 2019?
WITH yearly_comparison AS (
  SELECT
    calendar_year,
    -- 4-Week SUMS (Weeks 21-24 vs 25-28)
    SUM(CASE WHEN week_number BETWEEN 21 AND 24 THEN sales ELSE 0 END) AS sales_4wk_before,
    SUM(CASE WHEN week_number BETWEEN 25 AND 28 THEN sales ELSE 0 END) AS sales_4wk_after,
    
    -- 12-Week SUMS (Weeks 13-24 vs 25-36)
    SUM(CASE WHEN week_number BETWEEN 13 AND 24 THEN sales ELSE 0 END) AS sales_12wk_before,
    SUM(CASE WHEN week_number BETWEEN 25 AND 36 THEN sales ELSE 0 END) AS sales_12wk_after
  FROM
    data_mart.clean_weekly_sales
  GROUP BY
    calendar_year
)
SELECT
  calendar_year,
  -- 4-Week Percentage Change
  CONCAT(
    ROUND((sales_4wk_after - sales_4wk_before)::NUMERIC / sales_4wk_before * 100, 2),
    '%'
  ) AS pct_change_4wk,
  
  -- 12-Week Percentage Change
  CONCAT(
    ROUND((sales_12wk_after - sales_12wk_before)::NUMERIC / sales_12wk_before * 100, 2),
    '%'
  ) AS pct_change_12wk
FROM
  yearly_comparison
ORDER BY
  calendar_year;



  --Bonus Question

  --Region Analysis
  WITH sales_comparison AS (
  SELECT
    region,
    SUM(CASE WHEN week_number BETWEEN 13 AND 24 THEN sales ELSE 0 END) AS before_sales,
    SUM(CASE WHEN week_number BETWEEN 25 AND 36 THEN sales ELSE 0 END) AS after_sales
  FROM data_mart.clean_weekly_sales
  WHERE calendar_year = 2020
  GROUP BY region
)
SELECT
  region,
  ROUND((after_sales - before_sales)::NUMERIC / before_sales * 100, 2) AS percentage_change
FROM sales_comparison
WHERE before_sales > 0
ORDER BY percentage_change ASC;


--Platform Analyis
-- Query is the same as above, just replacing 'region' with 'platform'
WITH sales_comparison AS (
  SELECT
    platform,
    SUM(CASE WHEN week_number BETWEEN 13 AND 24 THEN sales ELSE 0 END) AS before_sales,
    SUM(CASE WHEN week_number BETWEEN 25 AND 36 THEN sales ELSE 0 END) AS after_sales
  FROM data_mart.clean_weekly_sales
  WHERE calendar_year = 2020
  GROUP BY platform
)
SELECT
  platform,
  ROUND((after_sales - before_sales)::NUMERIC / before_sales * 100, 2) AS percentage_change
FROM sales_comparison
WHERE before_sales > 0
ORDER BY percentage_change ASC;


--Age Band
WITH sales_comparison AS (
  SELECT
    age_band,
    SUM(CASE WHEN week_number BETWEEN 13 AND 24 THEN sales ELSE 0 END) AS before_sales,
    SUM(CASE WHEN week_number BETWEEN 25 AND 36 THEN sales ELSE 0 END) AS after_sales
  FROM
    data_mart.clean_weekly_sales
  WHERE
    calendar_year = 2020
  GROUP BY
    age_band
)
SELECT
  age_band,
  ROUND((after_sales - before_sales)::NUMERIC / before_sales * 100, 2) AS percentage_change
FROM
  sales_comparison
WHERE
  before_sales > 0
ORDER BY
  percentage_change ASC;


--Demographic Query
WITH sales_comparison AS (
  SELECT
    demographic,
    SUM(CASE WHEN week_number BETWEEN 13 AND 24 THEN sales ELSE 0 END) AS before_sales,
    SUM(CASE WHEN week_number BETWEEN 25 AND 36 THEN sales ELSE 0 END) AS after_sales
  FROM
    data_mart.clean_weekly_sales
  WHERE
    calendar_year = 2020
  GROUP BY
    demographic
)
SELECT
  demographic,
  ROUND((after_sales - before_sales)::NUMERIC / before_sales * 100, 2) AS percentage_change
FROM
  sales_comparison
WHERE
  before_sales > 0
ORDER BY
  percentage_change ASC;