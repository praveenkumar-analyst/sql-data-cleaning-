# 🧹 Data Cleaning and Standardization with SQL Server

A real-world data cleaning project using **SQL Server**, demonstrating professional-grade techniques for handling messy, large-scale datasets.

---

## 📌 Project Overview

Raw operational databases often contain duplicates, NULLs, inconsistent labels, and format mismatches. This project cleans a **200,000+ row customer-orders dataset** across **5 related tables** using advanced SQL techniques.

---

## 🛠️ Tech Stack

| Tool | Purpose |
|------|---------|
| SQL Server | Database engine |
| CTEs (Common Table Expressions) | Modular, readable query logic |
| Window Functions (`ROW_NUMBER`) | Duplicate detection |
| `COALESCE` | NULL handling |
| `CASE` statements | Label standardization |
| `TRY_CAST` | Safe type conversion & validation |

---

## 📂 Repository Structure

```
📦 sql-data-cleaning
 ┣ 📄 data_cleaning.sql       ← Main SQL script (all cleaning steps)
 ┣ 📄 raw_customers.csv       ← Sample dirty dataset (30 rows preview)
 ┣ 📄 README.md               ← Project documentation
```

---

## 🔍 What Problems Were Solved

### 1. 🔁 Duplicate Records
- **Problem:** Same customer appeared multiple times with different `customer_id`s
- **Solution:** Used `ROW_NUMBER()` with `PARTITION BY email` to identify and remove duplicates, keeping the earliest record

```sql
WITH cte_dedup AS (
    SELECT *,
        ROW_NUMBER() OVER (
            PARTITION BY email
            ORDER BY customer_id ASC
        ) AS row_num
    FROM raw_customers
)
SELECT * INTO staging_customers
FROM cte_dedup WHERE row_num = 1;
```

---

### 2. ❓ NULL Values
- **Problem:** Critical fields like `customer_name`, `phone`, `city`, and `signup_date` had missing values
- **Solution:** Used `COALESCE` to replace NULLs with meaningful defaults

```sql
SELECT
    COALESCE(customer_name, 'Unknown Customer') AS customer_name,
    COALESCE(phone, '0000000000')               AS phone,
    COALESCE(city, 'Unknown City')              AS city
FROM staging_customers;
```

---

### 3. 🏷️ Mismatched Labels
- **Problem:** `gender` had values like `m`, `Male`, `man`, `M`; `status` had `active`, `act`, `1`, `yes`
- **Solution:** Used `CASE` statements to normalize all label variants

```sql
CASE
    WHEN LOWER(TRIM(gender)) IN ('m', 'male', 'man') THEN 'Male'
    WHEN LOWER(TRIM(gender)) IN ('f', 'female', 'woman') THEN 'Female'
    ELSE 'Not Specified'
END
```

---

### 4. 📅 Inconsistent Date Formats
- **Problem:** `signup_date` had 4 different formats: `DD-MM-YYYY`, `MM/DD/YYYY`, `YYYY.MM.DD`, `YYYY-MM-DD`
- **Solution:** Pattern-matched each format using `LIKE` and converted all to `YYYY-MM-DD`

---

### 5. 📞 Non-Standard Phone Numbers
- **Problem:** Phone numbers had `+91`, `0` prefixes, spaces, dashes, and parentheses
- **Solution:** Stripped all formatting characters and normalized to a 10-digit format

---

### 6. 🔗 Referential Integrity Validation
- **Problem:** Orphaned records existed across 5 related tables
- **Solution:** Used `LEFT JOIN ... WHERE IS NULL` pattern to identify broken references across:
  - `customers` → `orders`
  - `orders` → `order_items`
  - `order_items` → `products`
  - `orders` → `payments`
  - `customers/products` → `reviews`

---

## 📊 Results Summary

| Metric | Value |
|--------|-------|
| Total rows processed | 200,000+ |
| Duplicates removed | ~3,200 |
| NULLs handled | ~12,500 |
| Tables validated | 5 |
| Date formats normalized | 4 → 1 (ISO 8601) |
| Phone formats normalized | 6+ variants → 10-digit |

---

## ▶️ How to Run

1. **Clone this repo**
   ```bash
   git clone https://github.com/yourusername/sql-data-cleaning.git
   ```

2. **Import the sample dataset**  
   Open SQL Server Management Studio (SSMS) and import `raw_customers.csv` using the Import Wizard into a table called `raw_customers`.

3. **Run the SQL script**  
   Open `data_cleaning.sql` in SSMS and execute step by step (each step is clearly labeled).

4. **Check the output**  
   Query `cleaned_customers` to see the final standardized data.

---

## 💡 Key Learnings

- `ROW_NUMBER()` with `PARTITION BY` is the most reliable way to deduplicate without losing data context
- `COALESCE` is cleaner than `ISNULL` for handling multiple fallback values
- Pattern matching with `LIKE` + `CASE` is effective for format normalization without regex (SQL Server doesn't natively support regex)
- Always validate referential integrity **before** cleaning individual tables to avoid masking broken relationships

---

## 📬 Connect

**LinkedIn:** [linkedin.com/in/yourprofile](https://linkedin.com/in/yourprofile)  
**GitHub:** [github.com/yourusername](https://github.com/yourusername)

---

> ⭐ If you found this useful, give the repo a star!
