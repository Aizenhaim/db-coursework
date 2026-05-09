-- ============================================================
-- Триггеры: База данных учёта продаж авиабилетов
-- Глава 2, раздел 2.4
-- ============================================================

USE airline_tickets;

DELIMITER $$

-- ------------------------------------------------------------
-- Триггер 1: trg_ticket_after_insert
-- Тип: AFTER INSERT на таблице ticket
-- Семантика: при добавлении нового билета автоматически
--            уменьшает количество свободных мест в тарифе на 1.
--            Если свободных мест нет — генерирует ошибку и
--            запрещает вставку (через SIGNAL).
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_ticket_before_insert$$

CREATE TRIGGER trg_ticket_before_insert
BEFORE INSERT ON ticket
FOR EACH ROW
BEGIN
    DECLARE v_available INT;

    -- Считываем текущее количество свободных мест
    SELECT available_seats
      INTO v_available
      FROM tariff
     WHERE tariff_id = NEW.tariff_id;

    -- Проверяем наличие мест (только для активных билетов)
    IF NEW.status != 'cancelled' AND v_available <= 0 THEN
        SIGNAL SQLSTATE '45000'
            SET MESSAGE_TEXT = 'Нет свободных мест в выбранном классе на данный рейс';
    END IF;

    -- Уменьшаем количество свободных мест
    IF NEW.status != 'cancelled' THEN
        UPDATE tariff
           SET available_seats = available_seats - 1
         WHERE tariff_id = NEW.tariff_id;
    END IF;
END$$

-- ------------------------------------------------------------
-- Триггер 2: trg_ticket_after_update
-- Тип: AFTER UPDATE на таблице ticket
-- Семантика: при изменении статуса билета на 'cancelled'
--            автоматически возвращает место в тариф (available_seats + 1).
--            При изменении статуса с 'cancelled' на активный —
--            снова занимает место.
-- ------------------------------------------------------------
DROP TRIGGER IF EXISTS trg_ticket_after_update$$

CREATE TRIGGER trg_ticket_after_update
AFTER UPDATE ON ticket
FOR EACH ROW
BEGIN
    -- Билет отменяется — возвращаем место
    IF OLD.status != 'cancelled' AND NEW.status = 'cancelled' THEN
        UPDATE tariff
           SET available_seats = available_seats + 1
         WHERE tariff_id = NEW.tariff_id;
    END IF;

    -- Билет восстанавливается из отменённого — занимаем место обратно
    IF OLD.status = 'cancelled' AND NEW.status != 'cancelled' THEN
        UPDATE tariff
           SET available_seats = available_seats - 1
         WHERE tariff_id = NEW.tariff_id;
    END IF;
END$$

DELIMITER ;

-- ============================================================
-- Демонстрация работы триггеров
-- ============================================================

-- --- До срабатывания триггера 1 ---
-- Смотрим свободные места по тарифу 1 (рейс SU1400, эконом):
SELECT tariff_id, flight_id, class_id, price, available_seats
  FROM tariff
 WHERE tariff_id = 1;
-- Ожидаем: available_seats = 150 (минус уже купленные через data.sql = 149)

-- Добавляем новый билет (вызовет триггер trg_ticket_before_insert):
INSERT INTO passenger (last_name, first_name, passport_number, birth_date, nationality, phone)
VALUES ('Тестов', 'Тест', '9999000001', '2000-01-01', 'Россия', '+7-999-000-00-01');

INSERT INTO ticket (ticket_number, passenger_id, tariff_id, seat_number, status, payment_method)
VALUES ('TKT-TEST-0001', LAST_INSERT_ID(), 1, '25A', 'paid', 'card');

-- --- После срабатывания триггера 1 ---
-- available_seats должен уменьшиться на 1:
SELECT tariff_id, flight_id, class_id, price, available_seats
  FROM tariff
 WHERE tariff_id = 1;

-- --- Демонстрация триггера 2 (отмена билета) ---
-- Смотрим состояние до отмены:
SELECT ticket_id, ticket_number, status FROM ticket WHERE ticket_number = 'TKT-TEST-0001';
SELECT tariff_id, available_seats FROM tariff WHERE tariff_id = 1;

-- Отменяем билет (вызовет trg_ticket_after_update):
UPDATE ticket
   SET status = 'cancelled'
 WHERE ticket_number = 'TKT-TEST-0001';

-- После отмены available_seats должен вернуться к предыдущему значению:
SELECT tariff_id, available_seats FROM tariff WHERE tariff_id = 1;
