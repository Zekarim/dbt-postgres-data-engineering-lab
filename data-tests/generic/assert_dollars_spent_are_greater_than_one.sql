{% test average_dollars_spent_greater_than_one( model, column_name, group_by_column) %}

select 
    {{ group_by_column }},
    avg( {{ column_name }} )

from {{ model }}
group by 1
having avg( {{ column_name }} ) < 1


{% endtest %}