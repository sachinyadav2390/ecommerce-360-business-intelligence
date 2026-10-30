# Project Interview Master Guide: 15 Job-Ready Questions & Answers
## E-Commerce 360° Business Intelligence Platform

This guide provides battle-tested, structured answers designed for Data Analyst, Business Intelligence Engineer, and Analytics Engineer interviews.

---

### Core Interview Questions (Top 10)

#### Q1: Why did you select the Olist dataset for this project?
* **Answer Structure:** Context -> Technical Depth -> Real-World Relevance.
* **Suggested Response:**  
  *"I chose the Brazilian E-Commerce Public Dataset by Olist because it simulates real enterprise marketplace operations far better than synthetic datasets. It contains over 100,000 real historical orders with multiple relational tables—customers, products, sellers, payments, reviews, and timestamps. Crucially, it reflects real-world data challenges: one-to-many relationship fan-outs, geographic disparities, logistical delays, missing categories, and messy review feedback. This gave me the opportunity to demonstrate end-to-end analytics: designing a production MySQL Star Schema, performing advanced SQL aggregations, building RFM and ML segmentation in Python, and modeling high-impact DAX measures in Power BI."*

---

#### Q2: How did you design your MySQL database architecture?
* **Suggested Response:**  
  *"I established a two-tier database architecture to maintain data integrity and separation of concerns:*
  1. *Staging Layer (`raw_*`): Direct 1:1 ingestion tables from the source CSVs. This preserved raw source data and allowed data validation audits without altering incoming records.*
  2. *Analytical Layer (Star Schema): Modeled around distinct business processes. Dimension tables (`dim_customers`, `dim_products`, `dim_sellers`, `dim_date`) hold descriptive attributes and SCD Type 1 mappings. Fact tables (`fact_orders`, `fact_order_items`, `fact_payments`, `fact_reviews`) store transactional metrics at strict, consistent grains.*
  *I also implemented indexing on foreign keys, purchase timestamps, and customer identifiers to ensure queries execute in milliseconds even on large joins."*

---

#### Q3: What is the difference between fact and dimension tables, and what grains did you choose?
* **Suggested Response:**  
  *"Dimension tables provide the 'context' (who, what, where, when) with descriptive, qualitative attributes used for slicing, dicing, and grouping. For example, `dim_products` has 1 row per product SKU, and `dim_customers` has 1 row per customer order address.*  
  *Fact tables contain quantitative metrics, foreign keys, and observable business events. In this project, maintaining consistent grain was vital:*
  * `fact_orders`: Grain is **1 row per order placed** (holding order-level timestamps and logistical latency).*
  * `fact_order_items`: Grain is **1 row per line item within an order** (holding item price and freight).*
  * `fact_payments`: Grain is **1 row per payment instrument transaction**.*
  * `fact_reviews`: Grain is **1 row per satisfaction survey response**.*  
  *By strictly separating these grains rather than collapsing them into one denormalized table, I prevented fan-out row multiplication errors."*

---

#### Q4: How did you prevent duplicate revenue calculations when joining orders, items, payments, and reviews?
* **Suggested Response:**  
  *"This is one of the most critical pitfalls in relational analytics. An order can have multiple items, multiple split payments (e.g., voucher + credit card), and multiple reviews. If you write a naive query joining `orders` directly to `order_items`, `payments`, and `reviews` in a single `JOIN`, the rows multiply exponentially through Cartesian fan-out, inflating total revenue by 200% to 300%.*  
  *To prevent this, I applied two rigorous engineering patterns:*
  1. *In SQL, I pre-aggregated line items and payment transactions in separate Common Table Expressions (CTEs) or subqueries at the `order_id` grain before joining to the orders table.*
  2. *In Power BI, I preserved the Star Schema with single-direction one-to-many relationships from dimensions to facts, calculating revenue exclusively from `SUM(FactOrderItems[price])` rather than pulling from the payment table."*

---

#### Q5: Which SQL window functions did you use, and what business problems did they solve?
* **Suggested Response:**  
  *"I utilized several advanced window functions across our 35 SQL queries:*
  * `LAG()`: Used in time-series analysis to calculate Month-over-Month (MoM) revenue growth % and to measure the exact days between successive purchases for repeat customers.*
  * `DENSE_RANK()`: Used to rank customers and sellers by total realized spend and fulfillment volume without skipping ranking positions.*
  * `NTILE(5)` and `NTILE(10)`: Used to divide customers into RFM score quintiles and spend deciles to measure Pareto concentration.*
  * `SUM() OVER (ORDER BY ... ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW)`: Used to calculate cumulative running revenue and Pareto 80/20 category distributions.*
  * `AVG() OVER (ORDER BY ... ROWS BETWEEN 2 PRECEDING AND CURRENT ROW)`: Used to compute a smoothed 3-month moving average of sales volume."*

---

