## Setup

1. Download Docker Desktop (if you don’t have installed) using the official website, install and launch.
2. Fork this Github project to you Github account. Clone the forked repo to your device.
3. Open your Command Prompt or Terminal, navigate to that folder, and run the command `docker compose up`.
4. Now you have launched a local Postgres database with the following credentials:
 ```
    Host: localhost
    User: admin
    Password: admin
    Port: 5432 
```
5. Connect to the db via a preferred tool (e.g. DataGrip, Dbeaver etc)
6. Install dbt-core and dbt-postgres using pip (if you don’t have) on your preferred environment.
7. Now you can run `dbt run` with the test model and check public_pipedrive_analytics schema to see the dbt result (with one test model)

## Project
1. Remove the test model once you make sure it works
2. Dive deep into the Pipedrive CRM source data to gain a thorough understanding of all its details. (You may also research the Pipedrive CRM tool terms).
3. Define DBT sources and build the necessary layers organizing the data flow for optimal relevance and maintainability.
4. Build a reporting model (rep_sales_funnel_monthly) with monthly intervals, incorporating the following funnel steps (KPIs):  
  &nbsp;&nbsp;&nbsp;Step 1: Lead Generation  
  &nbsp;&nbsp;&nbsp;Step 2: Qualified Lead  
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Step 2.1: Sales Call 1  
  &nbsp;&nbsp;&nbsp;Step 3: Needs Assessment  
  &nbsp;&nbsp;&nbsp;&nbsp;&nbsp;&nbsp;Step 3.1: Sales Call 2  
  &nbsp;&nbsp;&nbsp;Step 4: Proposal/Quote Preparation  
  &nbsp;&nbsp;&nbsp;Step 5: Negotiation  
  &nbsp;&nbsp;&nbsp;Step 6: Closing  
  &nbsp;&nbsp;&nbsp;Step 7: Implementation/Onboarding  
  &nbsp;&nbsp;&nbsp;Step 8: Follow-up/Customer Success  
  &nbsp;&nbsp;&nbsp;Step 9: Renewal/Expansion
5. Column names of the reporting model: `month`, `kpi_name`, `funnel_step`, `deals_count`
6. “Git commit” all the changes and create a PR to your forked repo (not the original one). Send your repo link to us.

---
## **Solution**

## Analysis 
# 📊 Pipedrive Sales Funnel Analytics (dbt)

This project implements a robust, modular data warehouse using **dbt (data build tool)** to transform raw Pipedrive CRM data into a clean, monthly sales funnel report.

---

## 🏗 Architecture Overview

I have followed the **Medallion Architecture** to ensure data integrity, scalability, and clear separation of concerns.



### 1. Staging Layer (`stg_`)
- **Purpose:** Primary cleaning, casting, and renaming of raw source tables.
- **Models:** `stg_users`, `stg_deal_changes`, `stg_activity`.

### 2. Intermediate Layer (`int_`)
- **`int_months_spine`**: Generates a continuous series of months to ensure no "gaps" in reporting.
- **`int_funnel_stages`**: Parses complex JSON stage history into a flat, numeric sequence.
- **`int_funnel_activities`**: Uses custom macros to map CRM activities (calls, emails) to specific funnel steps (e.g., Step 2.1).

### 3. Core & Marts Layer
- **`dim_users`**: A cleaned dimension table for sales representative metadata.
- **`rep_sales_funnel_monthly`**: The final "Golden Table." It uses a **Cross Join** between the month spine and funnel stages to ensure every stage appears in every month, even if the count is zero.

---

## 🛠 Technical Highlights

### 🔹 Gap-less Funnel Reporting
Unlike standard joins, this project uses a Cartesian product (Cross Join) between months and stages. This allows stakeholders to see exactly where the funnel "dried up" during specific periods.

### 🔹 Macro-Driven Mapping
To avoid hardcoding logic in multiple places, I developed the `get_activity_step` macro. This allows for easy maintenance—if a new activity type is added to the CRM, it can be mapped to the funnel in a single line of code.



### 🔹 Step Standardization
The funnel is filtered to focus on the active sales cycle (**Steps 1.0 through 9.0**), providing a clear view of lead progression without the noise of post-close or lost-deal metadata.

---
## 📂 Analysis & Modularization

