
  
    

  create  table "postgres"."public_pipedrive_analytics"."fct_funnel_kpi_monthly__dbt_tmp"
  
  
    as
  
  (
    with months as (select * from "postgres"."public_pipedrive_analytics"."int_months_spine"),

-- 1 & 2. STAGES AND LOST REASONS
stage_history as (
    select
        deal_id,
        change_time as entered_at,
        new_value::integer as option_id,
        changed_field_key
    from "postgres"."public_pipedrive_analytics"."stg_deal_changes"
    where changed_field_key in ('stage_id', 'lost_reason')
),

combined_stages as (
    select 
        ms.month,
        conf.option_name as kpi_name,
        case 
            when h.changed_field_key = 'stage_id' then conf.option_id::float 
            else conf.option_id::float + 10 
        end as step,
        h.deal_id
    from months ms
    left join stage_history h on date_trunc('month', h.entered_at) = ms.month
    join "postgres"."public_pipedrive_analytics"."int_field_configs" conf 
        on h.option_id = conf.option_id::integer 
        and h.changed_field_key = conf.field_key
),

-- 3. ACTIVITIES
activity_logic as (
    select 
        a.deal_id,
        date_trunc('month', a.due_to)::date as activity_month,
        case t.name 
            when 'Sales Call 1' then 2.1 
            when 'Sales Call 2' then 3.1
            when 'Follow Up Call' then 14.1
            when 'After Close Call' then 15.1
        end as step,
        t.name as kpi_name
    from "postgres"."public"."activity" a
    join "postgres"."public"."activity_types" t on a.type = t.type
),

-- 4 & 5. FIELD CREATION (ADD TIME / USER ID)
field_creation as (
    select 
        dc.change_month as month,
        f.name as kpi_name,
        case dc.changed_field_key when 'add_time' then 0.0 else 0.1 end as step,
        dc.deal_id
    from "postgres"."public_pipedrive_analytics"."stg_deal_changes" dc
    join "postgres"."public"."fields" f on dc.changed_field_key = f.field_key
    where dc.changed_field_key in ('add_time', 'user_id')
),

-- FINAL UNION
final_unioned as (
    select month, kpi_name, step, count(*) as deal_count from combined_stages group by 1,2,3
    union all
    select activity_month, kpi_name, step, count(*) from activity_logic group by 1,2,3
    union all
    select month, kpi_name, step, count(*) from field_creation group by 1,2,3
)

select * from final_unioned
order by step, kpi_name, month
  );
  