select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select step
from "postgres"."marts"."rep_sales_funnel_monthly"
where step is null



      
    ) dbt_internal_test