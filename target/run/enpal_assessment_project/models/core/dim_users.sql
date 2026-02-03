
  
    

  create  table "postgres"."core"."dim_users__dbt_tmp"
  
  
    as
  
  (
    

select
    user_id,
    user_name,
    user_email,
    modified_at
from "postgres"."staging"."stg_users"
  );
  