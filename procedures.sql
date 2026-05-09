-- ============================================================
-- Хранимые процедуры: База данных учёта продаж авиабилетов
-- Глава 2, раздел 2.5
-- ============================================================

USE airline_tickets;

DELIMITER $$

-- ------------------------------------------------------------
-- Процедура 1: sp_passenger_tickets
-- Семантика: выводит полную историю билетов пассажира по
--            номеру паспорта — все рейсы, классы, цены и статусы.
--            Используется при регистрации на рейс или по запросу
--            пассажира в кассе/колл-центре.
-- Параметры:
--   p_passport_number  — серия и номер паспорта пассажира
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_passenger_tickets$$

CREATE PROCEDURE sp_passenger_tickets(IN p_passport_number VARCHAR(20))
BEGIN
    -- Проверяем существование пассажира
    IF NOT EXISTS (
        SELECT 1 FROM passenger WHERE passport_number = p_passport_number
    ) THEN
        SELECT CONCAT('Пассажир с паспортом ', p_passport_number, ' не найден') AS Сообщение;
    ELSE
        SELECT
            t.ticket_number                                     AS 'Номер билета',
            t.status                                            AS 'Статус',
            f.flight_number                                     AS 'Рейс',
            al.name                                             AS 'Авиакомпания',
            CONCAT(ap_dep.city, ' (', ap_dep.iata_code, ')')   AS 'Откуда',
            CONCAT(ap_arr.city, ' (', ap_arr.iata_code, ')')   AS 'Куда',
            f.departure_datetime                                AS 'Вылет',
            f.arrival_datetime                                  AS 'Прилёт',
            sc.class_name                                       AS 'Класс',
            t.seat_number                                       AS 'Место',
            tr.price                                            AS 'Цена, руб.',
            t.payment_method                                    AS 'Оплата',
            t.booking_datetime                                  AS 'Дата бронирования'
        FROM ticket t
        INNER JOIN passenger    p       ON t.passenger_id           = p.passenger_id
        INNER JOIN tariff       tr      ON t.tariff_id              = tr.tariff_id
        INNER JOIN service_class sc     ON tr.class_id              = sc.class_id
        INNER JOIN flight       f       ON tr.flight_id             = f.flight_id
        INNER JOIN airline      al      ON f.airline_id             = al.airline_id
        INNER JOIN route        r       ON f.route_id               = r.route_id
        INNER JOIN airport      ap_dep  ON r.departure_airport_id   = ap_dep.airport_id
        INNER JOIN airport      ap_arr  ON r.arrival_airport_id     = ap_arr.airport_id
        WHERE p.passport_number = p_passport_number
        ORDER BY t.booking_datetime DESC;
    END IF;
END$$

-- ------------------------------------------------------------
-- Процедура 2: sp_flight_availability
-- Семантика: показывает доступность мест по классам на указанном
--            рейсе — сколько мест занято, сколько свободно и
--            текущую цену. Используется при поиске и продаже
--            билетов через кассу или веб-интерфейс.
-- Параметры:
--   p_flight_number  — номер рейса (например, 'SU1400')
--   p_flight_date    — дата вылета в формате 'YYYY-MM-DD'
-- ------------------------------------------------------------
DROP PROCEDURE IF EXISTS sp_flight_availability$$

CREATE PROCEDURE sp_flight_availability(
    IN p_flight_number VARCHAR(10),
    IN p_flight_date   DATE
)
BEGIN
    DECLARE v_flight_id   INT;
    DECLARE v_dep_city    VARCHAR(100);
    DECLARE v_arr_city    VARCHAR(100);
    DECLARE v_status      VARCHAR(20);

    -- Ищем рейс
    SELECT
        f.flight_id,
        ap_dep.city,
        ap_arr.city,
        f.status
    INTO v_flight_id, v_dep_city, v_arr_city, v_status
    FROM flight f
    INNER JOIN route   r      ON f.route_id             = r.route_id
    INNER JOIN airport ap_dep ON r.departure_airport_id = ap_dep.airport_id
    INNER JOIN airport ap_arr ON r.arrival_airport_id   = ap_arr.airport_id
    WHERE f.flight_number = p_flight_number
      AND DATE(f.departure_datetime) = p_flight_date
    LIMIT 1;

    IF v_flight_id IS NULL THEN
        SELECT CONCAT('Рейс ', p_flight_number, ' на ', p_flight_date, ' не найден') AS Сообщение;
    ELSE
        -- Общая информация о рейсе
        SELECT
            p_flight_number                             AS 'Рейс',
            CONCAT(v_dep_city, ' → ', v_arr_city)      AS 'Маршрут',
            v_status                                    AS 'Статус рейса';

        -- Доступность по классам
        SELECT
            sc.class_name                               AS 'Класс',
            tr.price                                    AS 'Цена, руб.',
            tr.available_seats                          AS 'Свободных мест',
            (
                SELECT COUNT(*)
                  FROM ticket tk
                 WHERE tk.tariff_id = tr.tariff_id
                   AND tk.status != 'cancelled'
            )                                           AS 'Продано билетов',
            CASE tr.is_refundable
                WHEN 1 THEN 'Возвратный'
                ELSE        'Невозвратный'
            END                                         AS 'Тариф',
            sc.baggage_allowance_kg                     AS 'Багаж, кг'
        FROM tariff tr
        INNER JOIN service_class sc ON tr.class_id = sc.class_id
        WHERE tr.flight_id = v_flight_id
        ORDER BY tr.price;
    END IF;
END$$

DELIMITER ;

-- ============================================================
-- Демонстрация работы процедур
-- ============================================================

-- --- Процедура 1: история билетов пассажира ---
-- Вызов для существующего пассажира:
CALL sp_passenger_tickets('4512345678');

-- Вызов для несуществующего паспорта:
CALL sp_passenger_tickets('0000000000');

-- --- Процедура 2: доступность мест на рейсе ---
-- Вызов для рейса SU1400 на 01.06.2026:
CALL sp_flight_availability('SU1400', '2026-06-01');

-- Вызов для несуществующего рейса:
CALL sp_flight_availability('XX9999', '2026-06-01');
