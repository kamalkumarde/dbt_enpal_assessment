select
    stage_id,
    stage_name
from {{ source('raw', 'stages') }}