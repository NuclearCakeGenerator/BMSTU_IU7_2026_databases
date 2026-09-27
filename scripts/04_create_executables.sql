-- Скалярная функция, возвращающая id человека, который последним использовал карту.
CREATE OR REPLACE FUNCTION last_card_user () RETURNS INT LANGUAGE SQL STABLE AS $$
SELECT
    person_id
FROM
    passages
ORDER BY
    passage_time DESC,
    id DESC
LIMIT
    1;
$$;

-- Табличная функция возвращающая таблицу отклоненных проходов в зоны.
CREATE OR REPLACE FUNCTION rejected_passages () RETURNS TABLE (
    first_name VARCHAR(255),
    last_name VARCHAR(255),
    passage_time TIMESTAMP,
    zone_name VARCHAR(255)
) LANGUAGE SQL STABLE AS $$
SELECT
    e.first_name,
    e.last_name,
    p.passage_time,
    z.zone_name
FROM
    passages AS p
    JOIN employees AS e ON e.id = p.person_id
    JOIN access_zones AS z ON z.id = p.zone_id
WHERE
    p.is_granted = FALSE
ORDER BY
    p.passage_time DESC;
$$;

-- Мульти операторная функция привязывает новую карту к сотруднику
CREATE OR REPLACE FUNCTION assign_card (p_employee_id INT, p_uid_card BYTEA) RETURNS TABLE (
    employee_id INT,
    card_id INT,
    uid_card BYTEA,
    card_status card_status_t,
    issue_date TIMESTAMP,
    expire_date TIMESTAMP,
    assignment_id INT
) LANGUAGE plpgsql VOLATILE AS $$
DECLARE
	new_card_id INT;
	new_assignment_id INT;
	new_issue_date TIMESTAMP := CURRENT_TIMESTAMP;
BEGIN
	IF NOT EXISTS (
		SELECT 1
		FROM employees
		WHERE id = p_employee_id
	) THEN
		RAISE EXCEPTION 'Employee with id % does not exist', p_employee_id;
	END IF;

	IF p_uid_card IS NULL OR length(p_uid_card) = 0 THEN
		RAISE EXCEPTION 'Card uid must not be empty';
	END IF;

	IF EXISTS (
		SELECT 1
		FROM access_cards AS existing_card
		WHERE existing_card.uid_card = p_uid_card
	) THEN
		RAISE EXCEPTION 'Card with the supplied uid already exists';
	END IF;

	INSERT INTO access_cards (
		uid_card,
		card_status,
		issue_date,
		expire_date
	)
	VALUES (
		p_uid_card,
		'active',
		new_issue_date,
		new_issue_date + INTERVAL '6 months'
	)
	RETURNING id INTO new_card_id;

	INSERT INTO card_assignments (
		is_active_assignment,
		owner_id,
		card_id
	)
	VALUES (TRUE, p_employee_id, new_card_id)
	RETURNING id INTO new_assignment_id;

	RETURN QUERY
	SELECT p_employee_id,
		   c.id,
		   c.uid_card,
		   c.card_status,
		   c.issue_date,
		   c.expire_date,
		   new_assignment_id
	FROM access_cards AS c
	WHERE c.id = new_card_id;
END;
$$;

-- Отобразить иерархию зон доступа.
CREATE OR REPLACE FUNCTION zone_hierarchy () RETURNS TABLE (
    zone_id INT,
    zone_name VARCHAR(255),
    outer_zone_id INT,
    DEPTH INT
) LANGUAGE SQL STABLE AS $$
WITH RECURSIVE
    zone_tree AS (
        SELECT
            z.id,
            z.zone_name,
            z.outer_zone_id,
            0 AS depth
        FROM
            access_zones AS z
        WHERE
            z.outer_zone_id IS NULL
        UNION ALL
        SELECT
            child.id,
            child.zone_name,
            child.outer_zone_id,
            parent.depth + 1
        FROM
            access_zones AS child
            JOIN zone_tree AS parent ON child.outer_zone_id = parent.id
    )
SELECT
    id,
    zone_name,
    outer_zone_id,
    depth
FROM
    zone_tree
ORDER BY
    depth,
    id;
$$;

-- Инвалидировать все просроченые карты
CREATE OR REPLACE PROCEDURE mark_expired_cards () LANGUAGE SQL AS $$
UPDATE access_cards
SET
    card_status = 'expired'
WHERE
    expire_date IS NOT NULL
    AND expire_date < CURRENT_TIMESTAMP
    AND card_status <> 'expired';
$$;

-- Рекурсивная процедура, записывающая иерархию зон во временную таблицу.
CREATE OR REPLACE PROCEDURE build_zone_hierarchy (p_root_zone_id INT DEFAULT NULL) LANGUAGE plpgsql AS $$
BEGIN
CREATE TEMP TABLE IF NOT EXISTS zone_hierarchy_result (
    zone_id INT,
    zone_name VARCHAR(255),
    outer_zone_id INT,
    depth INT
) ON
COMMIT
DROP;