#### Q6: How did you perform RFM customer segmentation?
* **Suggested Response:**  
  *"I performed RFM segmentation using both rule-based scoring and machine learning:*
  1. *Recency: Days elapsed between the customer's most recent order and the dataset anchor date.*
  2. *Frequency: Count of distinct delivered orders per `customer_unique_id`.*
  3. *Monetary: Total item price contributed by the customer.*  
  *In SQL and Python, I scored Recency and Monetary into quintiles (1–5). Because 96.9% of customers placed only one order, Frequency was bifurcated (score 5 for repeat buyers, score 1 for single buyers). I then mapped these into business personas: Champions, Loyal Customers, Potential Loyalists, At Risk, Can't Lose Them, and Hibernating.*  
  *Next, in Python, I log-transformed and standardized the features and applied K-Means clustering. I evaluated $k=2$ through $k=7$ using the Elbow Method and Silhouette Coefficients, establishing $k=4$ as the optimal grouping."*

---

#### Q7: What is cohort retention analysis, and why is it useful?
* **Suggested Response:**  
  *"Cohort analysis groups customers based on their acquisition date—specifically, their first purchase month—and tracks their behavior across subsequent months (Month 0, Month 1, Month 2, ... Month 12).*  
  *It is indispensable because aggregate sales can mask underlying retention problems. For instance, top-line revenue might be growing, but if 99% of that revenue is from expensive new customer acquisition while older cohorts completely churn out, the business has a leaky bucket.*  
  *In Olist's data, the cohort heatmap proved that Month 1 retention was under 0.7% across all cohorts, revealing that growth was entirely dependent on continuous acquisition."*

---

#### Q8: How did you calculate Repeat Customer Percentage?
* **Suggested Response:**  
  *"I calculated it at the unique customer level (`customer_unique_id`), not the transactional `customer_id`:*
  $$\text{Repeat Customer \%} = \frac{\text{Unique Customers with} > 1 \text{ Delivered Orders}}{\text{Total Unique Customers with Delivered Orders}} \times 100$$
  *In SQL, I used a CTE grouping by `customer_unique_id`, counting `DISTINCT order_id`, and aggregating with `SUM(CASE WHEN order_count > 1 THEN 1 ELSE 0 END) / COUNT(*)`. The resulting benchmark was **3.12%**."*

---

#### Q9: Why did you choose a Star Schema in Power BI?
* **Suggested Response:**  
  *"A Star Schema is Microsoft's officially recommended design for Power BI for three reasons:*
  1. *Performance: The VertiPaq engine compresses narrow dimension tables and numerical fact tables with exceptional efficiency, optimizing memory footprint.*
  2. *Simplicity: It creates unambiguous, single-direction 1-to-many relationships, eliminating circular dependencies, ambiguous filter paths, and bidirectional performance degradation.*
  3. *DAX Reliability: Standard time-intelligence and filter functions (`CALCULATE`, `DATEADD`, `USERELATIONSHIP`) work seamlessly when filtering facts through dedicated dimension tables."*

---

#### Q10: What actionable business recommendations did you derive from your analysis?
* **Suggested Response:**  
  *"I delivered four core recommendations to management:*
  1. *Retention Loop Automation: Trigger automated reorder emails 30 and 60 days post-delivery tailored to consumable categories, accompanied by a 90-day expiry loyalty credit to lift repeat rate toward 6%.*
  2. *Northeast Regional Fulfillment Hubs: Establish local cross-docking in Bahia and Pernambuco to cut delivery from 18 days to 4 days, eliminating the 80% delay penalty.*
  3. *Seller SLA Enforcement: Enforce a strict 48-hour carrier dispatch SLA and de-list merchants whose late delivery rate exceeds 10%.*
  4. *Freight Subsidization: Offer 50% freight subsidy on baskets exceeding R$ 150 to combat the 32% non-Southeast freight burden and increase AOV from R$ 136 to R$ 175."*

---

### Advanced Technical Follow-ups (Questions 11 to 15)

#### Q11: Why did you evaluate your sales forecasting model on a chronological holdout rather than random train-test split?
* **Answer:** *"In time-series data, random shuffling causes lookahead bias and data leakage because future information leaks into the training set. Real forecasting only operates sequentially: predicting the future based on the past. Therefore, I held out the final 4 chronological months (May to August 2018) and trained strictly on preceding data."*

#### Q12: Why did the baseline lag model outperform complex ML in your monthly forecasting experiment?
* **Answer:** *"With only 20 monthly aggregate observations, complex regression models suffer from high variance and parameter overfitting. The simple lag-1 persistence baseline (MAE 237 orders, 3.85% MAPE) proved far more robust. As a data analyst, it's vital to know when a simple, explainable baseline beats an over-engineered model."*

#### Q13: How did you handle category translations and missing categories?
* **Answer:** *"Product categories were originally in Portuguese, with 610 records missing categories. In our ETL pipeline, I left-joined `product_category_name_translation` to retrieve English titles, formatted underscores into clean title case, and explicitly classified missing or null entries as `'Unknown'`. This preserved referential integrity and avoided dropping transactions."*

#### Q14: How did you classify Brazilian macro-regions?
* **Answer:** *"I mapped Brazil's 27 state codes into the 5 official IBGE macro-regions: Southeast (SP, RJ, MG, ES), South (PR, SC, RS), Northeast (BA, PE, CE, etc.), Central-West (MT, MS, GO, DF), and North (AM, PA, etc.). This enabled regional logistics and freight equity analysis."*

#### Q15: How did you ensure data documentation integrity throughout the project?
* **Answer:** *"I generated a complete data dictionary covering all staging and analytical tables, documented schema DDL scripts, authored extensive docstrings in Python, and published structured business insights with mermaid architecture diagrams."*
