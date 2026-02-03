with range_values as (
    select 
        min(change_time) as start_date, 
        max(change_time) as end_date 
    from "postgres"."public_pipedrive_analytics"."stg_deal_changes"
)
select 
    generate_series(start_date, end_date, '1 month')::date as month
from range_values