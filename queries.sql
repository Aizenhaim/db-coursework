-- ============================================================
-- SQL-запросы: База данных учёта продаж авиабилетов
-- Глава 2, раздел 2.3
-- ============================================================

USE airline_tickets;

-- ------------------------------------------------------------
-- Запрос А. Соединение таблиц через WHERE (соединение по равенству)
-- Семантика: вывести список всех проданных/забронированных билетов
--            с ФИО пассажира, номером рейса, маршрутом и ценой
-- ------------------------------------------------------------
SELECT
    t.ticket_number                                         AS 'Номер билета',
    CONCAT(p.last_name, ' ', p.first_name)                 AS 'Пассажир',
    f.flight_number                                         AS 'Рейс',
    CONCAT(ap_dep.iata_code, ' → ', ap_arr.iata_code)      AS 'Маршрут',
    sc.class_name                                           AS 'Класс',
    tr.price                                                AS 'Цена, руб.',
    t.status                                                AS 'Статус'
FROM ticket t, passenger p, tariff tr, flight f,
     route r, airport ap_dep, airport ap_arr, service_class sc
WHERE t.passenger_id     = p.passenger_id
  AND t.tariff_id        = tr.tariff_id
  AND tr.flight_id       = f.flight_id
  AND tr.class_id        = sc.class_id
  AND f.route_id         = r.route_id
  AND r.departure_airport_id = ap_dep.airport_id
  AND r.arrival_airport_id   = ap_arr.airport_id
  AND t.status != 'cancelled'
ORDER BY t.booking_datetime;

-- ------------------------------------------------------------
-- Запрос Б. Тот же запрос через INNER JOIN
-- Семантика: идентичен запросу А, реализован через явный JOIN
-- ------------------------------------------------------------
SELECT
    t.ticket_number                                         AS 'Номер билета',
    CONCAT(p.last_name, ' ', p.first_name)                 AS 'Пассажир',
    f.flight_number                                         AS 'Рейс',
    CONCAT(ap_dep.iata_code, ' → ', ap_arr.iata_code)      AS 'Маршрут',
    sc.class_name                                           AS 'Класс',
    tr.price                                                AS 'Цена, руб.',
    t.status                                                AS 'Статус'
FROM ticket t
INNER JOIN passenger    p       ON t.passenger_id     = p.passenger_id
INNER JOIN tariff       tr      ON t.tariff_id        = tr.tariff_id
INNER JOIN service_class sc     ON tr.class_id        = sc.class_id
INNER JOIN flight       f       ON tr.flight_id       = f.flight_id
INNER JOIN route        r       ON f.route_id         = r.route_id
INNER JOIN airport      ap_dep  ON r.departure_airport_id = ap_dep.airport_id
INNER JOIN airport      ap_arr  ON r.arrival_airport_id   = ap_arr.airport_id
WHERE t.status != 'cancelled'
ORDER BY t.booking_datetime;

-- ------------------------------------------------------------
-- Запрос В. Команда CASE
-- Семантика: вывести список рейсов с категорией дальности
--            (ближний, средний, дальний) на основе расстояния маршрута
-- ------------------------------------------------------------
SELECT
    f.flight_number                                         AS 'Рейс',
    al.name                                                 AS 'Авиакомпания',
    CONCAT(ap_dep.city, ' → ', ap_arr.city)                AS 'Маршрут',
    r.distance_km                                           AS 'Расстояние, км',
    CASE
        WHEN r.distance_km < 1000  THEN 'Ближний'
        WHEN r.distance_km < 3000  THEN 'Средний'
        ELSE                            'Дальний'
    END                                                     AS 'Категория',
    f.departure_datetime                                    AS 'Вылет',
    f.status                                                AS 'Статус рейса'
FROM flight f
INNER JOIN route   r      ON f.route_id               = r.route_id
INNER JOIN airport ap_dep ON r.departure_airport_id   = ap_dep.airport_id
INNER JOIN airport ap_arr ON r.arrival_airport_id     = ap_arr.airport_id
INNER JOIN airline al     ON f.airline_id             = al.airline_id
ORDER BY r.distance_km;

-- ------------------------------------------------------------
-- Запрос Г. GROUP BY + агрегатные функции + HAVING
-- Семантика: найти авиакомпании, суммарная выручка которых
--            по оплаченным и использованным билетам превышает 50 000 руб.
-- ------------------------------------------------------------
SELECT
    al.name                                                 AS 'Авиакомпания',
    COUNT(t.ticket_id)                                      AS 'Кол-во билетов',
    SUM(tr.price)                                           AS 'Суммарная выручка, руб.',
    ROUND(AVG(tr.price), 2)                                 AS 'Средняя цена, руб.',
    MIN(tr.price)                                           AS 'Мин. цена, руб.',
    MAX(tr.price)                                           AS 'Макс. цена, руб.'
