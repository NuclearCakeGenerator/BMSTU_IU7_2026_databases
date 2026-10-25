TRUNCATE TABLE employees,
working_hours,
access_cards,
access_zones,
passages,
card_assignments;

--- Временный view для конвертации ---
CREATE VIEW working_hours_import_view AS
SELECT
    id,
    NULL::TIME AS start_time,
    NULL::TIME AS end_time
FROM
    working_hours;

--- Триггер для автоконвертации ---
CREATE OR REPLACE FUNCTION insert_working_hours_composite () RETURNS TRIGGER AS $$
BEGIN
    INSERT INTO working_hours (id, time_range)
    VALUES (NEW.id, make_time_window(NEW.start_time, NEW.end_time));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

--- Подключение триггера ---
CREATE TRIGGER trg_working_hours_import
INSTEAD OF INSERT ON working_hours_import_view FOR EACH ROW
EXECUTE FUNCTION insert_working_hours_composite ();

--- Копирование в view ---
COPY working_hours_import_view (id, start_time, end_time)
FROM
    '/var/lib/postgresql/csv_data/working_hours.csv'
WITH
    (
        FORMAT CSV,
        HEADER TRUE,
        DELIMITER ',',
        NULL '',
        ENCODING 'utf8'
    );

DROP TRIGGER trg_working_hours_import ON working_hours_import_view;

DROP FUNCTION insert_working_hours_composite ();

DROP VIEW working_hours_import_view;

--- Убрал все временное ---
COPY employees (
    id,
    first_name,
    last_name,
    email,
    access_level,
    hired_at,
    working_hours
)
FROM
    '/var/lib/postgresql/csv_data/employees.csv'
WITH
    (
        FORMAT CSV,
        HEADER TRUE,
        DELIMITER ',',
        NULL '',
        ENCODING 'utf8'
    );

COPY access_cards (
    id,
    uid_card,
    card_status,
    issue_date,
    expire_date
)
FROM
    '/var/lib/postgresql/csv_data/access_cards.csv'
WITH
    (
        FORMAT CSV,
        HEADER TRUE,
        DELIMITER ',',
        NULL '',
        ENCODING 'utf8'
    );

COPY access_zones (
    id,
    zone_name,
    security_level,
    outer_zone_id,
    device_model,
    city
)
FROM
    '/var/lib/postgresql/csv_data/access_zones.csv'
WITH
    (
        FORMAT CSV,
        HEADER TRUE,
        DELIMITER ',',
        NULL '',
        ENCODING 'utf8'
    );

COPY card_assignments (card_id, owner_id, id, is_active_assignment)
FROM
    '/var/lib/postgresql/csv_data/card_assignments.csv'
WITH
    (
        FORMAT CSV,
        HEADER TRUE,
        DELIMITER ',',
        NULL '',
        ENCODING 'utf8'
    );

COPY passages (
    id,
    passage_time,
    direction,
    is_granted,
    person_id,
    card_id,
    zone_id
)
FROM
    '/var/lib/postgresql/csv_data/passages.csv'
WITH
    (
        FORMAT CSV,
        HEADER TRUE,
        DELIMITER ',',
        NULL '',
        ENCODING 'utf8'
    );

-- Sync sequence counters after CSV import
SELECT
    SETVAL(
        PG_GET_SERIAL_SEQUENCE('working_hours', 'id'),
        COALESCE(MAX(id), 1)
    )
FROM
    working_hours;

SELECT
    SETVAL(
        PG_GET_SERIAL_SEQUENCE('employees', 'id'),
        COALESCE(MAX(id), 1)
    )
FROM
    employees;

SELECT
    SETVAL(
        PG_GET_SERIAL_SEQUENCE('access_cards', 'id'),
        COALESCE(MAX(id), 1)
    )
FROM
    access_cards;

SELECT
    SETVAL(
        PG_GET_SERIAL_SEQUENCE('access_zones', 'id'),
        COALESCE(MAX(id), 1)
    )
FROM
    access_zones;

SELECT
    SETVAL(
        PG_GET_SERIAL_SEQUENCE('card_assignments', 'id'),
        COALESCE(MAX(id), 1)
    )
FROM
    card_assignments;

SELECT
    SETVAL(
        PG_GET_SERIAL_SEQUENCE('passages', 'id'),
        COALESCE(MAX(id), 1)
    )
FROM
    passages;