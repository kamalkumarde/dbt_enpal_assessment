{% macro to_month(column_name) %}
    DATE_TRUNC('month', {{ column_name }})::date
{% endmacro %}