FROM ticket t
INNER JOIN tariff  tr  ON t.tariff_id  = tr.tariff_id
INNER JOIN flight  f   ON tr.flight_id = f.flight_id
INNER JOIN airline al  ON f.airline_id = al.airline_id
WHERE t.status IN ('paid', 'used')
GROUP BY al.airline_id, al.name
HAVING SUM(tr.price) > 50000
ORDER BY SUM(tr.price) DESC;

-- ------------------------------------------------------------
-- Запрос Д. LEFT JOIN
-- Семантика: вывести все рейсы и количество проданных билетов
--            (включая рейсы без единого билета)
-- ------------------------------------------------------------
SELECT
    f.flight_number                                         AS 'Рейс',
    CONCAT(ap_dep.iata_code, ' → ', ap_arr.iata_code)      AS 'Маршрут',
    f.departure_datetime                                    AS 'Дата вылета',
    f.status                                                AS 'Статус',
    COUNT(t.ticket_id)                                      AS 'Продано билетов'
FROM flight f
INNER JOIN route   r      ON f.route_id               = r.route_id
INNER JOIN airport ap_dep ON r.departure_airport_id   = ap_dep.airport_id
INNER JOIN airport ap_arr ON r.arrival_airport_id     = ap_arr.airport_id
LEFT  JOIN tariff  tr     ON tr.flight_id             = f.flight_id
LEFT  JOIN ticket  t      ON t.tariff_id              = tr.tariff_id
                          AND t.status != 'cancelled'
GROUP BY f.flight_id, f.flight_number, ap_dep.iata_code,
         ap_arr.iata_code, f.departure_datetime, f.status
ORDER BY f.departure_datetime;

-- ------------------------------------------------------------
-- Запрос Е. Вложенный подзапрос (вложенный SELECT)
-- Семантика: найти пассажиров, которые купили билеты
--            на рейсы с расстоянием выше среднего по всем маршрутам
-- ------------------------------------------------------------
SELECT DISTINCT
    CONCAT(p.last_name, ' ', p.first_name, ' ', COALESCE(p.middle_name,'')) AS 'ФИО пассажира',
    p.passport_number                                       AS 'Паспорт',
    p.phone                                                 AS 'Телефон'
FROM passenger p
WHERE p.passenger_id IN (
    SELECT DISTINCT t.passenger_id
    FROM ticket t
    INNER JOIN tariff  tr  ON t.tariff_id  = tr.tariff_id
    INNER JOIN flight  f   ON tr.flight_id = f.flight_id
    INNER JOIN route   r   ON f.route_id   = r.route_id
    WHERE r.distance_km > (SELECT AVG(distance_km) FROM route)
      AND t.status != 'cancelled'
)
ORDER BY p.last_name;

-- ------------------------------------------------------------
-- Запрос Ж. Создание представления (VIEW)
-- Семантика: представление «полная информация о билете» для
--            быстрого получения сводных данных без повторных JOIN
-- ------------------------------------------------------------
CREATE OR REPLACE VIEW vw_ticket_details AS
SELECT
    t.ticket_number                                         AS ticket_number,
    t.status                                                AS ticket_status,
    t.booking_datetime                                      AS booking_datetime,
    t.seat_number                                           AS seat_number,
    t.payment_method                                        AS payment_method,
    CONCAT(p.last_name, ' ', p.first_name)                 AS passenger_name,
    p.passport_number                                       AS passport_number,
    f.flight_number                                         AS flight_number,
    al.name                                                 AS airline_name,
    ap_dep.city                                             AS departure_city,
    ap_arr.city                                             AS arrival_city,
    ap_dep.iata_code                                        AS dep_iata,
    ap_arr.iata_code                                        AS arr_iata,
    f.departure_datetime                                    AS departure_datetime,
    f.arrival_datetime                                      AS arrival_datetime,
    sc.class_name                                           AS service_class,
    tr.price                                                AS price
FROM ticket t
INNER JOIN passenger    p       ON t.passenger_id           = p.passenger_id
INNER JOIN tariff       tr      ON t.tariff_id              = tr.tariff_id
INNER JOIN service_class sc     ON tr.class_id              = sc.class_id
INNER JOIN flight       f       ON tr.flight_id             = f.flight_id
INNER JOIN airline      al      ON f.airline_id             = al.airline_id
INNER JOIN route        r       ON f.route_id               = r.route_id
INNER JOIN airport      ap_dep  ON r.departure_airport_id   = ap_dep.airport_id
INNER JOIN airport      ap_arr  ON r.arrival_airport_id     = ap_arr.airport_id;

-- Использование представления:
SELECT * FROM vw_ticket_details WHERE ticket_status != 'cancelled' ORDER BY departure_datetime;
