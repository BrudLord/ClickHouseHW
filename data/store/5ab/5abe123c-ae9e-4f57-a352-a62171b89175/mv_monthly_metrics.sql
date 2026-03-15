ATTACH MATERIALIZED VIEW _ UUID '5a6f3782-8e1f-4c16-bcfc-46f82fd49e61' TO avito_hw.monthly_metrics
(
    `month` Date,
    `platform` Enum8('ios' = 1, 'android' = 2, 'web' = 3),
    `item_category` Enum8('auto' = 1, 'realty' = 2, 'electronics' = 3, 'services' = 4, 'jobs' = 5, 'personal_items' = 6, 'clothes' = 7),
    `total_events` UInt64,
    `unique_users` UInt64,
    `views_count` UInt64,
    `contacts_count` UInt64,
    `purchases_count` UInt64,
    `created_items_count` UInt64,
    `removed_items_count` UInt64,
    `promoted_items_count` UInt64,
    `revenue_sum` UInt64
)
AS SELECT
    toStartOfMonth(event_date) AS month,
    platform,
    item_category,
    count() AS total_events,
    uniq(user_id) AS unique_users,
    countIf(event_type = 'view_item') AS views_count,
    countIf(event_type IN ('show_phone', 'send_message', 'open_chat')) AS contacts_count,
    countIf(event_type = 'purchase') AS purchases_count,
    countIf(event_type = 'create_item') AS created_items_count,
    countIf(event_type = 'remove_item') AS removed_items_count,
    countIf(event_type = 'promote_item') AS promoted_items_count,
    sum(revenue) AS revenue_sum
FROM avito_hw.events
GROUP BY
    month,
    platform,
    item_category
