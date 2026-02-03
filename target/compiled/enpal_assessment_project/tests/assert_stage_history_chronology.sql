with validation as (
    select 
        deal_id,
        -- We'll use coalesce to catch whichever column name you used
        entered_at, 
        exited_at
    from "postgres"."intermediate"."int_funnel_stages"
)

select * from validation 
where exited_at < entered_at
  and exited_at is not null