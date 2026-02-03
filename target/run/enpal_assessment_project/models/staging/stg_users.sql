
  create view "postgres"."staging"."stg_users__dbt_tmp"
    
    
  as (
    select
    id as user_id,
    name as user_name,
    email as user_email,
    modified as modified_at
from "postgres"."public"."users"
  );