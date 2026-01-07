-- 1. Vývoj prípadov v celkovom čase
SELECT d.date, SUM(f.total_cases) as globalne_pripady
FROM FACT_COVID f
JOIN DIM_DATE d ON f.date_id = d.date_id
GROUP BY d.date
ORDER BY d.date;

-- 2. Priemerný počet úmrtí podľa typu prenosu
SELECT t.TRANSMISSION_CLASSIFICATION as typ_prenosu,
ROUND(AVG(f.deaths_total), 0) as priemerny_pocet_umrti
FROM FACT_COVID f
JOIN dim_transmission_classification t 
    ON f.transmission_id = t.transmission_id
WHERE t.TRANSMISSION_CLASSIFICATION IS NOT NULL
AND t.TRANSMISSION_CLASSIFICATION != 'Unknown'
GROUP BY t.TRANSMISSION_CLASSIFICATION
ORDER BY priemerny_pocet_umrti DESC;

-- 3. Top 10 krajín podľa celkového počtu úmrtí
SELECT c.country_name, MAX(f.deaths_total) as celkovo_umrti
FROM FACT_COVID f
JOIN dim_country c ON f.country_id = c.country_id
WHERE c.country_name NOT IN ('Global')
GROUP BY c.country_name
ORDER BY celkovo_umrti DESC
LIMIT 10;

-- 4. Počet typov prenosu ochorenia
SELECT t.TRANSMISSION_CLASSIFICATION, COUNT(*) as pocet_zaznamov
FROM FACT_COVID f
JOIN dim_transmission_classification t ON f.transmission_id = t.transmission_id
WHERE t.TRANSMISSION_CLASSIFICATION != 'Unknown'
GROUP BY t.TRANSMISSION_CLASSIFICATION;

-- 5. Mesačný prírastok nových prípadov
SELECT DATE_TRUNC('month', d.date) as mesiac,
       SUM(f.cases_total_new) as mesacny_prirastok
FROM FACT_COVID f
JOIN dim_date d ON f.date_id = d.date_id
WHERE d.year != 2021 AND d.year != 2023
GROUP BY mesiac
ORDER BY mesiac ASC;
