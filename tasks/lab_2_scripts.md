# 1 найти сотрпудников с уровнем доступа более чем ... и работающих ранее чем ...

```sql
SELECT first_name, last_name, access_level, start_time, end_time
FROM employees JOIN working_hours ON employees.working_hours = working_hours.id
WHERE access_level >= '10' AND start_time < '10:00:00'::time
ORDER BY access_level
```

# 2 найти работников, с графиком в определенных рамках

```sql
SELECT first_name, last_name, access_level, start_time, end_time
FROM employees JOIN working_hours ON employees.working_hours = working_hours.id
WHERE (start_time BETWEEN '8:00'::time AND '18:00'::time)
    AND (end_time BETWEEN '8:00'::time AND '18:00'::time)
ORDER BY last_name
```

# 3 найти email по шаблону

```sql
SELECT first_name, last_name, email
FROM employees
WHERE email LIKE '%max%'
```

# 4 найти зоны, в которые входили/выходили в указанные часы

```sql
SELECT zone_name, city, security_level
FROM access_zones
WHERE id IN (
    SELECT id
    FROM passages
    WHERE (passage_time AT TIME ZONE 'Europe/Moscow')::time
        BETWEEN '10:00:00'::time AND '10:15:00'::time
)
```

# 5 найти карты, которые ни разу не применялись

```sql
SELECT uid_card
FROM access_cards
WHERE NOT EXISTS (
    SELECT 1
    FROM passages
    WHERE passages.card_id = access_cards.id
)
```

# 6 найти сотрудника нанятого раньше всех владельцев уровня доступа 15

```sql
SELECT first_name, last_name, access_level, email
FROM employees
WHERE hired_at > ALL (
    SELECT hired_at
    FROM employees
    WHERE access_level = 15
)
```

# 7 определить средний уровень доступа всех, кто входил в определенную зону

```sql
SELECT AVG(access_level)
FROM (
    SELECT access_level
    FROM employees
    WHERE EXISTS (
        SELECT 1
        FROM passages
        WHERE person_id = employees.id AND zone_id = '1'
    )
)
```

# 8 отобразить людей вместе с максимальным уровнем зоны, в которую они входили/выходили

```sql
SELECT first_name, last_name, access_level, (
    SELECT MAX(access_zones.security_level)
    FROM access_zones
    WHERE EXISTS(
        SELECT 1
        FROM passages
        WHERE person_id = employees.id AND zone_id = access_zones.id
        )
    ) AS max_zone
FROM employees
```

# 9 отобразить проходы через турникеты по годам

```sql
SELECT person_id, card_id, zone_id,
    CASE EXTRACT(YEAR FROM passage_time)
        WHEN EXTRACT(YEAR FROM NOW()) THEN 'This Year'
        WHEN EXTRACT(YEAR FROM NOW() - INTERVAL '1 year') THEN 'Last Year'
        ELSE CAST(EXTRACT(YEAR FROM NOW()) - EXTRACT(YEAR FROM passage_time) AS varchar(5)) || 'years ago'
    END AS when_occured
FROM passages
```

# 10 примерно оценить давность прохода через турникет

```sql
SELECT person_id, card_id, zone_id,
    CASE
        WHEN passage_time > NOW() - INTERVAL '3 years' THEN 'recently'
        WHEN passage_time < NOW() - INTERVAL '3 years' THEN 'a long time ago'
        ELSE 'Exactly 3 years ago'
    END AS when_occured
FROM passages

```

# 11 создать временную таблицу с суммарным числом и долей успешных проходов по зонам

```sql
CREATE TEMP TABLE zone_passage_stats AS
SELECT zone_id,
       COUNT(*) AS passage_count,
       COUNT(*) FILTER (WHERE is_granted) AS granted_count,
       ROUND(
           100.0 * COUNT(*) FILTER (WHERE is_granted) / NULLIF(COUNT(*), 0),
           2
       ) AS granted_percent
FROM passages
WHERE zone_id IS NOT NULL
GROUP BY zone_id
```

# 12 найти лучшие зоны по количеству проходов и по числу успешных проходов

```sql
SELECT 'By passages' AS criteria, zone_name AS best_zone
FROM access_zones AS zones
JOIN (
    SELECT zone_id, COUNT(*) AS total_passages
    FROM passages
    GROUP BY zone_id
    ORDER BY total_passages DESC
    LIMIT 1
) AS stats ON stats.zone_id = zones.id
UNION
SELECT 'By granted passages' AS criteria, zone_name AS best_zone
FROM access_zones AS zones
JOIN (
    SELECT zone_id, COUNT(*) AS granted_passages
    FROM passages
    WHERE is_granted
    GROUP BY zone_id
    ORDER BY granted_passages DESC
    LIMIT 1
) AS stats ON stats.zone_id = zones.id
```

# 13 найти зону с максимальным числом успешных проходов через три уровня вложенности

