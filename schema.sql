-- ============================================================
-- КУРСОВАЯ РАБОТА: База данных учёта продаж авиабилетов
-- Дисциплина: Базы данных | РЭУ им. Плеханова | 2026
-- СУБД: MySQL 8.x
-- ============================================================

DROP DATABASE IF EXISTS airline_tickets;
CREATE DATABASE airline_tickets CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;
USE airline_tickets;

-- ------------------------------------------------------------
-- ДОМЕНЫ (эмулируются через CHECK-ограничения и ENUM в MySQL)
-- ------------------------------------------------------------

-- ------------------------------------------------------------
-- 1. АВИАКОМПАНИЯ (AIRLINE)
-- ------------------------------------------------------------
CREATE TABLE airline (
    airline_id   INT            NOT NULL AUTO_INCREMENT,
    name         VARCHAR(100)   NOT NULL,
    iata_code    CHAR(2)        NOT NULL,
    country      VARCHAR(50)    NOT NULL,
    phone        VARCHAR(20),
    email        VARCHAR(100),
    CONSTRAINT pk_airline     PRIMARY KEY (airline_id),
    CONSTRAINT uq_airline_iata UNIQUE (iata_code),
    CONSTRAINT ck_airline_email CHECK (email LIKE '%@%.%' OR email IS NULL)
);

-- ------------------------------------------------------------
-- 2. АЭРОПОРТ (AIRPORT)
-- ------------------------------------------------------------
CREATE TABLE airport (
    airport_id   INT            NOT NULL AUTO_INCREMENT,
    name         VARCHAR(150)   NOT NULL,
    iata_code    CHAR(3)        NOT NULL,
    city         VARCHAR(100)   NOT NULL,
    country      VARCHAR(50)    NOT NULL,
    timezone     VARCHAR(50)    NOT NULL,
    CONSTRAINT pk_airport      PRIMARY KEY (airport_id),
    CONSTRAINT uq_airport_iata UNIQUE (iata_code)
);

-- ------------------------------------------------------------
-- 3. САМОЛЁТ (AIRCRAFT)
-- ------------------------------------------------------------
CREATE TABLE aircraft (
    aircraft_id          INT          NOT NULL AUTO_INCREMENT,
    model                VARCHAR(50)  NOT NULL,
    registration_number  VARCHAR(20)  NOT NULL,
    total_seats          SMALLINT     NOT NULL,
    year_manufactured    YEAR,
    airline_id           INT          NOT NULL,
    CONSTRAINT pk_aircraft          PRIMARY KEY (aircraft_id),
    CONSTRAINT uq_aircraft_reg      UNIQUE (registration_number),
    CONSTRAINT fk_aircraft_airline  FOREIGN KEY (airline_id) REFERENCES airline(airline_id),
    CONSTRAINT ck_aircraft_seats    CHECK (total_seats > 0)
);

-- ------------------------------------------------------------
-- 4. МАРШРУТ (ROUTE)
-- ------------------------------------------------------------
CREATE TABLE route (
    route_id              INT   NOT NULL AUTO_INCREMENT,
    departure_airport_id  INT   NOT NULL,
    arrival_airport_id    INT   NOT NULL,
    distance_km           INT,
    flight_duration_min   INT,
    CONSTRAINT pk_route              PRIMARY KEY (route_id),
    CONSTRAINT fk_route_departure    FOREIGN KEY (departure_airport_id) REFERENCES airport(airport_id),
    CONSTRAINT fk_route_arrival      FOREIGN KEY (arrival_airport_id)   REFERENCES airport(airport_id),
    CONSTRAINT uq_route              UNIQUE (departure_airport_id, arrival_airport_id),
    CONSTRAINT ck_route_airports     CHECK (departure_airport_id <> arrival_airport_id),
    CONSTRAINT ck_route_distance     CHECK (distance_km > 0 OR distance_km IS NULL),
    CONSTRAINT ck_route_duration     CHECK (flight_duration_min > 0 OR flight_duration_min IS NULL)
);

-- ------------------------------------------------------------
-- 5. КЛАСС ОБСЛУЖИВАНИЯ (SERVICE_CLASS)
-- ------------------------------------------------------------
CREATE TABLE service_class (
    class_id              INT          NOT NULL AUTO_INCREMENT,
    class_name            VARCHAR(50)  NOT NULL,
    baggage_allowance_kg  TINYINT      NOT NULL DEFAULT 20,
    description           VARCHAR(200),
    CONSTRAINT pk_service_class      PRIMARY KEY (class_id),
    CONSTRAINT uq_service_class_name UNIQUE (class_name),
    CONSTRAINT ck_service_baggage    CHECK (baggage_allowance_kg >= 0)
);

