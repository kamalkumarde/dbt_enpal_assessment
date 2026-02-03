select
    id as user_id,
    name as user_name,
    email as user_email,
    modified as modified_at
from "postgres"."public"."users"