```sql
SELECT zone_name, security_level
FROM access_zones
WHERE id = (
    SELECT zone_id
    FROM passages
    WHERE is_granted
    GROUP BY zone_id
    HAVING COUNT(*) = (
        SELECT MAX(granted_count)
        FROM (
            SELECT COUNT(*) AS granted_count
            FROM passages
            WHERE is_granted
            GROUP BY zone_id
        ) AS zone_stats
    )
    ORDER BY zone_id
    LIMIT 1
)
```

# 14 сгруппировать проходы по зонам без HAVING

```sql
SELECT zone_id,
       COUNT(*) AS passage_count,
       COUNT(*) FILTER (WHERE is_granted) AS granted_count
FROM passages
GROUP BY zone_id
```

# 15 найти зоны, где средний уровень доступа сотрудников выше среднего по всем сотрудникам

```sql
SELECT p.zone_id, AVG(e.access_level) AS average_access_level
FROM passages AS p
JOIN employees AS e ON e.id = p.person_id
GROUP BY p.zone_id
HAVING AVG(e.access_level) > (SELECT AVG(access_level) FROM employees)
```

# 16 вставить одну строку в таблицу рабочих графиков

```sql
INSERT INTO working_hours (start_time, end_time)
VALUES ('09:00:00', '18:00:00')
```

# 17 вставить несколько назначений карт на сотрудников из результирующего набора

```sql
INSERT INTO card_assignments (is_active_assignment, owner_id, card_id)
SELECT TRUE,
       (SELECT MIN(id) FROM employees),
       cards.id
FROM access_cards AS cards
WHERE NOT EXISTS (
    SELECT 1
    FROM card_assignments AS assignments
    WHERE assignments.card_id = cards.id
)
LIMIT 10
```

# 18 обновить статус просроченных активных карт

```sql
UPDATE access_cards
SET card_status = 'expired'
WHERE card_status = 'active'
    AND expire_date < NOW()
```

# 19 установить сотруднику средний уровень безопасности зон

```sql
UPDATE employees
SET access_level = (
    SELECT ROUND(AVG(security_level))::INT
    FROM access_zones
)
WHERE id = (SELECT MIN(id) FROM employees)
```

# 20 удалить старые отклонённые проходы

```sql
DELETE FROM passages
WHERE is_granted = FALSE
    AND passage_time < NOW() - INTERVAL '3 years'
```

# 21 удалить неиспользуемые отозванные карты коррелированным подзапросом

```sql
DELETE FROM access_cards AS cards
WHERE cards.card_status = 'revoked'
    AND NOT EXISTS (
        SELECT 1
        FROM passages AS p
        WHERE p.card_id = cards.id
    )
```

# 22 вычислить среднее число проходов на зону

```sql
WITH zone_passages (zone_id, passage_count) AS (
    SELECT zone_id, COUNT(*)
    FROM passages
    WHERE zone_id IS NOT NULL
    GROUP BY zone_id
)
SELECT AVG(passage_count) AS average_passages_per_zone
FROM zone_passages
```

# 23 вывести иерархию зон рекурсивным CTE

```sql
WITH RECURSIVE zone_tree (zone_id, zone_name, outer_zone_id, depth) AS (
    SELECT id, zone_name, outer_zone_id, 0
    FROM access_zones
    WHERE outer_zone_id IS NULL
    UNION ALL
    SELECT child.id, child.zone_name, child.outer_zone_id, parent.depth + 1
    FROM access_zones AS child
    JOIN zone_tree AS parent ON child.outer_zone_id = parent.zone_id
)
SELECT zone_id, zone_name, outer_zone_id, depth
FROM zone_tree
ORDER BY depth, zone_id
```

# 24 показать средний, минимальный и максимальный уровень доступа по каждой зоне

```sql
SELECT p.id AS passage_id,
       p.zone_id,
       e.access_level,
       AVG(e.access_level) OVER (PARTITION BY p.zone_id) AS average_access_level,
       MIN(e.access_level) OVER (PARTITION BY p.zone_id) AS min_access_level,
       MAX(e.access_level) OVER (PARTITION BY p.zone_id) AS max_access_level
FROM passages AS p
JOIN employees AS e ON e.id = p.person_id
```

# 25 создать полные дубли и оставить по одной строке через ROW_NUMBER()

```sql
WITH duplicated_passages AS (
    SELECT person_id, card_id, zone_id, direction, is_granted
    FROM passages
    UNION ALL
    SELECT person_id, card_id, zone_id, direction, is_granted
    FROM passages
),
ranked_passages AS (
    SELECT duplicated_passages.*,
           ROW_NUMBER() OVER (
               PARTITION BY person_id, card_id, zone_id, direction, is_granted
               ORDER BY person_id
           ) AS row_number
    FROM duplicated_passages
)
SELECT person_id, card_id, zone_id, direction, is_granted
FROM ranked_passages
WHERE row_number = 1
```
