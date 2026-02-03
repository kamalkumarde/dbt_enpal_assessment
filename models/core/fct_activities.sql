select
    activity_id,
    deal_id,
    assigned_to_user as user_id,
    type as activity_type,
    done as is_completed,
    due_to as scheduled_at,
    {{ to_month('due_to') }} as activity_month
from {{ source('raw', 'activity') }}