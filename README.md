# My 8 Week SQL Challenge Journey 🚀

Welcome to my repository for the **[8 Week SQL Challenge](https://8weeksqlchallenge.com/)**! 
This is a collection of my detailed solutions, where I tackle real-world business problems using SQL. Each case study folder contains the full analysis, SQL queries, and results.

## 🛠️ Tech Stack

* **SQL Dialect:** PostgreSQL
* **Database:** Docker & pgAdmin

---

## 📂 Case Studies

Here's a summary of my work on each case study, including the key business questions I answered and the SQL skills I applied.

### 🍣 Case Study #1: Danny's Diner

This case study centered around analyzing basic customer data for a restaurant to understand their visiting and spending habits.

[➡️ **View Full Solution & Queries for Case Study #1**](./CaseStudy1_DannysDiner/)

#### What I learned and did:

* Calculated total sales and the amount each customer spent.
* Determined customer visit frequency and their first and last order dates.
* Identified the most popular items on the menu.
* Analyzed customer loyalty patterns by tracking purchases before and after they became members.

#### Key SQL Concepts I Practiced:

* **`JOIN`s** and **`LEFT JOIN`s** to combine data from multiple tables.
* **Common Table Expressions (`CTE`s)** to structure and simplify complex queries.
* **Window Functions** like `RANK()`, `DENSE_RANK()`, and `ROW_NUMBER()` to rank customer orders.
* **Aggregate Functions** such as `SUM()`, `COUNT()`, and `MIN()`/`MAX()`.
* **Date and Time Functions** to handle order dates.

---

### 🍕 Case Study #2: Pizza Runner

This case study was a deep dive into pizza delivery logistics, focusing heavily on **data cleaning, transformation, and handling denormalized data structures.**

[➡️ **View Full Solution & Queries for Case Study #2**](./CaseStudy2_PizzaRunner/)

#### What I learned and did:

* Performed intensive data cleaning on `runner_orders` and `customer_orders`, handling `null` values, incorrect data types, and inconsistent text.
* **Normalized comma-separated values** in the `extras` and `exclusions` columns, transforming them into a usable row-level format for ingredient analysis.
* Analyzed pizza order volumes and customer modifications.
* Calculated runner performance metrics, such as delivery times, distance, and average speed.
* Determined the most successful delivery runners and identified opportunities for business optimization.

#### Key SQL Concepts I Practiced:

* **Data Cleaning:** Using `CASE` statements, `REPLACE()`, `TRIM()`, and `NULLIF()` to standardize messy data.
* **Data Transformation:** Casting data types (e.g., `CAST(column AS INTEGER)`).
* **Advanced String & Array Manipulation:** Dealt with denormalized data by splitting comma-separated strings into multiple rows using functions like **`UNNEST()`** (in PostgreSQL) or **`STRING_SPLIT()`** (in SQL Server).
* **Advanced use of `JOIN`s** to connect the cleaned and transformed tables.
* All concepts from the first case study (**`CTE`s**, **Window Functions**, **Aggregates**).

---

### 🛒 Case Study #5: Data Mart

This case study involved creating a clean data mart for weekly sales data and performing a 'before and after' analysis to measure the impact of a packaging change.

[➡️ **View Full Solution & Queries for Case Study #5**](./CaseStudy5_DataMart/)

#### What I learned and did:

* Built a clean, analysis-ready `weekly_sales` data mart by converting data types, extracting date parts, and mapping categorical values.
* Performed a time-series analysis to measure the sales impact of a sustainable packaging change.
* Calculated sales metrics for 4-week and 12-week periods before and after the change date.
* Compared the 2020 results against 2018 and 2019 to account for seasonality and isolate the true impact of the change.
* Dived deeper into the data to identify which customer segments were most affected and provided strategic business recommendations.

#### Key SQL Concepts I Practiced:

* **Data Mart Creation:** Using `CREATE TABLE AS SELECT` to build a clean, aggregated table for analysis.
* **Date/Time Functions:** `TO_DATE()` to convert strings and `EXTRACT()` to pull specific date parts (week, month, year).
* **Conditional Aggregation:** Extensive use of `SUM(CASE WHEN ...)` to create custom time-based buckets for the before-and-after analysis.
* **Window Functions:** `SUM(...) OVER (PARTITION BY ...)` for calculating percentage-of-total metrics.
* All core concepts from previous studies (**`CTE`s**, **`JOIN`s**, **Aggregates**).

---

Feel free to explore the folders for a deeper look at my code and analysis!
