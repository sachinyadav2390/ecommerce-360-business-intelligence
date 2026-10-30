# Data Dictionary: E-Commerce 360° Business Intelligence Platform

This data dictionary outlines the schemas, field definitions, data types, and grain of both the **Staging Layer** (raw Olist tables) and the curated **Analytical Star Schema Layer**.

---

## 1. Analytical Star Schema Layer

### Table: `dim_customers`
* **Grain:** One row per customer order address.
* **Storage Engine:** InnoDB
* **Primary Key:** `customer_id`

| Column | Data Type | Nullable | Description |
| :--- | :--- | :--- | :--- |
| `customer_id` | `VARCHAR(50)` | NO | Unique surrogate key generated per order. Used to join with `fact_orders`. |
| `customer_unique_id` | `VARCHAR(50)` | NO | Unique identifier of the real physical individual. Used for customer-level analytics (LTV, repeat rates, RFM). |
| `zip_code_prefix` | `INT` | NO | First 5 digits of the Brazilian postal code (CEP). |
| `city` | `VARCHAR(100)` | NO | Customer shipping city name (standardized to title case). |
| `state` | `VARCHAR(5)` | NO | Two-letter Brazilian federal unit code (e.g., SP, RJ, MG). |
| `region` | `VARCHAR(20)` | NO | Brazilian macro-region (*Southeast, South, Northeast, Central-West, North*). |

---

### Table: `dim_products`
* **Grain:** One row per product SKU in catalog.
* **Primary Key:** `product_id`

| Column | Data Type | Nullable | Description |
| :--- | :--- | :--- | :--- |
| `product_id` | `VARCHAR(50)` | NO | Unique alphanumeric product SKU identifier. |
| `category_name_pt` | `VARCHAR(100)` | NO | Original Portuguese category name (`desconhecido` if null). |
| `category_name_en` | `VARCHAR(100)` | NO | English translated category name (`Unknown` if missing). |
| `name_length` | `INT` | YES | Character length of the product title. |
| `description_length` | `INT` | YES | Character length of the product description. |
| `photos_qty` | `INT` | YES | Number of product photos published on the listing. |
| `weight_g` | `INT` | YES | Product weight in grams. |
| `length_cm` | `INT` | YES | Package length in centimeters. |
| `height_cm` | `INT` | YES | Package height in centimeters. |
| `width_cm` | `INT` | YES | Package width in centimeters. |
| `volume_cm3` | `DECIMAL(12,2)` | YES | Calculated physical cubic volume ($L \times H \times W$). |

---

### Table: `dim_sellers`
* **Grain:** One row per marketplace merchant seller.
* **Primary Key:** `seller_id`

| Column | Data Type | Nullable | Description |
| :--- | :--- | :--- | :--- |
| `seller_id` | `VARCHAR(50)` | NO | Unique identifier of the registered marketplace seller. |
| `zip_code_prefix` | `INT` | NO | Seller dispatch facility postal code prefix. |
| `city` | `VARCHAR(100)` | NO | Seller city name. |
| `state` | `VARCHAR(5)` | NO | Seller state code. |
| `region` | `VARCHAR(20)` | NO | Seller Brazilian macro-region. |

---

### Table: `dim_date`
* **Grain:** One row per calendar day (2016-01-01 to 2018-12-31).
* **Primary Key:** `date_key`

| Column | Data Type | Nullable | Description |
| :--- | :--- | :--- | :--- |
| `date_key` | `DATE` | NO | Date in `YYYY-MM-DD` format. |
| `full_date_description`| `VARCHAR(50)` | NO | Formatted day string (e.g., 'Tuesday, November 28, 2017'). |
| `day_of_month` | `INT` | NO | Calendar day of month (1 to 31). |
| `day_name` | `VARCHAR(15)` | NO | Full name of weekday (e.g., Monday). |
| `day_of_week` | `INT` | NO | Day index (1 = Sunday to 7 = Saturday). |
| `is_weekend` | `TINYINT(1)` | NO | Flag: 1 for Saturday/Sunday, 0 for weekdays. |
| `month_number` | `INT` | NO | Month index (1 to 12). |
| `month_name` | `VARCHAR(15)` | NO | Full month name (e.g., November). |
| `year_month` | `VARCHAR(7)` | NO | Year-Month string (e.g., '2017-11'). |
| `quarter_number` | `INT` | NO | Calendar quarter (1 to 4). |
| `year_quarter` | `VARCHAR(7)` | NO | Year-Quarter string (e.g., '2017-Q4'). |
| `year_number` | `INT` | NO | Calendar year (2016, 2017, 2018). |

---

### Table: `fact_orders`
* **Grain:** One row per order transaction.
* **Primary Key:** `order_id`
* **Foreign Keys:** `customer_id` -> `dim_customers`, `purchase_date` -> `dim_date`

