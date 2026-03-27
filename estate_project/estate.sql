/* Проект первого модуля: анализ данных для агентства недвижимости
 * Часть 2. Решаем ad hoc задачи
 *
 * Автор: Козбаков Айдын
 * Дата: 25.01.2026
*/



-- Задача 1: Время активности объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    )
-- Выведем объявления без выбросов:
SELECT
	CASE 
		WHEN city = 'Санкт-Петербург' THEN 'Санкт-Петербург'
		ELSE 'ЛенОбл'
	END AS "Регион",
	CASE 
	WHEN days_exposition BETWEEN 1 AND 30 THEN '1до месяца'
	WHEN days_exposition BETWEEN 31 AND 90 THEN '2до трех месяцев'
	WHEN days_exposition BETWEEN 91 AND 180 THEN '3до полугода'
	WHEN days_exposition > 180 THEN '4более полугода'
	ELSE '5non category'
END AS "Сегмент активности",
	count(a.id) AS "Кол-во квартир",
	round(avg(total_area)::decimal,2) AS "Средняя площадь",
	round(avg(last_price / total_area)::decimal,2) AS "Средняя стоимость кв метра",
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY rooms) AS "Медиана кол-ва комнат",
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY balcony) AS "Медиана кол-ва балконов",
	PERCENTILE_DISC(0.5) WITHIN GROUP (ORDER BY floor) AS "Медиана этажности"
FROM real_estate.advertisement a 
JOIN real_estate.flats f using(id)
JOIN real_estate.city c using(city_id)
JOIN real_estate."type" t using(type_id)
WHERE id IN (SELECT * FROM filtered_id)
AND TYPE = 'город'
AND EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018
GROUP BY 1,2
ORDER BY 1 DESC, 2;

--Регион         |Сегмент активности|Кол-во квартир|Средняя площадь|Средняя стоимость кв метра|Медиана кол-ва комнат|Медиана кол-ва балконов|Медиана этажности|
-----------------+------------------+--------------+---------------+--------------------------+---------------------+-----------------------+-----------------+
--Санкт-Петербург|1до месяца        |          1794|          54.66|                 108919.78|                    2|                    1.0|                5|
--Санкт-Петербург|2до трех месяцев  |          3020|          56.58|                 110874.32|                    2|                    1.0|                5|
--Санкт-Петербург|3до полугода      |          2244|          60.55|                 111973.67|                    2|                    1.0|                5|
--Санкт-Петербург|4более полугода   |          3506|          65.76|                 114981.07|                    2|                    1.0|                5|
--Санкт-Петербург|5non category     |           653|          81.38|                 136107.66|                    3|                    1.0|                4|
--ЛенОбл         |1до месяца        |           340|          48.75|                  71907.63|                    2|                    1.0|                4|
--ЛенОбл         |2до трех месяцев  |           864|          50.85|                  67423.80|                    2|                    1.0|                3|
--ЛенОбл         |3до полугода      |           553|          51.83|                  69809.30|                    2|                    1.0|                3|
--ЛенОбл         |4более полугода   |           873|          55.03|                  68215.11|                    2|                    1.0|                3|
--ЛенОбл         |5non category     |           198|          62.78|                  72925.89|                    2|                    1.0|                3|

-- Задача 2: Сезонность объявлений
-- Определим аномальные значения (выбросы) по значению перцентилей:
WITH limits AS (
    SELECT  
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY total_area) AS total_area_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY rooms) AS rooms_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY balcony) AS balcony_limit,
        PERCENTILE_DISC(0.99) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_h,
        PERCENTILE_DISC(0.01) WITHIN GROUP (ORDER BY ceiling_height) AS ceiling_height_limit_l
    FROM real_estate.flats     
),
-- Найдём id объявлений, которые не содержат выбросы:
filtered_id AS(
    SELECT id
    FROM real_estate.flats  
    WHERE 
        total_area < (SELECT total_area_limit FROM limits)
        AND (rooms < (SELECT rooms_limit FROM limits) OR rooms IS NULL)
        AND (balcony < (SELECT balcony_limit FROM limits) OR balcony IS NULL)
        AND ((ceiling_height < (SELECT ceiling_height_limit_h FROM limits)
            AND ceiling_height > (SELECT ceiling_height_limit_l FROM limits)) OR ceiling_height IS NULL)
    ),-- Выведем объявления без выбросов:
t1 AS (
SELECT 
	EXTRACT(MONTH FROM first_day_exposition) AS MONTH,
	count(id) AS count_adv,
	round(avg(last_price / total_area)::decimal,2) AS avg_price_adv,
	round(avg(total_area)::decimal,2) AS avg_area_adv
FROM real_estate.advertisement a
JOIN real_estate.flats f using(id)
JOIN real_estate."type" t using(type_id)
WHERE id IN (SELECT * FROM filtered_id)
AND EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018
AND TYPE = 'город'
GROUP BY MONTH
ORDER BY MONTH 
),t2 AS (
SELECT
	EXTRACT(MONTH FROM first_day_exposition + days_exposition::int) AS month,
	count(id) AS count_sale,
	round(avg(last_price / total_area)::decimal,2) AS avg_price_sale,
	round(avg(total_area)::decimal,2) AS avg_area_sale
FROM real_estate.advertisement a 
JOIN real_estate.flats f using(id)
JOIN real_estate."type" t using(type_id)
WHERE id IN (SELECT * FROM filtered_id)
AND EXTRACT(YEAR FROM first_day_exposition) BETWEEN 2015 AND 2018
AND TYPE = 'город'
AND days_exposition IS NOT NULL 
GROUP BY month
ORDER BY MONTH
)
SELECT 
	t1.MONTH,
	count_adv,
	count_sale,
	avg_price_adv,
	avg_price_sale,
	avg_area_adv,
	avg_area_sale
FROM t1
JOIN t2 using(month);

--month|count_adv|count_sale|avg_price_adv|avg_price_sale|avg_area_adv|avg_area_sale|
-------+---------+----------+-------------+--------------+------------+-------------+
--    1|      735|      1225|    106106.24|     104947.31|       59.16|        57.53|
--    2|     1369|      1048|    103058.51|     103883.72|       60.10|        61.12|
--    3|     1119|      1071|    102429.95|     106832.40|       60.00|        60.37|
--    4|     1021|      1031|    102632.41|     102444.24|       60.60|        59.22|
--    5|      891|       729|    102465.12|      99724.07|       59.19|        57.78|
--    6|     1224|       771|    104802.15|     101863.69|       58.37|        59.82|
--    7|     1149|      1108|    104488.96|     102290.72|       60.42|        58.54|
--    8|     1166|      1137|    107034.70|     100036.51|       58.99|        56.83|
--    9|     1341|      1238|    107563.12|     104070.07|       61.04|        57.49|
--   10|     1437|      1360|    104065.11|     104317.33|       59.43|        58.86|
--   11|     1569|      1301|    105048.80|     103791.36|       59.58|        56.71|
--   12|     1024|      1175|    104775.39|     105504.52|       58.84|        59.26|