This project evolved from a series of monolithic SQL queries into a structured dbt project. Below is the mapping of how the original analytical logic was broken down into modular components.
### 0. Monotlith analysis queries
```bash
   -- for stage transformation
with stages_conf as (
SELECT id,field_key,
  elem ->> 'id'    AS stage_id,
  elem ->> 'label' AS stage_name
FROM fields
CROSS JOIN LATERAL jsonb_array_elements(field_value_options) AS elem where field_key ='stage_id'),
months as (SELECT generate_series(
        MIN(change_time),
        MAX(change_time),
        '1 month'
    )::date AS month from deal_changes),
int_deal_stage_history as(
SELECT
    deal_id,
    change_time AS entered_at,
    new_value::integer AS stage_id,
    LEAD(change_time) OVER (PARTITION BY deal_id ORDER BY change_time ASC) AS exited_at
FROM deal_changes
WHERE changed_field_key = 'stage_id'),
funel_vw as
(
    SELECT
        h.deal_id,
        s.stage_id::float as step,
        s.stage_name,
        h.entered_at,
        h.exited_at,
         CASE WHEN h.stage_id = 0 THEN 'Lost' ELSE s.stage_name END AS funnel_step_name
    FROM int_deal_stage_history h
    JOIN stages_conf s ON h.stage_id = s.stage_id::integer
)
select month,stage_name as kpi_name,step,count(*) as  deal_count
from  months  ms left join funel_vw  fn ON DATE_TRUNC('month', fn.entered_at ) = ms.month
group by  stage_name,month,step
order by step,stage_name, month

-- 2 for lost reason transformation

with lost_reason_conf as (
SELECT id,field_key,
  elem ->> 'id'    AS reason_id,
  elem ->> 'label' AS reason_name
FROM fields
CROSS JOIN LATERAL jsonb_array_elements(field_value_options) AS elem where field_key ='lost_reason'),
months as (SELECT generate_series(
        MIN(change_time),
        MAX(change_time),
        '1 month'
    )::date AS month from deal_changes),
int_deal_stage_history as(
SELECT
    deal_id,
    change_time AS entered_at,
    new_value::integer AS stage_id,
    LEAD(change_time) OVER (PARTITION BY deal_id ORDER BY change_time ASC) AS exited_at
FROM deal_changes
WHERE changed_field_key = 'lost_reason'),
funel_vw as
(
    SELECT
        h.deal_id,
        s.reason_id::float+10 as step,
        s.reason_name,
        h.entered_at,
        h.exited_at,
         CASE WHEN h.stage_id = 0 THEN 'Lost' ELSE s.reason_name END AS funnel_step_name
    FROM int_deal_stage_history h
    JOIN lost_reason_conf s ON h.stage_id = s.reason_id::integer
)
select month,reason_name as kpi_name,step,count(*) as  deal_count
from  months  ms left join funel_vw  fn ON DATE_TRUNC('month', fn.entered_at ) = ms.month
group by  reason_name,month,step
order by step,reason_name, month


--3 other other kpis like creation and stage
 with activity_step_conf as  (select name ,
                                   CASE name WHEN 'Sales Call 1' THEN '2.1' WHEN 'Sales Call 2'THEN '3.1'
                                   WHEN 'Follow Up Call'    THEN '14.1'WHEN 'After Close Call'  THEN '15.1'
                                   ELSE NULL END   as step,type
                              from activity_types),
                months as   (SELECT generate_series(MIN(due_to),MAX(due_to),'1 month' )::date AS month
                             from activity),
                    activity_vw as  (select a.deal_id ,asf.step::float as step, asf.name as activity_name,a.due_to
                                from activity a
                                 join activity_step_conf asf on  a.type = asf.type )
              select month,activity_name,step,count(*) as deal_count
                 from months ms left join activity_vw av   ON DATE_TRUNC('month', av.due_to ) = ms.month
                group by month,activity_name,step

with
 months as   (SELECT generate_series(MIN(change_time),MAX(change_time),'1 month' )::date AS month
                             from deal_changes)
 select month,f.name as staging_name,'0.0' as step, count(*) as deal_Count from deal_changes dc  join fields f on (dc.changed_field_key= f.field_key)
        left  join months ms ON DATE_TRUNC('month', dc.change_time ) = ms.month
         where dc.changed_field_key = 'add_time'  group by month, name


with
 months as   (SELECT generate_series(MIN(change_time),MAX(change_time),'1 month' )::date AS month
                             from deal_changes)
 select month,f.name as staging_name,'0.1' as step, count(*) as deal_Count from deal_changes dc  join fields f on (dc.changed_field_key= f.field_key)
        left  join months ms ON DATE_TRUNC('month', dc.change_time ) = ms.month
         where dc.changed_field_key = 'user_id'  group by month, name

```


Markdown
## 🏗 Data Modelling & Schema Design

This project implements a **Star Schema** approach within the dbt environment, optimizing the raw normalized CRM data into an analytics-ready dimensional model.

