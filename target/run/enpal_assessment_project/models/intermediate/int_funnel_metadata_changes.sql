
  create view "postgres"."intermediate"."int_funnel_metadata_changes__dbt_tmp"
    
    
  as (
    select 
    dc.deal_id,
    -- Using our macro for consistency
    
    DATE_TRUNC('month', dc.change_time)::date
 as month,
    f.name as kpi_name,
    -- Defining the starting steps of the funnel
    case dc.changed_field_key 
        when 'add_time' then 0.0  -- Deal Created
        when 'user_id'  then 0.1  -- Deal Assigned to Rep
        else 0.9 
    end as step,
    -- We include user_id here if we want to slice the funnel by owner later
    dc.new_value as metadata_value 
from "postgres"."staging"."stg_deal_changes" dc
join "postgres"."public"."fields" f on dc.changed_field_key = f.field_key
where dc.changed_field_key in ('add_time', 'user_id')
  );