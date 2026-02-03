select 
    a.deal_id,
    a.assigned_to_user as user_id,
    
    DATE_TRUNC('month', a.due_to)::date
 as month,
    
    CASE t.name
        WHEN 'Sales Call 1' THEN 2.1
        WHEN 'Sales Call 2' THEN 3.1
        WHEN 'Follow Up Call' THEN 14.1
        WHEN 'After Close Call' THEN 15.1
        ELSE NULL
    END
 as step, -- This line executes the macro
    t.name as kpi_name
from "postgres"."public"."activity" a
join "postgres"."public"."activity_types" t on a.type = t.type
where 
    CASE t.name
        WHEN 'Sales Call 1' THEN 2.1
        WHEN 'Sales Call 2' THEN 3.1
        WHEN 'Follow Up Call' THEN 14.1
        WHEN 'After Close Call' THEN 15.1
        ELSE NULL
    END
 is not null