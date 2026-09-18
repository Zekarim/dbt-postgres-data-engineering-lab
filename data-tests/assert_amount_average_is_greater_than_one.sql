{{ config(enabled = false) }}
select
    customer_id,
    avg(order_total) as average_amount
from {{ ref('orders') }}
group by 1
having count(customer_id) > 1
   and avg(order_total) < 1