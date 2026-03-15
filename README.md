# ClickHouseHW (Авито)
## Создание таблиц
Сначала создадим новую БД
```
CREATE DATABASE IF NOT EXISTS avito_hw;

USE avito_hw;
```
Далее создадим таблицу пользователей. Часть параметров очевидна для аналитики, но часть пусть лучше будет пояснена:

last_platform - сравнение использования iOS / Android / Web

user_type - типы аккаутов: покупатели, продавцы как физ лица и продавцы как юр лица 

acquisition_channel - анализ каналов привлечения

total_spent - сумма потраченных денег

has_photo - установлено ли фото профиля

all_items_count - общее число опубликованных объявлений

```
CREATE TABLE IF NOT EXISTS users
(
    user_id UInt64,
    registration_date Date,
    country LowCardinality(String),
    region LowCardinality(String),
    city LowCardinality(String),
    last_platform Enum8('ios' = 1, 'android' = 2, 'web' = 3),
    user_type Enum8('buyer' = 1, 'seller' = 2, 'business' = 3),
    acquisition_channel Enum8('organic' = 1, 'ads' = 2, 'referral' = 3, 'seo' = 4, 'smm' = 5),
    age UInt8,
    gender Enum8('male' = 1, 'female' = 2),
    is_verified UInt8,
    total_spent UInt64,
    rating Float32, 
    has_photo UInt8,
    all_items_count UInt16,
    active_items_count UInt16
)
ENGINE = MergeTree
ORDER BY user_id;
```
Теперь создаём таблицу событий. Для начала пройдёмся также по полям

event_type - тип действия пользователя

item_category - категория объявления

platform - платформа, с которой произошло событие

device_type - тип устройства

traffic_source - источник трафика

revenue - доход платформы от события

```
CREATE TABLE IF NOT EXISTS events
(
    event_id UInt64,
    event_time DateTime,
    event_date Date MATERIALIZED toDate(event_time),
    user_id UInt64,
    item_id UInt64,
    session_id UInt64,
    event_type Enum8(
        'view_item' = 1,
        'favorite_add' = 2,
        'show_phone' = 3,
        'send_message' = 4,
        'search' = 5,
        'create_item' = 6,
        'remove_item' = 7,
        'promote_item' = 8,
        'stop_promoting_item' = 9,
        'purchase' = 10,
        'open_chat' = 11,
        'close_chat' = 12
    ),
    item_category Enum8(
        'auto' = 1,
        'realty' = 2,
        'electronics' = 3,
        'services' = 4,
        'jobs' = 5,
        'personal_items' = 6,
        'clothes' = 7
    ),
    platform Enum8('ios' = 1, 'android' = 2, 'web' = 3),
    device_type Enum8('mobile' = 1, 'desktop' = 2, 'tablet' = 3),
    traffic_source Enum8('direct' = 1, 'seo' = 2, 'ads' = 3, 'push' = 4, 'email' = 5),
    item_price UInt32,
    revenue UInt32,
    search_text String
)
ENGINE = MergeTree
PARTITION BY toYYYYMM(event_date)
ORDER BY (event_date, event_type, user_id, item_id);
```

## Создание материализованных представлений
### Ежедневные отчёты
Для хранения агрегированных данных создадим отдельную таблицу daily_metrics, 
в которую материализованное представление будет записывать результаты вычислений.
```
CREATE TABLE IF NOT EXISTS daily_metrics
(
    event_date Date,
    platform Enum8('ios' = 1, 'android' = 2, 'web' = 3),
    item_category Enum8(
        'auto' = 1,
        'realty' = 2,
        'electronics' = 3,
        'services' = 4,
        'jobs' = 5,
        'personal_items' = 6,
        'clothes' = 7
    ),
    total_events UInt64,
    unique_users UInt64,
    views_count UInt64,
    searches_count UInt64,
    contacts_count UInt64,
    purchases_count UInt64,
    revenue_sum UInt64
)
ENGINE = SummingMergeTree
ORDER BY (event_date, platform, item_category);
```
Теперь запишем туда материализацию
```
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_daily_metrics
TO daily_metrics
AS
SELECT
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
FROM events
GROUP BY
    event_date,
    platform,
    item_category;
```

