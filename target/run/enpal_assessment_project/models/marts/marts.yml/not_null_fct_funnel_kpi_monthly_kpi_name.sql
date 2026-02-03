select
      count(*) as failures,
      count(*) != 0 as should_warn,
      count(*) != 0 as should_error
    from (
      
    
    



select kpi_name
from "postgres"."marts"."fct_funnel_kpi_monthly"
where kpi_name is null



      
    ) dbt_internal_test