select
    activity_id,
    deal_id,
    assigned_to_user as user_id,
    type as activity_type,
    done as is_completed,
    due_to as scheduled_at,
    
    DATE_TRUNC('month', due_to)::date
 as activity_month
from "postgres"."public"."activity"