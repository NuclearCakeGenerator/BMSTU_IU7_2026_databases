# 1 Вызов скалярной функции

```sql
SELECT
    first_name,
    last_name,
    email,
    hideemail (email)
FROM
    employees;
```

# 2 Вызов агрегатной функции

```sql
SELECT
    first_name,
    last_name,
    xor_cards_uid (uid_card) AS common_uid
FROM
    access_cards ac
    JOIN card_assignments ca ON ca.card_id = ac.id
    JOIN employees e ON ca.owner_id = e.id
GROUP BY
    first_name,
    last_name
ORDER BY
    first_name,
    last_name;

-- для сравнения ---
SELECT
    first_name,
    last_name,
    uid_card
FROM
    access_cards ac
    JOIN card_assignments ca ON ca.card_id = ac.id
    JOIN employees e ON ca.owner_id = e.id
ORDER BY
    first_name,
    last_name;
```

# 3 Вызов табличной функции

```sql
SELECT * FROM detect_double_passages_by_id(5);
```

# 4 Вызов процедуры

```sql
CALL archive_expired_cards (50);
```

# 5 Вызов триггера

```sql
SELECT
    id,
    email
FROM
    employees e
WHERE
    id = 1;

UPDATE employees e
SET
    email = 'UPPERCASE@POCHTA.RU'
WHERE
    id = 1;

SELECT
    id,
    email
FROM
    employees e
WHERE
    id = 1;
```

# 6 Использование пользовательского типа данных

```sql
--- тест ---
SELECT
    make_time_window ('22:00', '06:00') @> '23:30'::TIME;

SELECT
    make_time_window ('22:00', '06:00') @> '12:00'::TIME;

SELECT
    tw_minutes (make_time_window ('22:00', '06:00'));

--- использование ---
SELECT
    e.last_name,
    p.passage_time,
    (w.time_range).start_t AS start,
    (w.time_range).end_t AS END
FROM
    passages p
    JOIN employees e ON e.id = p.person_id
    JOIN working_hours w ON w.id = e.working_hours
WHERE
    p.is_granted
    AND NOT (w.time_range @> p.passage_time::TIME)
LIMIT
    20;
```
