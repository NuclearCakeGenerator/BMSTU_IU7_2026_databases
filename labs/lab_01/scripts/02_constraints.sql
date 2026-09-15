-- 1. Первичные ключи
ALTER TABLE employees
ADD CONSTRAINT pk_employees PRIMARY KEY (id);

ALTER TABLE working_hours
ADD CONSTRAINT pk_pworking_hours PRIMARY KEY (id);

ALTER TABLE access_cards
ADD CONSTRAINT pk_access_cards PRIMARY KEY (id);

ALTER TABLE access_zones
ADD CONSTRAINT pk_access_zones PRIMARY KEY (id);

ALTER TABLE card_assignments
ADD CONSTRAINT pk_card_assignments PRIMARY KEY (id);

ALTER TABLE passages
ADD CONSTRAINT pk_passages PRIMARY KEY (id);

-- 2. Внешние ключи
ALTER TABLE employees
ADD CONSTRAINT fk_orders_customer FOREIGN KEY (working_hours) REFERENCES working_hours (id) ON DELETE SET NULL;

ALTER TABLE access_zones
ADD CONSTRAINT fk_access_zones FOREIGN KEY (outer_zone_id) REFERENCES access_zones (id) ON DELETE CASCADE;

ALTER TABLE card_assignments
ADD CONSTRAINT fk_card_assignments_to_employees FOREIGN KEY (owner_id) REFERENCES employees (id) ON DELETE CASCADE,
ADD CONSTRAINT fk_card_assignments_to_cards FOREIGN KEY (card_id) REFERENCES access_cards (id) ON DELETE CASCADE;

ALTER TABLE passages
ADD CONSTRAINT fk_passages_to_employees FOREIGN KEY (person_id) REFERENCES employees (id) ON DELETE SET NULL,
ADD CONSTRAINT fk_passages_to_access_zones FOREIGN KEY (zone_id) REFERENCES access_zones (id) ON DELETE SET NULL,
ADD CONSTRAINT fk_passages_to_access_cards FOREIGN KEY (card_id) REFERENCES access_cards (id) ON DELETE SET NULL;

-- 3. Ограничения проверки
ALTER TABLE employees
ADD CONSTRAINT chk_employees_access_level CHECK (access_level > 0);

ALTER TABLE access_cards
ADD CONSTRAINT chk_access_cards_expiry CHECK (
    expiry_date = NULL
    OR expiry_date >= issue_date
);

ALTER TABLE access_zones
ADD CONSTRAINT chk_access_zones_level CHECK (security_level > 0);

ALTER TABLE working_hours
ADD CONSTRAINT chk_working_hrs CHECK (start_time <= end_time);