
  create view "postgres"."intermediate"."int_funnel_stages__dbt_tmp"
    
    
  as (
    with stage_history as (
    select
        deal_id,
        change_time as entered_at,
        new_value::integer as option_id,
        changed_field_key,
        -- Use LEAD to find the next change_time for this specific deal
        lead(change_time) over (
            partition by deal_id 
            order by change_time asc
        ) as exited_at
    from "postgres"."staging"."stg_deal_changes"
    where changed_field_key in ('stage_id', 'lost_reason')
)

select 
    
    DATE_TRUNC('month', h.entered_at)::date
 as month,
    conf.option_name as kpi_name,
    case 
        when h.changed_field_key = 'stage_id' then conf.option_id::float 
        else conf.option_id::float + 10 
    end as step,
    h.deal_id,
    h.entered_at,
    h.exited_at
from stage_history h
join "postgres"."intermediate"."int_field_configs" conf 
    on h.option_id = conf.option_id::integer 
    and h.changed_field_key = conf.field_key
  );