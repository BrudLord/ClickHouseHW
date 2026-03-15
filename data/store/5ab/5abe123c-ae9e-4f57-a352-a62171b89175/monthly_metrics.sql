ATTACH TABLE _ UUID '1532ffb9-adaf-4165-854f-11152b07e506'
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
ENGINE = SummingMergeTree
ORDER BY (month, platform, item_category)
SETTINGS index_granularity = 8192