### 🔵 The Dimensional Model
I have organized the data into a central **Fact table** supported by **Dimension tables** to allow for flexible slicing and dicing of funnel metrics.

* **Fact Table:** `rep_sales_funnel_monthly`
    * Contains the quantitative measures (`deal_count`).
    * Acts as the "Accumulating Snapshot" of the funnel performance.
* **Dimension Tables:** * `dim_users`: Contains representative metadata (names, emails, assignment history).
    * `dim_stages`: A reference table for stage names, numeric steps, and phase categories.



### 🟢 Medallion Architecture (Data Flow)
The data flows through three distinct zones to ensure quality and lineage:

1.  **Bronze (Staging):** Direct mapping of raw Postgres tables. Minimal transformation, primarily focused on renaming columns to a consistent snake_case and casting data types (e.g., timestamps).
2.  **Silver (Intermediate):** This is where the heavy lifting occurs. Logic like **JSON parsing**, **window functions** for stage history, and **activity mapping** is performed here. These models are kept as `views` to save on storage while maintaining logic modularity.
3.  **Gold (Marts):** Business-ready tables. The `rep_sales_funnel_monthly` table is materialized as a `table` for high-performance querying in BI tools.



### 🟡 Handling Sparsity (The Master Grid)
One of the key modelling challenges was "Sparse Data"—months where certain stages had zero activity. 
* **Solution:** I implemented a **Cartesian Product (Cross Join)** between `int_months_spine` and `dim_stages`.
* **Result:** This creates a dense matrix (Year-Month x Stage). When left-joined back to our deal activities, it ensures that zeros are explicitly reported rather than rows being missing.

### 🧪 Entity Relationship Diagram (ERD) Overview
* **`stg_deal_changes`** → Many-to-One → **`dim_users`** (on `user_id`)
* **`rep_sales_funnel_monthly`** → Many-to-One → **`dim_stages`** (on `step`)
* **`int_funnel_activities`** → One-to-Many → **`stg_deal_changes`** (on `deal_id`)
### 1. Funnel Stages & Lost Reasons Logic
**Original Logic:** Used `CROSS JOIN LATERAL` with `jsonb_array_elements` to parse field options and window functions (`LEAD`) to calculate stage duration.

**dbt Implementation:**
* **Model:** `int_funnel_stages.sql`
* **Transformation:** The logic was moved to an intermediate layer that extracts `stage_id` and `label` from the `fields` source. 
* **Step Standardization:** * **Stages:** Mapped to numeric floats based on CRM configuration.
    * **Lost Reasons:** Dynamically shifted to **Step 10.0+** (`reason_id + 10`) to separate churn analysis from the active sales funnel.



### 2. Activity Mapping & Sequencing
**Original Logic:** Hardcoded `CASE` statements within a CTE to map activity names (e.g., 'Sales Call 1') to funnel positions.

**dbt Implementation:**
* **Macro:** `macros/get_activity_step.sql`
* **Model:** `int_funnel_activities.sql`
* **Benefit:** By centralizing the mapping in a Jinja macro, the logic is "DRY" (Don't Repeat Yourself). If the sales team adds a "Discovery Call," it only needs to be updated in the macro to reflect across all models.

### 3. Metadata & Entry Point Tracking
**Original Logic:** Separate CTEs for `add_time` and `user_id` to track deal creation and ownership changes.

**dbt Implementation:**
* **Model:** `int_funnel_metadata_changes.sql`
* **Refinement:** Unified all system-level changes into a single model.
    * `add_time` is standardized to **Step 0.0** (Deal Entry).
    * `user_id` is standardized to **Step 0.1** (Assignment).

### 4. Time-Series Continuity (Date Spine)
**Original Logic:** Repeated use of `generate_series` within every sub-query to create monthly buckets.

**dbt Implementation:**
* **Model:** `int_months_spine.sql`
* **Refinement:** Created a single source of truth for time. The final mart performs a `CROSS JOIN` between this spine and all funnel steps. This ensures that every stage (1-9) is represented for every month, preventing "data gaps" in BI visualizations.



---

## 🛠 Model Mapping Summary

| Original CTE Component | dbt Model / Macro | Logic Summary |
| :--- | :--- | :--- |
| `stages_conf` | `int_funnel_stages` | Parses `stage_id` and labels from JSONB. |
| `lost_reason_conf` | `int_funnel_stages` | Offsets lost reasons to Step 10+. |
| `activity_step_conf` | `macros/get_activity_step` | Centralized name-to-step mapping. |
| `months` | `int_months_spine` | Global `generate

---
