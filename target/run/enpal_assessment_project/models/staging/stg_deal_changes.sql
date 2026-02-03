
  create view "postgres"."staging"."stg_deal_changes__dbt_tmp"
    
    
  as (
    select
    deal_id,
    change_time,
    changed_field_key,
    new_value,
    
    DATE_TRUNC('month', change_time)::date
 as change_month
from "postgres"."public"."deal_changes"
  );