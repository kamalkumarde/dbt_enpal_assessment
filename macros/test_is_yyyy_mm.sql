{% test is_yyyy_mm(model, column_name) %}

with validation as (
    select
        {{ column_name }} as date_col
    from {{ model }}
)
select *
from validation
where date_col !~ '^\d{4}-(0[1-9]|1[0-2])$'

{% endtest %}