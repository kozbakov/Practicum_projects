/* Проект «Секреты Тёмнолесья»
 * Цель проекта: изучить влияние характеристик игроков и их игровых персонажей 
 * на покупку внутриигровой валюты «райские лепестки», а также оценить 
 * активность игроков при совершении внутриигровых покупок
 * 
 * Автор: Козбаков Айдын
 * Дата: 13.01.2026
*/

-- Часть 1. Исследовательский анализ данных
-- Задача 1. Исследование доли платящих игроков
-- 1.1. Доля платящих пользователей по всем данным:
-- Напишите ваш запрос здесь
SELECT 
	sum(payer) AS cnt_pay_id, 
	count(id) AS cnt_id,  
	round(avg(payer)::numeric * 100,2) AS ratio
FROM fantasy.users u

--cnt_pay_id|cnt_id|ratio|
------------+------+-----+
--      3929| 22214|17.69|
--17% от всех пользователей является платящими

-- 1.2. Доля платящих пользователей в разрезе расы персонажа:
-- Напишите ваш запрос здесь
SELECT 
	race, 
	sum(payer) AS cnt_pay_id, 
	count(id) AS cnt_id,
	round(avg(payer)::numeric * 100,2) AS ratio 
FROM fantasy.race r 
JOIN fantasy.users u using(race_id)
GROUP BY race
ORDER BY cnt_pay_id DESC

--race    |cnt_pay_id|cnt_id|ratio|
----------+----------+------+-----+
--Human   |      1114|  6328|17.60|
--Hobbit  |       659|  3648|18.06|
--Orc     |       636|  3619|17.57|
--Northman|       626|  3562|17.57|
--Elf     |       427|  2501|17.07|
--Demon   |       238|  1229|19.37|
--Angel   |       229|  1327|17.26|
-- Самая популярная раса - Human

-- Задача 2. Исследование внутриигровых покупок
-- 2.1. Статистические показатели по полю amount:
-- Напишите ваш запрос здесь
SELECT 
	count(amount) AS count_amount,
	sum(amount) AS sum_amount,
	min(amount) AS min_amount,
	max(amount) AS max_amount,
	round(avg(amount)::decimal,2) AS avg_amount,
	percentile_disc(0.5) WITHIN GROUP (ORDER BY amount) AS median_amount,
	round(stddev(amount)::decimal,2) AS stddev_amount 
FROM fantasy.events e 
WHERE amount > 0

--count_amount|sum_amount|min_amount|max_amount|avg_amount|median_amount|stddev_amount|
--------------+----------+----------+----------+----------+-------------+-------------+
--     1306771| 686615040|      0.01|  486615.1|    526.06|        74.86|      2518.18|


-- 2.2: Аномальные нулевые покупки:
-- Напишите ваш запрос здесь
SELECT
    SUM((amount = 0)::int) AS zero_amount,
    COUNT(*) AS count_trans,
    AVG((amount = 0)::int)::real AS ratio
FROM fantasy.events;

--zero_amount|count_trans|ratio    |
-------------+-----------+---------+
--        907|    1307678|0.0006936|

-- 2.3: Популярные эпические предметы:
-- Напишите ваш запрос здесь
SELECT 
    game_items,
    COUNT(*) AS sales_count,
    round(COUNT(*) 
        / (SELECT COUNT(*) FROM fantasy.events WHERE amount > 0)::NUMERIC*100,2) 
        AS sales_ratio,
    round(COUNT(DISTINCT e.id)
        / (SELECT COUNT(DISTINCT id) FROM fantasy.events WHERE amount > 0)::NUMERIC*100,2)
        AS user_ratio
FROM fantasy.items i
JOIN fantasy.events e USING(item_code)
WHERE amount > 0
GROUP BY game_items
ORDER BY sales_count DESC;

--game_items               |sales_count|sales_ratio|user_ratio|
---------------------------+-----------+-----------+----------+
--Book of Legends          |    1004516|      76.87|     88.41|
--Bag of Holding           |     271875|      20.81|     86.77|
--Necklace of Wisdom       |      13828|       1.06|     11.80|
--Gems of Insight          |       3833|       0.29|      6.71|
--Treasure Map             |       3183|       0.24|      5.94|
--Amulet of Protection     |       1078|       0.08|      3.23|

-- Часть 2. Решение ad hoc-задачи
-- Задача: Зависимость активности игроков от расы персонажа:
-- Напишите ваш запрос здесь
WITH users_by_race AS (
	SELECT 
		race,
		count(u.id) AS total_users
	FROM fantasy.users u 
	JOIN fantasy.race r using(race_id)
	GROUP BY race 
	ORDER BY total_users DESC
),-- тут я добавил долю покупателей
buyers_by_race AS (
	SELECT 
    r.race,
    -- количество покупателей
    COUNT(DISTINCT u.id) FILTER (WHERE e.amount > 0) AS buyers,
    -- доля покупателей от всех игроков расы
    ROUND(COUNT(DISTINCT u.id) FILTER (WHERE e.amount > 0) / COUNT(DISTINCT u.id)::NUMERIC * 100, 2) AS buyers_ratio,
    -- доля платящих среди покупателей
    ROUND(COUNT(DISTINCT u.id) FILTER (WHERE e.amount > 0 AND u.payer = 1) / COUNT(DISTINCT u.id) FILTER (WHERE e.amount > 0)::NUMERIC * 100, 2 ) AS payer_ratio
FROM fantasy.users u
JOIN fantasy.race r USING (race_id)
LEFT JOIN fantasy.events e USING (id)
GROUP BY r.race
ORDER BY buyers DESC 
),
player_activity AS (
	SELECT 
		race,
		u.id,
		count(e.*) AS count_orders,
		avg(e.amount) AS avg_amount,
		sum(e.amount) AS sum_amount
	FROM fantasy.events e 
	JOIN fantasy.users u using(id)
	JOIN fantasy.race r using(race_id)
	WHERE amount > 0
	GROUP BY race, u.id
)
SELECT 
	u.race,
	total_users,
	buyers,
	buyers_ratio,
	payer_ratio,
	round(avg(p.count_orders)) AS avg_orders,
	round(avg(p.avg_amount)::numeric) AS avg_amount,
	round(avg(p.sum_amount)::numeric) AS avg_sum
FROM users_by_race u
JOIN buyers_by_race b USING(race)
JOIN player_activity p USING(race)
GROUP BY 
	u.race,
	total_users,
	buyers,
	buyers_ratio,
	payer_ratio
ORDER BY total_users DESC 

--race    |total_users|buyers|buyers_ratio|payer_ratio|avg_orders|avg_amount|avg_sum|
----------+-----------+------+------------+-----------+----------+----------+-------+
--Human   |       6328|  3921|       61.96|      18.01|       121|       734|  48941|
--Hobbit  |       3648|  2266|       62.12|      17.70|        86|       700|  47621|
--Orc     |       3619|  2276|       62.89|      17.40|        82|       709|  41760|
--Northman|       3562|  2229|       62.58|      18.21|        82|       781|  62521|
--Elf     |       2501|  1543|       61.70|      16.27|        79|       792|  53762|
--Angel   |       1327|   820|       61.79|      16.71|       107|       776|  48669|
--Demon   |       1229|   737|       59.97|      19.95|        78|       735|  41197|
	