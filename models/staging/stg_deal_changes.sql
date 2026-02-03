select
    deal_id,
    change_time,
    changed_field_key,
    new_value,
    {{ to_month('change_time') }} as change_month
from {{ source('raw', 'deal_changes') }}