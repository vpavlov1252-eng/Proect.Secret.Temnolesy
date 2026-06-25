WITH total_users AS (
 SELECT 
 r.race, -- Раса персонажа
 COUNT(DISTINCT u.id) AS total_users -- Общее количество уникальных пользователей
 FROM fantasy.users AS u
 LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id
 GROUP BY r.race -- Группируем только по расе
),

-- CTE для подсчета всех показателей по покупкам
purchase_summary AS (
 SELECT 
 r.race, -- Раса персонажа
 -- Подсчет платящих пользователей с использованием CASE WHEN
 COUNT(DISTINCT CASE WHEN u.payer = 1 THEN e.id END) AS paying_users,
 COUNT(DISTINCT e.id) AS total_payers, -- Общее количество покупателей
 COUNT(e.id) AS total_events, -- Общее количество событий
 SUM(e.amount) AS total_amount -- Общая сумма транзакций
 FROM fantasy.users AS u
 LEFT JOIN fantasy.events AS e ON u.id = e.id
 LEFT JOIN fantasy.race AS r ON u.race_id = r.race_id
 WHERE e.amount > 0 -- Фильтруем только положительные транзакции
 GROUP BY r.race -- Группируем только по расе
)

-- Основной запрос для расчета всех метрик
SELECT 
 pu.race, -- Раса персонажа
 
 -- Общее количество пользователей
 total_users,
 
 -- Общее количество покупателей
 total_payers,
 
 -- Доля покупателей (%)
 ROUND(CAST(total_payers AS numeric) / total_users * 100, 2) AS buyer_share,
 
 -- Доля платящих пользователей (%)
 ROUND(CAST(paying_users AS numeric) / total_payers * 100, 2) AS paying_share,
 
 -- Среднее количество покупок на пользователя
 ROUND(CAST(total_events AS numeric) / total_payers, 2) AS avg_purchases_per_user,
 
 -- Средняя стоимость одной покупки
 ROUND(CAST(total_amount AS NUMERIC) / total_events, 2) AS avg_purchase_amount,
 
 -- Средняя суммарная стоимость всех покупок
 ROUND(CAST(total_amount AS numeric) / total_payers, 2) AS avg_total_amount

FROM purchase_summary AS pu
JOIN total_users AS tu ON pu.race = tu.race -- Соединяем данные по расе
ORDER BY race; -- Сортируем по расе
-- Задача 2: Частота покупок
-- Напишите ваш запрос здесь
-- CTE для подсчета общего количества покупок и уникальных пользователей
WITH purchase_intervals AS (
    SELECT 
        id,
        amount,
        date,
        LAG(date) OVER (PARTITION BY id ORDER BY date) AS prev_date,
        -- Расчет разницы между датами в виде интервала
        AGE(date::timestamp, LAG(date::timestamp) OVER (PARTITION BY id ORDER BY date::timestamp)) AS days_between
    FROM fantasy.events
    WHERE amount > 0
),

-- CTE для расчета средних показателей по пользователям
user_metrics AS (
    SELECT 
        p.id,
        u.payer,
        COUNT(*) AS purchase_count,
        -- Извлечение только дня из среднего интервала
        EXTRACT(DAY FROM AVG(days_between)) AS avg_days_between,
        -- Определение категории частоты покупок
        CASE 
            
            WHEN AVG(days_between) <= INTERVAL '7 days' THEN 'высокая'
            WHEN AVG(days_between) BETWEEN INTERVAL '8 days' AND INTERVAL '14 days' THEN 'умеренная'
            ELSE 'низкая'
        END AS purchase_frequency
    FROM purchase_intervals p
    JOIN fantasy.users u ON p.id = u.id
    GROUP BY p.id, u.payer
    HAVING COUNT(*) >= 3 -- Минимум 3 покупки для расчета
),

-- Финальный запрос с агрегированием по категориям
final_metrics AS (
    SELECT 
        purchase_frequency,
        COUNT(DISTINCT id) AS total_users,
        SUM(CASE WHEN payer = 1 THEN 1 ELSE 0 END) AS paying_users,
        -- Расчет процента платящих пользователей
        ROUND(
            CAST(SUM(CASE WHEN payer = 1 THEN 1 ELSE 0 END) AS numeric) 
            / COUNT(DISTINCT id) * 100, 
            2
        ) AS paying_percentage,
        ROUND(AVG(purchase_count::NUMERIC), 2) AS avg_purchase_count,
        ROUND(AVG(avg_days_between::INTEGER), 2) AS avg_days_between
    FROM user_metrics
    GROUP BY purchase_frequency
)

SELECT 
    purchase_frequency,
    total_users,
    paying_users,
    paying_percentage,
    avg_purchase_count,
    avg_days_between
FROM final_metrics
ORDER BY 
    CASE purchase_frequency
        WHEN 'высокая' THEN 1
        WHEN 'умеренная' THEN 2
        WHEN 'низкая' THEN 3
    END;