IF p_root_zone_id IS NULL THEN
TRUNCATE zone_hierarchy_result;

INSERT INTO
    zone_hierarchy_result
SELECT
    *
FROM
    zone_hierarchy ();

ELSE
INSERT INTO
    zone_hierarchy_result
SELECT
    z.id,
    z.zone_name,
    z.outer_zone_id,
    0
FROM
    access_zones AS z
WHERE
    z.id = p_root_zone_id;

CALL build_zone_children (p_root_zone_id, 1);

END IF;

END;
$$;

CREATE OR REPLACE PROCEDURE build_zone_children (p_outer_zone_id INT, p_depth INT) LANGUAGE plpgsql AS $$
DECLARE child_zone RECORD;

BEGIN FOR child_zone IN
SELECT
    id,
    zone_name,
    outer_zone_id
FROM
    access_zones
WHERE
    outer_zone_id = p_outer_zone_id
ORDER BY
    id LOOP
INSERT INTO
    zone_hierarchy_result
VALUES
    (
        child_zone.id,
        child_zone.zone_name,
        child_zone.outer_zone_id,
        p_depth
    );

CALL build_zone_children (child_zone.id, p_depth + 1);

END LOOP;

END;
$$;

-- Процедура возвращает курсор для обработки списка отклоненных проходов.
CREATE OR REPLACE PROCEDURE open_rejected_passages_cursor (INOUT p_cursor REFCURSOR) LANGUAGE plpgsql AS $$
BEGIN
	OPEN p_cursor FOR
		SELECT p.id,
			   e.first_name,
			   e.last_name,
			   p.passage_time,
			   z.zone_name
		FROM passages AS p
		LEFT JOIN employees AS e ON e.id = p.person_id
		LEFT JOIN access_zones AS z ON z.id = p.zone_id
		WHERE p.is_granted = FALSE
		ORDER BY p.passage_time;
END;
$$;

-- Процедура позволяет увидеть структуру самих таблиц БД.
CREATE OR REPLACE PROCEDURE open_database_metadata (INOUT p_cursor REFCURSOR) LANGUAGE plpgsql AS $$
BEGIN
	OPEN p_cursor FOR
		SELECT table_name, column_name, data_type, is_nullable
		FROM information_schema.columns
		WHERE table_schema = 'public'
		ORDER BY table_name, ordinal_position;
END;
$$;

-- AFTER триггер - аписывает историю изменений содержимого таблицы лога проходов.
CREATE TABLE IF NOT EXISTS passage_audit (
    audit_id INT GENERATED BY DEFAULT AS IDENTITY PRIMARY KEY,
    passage_id INT,
    operation VARCHAR(10) NOT NULL,
    changed_at TIMESTAMP NOT NULL DEFAULT CURRENT_TIMESTAMP,
    old_is_granted BOOLEAN,
    new_is_granted BOOLEAN
);

CREATE OR REPLACE FUNCTION audit_passage_change () RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
	INSERT INTO passage_audit (
		passage_id,
		operation,
		old_is_granted,
		new_is_granted
	)
	VALUES (
		COALESCE(NEW.id, OLD.id),
		TG_OP,
		OLD.is_granted,
		NEW.is_granted
	);

	IF TG_OP = 'DELETE' THEN
		RETURN OLD;
	END IF;

	RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_audit_passage_change ON passages;

CREATE TRIGGER trg_audit_passage_change
AFTER INSERT OR UPDATE OR DELETE ON passages FOR EACH ROW
EXECUTE FUNCTION audit_passage_change ();

-- INSTEAD OF триггер - переносит вставку лога о заблокированных проходах из view в оригинальную таблицу
CREATE OR REPLACE VIEW rejected_passages_view AS
SELECT
    id,
    person_id,
    card_id,
    zone_id,
    passage_time,
    direction,
    is_granted
FROM
    passages
WHERE
    is_granted = FALSE;

CREATE OR REPLACE FUNCTION insert_rejected_passage () RETURNS TRIGGER LANGUAGE plpgsql AS $$
BEGIN
	INSERT INTO passages (
		passage_time,
		direction,
		is_granted,
		person_id,
		card_id,
		zone_id
	)
	VALUES (
		COALESCE(NEW.passage_time, CURRENT_TIMESTAMP),
		NEW.direction,
		FALSE,
		NEW.person_id,
		NEW.card_id,
		NEW.zone_id
	);

	RETURN NEW;
END;
$$;

DROP TRIGGER IF EXISTS trg_insert_rejected_passage ON rejected_passages_view;

CREATE TRIGGER trg_insert_rejected_passage
INSTEAD OF INSERT ON rejected_passages_view FOR EACH ROW
EXECUTE FUNCTION insert_rejected_passage ();