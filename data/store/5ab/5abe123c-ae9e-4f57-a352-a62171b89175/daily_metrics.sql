ATTACH TABLE _ UUID '87f737ee-2b34-4ba9-ac75-fef1d336de64'
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
ENGINE = SummingMergeTree
ORDER BY (event_date, platform, item_category)
SETTINGS index_granularity = 8192
