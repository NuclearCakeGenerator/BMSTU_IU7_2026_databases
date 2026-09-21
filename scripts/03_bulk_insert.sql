TRUNCATE TABLE employees,
working_hours,
access_cards,
access_zones,
passages,
card_assignments;

COPY working_hours (id, start_time, end_time)
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