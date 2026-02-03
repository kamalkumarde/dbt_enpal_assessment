{% macro get_activity_step(activity_name) %}
    CASE {{ activity_name }}
        WHEN 'Sales Call 1' THEN 2.1
        WHEN 'Sales Call 2' THEN 3.1
        WHEN 'Follow Up Call' THEN 14.1
        WHEN 'After Close Call' THEN 15.1
        ELSE NULL
    END
{% endmacro %}