### Ежемесячные отчёты
Повторим для ежемесячных отчётов создание таблицы
```
CREATE TABLE IF NOT EXISTS monthly_metrics
(
    month Date,
    platform Enum8('ios' = 1, 'android' = 2, 'web' = 3),
    item_category Enum8(
        'auto' = 1,
        'realty' = 2,
        'electronics' = 3,
        'services' = 4,
        'jobs' = 5,
        'personal_items' = 6,
        'clothes' = 7
    ),
    total_events UInt64,
    unique_users UInt64,
    views_count UInt64,
    contacts_count UInt64,
    purchases_count UInt64,
    created_items_count UInt64,
    removed_items_count UInt64,
    promoted_items_count UInt64,
    revenue_sum UInt64
)
ENGINE = SummingMergeTree
ORDER BY (month, platform, item_category);
```
Теперь запишем туда материализацию
```
CREATE MATERIALIZED VIEW IF NOT EXISTS mv_monthly_metrics
TO monthly_metrics
AS
SELECT
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
FROM events
GROUP BY
    month,
    platform,
    item_category;
```

## Вставка значений
В таблицу users:
```
INSERT INTO users
SELECT
    number + 1 AS user_id,
    toDate('2020-01-01') + (number % 1000) AS registration_date,
    arrayElement(
        ['Russia', 'Kazakhstan', 'Belarus', 'Germany', 'Poland', 'Kuba'],
        (number % 6) + 1
    ) AS country,
    arrayElement(
        ['Moscow', 'Saint Petersburg', 'Berlin', 'Varshava', 'Minsk', 'Almaty', 'Bavaria'],
        (number % 7) + 1
    ) AS region,
    arrayElement(
        ['Moscow', 'Saint Petersburg', 'Berlin', 'Varshava', 'Minsk', 'Almaty', 'Munchen'],
        (number % 7) + 1
    ) AS city,
    CAST(
        arrayElement(['ios', 'android', 'web'], (number % 3) + 1),
        'Enum8(\'ios\' = 1, \'android\' = 2, \'web\' = 3)'
    ) AS last_platform,
    CAST(
        arrayElement(['buyer', 'seller', 'business'], (intDiv(number, 3) % 3) + 1),
        'Enum8(\'buyer\' = 1, \'seller\' = 2, \'business\' = 3)'
    ) AS user_type,
    CAST(
        arrayElement(['organic', 'ads', 'referral', 'seo', 'smm'], (number % 5) + 1),
        'Enum8(\'organic\' = 1, \'ads\' = 2, \'referral\' = 3, \'seo\' = 4, \'smm\' = 5)'
    ) AS acquisition_channel,
    18 + (number % 50) AS age,
    CAST(
        arrayElement(['male', 'female'], (number % 2) + 1),
        'Enum8(\'male\' = 1, \'female\' = 2)'
    ) AS gender,
    number % 2 AS is_verified,
    (number % 200000) * 100 AS total_spent,
    toFloat32(1.0 + ((number % 41) / 10.0)) AS rating,
    (number % 3 + 1) % 2 AS has_photo,
    number % 200 AS all_items_count,
    number % 100 AS active_items_count
FROM numbers(20000);
```
Вставка событий:
```
INSERT INTO events
SELECT
    number + 1 AS event_id,
    toDateTime('2023-06-01 00:00:00') + (number % 31536000) AS event_time,
    (number % 20000) + 1 AS user_id,
    (number % 2000000) + 1 AS item_id,
    (number % 3000000) + 1 AS session_id,
    CAST(
        arrayElement(
            [
                'view_item',
                'favorite_add',
                'show_phone',
                'send_message',
                'search',
                'create_item',
                'remove_item',
                'promote_item',
                'stop_promoting_item',
                'purchase',
                'open_chat',
                'close_chat'
            ],
            (number % 12) + 1
        ),
        'Enum8(
            \'view_item\' = 1,
            \'favorite_add\' = 2,
            \'show_phone\' = 3,
            \'send_message\' = 4,
            \'search\' = 5,
            \'create_item\' = 6,
            \'remove_item\' = 7,
            \'promote_item\' = 8,
            \'stop_promoting_item\' = 9,
            \'purchase\' = 10,
            \'open_chat\' = 11,
            \'close_chat\' = 12
        )'
    ) AS event_type,
    CAST(
        arrayElement(
            ['auto', 'realty', 'electronics', 'services', 'jobs', 'personal_items', 'clothes'],
            (number % 7) + 1
        ),
        'Enum8(
            \'auto\' = 1,
            \'realty\' = 2,
            \'electronics\' = 3,
            \'services\' = 4,
            \'jobs\' = 5,
            \'personal_items\' = 6,
            \'clothes\' = 7
        )'
    ) AS item_category,
    CAST(
        arrayElement(['ios', 'android', 'web'], (number % 3) + 1),
        'Enum8(\'ios\' = 1, \'android\' = 2, \'web\' = 3)'
    ) AS platform,
    CAST(
        arrayElement(['mobile', 'desktop', 'tablet'], (number % 3) + 1),
        'Enum8(\'mobile\' = 1, \'desktop\' = 2, \'tablet\' = 3)'
    ) AS device_type,
    CAST(
        arrayElement(['direct', 'seo', 'ads', 'push', 'email'], (number % 5) + 1),
        'Enum8(\'direct\' = 1, \'seo\' = 2, \'ads\' = 3, \'push\' = 4, \'email\' = 5)'
    ) AS traffic_source,
    500 + (number % 200000) AS item_price,
    multiIf(
        ((number % 12) + 1) = 8, 199 + (number % 5000),
        ((number % 12) + 1) = 10, 99 + (number % 10000),
        0
    ) AS revenue,
    arrayElement(
        [
            '',
            '',
            '',
            'iphone 15',
            'used car',
            'apartment moscow',
            'laptop',
            'winter jacket',
            'job manager',
            'sofa',
            'flat in SPb',
            'socks and socks',
            'windows'
        ],
        (number % 13) + 1
    ) AS search_text
FROM numbers(20000000);
```

