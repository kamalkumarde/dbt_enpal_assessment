
  create view "postgres"."intermediate"."int_funnel_stages__dbt_tmp"
    
    
  as (
    with stage_history as (
    select
        deal_id,
        change_time,
        new_value::integer as option_id,
        changed_field_key
    from "postgres"."staging"."stg_deal_changes"
    where changed_field_key in ('stage_id', 'lost_reason')
)
select 
    
    DATE_TRUNC('month', h.change_time)::date
 as month,
    conf.option_name as kpi_name,
    case 
        when h.changed_field_key = 'stage_id' then conf.option_id::float 
        else conf.option_id::float + 10 
    end as step,
    h.deal_id
from stage_history h
join "postgres"."intermediate"."int_field_configs" conf 
    on h.option_id = conf.option_id::integer 
    and h.changed_field_key = conf.field_key
  );