| Column | Data Type | Nullable | Description |
| :--- | :--- | :--- | :--- |
| `order_id` | `VARCHAR(50)` | NO | Unique order transaction identifier. |
| `customer_id` | `VARCHAR(50)` | NO | Foreign key referencing `dim_customers`. |
| `order_status` | `VARCHAR(20)` | NO | Status: `delivered`, `shipped`, `canceled`, `invoiced`, `processing`, `unavailable`. |
| `purchase_date` | `DATE` | NO | Date dimension key for time-intelligence partitioning. |
| `purchase_timestamp` | `DATETIME` | NO | Exact timestamp of order placement. |
| `approved_at` | `DATETIME` | YES | Timestamp of payment gateway authorization. |
| `delivered_carrier_date`| `DATETIME` | YES | Timestamp when merchant handed order to postal carrier. |
| `delivered_customer_date`| `DATETIME` | YES | Timestamp when final delivery was signed by recipient. |
| `estimated_delivery_date`| `DATETIME` | NO | Target SLA delivery date quoted to customer at checkout. |
| `delivery_lead_time_days`| `DECIMAL(6,2)`| YES | Total door-to-door transit time in fractional days. |
| `delivery_vs_estimated_days`| `DECIMAL(6,2)`| YES | Delivery variance relative to SLA (Negative = Early, Positive = Late). |
| `delivery_status` | `VARCHAR(20)` | NO | Classified status: `On-Time`, `Late`, `Undelivered`. |

---

### Table: `fact_order_items`
* **Grain:** One row per line item within an order.
* **Primary Key:** `order_item_surrogate_id`
* **Foreign Keys:** `order_id` -> `fact_orders`, `product_id` -> `dim_products`, `seller_id` -> `dim_sellers`, `purchase_date` -> `dim_date`

| Column | Data Type | Nullable | Description |
| :--- | :--- | :--- | :--- |
| `order_item_surrogate_id`| `INT` (AI) | NO | Primary surrogate key. |
| `order_id` | `VARCHAR(50)` | NO | Parent order identifier. |
| `order_item_id` | `INT` | NO | Sequential item number inside the order (1, 2, ...). |
| `product_id` | `VARCHAR(50)` | NO | Foreign key referencing `dim_products`. |
| `seller_id` | `VARCHAR(50)` | NO | Foreign key referencing `dim_sellers`. |
| `purchase_date` | `DATE` | NO | Denormalized purchase date for efficient filtering. |
| `shipping_limit_date` | `DATETIME` | NO | Seller dispatch deadline before penalty. |
| `price` | `DECIMAL(10,2)`| NO | Item sale price in Brazilian Real (BRL). |
| `freight_value` | `DECIMAL(10,2)`| NO | Shipping freight charge allocated to this item in BRL. |
| `total_item_value` | `DECIMAL(10,2)`| NO | Gross item cost ($Price + Freight$). |

---

### Table: `fact_payments`
* **Grain:** One row per payment transaction instrument.
* **Primary Key:** `payment_surrogate_id`
* **Foreign Keys:** `order_id` -> `fact_orders`

| Column | Data Type | Nullable | Description |
| :--- | :--- | :--- | :--- |
| `payment_surrogate_id` | `INT` (AI) | NO | Primary surrogate key. |
| `order_id` | `VARCHAR(50)` | NO | Foreign key referencing `fact_orders`. |
| `payment_sequential` | `INT` | NO | Payment sequence index (in case of split payments). |
| `payment_type` | `VARCHAR(20)` | NO | Instrument: `credit_card`, `boleto`, `voucher`, `debit_card`. |
| `payment_installments` | `INT` | NO | Number of financing installment months chosen by buyer. |
| `payment_value` | `DECIMAL(10,2)`| NO | Amount charged to this payment method in BRL. |

---

### Table: `fact_reviews`
* **Grain:** One row per customer satisfaction review survey.
* **Primary Key:** `(review_id, order_id)`
* **Foreign Keys:** `order_id` -> `fact_orders`

| Column | Data Type | Nullable | Description |
| :--- | :--- | :--- | :--- |
| `review_id` | `VARCHAR(50)` | NO | Review submission identifier. |
| `order_id` | `VARCHAR(50)` | NO | Foreign key referencing `fact_orders`. |
| `review_score` | `INT` | NO | Customer satisfaction score: 1 (worst) to 5 (best). |
| `review_comment_title` | `VARCHAR(255)`| YES | Free-text subject headline. |
| `review_comment_message`| `TEXT` | YES | Full customer written feedback body. |
| `review_creation_date` | `DATETIME` | NO | Date when survey form was emailed to recipient. |
| `review_answer_timestamp`| `DATETIME` | NO | Timestamp when recipient completed the survey. |
| `review_response_time_hours`| `DECIMAL(8,2)`| YES | Latency in hours between invite and completion. |

---

## 2. Metric Definitions & Business Rules

* **Delivered Revenue:** Defined strictly as `SUM(FactOrderItems[price])` where `order_status = 'delivered'`. Freight is reported distinctly to avoid inflating merchandise volume.
* **Gross Merchandise Value (GMV):** Defined as `SUM(price) + SUM(freight_value)` for delivered orders.
* **Repeat Customer:** A customer unique identifier (`customer_unique_id`) associated with more than one distinct delivered order (`COUNT(DISTINCT order_id) > 1`).
* **Late Delivery:** An order where the actual delivered customer date is strictly after the estimated delivery date (`delivered_customer_date > estimated_delivery_date`).
* **Delivery Lead Time:** The elapsed time between order placement and customer physical delivery (`delivered_customer_date - order_purchase_timestamp`).
