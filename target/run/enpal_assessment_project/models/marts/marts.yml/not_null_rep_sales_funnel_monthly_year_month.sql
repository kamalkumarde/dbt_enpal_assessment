select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select year_month
from "postgres"."marts"."rep_sales_funnel_monthly"
where year_month is null



      
    ) dbt_internal_test