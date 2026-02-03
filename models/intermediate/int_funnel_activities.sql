select 
    a.deal_id,
    a.assigned_to_user as user_id,
    {{ to_month('a.due_to') }} as month,
    {{ get_activity_step('t.name') }} as step, -- This line executes the macro
    t.name as kpi_name
from {{ source('raw', 'activity') }} a
join {{ source('raw', 'activity_types') }} t on a.type = t.type
where {{ get_activity_step('t.name') }} is not null