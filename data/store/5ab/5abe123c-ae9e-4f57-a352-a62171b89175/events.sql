ATTACH TABLE _ UUID 'f58ea55e-86a3-480c-892a-04199f20b7a8'
(
    `event_id` UInt64,
    `event_time` DateTime,
    `event_date` Date MATERIALIZED toDate(event_time),
    `user_id` UInt64,
    `item_id` UInt64,
    `session_id` UInt64,
    `event_type` Enum8('view_item' = 1, 'favorite_add' = 2, 'show_phone' = 3, 'send_message' = 4, 'search' = 5, 'create_item' = 6, 'remove_item' = 7, 'promote_item' = 8, 'stop_promoting_item' = 9, 'purchase' = 10, 'open_chat' = 11, 'close_chat' = 12),
    `item_category` Enum8('auto' = 1, 'realty' = 2, 'electronics' = 3, 'services' = 4, 'jobs' = 5, 'personal_items' = 6, 'clothes' = 7),
    `platform` Enum8('ios' = 1, 'android' = 2, 'web' = 3),
    `device_type` Enum8('mobile' = 1, 'desktop' = 2, 'tablet' = 3),
    `traffic_source` Enum8('direct' = 1, 'seo' = 2, 'ads' = 3, 'push' = 4, 'email' = 5),
    `item_price` UInt32,
    `revenue` UInt32,
    `search_text` String
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_date, event_type, user_id, item_id)
SETTINGS index_granularity = 8192
