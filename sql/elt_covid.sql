-- Vytvorenie schémy
CREATE SCHEMA IF NOT EXISTS DOG_DB.covid;
USE SCHEMA DOG_DB.covid;

-- Staging tabuľky
CREATE OR REPLACE TABLE WHO_TIMESERIES AS
SELECT * 
FROM COVID19_EPIDEMIOLOGICAL_DATA.PUBLIC.WHO_TIMESERIES;

CREATE OR REPLACE TABLE WHO_DAILY_REPORT AS
SELECT * 
FROM COVID19_EPIDEMIOLOGICAL_DATA.PUBLIC.WHO_DAILY_REPORT;

CREATE OR REPLACE TABLE WHO_REPORTS AS
SELECT * 
FROM COVID19_EPIDEMIOLOGICAL_DATA.PUBLIC.WHO_SITUATION_REPORTS;
-- Kontrola obsahu staging tabuliek
SELECT * FROM WHO_TIMESERIES;
SELECT * FROM WHO_SITUATION_REPORTS;
SELECT * FROM WHO_DAILY_REPORT;
---------------------- DIM DATE ---------------------------
-- Dimenzia času, vytvorená zo všetkých unikátnych dátumov
CREATE OR REPLACE TABLE DIM_DATE AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY d_date) AS date_id,
    d_date AS date,
    YEAR(d_date) AS year,
    MONTH(d_date) AS month,
    DAY(d_date) AS day
FROM(
    SELECT DISTINCT CAST(DATE AS DATE) as d_date FROM WHO_TIMESERIES
    UNION
    SELECT DISTINCT CAST(DATE AS DATE) FROM WHO_SITUATION_REPORTS
    UNION
    SELECT DISTINCT CAST(DATE AS DATE) FROM WHO_DAILY_REPORT
);

SELECT * FROM DIM_DATE;
------------------------ DIM COUNTRY -----------------------
-- Obsahuje jedinečné krajiny zo zdrojových dát
-- TRIM() používa na odstránenie medzier
CREATE OR REPLACE TABLE dim_country AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY country_name) AS country_id,
    country_name,
    iso_code
FROM(
    SELECT DISTINCT TRIM(COUNTRY_REGION) as country_name, ISO3166_1 as        iso_code FROM WHO_TIMESERIES
    UNION
    SELECT DISTINCT TRIM(COUNTRY_REGION), ISO3166_1 FROM WHO_SITUATION_REPORTS
);

SELECT * FROM dim_country;
---------------------- DIM REPORT TYPE ---------------------
-- Určuje pôvod záznamu
CREATE OR REPLACE TABLE dim_report_type AS
SELECT
    CAST(ROW_NUMBER() OVER(ORDER BY report_name) AS INT) AS REPORT_TYPE_ID,
    report_name
FROM(
    SELECT 'TIMESERIES' AS report_name
    UNION ALL
    SELECT 'DAILY_REPORT'
    UNION ALL
    SELECT 'SITUATION_REPORT'
);

SELECT * FROM dim_report_type;
--------------------- DIM TRANSMISSION ----------------
-- Klasifikácia prenosu ochorenia
CREATE OR REPLACE TABLE dim_transmission_classification AS
SELECT 
    ROW_NUMBER() OVER(ORDER BY TRANSMISSION_CLASSIFICATION) AS transmission_id,
    TRANSMISSION_CLASSIFICATION
FROM(
    SELECT DISTINCT TRANSMISSION_CLASSIFICATION
    FROM WHO_TIMESERIES
    WHERE TRANSMISSION_CLASSIFICATION IS NOT NULL
);

SELECT * FROM dim_transmission_classification;
------------------- FACT ---------------------------
-- Integruje všetky zdrojové dáta do jedného faktu
CREATE OR REPLACE TABLE FACT_COVID AS
WITH unified_staging AS(
-- Zjednotenie dát z WHO_TIMESERIES
    SELECT
    TRIM(COUNTRY_REGION) as c_name, CAST(DATE AS DATE) as d_date, 3 as r_type,
    CASES_TOTAL as tot_cases, DEATHS_TOTAL as tot_deaths,
    TRANSMISSION_CLASSIFICATION as trans_class
FROM WHO_TIMESERIES
UNION ALL
-- Zjednotenie dát z WHO_SITUATION_REPORTS
SELECT
    TRIM(COUNTRY_REGION), CAST(DATE AS DATE), 2,
    TOTAL_CASES, DEATHS,
    TRANSMISSION_CLASSIFICATION
FROM WHO_SITUATION_REPORTS
UNION ALL
-- Zjednotenie dát z WHO_DAILY_REPORT
SELECT
    TRIM(COUNTRY_REGION), CAST(DATE AS DATE), 1,
    CASES_TOTAL, DEATHS_TOTAL,
    NULL
FROM WHO_DAILY_REPORT
),
final_calculation AS(
-- Agregácia dát na úroveň krajina + dátum + typ reportu
SELECT
    c_name, d_date, r_type,
    MAX(tot_cases) as cases_max,
    MAX(tot_deaths) as deaths_max,
    MAX(trans_class) as trans_class
FROM unified_staging
GROUP BY 1, 2, 3
)
-- Finálne naplnenie faktovej tabuľky
SELECT
    ROW_NUMBER() OVER (ORDER BY m.d_date, c.country_id) AS fact_id,
    c.country_id,
    d.date_id,
    m.r_type as report_type_id,
    COALESCE(tc.transmission_id, 0) as transmission_id,
    -- Kumulatívne hodnoty
    m.cases_max as total_cases,
    m.deaths_max as deaths_total,
    -- Nové prípady vypočítané pomocou funkcie LAG
    COALESCE(m.cases_max - LAG(m.cases_max) OVER (PARTITION BY c.country_id
    ORDER BY m.d_date), 0) as cases_total_new,

    COALESCE(m.deaths_max - LAG(m.deaths_max) OVER (PARTITION BY c.country_id
    ORDER BY m.d_date), 0) as deaths_new
    
FROM final_calculation m
JOIN DIM_COUNTRY c ON m.c_name = c.country_name
JOIN DIM_DATE d ON m.d_date = d.date
LEFT JOIN dim_transmission_classification tc ON m.trans_class = tc.TRANSMISSION_CLASSIFICATION;
-- Skúškový analytický dotaz
-- Vývoj Covid štatistík pre vybranú krajinu (China)
SELECT c.country_name, d.date, f.total_cases, f.cases_total_new, deaths_total, f.deaths_new, t.TRANSMISSION_CLASSIFICATION
FROM FACT_COVID f
JOIN DIM_COUNTRY c ON f.country_id = c.country_id
JOIN DIM_DATE d ON f.date_id = d.date_id
LEFT JOIN DIM_TRANSMISSION_CLASSIFICATION t ON f.transmission_id = t.transmission_id
WHERE c.country_name = 'China'
ORDER BY d.date ASC;