-- ------------------------------------------------------------
-- 6. РЕЙС (FLIGHT)
-- ------------------------------------------------------------
CREATE TABLE flight (
    flight_id          INT          NOT NULL AUTO_INCREMENT,
    flight_number      VARCHAR(10)  NOT NULL,
    route_id           INT          NOT NULL,
    aircraft_id        INT          NOT NULL,
    airline_id         INT          NOT NULL,
    departure_datetime DATETIME     NOT NULL,
    arrival_datetime   DATETIME     NOT NULL,
    status             ENUM('scheduled','delayed','cancelled','completed') NOT NULL DEFAULT 'scheduled',
    CONSTRAINT pk_flight            PRIMARY KEY (flight_id),
    CONSTRAINT fk_flight_route      FOREIGN KEY (route_id)    REFERENCES route(route_id),
    CONSTRAINT fk_flight_aircraft   FOREIGN KEY (aircraft_id) REFERENCES aircraft(aircraft_id),
    CONSTRAINT fk_flight_airline    FOREIGN KEY (airline_id)  REFERENCES airline(airline_id),
    CONSTRAINT ck_flight_datetime   CHECK (arrival_datetime > departure_datetime)
);

-- ------------------------------------------------------------
-- 7. ТАРИФ (TARIFF)
--    Цена и количество мест для каждого класса на каждом рейсе
-- ------------------------------------------------------------
CREATE TABLE tariff (
    tariff_id        INT             NOT NULL AUTO_INCREMENT,
    flight_id        INT             NOT NULL,
    class_id         INT             NOT NULL,
    price            DECIMAL(10,2)   NOT NULL,
    available_seats  SMALLINT        NOT NULL,
    is_refundable    TINYINT(1)      NOT NULL DEFAULT 1,
    CONSTRAINT pk_tariff          PRIMARY KEY (tariff_id),
    CONSTRAINT fk_tariff_flight   FOREIGN KEY (flight_id) REFERENCES flight(flight_id),
    CONSTRAINT fk_tariff_class    FOREIGN KEY (class_id)  REFERENCES service_class(class_id),
    CONSTRAINT uq_tariff          UNIQUE (flight_id, class_id),
    CONSTRAINT ck_tariff_price    CHECK (price > 0),
    CONSTRAINT ck_tariff_seats    CHECK (available_seats >= 0)
);

-- ------------------------------------------------------------
-- 8. ПАССАЖИР (PASSENGER)
-- ------------------------------------------------------------
CREATE TABLE passenger (
    passenger_id     INT          NOT NULL AUTO_INCREMENT,
    last_name        VARCHAR(50)  NOT NULL,
    first_name       VARCHAR(50)  NOT NULL,
    middle_name      VARCHAR(50),
    passport_number  VARCHAR(20)  NOT NULL,
    birth_date       DATE         NOT NULL,
    nationality      VARCHAR(50)  NOT NULL DEFAULT 'Россия',
    phone            VARCHAR(20),
    email            VARCHAR(100),
    CONSTRAINT pk_passenger          PRIMARY KEY (passenger_id),
    CONSTRAINT uq_passenger_passport UNIQUE (passport_number),
    CONSTRAINT ck_passenger_email    CHECK (email LIKE '%@%.%' OR email IS NULL)
);

-- ------------------------------------------------------------
-- 9. БИЛЕТ (TICKET)
-- ------------------------------------------------------------
CREATE TABLE ticket (
    ticket_id        INT          NOT NULL AUTO_INCREMENT,
    ticket_number    VARCHAR(20)  NOT NULL,
    passenger_id     INT          NOT NULL,
    tariff_id        INT          NOT NULL,
    seat_number      VARCHAR(5)   NOT NULL,
    booking_datetime DATETIME     NOT NULL DEFAULT CURRENT_TIMESTAMP,
    status           ENUM('booked','paid','cancelled','used') NOT NULL DEFAULT 'booked',
    payment_method   ENUM('card','cash','online') NOT NULL DEFAULT 'card',
    CONSTRAINT pk_ticket           PRIMARY KEY (ticket_id),
    CONSTRAINT uq_ticket_number    UNIQUE (ticket_number),
    CONSTRAINT fk_ticket_passenger FOREIGN KEY (passenger_id) REFERENCES passenger(passenger_id),
    CONSTRAINT fk_ticket_tariff    FOREIGN KEY (tariff_id)    REFERENCES tariff(tariff_id)
);
