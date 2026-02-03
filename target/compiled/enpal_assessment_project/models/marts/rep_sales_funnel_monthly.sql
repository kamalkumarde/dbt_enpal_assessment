with months as (
    select month_date from "postgres"."intermediate"."int_months_spine"
),

-- Get every unique stage/kpi name that exists in your funnel
all_stages as (
    select distinct kpi_name, step 
    from (
        select kpi_name, step from "postgres"."intermediate"."int_funnel_stages"
        union all
        select kpi_name, step from "postgres"."intermediate"."int_funnel_activities"
        union all
        select kpi_name, step from "postgres"."intermediate"."int_funnel_metadata_changes"
    )
    where step >= 1 and step <= 9
),

-- Create the master grid: Every month X Every stage
grid as (
    select 
        m.month_date,
        s.kpi_name,
        s.step
    from months m
    cross join all_stages s
),

unioned_data as (
    select month, kpi_name, step, deal_id from "postgres"."intermediate"."int_funnel_stages"
    union all
    select month, kpi_name, step, deal_id from "postgres"."intermediate"."int_funnel_activities"
    union all
    select month, kpi_name, step, deal_id from "postgres"."intermediate"."int_funnel_metadata_changes"
)

select 
    to_char(g.month_date, 'YYYY-MM') as year_month,
    g.kpi_name,
    g.step,
    count(distinct d.deal_id) as deal_count
from grid g
left join unioned_data d 
    on g.month_date = d.month 
    and g.kpi_name = d.kpi_name
group by g.month_date, g.kpi_name, g.step
order by g.step,g.month_date