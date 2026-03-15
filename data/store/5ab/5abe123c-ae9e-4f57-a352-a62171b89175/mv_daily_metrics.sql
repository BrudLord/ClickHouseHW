ATTACH MATERIALIZED VIEW _ UUID '544bd4fb-30b2-4152-83cd-9c6371e61324' TO avito_hw.daily_metrics
(
    `event_date` Date,
    `platform` Enum8('ios' = 1, 'android' = 2, 'web' = 3),
    `item_category` Enum8('auto' = 1, 'realty' = 2, 'electronics' = 3, 'services' = 4, 'jobs' = 5, 'personal_items' = 6, 'clothes' = 7),
    `total_events` UInt64,
    `unique_users` UInt64,
    `views_count` UInt64,
    `searches_count` UInt64,
    `contacts_count` UInt64,
    `purchases_count` UInt64,
    `revenue_sum` UInt64
)
AS SELECT
    event_date,
    platform,
    item_category,
    count() AS total_events,
    uniq(user_id) AS unique_users,
    countIf(event_type = 'view_item') AS views_count,
    countIf(event_type = 'search') AS searches_count,
    countIf(event_type IN ('show_phone', 'send_message', 'open_chat')) AS contacts_count,
    countIf(event_type = 'purchase') AS purchases_count,
    sum(revenue) AS revenue_sum
FROM avito_hw.events
GROUP BY
    event_date,
    platform,
    item_category