## Аналитические запросы
### Динамика просмотров, контактов и покупок по дням
Показывает интерес к платформе, соотношение 
к просмотров объявлений к контактам и к реальным покупкам
```
SELECT
    item_category,
    uniqIf(user_id, event_type = 'view_item') AS viewers,
    uniqIf(user_id, event_type IN ('show_phone', 'send_message', 'open_chat')) AS contacted_users,
    uniqIf(user_id, event_type = 'purchase') AS buyers,
    round(contacted_users * 100.0 / nullIf(viewers, 0), 2) AS view_to_contact_cr,
    round(buyers * 100.0 / nullIf(contacted_users, 0), 2) AS contact_to_purchase_cr,
    round(buyers * 100.0 / nullIf(viewers, 0), 2) AS view_to_purchase_cr
FROM events
GROUP BY item_category
ORDER BY view_to_purchase_cr DESC
```
### Сравнение категорий объявлений по месяцам
Аналитика того какие категории товаров наиболее популярны в какие месяцы и какая выроучка с них
```
SELECT
    traffic_source,
    uniq(user_id) AS users,
    countIf(event_type = 'view_item') AS views,
    countIf(event_type IN ('show_phone', 'send_message', 'open_chat')) AS contacts,
    countIf(event_type = 'purchase') AS purchases,
    sum(revenue) AS revenue,
    round(contacts * 100.0 / nullIf(views, 0), 2) AS contact_rate,
    round(purchases * 100.0 / nullIf(contacts, 0), 2) AS purchase_from_contact_rate,
    round(revenue * 1.0 / nullIf(users, 0), 2) AS revenue_per_user
FROM events
GROUP BY traffic_source
ORDER BY revenue DESC
```
### Топ категорий по монетизации продвижения
```
SELECT
    item_category,
    countIf(event_type = 'promote_item') AS promotions,
    sumIf(revenue, event_type = 'promote_item') AS promotion_revenue,
    round(sumIf(revenue, event_type = 'promote_item') * 1.0 / nullIf(promotions, 0), 2) AS avg_revenue_per_promotion
FROM events
GROUP BY item_category
ORDER BY promotion_revenue DESC
```

