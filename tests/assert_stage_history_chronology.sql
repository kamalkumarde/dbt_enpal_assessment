with validation as (
    select 
        deal_id,
        
        entered_at, 
        exited_at
    from {{ ref('int_funnel_stages') }}
)

select * from validation 
where exited_at < entered_at
  and exited_at is not null