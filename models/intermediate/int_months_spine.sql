with date_range as (
    select 
        min(change_time)::date as start_date, 
        max(change_time)::date as end_date 
    from {{ ref('stg_deal_changes') }}
)
select 
    generate_series(
        date_trunc('month', start_date), 
        date_trunc('month', end_date), 
        '1 month'::interval
    )::date as month_date 
from date_range