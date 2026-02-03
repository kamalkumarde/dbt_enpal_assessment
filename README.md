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
#  Pipedrive Sales Funnel Analytics (dbt)

This project implements a robust, modular data warehouse using **dbt (data build tool)** to transform raw Pipedrive CRM data into a clean, monthly sales funnel report.

---
##  Architecture Overview

I have followed the **Medallion Architecture** to ensure data integrity, scalability, and clear separation of concerns.

### 1. Staging Layer (`stg_`)--> Bronze
- **Purpose:** Primary cleaning, casting, and renaming of raw source tables.
- **Models:** `stg_users`, `stg_deal_changes`, `stg_activity`.

### 2. Intermediate Layer (`int_`)--> Silver
- **`int_months_spine`**: Generates a continuous series of months to ensure no "gaps" in reporting.
- **`int_funnel_stages`**: Parses complex JSON stage history into a flat, numeric sequence.
- **`int_funnel_activities`**: Uses custom macros to map CRM activities (calls, emails) to specific funnel steps (e.g., Step 2.1).

### 3. Core & Marts Layer --> Gold
- **`dim_users`**: A cleaned dimension table for sales representative metadata.
- **`rep_sales_funnel_monthly`**: The final "Golden Table." It uses a **Cross Join** between the month spine and funnel stages to ensure every stage appears in every month, even if the count is zero.
---

##  Technical Highlights

###  Gap-less Funnel Reporting
Used  cross join that  allows stakeholders to see exactly where the funnel "dried up" during specific periods.

###  Macro-Driven Mapping
To avoid hardcoding logic in multiple places, I developed the `get_activity_step` macro. This allows for easy maintenance, if a new activity type is added to the CRM, it can be mapped to the funnel.

###  Step Standardization

The funnel is filtered to focus on the active sales cycle (**Steps 1.0 through 9.0**), removing or altering the filter can enable the model to cover all the possible kpis like followup, meeting and lost cases stages.

---
##  Analysis & Modularization

This project evolved from a series of monolithic SQL queries into a structured dbt project. Below is the mapping of how the original monolithic SQL logic was broken down into modular components.
### Phase 0. Monotlith analysis queries
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
---
## Phase 1 Data Modelling & Schema Design

This project implements a **Star Schema** approach within the dbt environment.

###  The Dimensional Model
I have organized the data into a central **Fact table** supported by **Dimension tables** to allow for flexible slicing and dicing of funnel metrics.

* **Fact Table:** `rep_sales_funnel_monthly`
    * Contains the quantitative measures (`deal_count`).
    * Acts as the "Accumulating Snapshot" of the funnel performance.
* **Dimension Tables:** * `dim_users`: Contains representative metadata (names, emails, assignment history).
    * `dim_stages`: A reference table for stage names, numeric steps, and phase categories.
---
### Phase 2  Medallion Flow (Data Flow)
The data flows through three distinct zones to ensure quality and lineage:

1.  **Bronze (Staging):** Direct mapping of raw Postgres tables. Minimal transformation, primarily focused on renaming columns to a consistent snake_case and casting data types (e.g., timestamps).
2.  **Silver (Intermediate):** This is where the heavy lifting occurs. Logic like **JSON parsing**, **window functions** for stage history, and **activity mapping** is performed here. These models are kept as `views` to save on storage while maintaining logic modularity.
3.  **Gold (Marts):** Business-ready tables. The `rep_sales_funnel_monthly` table is materialized as a `table` for high-performance querying in BI tools.
---
###  Entity Relationship Diagram (ERD) Overview
* **`stg_deal_changes`** → Many-to-One → **`dim_users`** (on `user_id`)
* **`rep_sales_funnel_monthly`** → Many-to-One → **`dim_stages`** (on `step`)
* **`int_funnel_activities`** → One-to-Many → **`stg_deal_changes`** (on `deal_id`)
###  Funnel Stages & Lost Reasons Logic
**dbt Implementation:**
* **Model:** `int_funnel_stages.sql`
* **Transformation:** The logic was moved to an intermediate layer that extracts `stage_id` and `label` from the `fields` source. 
* **Step Standardization:** * **Stages:** Mapped to numeric floats based on CRM configuration.
    * **Lost Reasons:** Dynamically shifted to **Step 10.0+** (`reason_id + 10`) to separate churn analysis from the active sales funnel.
