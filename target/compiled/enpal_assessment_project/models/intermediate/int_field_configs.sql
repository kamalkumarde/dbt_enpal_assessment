select
    field_key,
    name as field_display_name,
    elem ->> 'id' as option_id,
    elem ->> 'label' as option_name
from "postgres"."public"."fields"
cross join lateral jsonb_array_elements(field_value_options) as elem