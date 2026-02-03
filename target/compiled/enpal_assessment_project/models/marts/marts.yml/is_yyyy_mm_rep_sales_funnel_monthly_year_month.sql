

with validation as (
    select
        year_month as date_col
    from "postgres"."marts"."rep_sales_funnel_monthly"
)
select *
from validation
where date_col !~ '^\d{4}-(0[1-9]|1[0-2])$'

