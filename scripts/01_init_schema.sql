CREATE TYPE card_status_t AS ENUM('active', 'revoked', 'expired');

CREATE TYPE direction_t AS ENUM('IN', 'OUT');

CREATE TABLE
    employees (
        id INT NOT NULL,
        first_name VARCHAR(255) NOT NULL,
        last_name VARCHAR(255),
        email VARCHAR(255),
        access_level INT NOT NULL,
        hired_at TIMESTAMP NOT NULL,
        working_hours INT
    );

CREATE TABLE
    working_hours (
        id INT NOT NULL,
        start_time TIME NOT NULL,
        end_time TIME NOT NULL
    );

CREATE TABLE
    access_cards (
        id INT NOT NULL,
        uid_card BYTEA NOT NULL,
        card_status card_status_t NOT NULL,
        issue_date TIMESTAMP NOT NULL,
        expiry_date TIMESTAMP
    );

CREATE TABLE
    access_zones (
        id INT NOT NULL,
        zone_name VARCHAR(255) NOT NULL,
        security_level INT NOT NULL,
        outer_zone_id INT,
        device_model BYTEA,
        city VARCHAR(255) NOT NULL
    );

CREATE TABLE
    card_assignments (
        id INT NOT NULL,
        is_active_assignment BOOLEAN NOT NULL,
        owner_id INT NOT NULL,
        card_id INT NOT NULL
    );

CREATE TABLE
    passages (
        id INT NOT NULL,
        passage_time TIMESTAMP NOT NULL,
        direction direction_t NOT NULL,
        is_granted BOOLEAN NOT NULL,
        person_id INT,
        card_id INT,
        zone_id INT
    );