----  
**dbt Implementation:**
* **Model:** `int_funnel_metadata_changes.sql`
* **Refinement:** Unified all system-level changes into a single model.
    * `add_time` is standardized to **Step 0.0** (Deal Entry).
    * `user_id` is standardized to **Step 0.1** (Assignment).
---      
###  Time-Series Continuity (Date Spine)
**Logic:** Repeated use of `generate_series` within every sub-query to create monthly buckets.
**dbt Implementation:**
* **Model:** `int_months_spine.sql`
* **Refinement:** Created a single source of truth for time. 
---
##  Model Mapping Summary
| Original CTE Component | dbt Model / Macro | Logic Summary |
| :--- | :--- | :--- |
| `stages_conf` | `int_funnel_stages` | Parses `stage_id` and labels from JSONB. |
| `lost_reason_conf` | `int_funnel_stages` | Offsets lost reasons to Step 10+. |
| `activity_step_conf` | `macros/get_activity_step` | Centralized name-to-step mapping. |
| `months` | `int_months_spine` | Global `generate

---
##  Testing
###  Automated Schema Tests
Standard dbt tests 
* **Uniqueness:** Verified on `user_id` in `dim_users` and primary keys in staging models.
* **Non-Nullity:** Mandatory for critical reporting dimensions like `year_month`, `step`, and `deal_id`.
* **Referential Integrity:** Ensuring every `user_id` in the final mart has a corresponding record in the source system.
---
###  Validations 
We leverage the `dbt-utils` package to enforce stricter data contracts:
* **`accepted_range`**: Applied to `deal_count` to ensure we never report negative deals, and to `step` to keep funnel stages within the defined 0.0–16.0 range.
---
###  Custom Singular Tests
I have developed specialized SQL tests to catch logical errors that standard tests might miss:
* **Stage Chronology (`assert_stage_history_chronology`):** This test uses window functions to verify that a deal's `exited_at` timestamp is never earlier than its `entered_at` timestamp.
* ** Format Validation (`is_yyyy_mm`):** A custom macro test that uses regular expressions to ensure the `year_month` column strictly follows the `YYYY-MM` string format required by our BI tools.
---
##   Test Results
```bash
(base) Mac:dbt_enpal_assessment kamalkumar$ dbt clean
13:46:50  Running with dbt=1.7.19
13:46:50  Checking /Users/kamalkumar/projects/dbt_enpal_assessment/dbt_packages/*
13:46:50  Cleaned /Users/kamalkumar/projects/dbt_enpal_assessment/dbt_packages/*
13:46:50  Checking /Users/kamalkumar/projects/dbt_enpal_assessment/target/*
13:46:50  Cleaned /Users/kamalkumar/projects/dbt_enpal_assessment/target/*
13:46:50  Finished cleaning all paths.
(base) Mac:dbt_enpal_assessment kamalkumar$ dbt deps
13:46:54  Running with dbt=1.7.19
13:46:55  Installing dbt-labs/dbt_utils
13:46:55  Installed from version 1.1.1
13:46:55  Updated version available: 1.3.3
13:46:55  
13:46:55  Updates available for packages: ['dbt-labs/dbt_utils']                 
Update your versions in packages.yml, then run dbt deps
(base) Mac:dbt_enpal_assessment kamalkumar$ dbt test
13:47:02  Running with dbt=1.7.19
13:47:02  Registered adapter: postgres=1.10.0
13:47:02  Unable to do partial parsing because saved manifest not found. Starting full parse.
13:47:02  Found 11 models, 11 tests, 6 sources, 0 exposures, 0 metrics, 560 macros, 0 groups, 0 semantic models
13:47:02  
13:47:03  Concurrency: 1 threads (target='dev')
13:47:03  
13:47:03  1 of 10 START test assert_stage_history_chronology ............................. [RUN]
13:47:03  1 of 10 PASS assert_stage_history_chronology ................................... [PASS in 0.03s]
13:47:03  2 of 10 START test dbt_utils_accepted_range_rep_sales_funnel_monthly_deal_count__0  [RUN]
13:47:03  2 of 10 PASS dbt_utils_accepted_range_rep_sales_funnel_monthly_deal_count__0 ... [PASS in 0.01s]
13:47:03  3 of 10 START test dbt_utils_accepted_range_rep_sales_funnel_monthly_step__16__0  [RUN]
13:47:03  3 of 10 PASS dbt_utils_accepted_range_rep_sales_funnel_monthly_step__16__0 ..... [PASS in 0.01s]
13:47:03  4 of 10 START test is_yyyy_mm_rep_sales_funnel_monthly_year_month .............. [RUN]
13:47:03  4 of 10 PASS is_yyyy_mm_rep_sales_funnel_monthly_year_month .................... [PASS in 0.01s]
13:47:03  5 of 10 START test not_null_dim_users_user_id .................................. [RUN]
13:47:03  5 of 10 PASS not_null_dim_users_user_id ........................................ [PASS in 0.01s]
13:47:03  6 of 10 START test not_null_rep_sales_funnel_monthly_deal_count ................ [RUN]
13:47:03  6 of 10 PASS not_null_rep_sales_funnel_monthly_deal_count ...................... [PASS in 0.01s]
13:47:03  7 of 10 START test not_null_rep_sales_funnel_monthly_step ...................... [RUN]
13:47:03  7 of 10 PASS not_null_rep_sales_funnel_monthly_step ............................ [PASS in 0.01s]
13:47:03  8 of 10 START test not_null_rep_sales_funnel_monthly_year_month ................ [RUN]
13:47:03  8 of 10 PASS not_null_rep_sales_funnel_monthly_year_month ...................... [PASS in 0.01s]
13:47:03  9 of 10 START test relationships_dim_users_user_id__user_id__ref_stg_users_ .... [RUN]
13:47:03  9 of 10 PASS relationships_dim_users_user_id__user_id__ref_stg_users_ .......... [PASS in 0.01s]
13:47:03  10 of 10 START test unique_dim_users_user_id ................................... [RUN]
13:47:03  10 of 10 PASS unique_dim_users_user_id ......................................... [PASS in 0.01s]
13:47:03  
13:47:03  Finished running 10 tests in 0 hours 0 minutes and 0.24 seconds (0.24s).
13:47:03  
13:47:03  Completed successfully
13:47:03  
13:47:03  Done. PASS=10 WARN=0 ERROR=0 SKIP=0 TOTAL=10
(base) Mac:dbt_enpal_assessment kamalkumar$ dbt run
13:47:08  Running with dbt=1.7.19
13:47:08  Registered adapter: postgres=1.10.0
13:47:08  Found 11 models, 11 tests, 6 sources, 0 exposures, 0 metrics, 560 macros, 0 groups, 0 semantic models
13:47:08  
13:47:09  Concurrency: 1 threads (target='dev')
13:47:09  
13:47:09  1 of 11 START sql table model core.dim_stages .................................. [RUN]
13:47:09  1 of 11 OK created sql table model core.dim_stages ............................. [SELECT 9 in 0.05s]
13:47:09  2 of 11 START sql table model core.fct_activities .............................. [RUN]
13:47:09  2 of 11 OK created sql table model core.fct_activities ......................... [SELECT 4579 in 0.02s]
13:47:09  3 of 11 START sql view model intermediate.int_field_configs .................... [RUN]
13:47:09  3 of 11 OK created sql view model intermediate.int_field_configs ............... [CREATE VIEW in 0.03s]
13:47:09  4 of 11 START sql view model intermediate.int_funnel_activities ................ [RUN]
13:47:09  4 of 11 OK created sql view model intermediate.int_funnel_activities ........... [CREATE VIEW in 0.02s]
13:47:09  5 of 11 START sql view model staging.stg_deal_changes .......................... [RUN]
13:47:09  5 of 11 OK created sql view model staging.stg_deal_changes ..................... [CREATE VIEW in 0.02s]
13:47:09  6 of 11 START sql view model staging.stg_users ................................. [RUN]
13:47:09  6 of 11 OK created sql view model staging.stg_users ............................ [CREATE VIEW in 0.02s]
13:47:09  7 of 11 START sql view model intermediate.int_funnel_metadata_changes .......... [RUN]
13:47:09  7 of 11 OK created sql view model intermediate.int_funnel_metadata_changes ..... [CREATE VIEW in 0.06s]
13:47:09  8 of 11 START sql view model intermediate.int_funnel_stages .................... [RUN]
13:47:09  8 of 11 OK created sql view model intermediate.int_funnel_stages ............... [CREATE VIEW in 0.02s]
13:47:09  9 of 11 START sql view model intermediate.int_months_spine ..................... [RUN]
13:47:09  9 of 11 OK created sql view model intermediate.int_months_spine ................ [CREATE VIEW in 0.02s]
13:47:09  10 of 11 START sql table model core.dim_users .................................. [RUN]
13:47:09  10 of 11 OK created sql table model core.dim_users ............................. [SELECT 1787 in 0.02s]
13:47:09  11 of 11 START sql table model marts.rep_sales_funnel_monthly .................. [RUN]
13:47:09  11 of 11 OK created sql table model marts.rep_sales_funnel_monthly ............. [SELECT 165 in 0.06s]
13:47:09  
13:47:09  Finished running 4 table models, 7 view models in 0 hours 0 minutes and 0.47 seconds (0.47s).
13:47:09  
13:47:09  Completed successfully
13:47:09  
13:47:09  Done. PASS=11 WARN=0 ERROR=0 SKIP=0 TOTAL=11
(base) Mac:dbt_enpal_assessment kamalkumar$ dbt show -s rep_sales_funnel_monthly --limit 500
13:47:22  Running with dbt=1.7.19
13:47:22  Registered adapter: postgres=1.10.0
13:47:22  Found 11 models, 11 tests, 6 sources, 0 exposures, 0 metrics, 560 macros, 0 groups, 0 semantic models
13:47:22  
13:47:22  Concurrency: 1 threads (target='dev')
13:47:22  
13:47:22  Previewing node 'rep_sales_funnel_monthly':
| year_month | kpi_name             | step | deal_count |
| ---------- | -------------------- | ---- | ---------- |
| 2024-01    | Lead Generation      |  1.0 |         30 |
| 2024-02    | Lead Generation      |  1.0 |        194 |
| 2024-03    | Lead Generation      |  1.0 |        199 |
| 2024-04    | Lead Generation      |  1.0 |        230 |
| 2024-05    | Lead Generation      |  1.0 |        248 |
| 2024-06    | Lead Generation      |  1.0 |        244 |
| 2024-07    | Lead Generation      |  1.0 |        267 |
| 2024-08    | Lead Generation      |  1.0 |        240 |
| 2024-09    | Lead Generation      |  1.0 |        210 |
| 2024-10    | Lead Generation      |  1.0 |        120 |
| 2024-11    | Lead Generation      |  1.0 |         18 |
| 2024-12    | Lead Generation      |  1.0 |          0 |
| 2025-01    | Lead Generation      |  1.0 |          0 |
| 2025-02    | Lead Generation      |  1.0 |          0 |
| 2025-03    | Lead Generation      |  1.0 |          0 |
| 2024-01    | Qualified Lead       |  2.0 |          6 |
| 2024-02    | Qualified Lead       |  2.0 |         74 |
| 2024-03    | Qualified Lead       |  2.0 |        157 |
| 2024-04    | Qualified Lead       |  2.0 |        153 |
| 2024-05    | Qualified Lead       |  2.0 |        178 |
| 2024-06    | Qualified Lead       |  2.0 |        178 |
| 2024-07    | Qualified Lead       |  2.0 |        190 |
| 2024-08    | Qualified Lead       |  2.0 |        191 |
| 2024-09    | Qualified Lead       |  2.0 |        175 |
| 2024-10    | Qualified Lead       |  2.0 |        129 |
| 2024-11    | Qualified Lead       |  2.0 |         49 |
| 2024-12    | Qualified Lead       |  2.0 |          3 |
| 2025-01    | Qualified Lead       |  2.0 |          0 |
| 2025-02    | Qualified Lead       |  2.0 |          0 |
| 2025-03    | Qualified Lead       |  2.0 |          0 |
| 2024-01    | Sales Call 1         |  2.1 |        148 |
| 2024-02    | Sales Call 1         |  2.1 |        117 |
| 2024-03    | Sales Call 1         |  2.1 |        125 |
| 2024-04    | Sales Call 1         |  2.1 |        134 |
| 2024-05    | Sales Call 1         |  2.1 |        122 |
| 2024-06    | Sales Call 1         |  2.1 |        141 |
| 2024-07    | Sales Call 1         |  2.1 |        165 |
| 2024-08    | Sales Call 1         |  2.1 |        130 |
| 2024-09    | Sales Call 1         |  2.1 |         63 |
| 2024-10    | Sales Call 1         |  2.1 |          0 |
| 2024-11    | Sales Call 1         |  2.1 |          0 |
| 2024-12    | Sales Call 1         |  2.1 |          0 |
| 2025-01    | Sales Call 1         |  2.1 |          0 |
| 2025-02    | Sales Call 1         |  2.1 |          0 |
| 2025-03    | Sales Call 1         |  2.1 |          0 |
| 2024-01    | Needs Assessment     |  3.0 |          0 |
| 2024-02    | Needs Assessment     |  3.0 |         27 |
| 2024-03    | Needs Assessment     |  3.0 |        142 |
| 2024-04    | Needs Assessment     |  3.0 |        131 |
| 2024-05    | Needs Assessment     |  3.0 |        149 |
| 2024-06    | Needs Assessment     |  3.0 |        168 |
| 2024-07    | Needs Assessment     |  3.0 |        168 |
| 2024-08    | Needs Assessment     |  3.0 |        175 |
| 2024-09    | Needs Assessment     |  3.0 |        128 |
| 2024-10    | Needs Assessment     |  3.0 |        138 |
| 2024-11    | Needs Assessment     |  3.0 |         67 |
| 2024-12    | Needs Assessment     |  3.0 |         14 |
| 2025-01    | Needs Assessment     |  3.0 |          1 |
| 2025-02    | Needs Assessment     |  3.0 |          0 |
| 2025-03    | Needs Assessment     |  3.0 |          0 |
| 2024-01    | Sales Call 2         |  3.1 |        139 |
| 2024-02    | Sales Call 2         |  3.1 |        117 |
| 2024-03    | Sales Call 2         |  3.1 |        148 |
| 2024-04    | Sales Call 2         |  3.1 |        123 |
| 2024-05    | Sales Call 2         |  3.1 |        132 |
| 2024-06    | Sales Call 2         |  3.1 |        127 |
| 2024-07    | Sales Call 2         |  3.1 |        135 |
| 2024-08    | Sales Call 2         |  3.1 |        140 |
| 2024-09    | Sales Call 2         |  3.1 |         63 |
| 2024-10    | Sales Call 2         |  3.1 |          0 |
| 2024-11    | Sales Call 2         |  3.1 |          0 |
| 2024-12    | Sales Call 2         |  3.1 |          0 |
| 2025-01    | Sales Call 2         |  3.1 |          0 |
| 2025-02    | Sales Call 2         |  3.1 |          0 |
| 2025-03    | Sales Call 2         |  3.1 |          0 |
| 2024-01    | Proposal/Quote Pr... |  4.0 |          1 |
| 2024-02    | Proposal/Quote Pr... |  4.0 |         17 |
| 2024-03    | Proposal/Quote Pr... |  4.0 |         75 |
| 2024-04    | Proposal/Quote Pr... |  4.0 |        100 |
| 2024-05    | Proposal/Quote Pr... |  4.0 |        122 |
| 2024-06    | Proposal/Quote Pr... |  4.0 |        138 |
| 2024-07    | Proposal/Quote Pr... |  4.0 |        127 |
| 2024-08    | Proposal/Quote Pr... |  4.0 |        156 |
| 2024-09    | Proposal/Quote Pr... |  4.0 |        131 |
| 2024-10    | Proposal/Quote Pr... |  4.0 |        118 |
| 2024-11    | Proposal/Quote Pr... |  4.0 |         72 |
| 2024-12    | Proposal/Quote Pr... |  4.0 |         28 |
| 2025-01    | Proposal/Quote Pr... |  4.0 |          2 |
| 2025-02    | Proposal/Quote Pr... |  4.0 |          0 |
| 2025-03    | Proposal/Quote Pr... |  4.0 |          0 |
| 2024-01    | Negotiation          |  5.0 |          0 |
| 2024-02    | Negotiation          |  5.0 |         10 |
| 2024-03    | Negotiation          |  5.0 |         51 |
| 2024-04    | Negotiation          |  5.0 |         85 |
| 2024-05    | Negotiation          |  5.0 |         97 |
| 2024-06    | Negotiation          |  5.0 |        114 |
| 2024-07    | Negotiation          |  5.0 |         96 |
| 2024-08    | Negotiation          |  5.0 |        104 |
| 2024-09    | Negotiation          |  5.0 |        131 |
| 2024-10    | Negotiation          |  5.0 |        110 |
| 2024-11    | Negotiation          |  5.0 |         64 |
| 2024-12    | Negotiation          |  5.0 |         28 |
| 2025-01    | Negotiation          |  5.0 |          5 |
| 2025-02    | Negotiation          |  5.0 |          0 |
| 2025-03    | Negotiation          |  5.0 |          0 |
| 2024-01    | Closing              |  6.0 |          0 |
| 2024-02    | Closing              |  6.0 |          8 |
| 2024-03    | Closing              |  6.0 |         28 |
| 2024-04    | Closing              |  6.0 |         72 |
| 2024-05    | Closing              |  6.0 |         84 |
| 2024-06    | Closing              |  6.0 |         89 |
| 2024-07    | Closing              |  6.0 |         95 |
| 2024-08    | Closing              |  6.0 |         99 |
| 2024-09    | Closing              |  6.0 |         78 |
| 2024-10    | Closing              |  6.0 |         84 |
| 2024-11    | Closing              |  6.0 |         60 |
| 2024-12    | Closing              |  6.0 |         34 |
| 2025-01    | Closing              |  6.0 |         10 |
| 2025-02    | Closing              |  6.0 |          0 |
| 2025-03    | Closing              |  6.0 |          0 |
| 2024-01    | Implementation/On... |  7.0 |          0 |
| 2024-02    | Implementation/On... |  7.0 |          1 |
| 2024-03    | Implementation/On... |  7.0 |         21 |
| 2024-04    | Implementation/On... |  7.0 |         43 |
| 2024-05    | Implementation/On... |  7.0 |         49 |
| 2024-06    | Implementation/On... |  7.0 |         70 |
| 2024-07    | Implementation/On... |  7.0 |         91 |
| 2024-08    | Implementation/On... |  7.0 |         74 |
| 2024-09    | Implementation/On... |  7.0 |         70 |
| 2024-10    | Implementation/On... |  7.0 |         79 |
| 2024-11    | Implementation/On... |  7.0 |         50 |
| 2024-12    | Implementation/On... |  7.0 |         29 |
| 2025-01    | Implementation/On... |  7.0 |          9 |
| 2025-02    | Implementation/On... |  7.0 |          2 |
| 2025-03    | Implementation/On... |  7.0 |          0 |
| 2024-01    | Follow-up/Custome... |  8.0 |          0 |
| 2024-02    | Follow-up/Custome... |  8.0 |          0 |
| 2024-03    | Follow-up/Custome... |  8.0 |         12 |
| 2024-04    | Follow-up/Custome... |  8.0 |         33 |
| 2024-05    | Follow-up/Custome... |  8.0 |         59 |
| 2024-06    | Follow-up/Custome... |  8.0 |         65 |
| 2024-07    | Follow-up/Custome... |  8.0 |         55 |
| 2024-08    | Follow-up/Custome... |  8.0 |         74 |
| 2024-09    | Follow-up/Custome... |  8.0 |         51 |
| 2024-10    | Follow-up/Custome... |  8.0 |         52 |
| 2024-11    | Follow-up/Custome... |  8.0 |         46 |
| 2024-12    | Follow-up/Custome... |  8.0 |         20 |
| 2025-01    | Follow-up/Custome... |  8.0 |         10 |
| 2025-02    | Follow-up/Custome... |  8.0 |          2 |
| 2025-03    | Follow-up/Custome... |  8.0 |          0 |
| 2024-01    | Renewal/Expansion    |  9.0 |          0 |
| 2024-02    | Renewal/Expansion    |  9.0 |          2 |
| 2024-03    | Renewal/Expansion    |  9.0 |          7 |
| 2024-04    | Renewal/Expansion    |  9.0 |         23 |
| 2024-05    | Renewal/Expansion    |  9.0 |         25 |
| 2024-06    | Renewal/Expansion    |  9.0 |         42 |
| 2024-07    | Renewal/Expansion    |  9.0 |         48 |
| 2024-08    | Renewal/Expansion    |  9.0 |         37 |
| 2024-09    | Renewal/Expansion    |  9.0 |         43 |
| 2024-10    | Renewal/Expansion    |  9.0 |         36 |
| 2024-11    | Renewal/Expansion    |  9.0 |         31 |
| 2024-12    | Renewal/Expansion    |  9.0 |         19 |
| 2025-01    | Renewal/Expansion    |  9.0 |         10 |
| 2025-02    | Renewal/Expansion    |  9.0 |          1 |
| 2025-03    | Renewal/Expansion    |  9.0 |          0 |

(base) Mac:dbt_enpal_assessment kamalkumar$ 
```
---
## **Thanks**
