CREATE TYPE card_status_t AS ENUM('active', 'revoked', 'expired');

CREATE TYPE direction_t AS ENUM('IN', 'OUT');

CREATE TABLE
    employees (
        id INT,
        first_name VARCHAR(255),
        last_name VARCHAR(255),
        email VARCHAR(255),
        access_level INT,
        hired_at TIMESTAMP,
        working_hours INT
    );

CREATE TABLE
    working_hours (id INT, start_time TIME, end_time TIME);

CREATE TABLE
    access_cards (
        id INT,
        uid_card BYTEA,
        card_status card_status_t,
        issue_date TIMESTAMP,
        expiry_date TIMESTAMP
    );

CREATE TABLE
    access_zones (
        id INT,
        zone_name VARCHAR(255),
        security_level INT,
        outer_zone_id INT,
        device_model BYTEA,
        city VARCHAR(255)
    );

CREATE TABLE
    card_assignments (
        id INT,
        is_active_assignment BOOLEAN,
        owner_id INT,
        card_id INT
    );

CREATE TABLE
    passages (
        id INT,
        TIME TIMESTAMP,
        direction direction_t,
        is_granted BOOLEAN,
        person_id INT,
        card_id INT,
        zone_id INT
    );