## Использование объединения таблиц
Сравниваем то какие и в каком количестве запросы генерируют разные пользователи.
```
SELECT
    u.user_type,
    count() AS total_events,
    uniq(e.user_id) AS unique_users,
    countIf(e.event_type = 'view_item') AS views,
    countIf(e.event_type IN ('show_phone', 'send_message', 'open_chat')) AS contacts,
    countIf(e.event_type = 'purchase') AS purchases,
    countIf(e.event_type = 'promote_item') AS promotions,
    sum(e.revenue) AS revenue,
    round(countIf(e.event_type IN ('show_phone', 'send_message', 'open_chat')) * 100.0
        / nullIf(countIf(e.event_type = 'view_item'), 0), 2) AS view_to_contact_cr,
    round(countIf(e.event_type = 'purchase') * 100.0
        / nullIf(countIf(e.event_type IN ('show_phone', 'send_message', 'open_chat')), 0), 2) AS contact_to_purchase_cr,
    round(sum(e.revenue) * 1.0 / nullIf(uniq(e.user_id), 0), 2) AS revenue_per_user
FROM events e
INNER JOIN users u ON e.user_id = u.user_id
GROUP BY u.user_type
ORDER BY revenue DESC
```

## Использование словаря
В качестве ключа возьмём id:
```
CREATE DICTIONARY IF NOT EXISTS users_dict
(
    user_id UInt64,
    country String,
    region String,
    city String,
    last_platform String,
    user_type String,
    acquisition_channel String,
    age UInt8,
    gender String,
    is_verified UInt8,
    total_spent UInt64,
    rating Float32,
    has_photo UInt8,
    all_items_count UInt16,
    active_items_count UInt16
)
PRIMARY KEY user_id
SOURCE(CLICKHOUSE(
    HOST 'clickhouse'
    PORT 9000
    USER 'admin'
    PASSWORD 'password123'
    DB 'avito_hw'
    TABLE 'users'
))
LIFETIME(MIN 0 MAX 300)
LAYOUT(HASHED());
```
Новый запрос со словарём:
```
SELECT
    user_type,
    total_events,
    unique_users,
    views,
    contacts,
    purchases,
    promotions,
    revenue,
    round(contacts * 100.0 / nullIf(views, 0), 2) AS view_to_contact_cr,
    round(purchases * 100.0 / nullIf(contacts, 0), 2) AS contact_to_purchase_cr,
    round(revenue * 1.0 / nullIf(unique_users, 0), 2) AS revenue_per_user
FROM
(
    SELECT
        dictGetString('users_dict', 'user_type', user_id) AS user_type,
        count() AS total_events,
        uniq(user_id) AS unique_users,
        countIf(event_type = 'view_item') AS views,
        countIf(event_type IN ('show_phone', 'send_message', 'open_chat')) AS contacts,
        countIf(event_type = 'purchase') AS purchases,
        countIf(event_type = 'promote_item') AS promotions,
        sum(revenue) AS revenue
    FROM events
    GROUP BY user_type
)
ORDER BY revenue DESC
```