# Covid-19-ELT
Téma tohto projektu je analýza vývoja ochorenia COVID-19 na základe verejne dostupných dát Svetovej zdravotníckej organizácie (WHO). Projekt sa zameriava na spracovanie a analýzu časových radov, denných reportov a situačných správ o počte prípadov a úmrtí v jednotlivých krajinách.

---

## 1. Úvod a popis zdrojových dát

Zdrojové dáta pochádzajú z datasetu [Covid-19](https://app.snowflake.com/marketplace/listing/GZSNZ7F5UH/starschema-covid-19-epidemiological-data?sortBy=popular) verejne dostupného v Snowflake Market Place

### Prečo bol zvolený tento dataset
- Verejná dostupnosť v Snowflake Market Place
- reálny a globálny charakter dát
- vhodnosť pre analytické spracovanie a tvorbu dátového skladu
- dostatočný objem dát na demonštráciu ELT procesu

### Biznis proces, ktorý dáta podporujú
Dáta podporujú proces monitorovania a vyhodnocovania epidemiologickej situácie v jednotlivých krajinách. Umožňujú sledovať:
- vývoj počtu potvrdených prípadov,
- vývoj počtu úmrtí,
- rozdiely medzi krajinami a časovými obdobiami,
- typ prenosu ochorenia v čase.

### Zameranie analýzy
- porovnanie vývoja Covid-19 medzi krajinami
- agregácie prípadov a úmrtí podľa rôznych dimenzií

### Popis zdrojových tabuliek
#### WHO_TIMESERIES: 
Táto tabuľka obsahuje časové rady celkového počtu prípadov a úmrtí pre jednotlivé krajiny a dátumy. Zároveň obsahuje informáciu o klasifikácii prenosu ochorenia a ISO kód krajiny. Slúži ako hlavný zdroj agregovaných historických dát.
#### WHO_DAILY_REPORT:
Tabuľka obsahuje denné reporty o počte prípadov a úmrtí pre jednotlivé krajiny. Dáta sú vhodné na detailnú analýzu denných zmien a porovnanie s agregovanými časovými radmi.
#### WHO_SITUATION_REPORTS:
Táto tabuľka obsahuje situačné správy WHO, ktoré zahŕňajú celkový počet prípadov, nové úmrtia a názov konkrétneho reportu. Poskytuje kontextové informácie k epidemiologickej situácii v daný deň.

---

## ERD diagram
Zdrojové tabuľky neobsahujú explicitne definované primárne ani cudzie kľúče, keďže ide o analytické datasety. Vzťahy medzi tabuľkami sú preto logické, založené najmä na kombinácii atribútov COUNTRY_REGION a DATE. ERD diagram slúži ako vizuálny prehľad pôvodnej dátovej štruktúry, ktorá je následne transformovaná do dimenzionálneho modelu (Star Schema).
<p align="center">
  <img src="https://github.com/Ha-Khu/Covid-19-ELT/blob/main/img/ERD_diagram.png" alt="ERD Schema">
</p>

---

## 2. Návrh dimenzionálneho modelu (Star schema)
Pre analytické spracovanie dát bol navrhnutý dimenzionálny model typu Star Schema, ktorý umožňuje efektívne agregácie a jednoduchú tvorbu analytických dotazov a vizualizácií. Model pozostáva z jednej faktovej tabuľky a štyroch dimenzií.
<p align="center">
  <img src="https://github.com/Ha-Khu/Covid-19-ELT/blob/main/img/StarSchema.png" alt="Star schema">
</p>

### Popis dimenzií
- `dim_country` - Obsahuje geografické údaje o jednotlivých krajinách (country_id(PK), country_region, ISO3166_1)
- `dim_date` - Slúži na časovú analýzu dát (date_id(PK), date, year, month, day)
- `dim_report_type` - Obsahuje dáta z ktorého metriky pochádzajú (report_type_id(PK), report_name)
- `dim_transmission_classification` - Obsahuje klasifikácie prenosu ochorenia (transmission_id(PK), transmission_classification)

### Popis faktovej tabuľky
- `fact_covid` - Obsahuje hlavné metriky súvisiace s vývojom ochorenia COVID-19 a prepája jednotlivé dimenzie (<br>
  PK: fact_id<br>
  FK: country_id, date_id, report_type_id, transmission_id<br>
  Atribúty: cases_total_new, deaths_total, deaths_new, total_cases<br>
  )

---

## 3. ELT proces v Snowflake
### Extrahovanie a načítanie dát:
Zdrojové dáta boli získané priamo zo Snowflake Marketplace prostredníctvom zdieľaného datasetu. Tento prístup eliminuje potrebu manuálneho sťahovania súborov, nakoľko dáta sú prístupné priamo v Snowflake prostredníctvom databázy Covid-19

Pre účely projektu boli zo schémy WHO vybrané tri hlavné tabuľky:
- WHO_TIMESERIES
- WHO_DAILY_REPORT
- WHO_SITUATION_REPORTS

Následne prebehlo načítanie dát (Vytvorenie staging tabuliek pre surové dáta)

```sql
CREATE OR REPLACE TABLE WHO_TIMESERIES AS
SELECT * 
FROM COVID19_EPIDEMIOLOGICAL_DATA.PUBLIC.WHO_TIMESERIES;

CREATE OR REPLACE TABLE WHO_SITUATION_REPORTS AS
SELECT * 
FROM COVID19_EPIDEMIOLOGICAL_DATA.PUBLIC.WHO_SITUATION_REPORTS;

CREATE OR REPLACE TABLE WHO_DAILY_REPORT AS
SELECT * 
FROM COVID19_EPIDEMIOLOGICAL_DATA.PUBLIC.WHO_DAILY_REPORT;
```

Prebehlo overenie, či sa surové dáta zo Snowflake Marketplace správne načítali do staging vrstvy

```sql
SELECT * FROM WHO_TIMESERIES;
SELECT * FROM WHO_SITUATION_REPORTS;
SELECT * FROM WHO_DAILY_REPORT;
```

---

### Transformácia dát
V tejto fáze prebehlo čistenie, deduplikácia a reorganizácia dát zo staging tabuliek do finálnej štruktúry dimenzií a faktovej tabuľky.

### Dimenzie
Dimenzie boli navrhnuté tak, aby poskytovali kontext pre epidemiologické štatistiky.

Dimenzia `dim_date` je kľúčová pre časovú analýzu vývoja pandémie. Obsahuje rozdelenie na rok, mesiac a deň. Táto dimenzia je klasifikovaná ako SCD Typ 0, pretože kalendárne údaje sú statické a nemenné.

```sql
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
```

Dimenzia `dim_country` obsahuje geografické údaje o krajinách. Pri transformácii bol použitý príkaz `TRIM` na odstránenie bielych znakov a `DISTINCT` na zabezpečenie unikátnosti záznamov. Z hľadiska zachovania histórie je táto dimenzia typu SCD Typ 1, čo znamená, že v prípade zmeny názvu krajiny sa hodnota prepíše najaktuálnejšou.

```sql
CREATE OR REPLACE TABLE dim_country AS
SELECT 
    ROW_NUMBER() OVER (ORDER BY country_name) AS country_id,
    country_name,
    iso_code
FROM(
    SELECT DISTINCT TRIM(COUNTRY_REGION) as country_name, ISO3166_1 as iso_code FROM WHO_TIMESERIES
    UNION
    SELECT DISTINCT TRIM(COUNTRY_REGION), ISO3166_1 FROM WHO_SITUATION_REPORTS
);
```

Dimenzia `dim_report_type` slúži ako číselník pre typy správ (napr. Timeseries, Daily report), čo umožňuje filtrovať metriky podľa ich pôvodu. Ide o SCD Typ 0.

```sql
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
```

Dimenzia `dim_transmission_classification` uchováva informácie o type šírenia nákazy. Táto kategorizácia je dôležitá pre epidemiologické štúdie a porovnávanie efektivity opatrení. Z hľadiska zachovania dát ide o SCD Typ 0, keďže klasifikácie priradené k historickým reportom sa spätne nemenia.

```sql
CREATE OR REPLACE TABLE dim_transmission_classification AS
SELECT 
    ROW_NUMBER() OVER(ORDER BY TRANSMISSION_CLASSIFICATION) AS transmission_id,
    TRANSMISSION_CLASSIFICATION
FROM(
    SELECT DISTINCT TRANSMISSION_CLASSIFICATION
    FROM WHO_TIMESERIES
    WHERE TRANSMISSION_CLASSIFICATION IS NOT NULL
);
```
### Faktová tabuľka

Faktová tabuľka `FACT_COVID` predstavuje centrálny bod modelu a prepája všetky dimenzie. Obsahuje kľúčové metriky o počte nakazených a úmrtí. Proces jej tvorby zahŕňal zjednotenie troch rôznych zdrojov dát pomocou operácie `UNION ALL` a následné čistenie dát v rámci spoločnej staging vrstvy. Pre hlbšiu analytickú hodnotu boli použité window funkcie (`LAG`), ktoré umožnili transformovať kumulatívne údaje na denné prírastky (`cases_total_new`, `deaths_new`).

```sql
CREATE OR REPLACE TABLE FACT_COVID AS
WITH unified_staging AS(
    SELECT
    TRIM(COUNTRY_REGION) as c_name, CAST(DATE AS DATE) as d_date, 3 as r_type,
    CASES_TOTAL as tot_cases, DEATHS_TOTAL as tot_deaths,
    TRANSMISSION_CLASSIFICATION as trans_class
FROM WHO_TIMESERIES
UNION ALL

SELECT
    TRIM(COUNTRY_REGION), CAST(DATE AS DATE), 2,
    TOTAL_CASES, DEATHS,
    TRANSMISSION_CLASSIFICATION
FROM WHO_SITUATION_REPORTS
UNION ALL

SELECT
    TRIM(COUNTRY_REGION), CAST(DATE AS DATE), 1,
    CASES_TOTAL, DEATHS_TOTAL,
    NULL
FROM WHO_DAILY_REPORT
),
final_calculation AS(
SELECT
    c_name, d_date, r_type,
    MAX(tot_cases) as cases_max,
    MAX(tot_deaths) as deaths_max,
    MAX(trans_class) as trans_class
FROM unified_staging
GROUP BY 1, 2, 3
)
SELECT
    ROW_NUMBER() OVER (ORDER BY m.d_date, c.country_id) AS fact_id,
    c.country_id,
    d.date_id,
    m.r_type as report_type_id,
    COALESCE(tc.transmission_id, 0) as transmission_id,
    m.cases_max as total_cases,
    m.deaths_max as deaths_total,

    COALESCE(m.cases_max - LAG(m.cases_max) OVER (PARTITION BY c.country_id
    ORDER BY m.d_date), 0) as cases_total_new,

    COALESCE(m.deaths_max - LAG(m.deaths_max) OVER (PARTITION BY c.country_id
    ORDER BY m.d_date), 0) as deaths_new
    
FROM final_calculation m
JOIN DIM_COUNTRY c ON m.c_name = c.country_name
JOIN DIM_DATE d ON m.d_date = d.date
LEFT JOIN dim_transmission_classification tc ON m.trans_class = tc.TRANSMISSION_CLASSIFICATION;
```

Následne prebehla validácia dát pomocou dopytu nad krajinou Čína, kde bolo overené správne prepojenie na všetky dimenzie vrátane klasifikácie prenosu.

```sql
SELECT c.country_name, d.date, f.total_cases, f.cases_total_new, deaths_total, f.deaths_new, t.TRANSMISSION_CLASSIFICATION
FROM FACT_COVID f
JOIN DIM_COUNTRY c ON f.country_id = c.country_id
JOIN DIM_DATE d ON f.date_id = d.date_id
LEFT JOIN DIM_TRANSMISSION_CLASSIFICATION t ON f.transmission_id = t.transmission_id
WHERE c.country_name = 'China'
ORDER BY d.date ASC;
```

---

## 4. Vizualizácia dát

Dashboard obsahuje 5 vizualizácií ktoré slúžia na prezentáciu analytických výstupov. Cieľom bolo prehľadne zobraziť vývoj ochorenia Covid-19 v čase a porovnať situáciu medzi krajinami a taktiež identifikovať počty prípadov a úmrtí

<p align="center">
  <img src="https://github.com/Ha-Khu/Covid-19-ELT/blob/main/img/Covid-19_dashboard.png" alt="dashboard png">
</p>

--- 

### Graf 1: Vývoj prípadov v celkovom čase
Tento graf zobrazuje kumulatívny nárast celkového počtu potvrdených prípadov COVID-19 na globálnej úrovni. Umožňuje sledovať celkovú trajektóriu pandémie a identifikovať obdobia najrýchlejšieho šírenia vírusu.

```sql
SELECT d.date, SUM(f.total_cases) as globalne_pripady
FROM FACT_COVID f
JOIN DIM_DATE d ON f.date_id = d.date_id
GROUP BY d.date
ORDER BY d.date;
```

---

### Graf 2: Priemerný počet úmrtí podľa typu prenosu
Graf analyzuje závažnosť dopadov pandémie v závislosti od spôsobu šírenia nákazy. Zobrazuje priemerný počet úmrtí pripadajúcich na jednotlivé kategórie klasifikácie prenosu. Pomáha identifikovať, ktoré typy prenosu (napr. komunitné šírenie) sú štatisticky spojené s vyššou mortalitou, čo je kľúčové pre pochopenie rizikovosti rôznych prostredí.

```sql
SELECT t.TRANSMISSION_CLASSIFICATION as typ_prenosu,
ROUND(AVG(f.deaths_total), 0) as priemerny_pocet_umrti
FROM FACT_COVID f
JOIN dim_transmission_classification t 
    ON f.transmission_id = t.transmission_id
WHERE t.TRANSMISSION_CLASSIFICATION IS NOT NULL
AND t.TRANSMISSION_CLASSIFICATION != 'Unknown'
GROUP BY t.TRANSMISSION_CLASSIFICATION
ORDER BY priemerny_pocet_umrti DESC;
```

---

### Graf 3: Top 10 krajín podľa celkového počtu úmrtí
Vizualizácia identifikuje desať krajín, ktoré zaznamenali najvyšší celkový počet obetí. Z analýzy sú odfiltrované súhrnné globálne záznamy, aby sa zachovala relevantnosť na úrovni jednotlivých štátov. Poskytuje jasný prehľad o tom, ktoré geografické oblasti boli pandémiou zasiahnuté najtragickejšie z hľadiska absolútnych čísiel.

```sql
SELECT c.country_name, MAX(f.deaths_total) as celkovo_umrti
FROM FACT_COVID f
JOIN dim_country c ON f.country_id = c.country_id
WHERE c.country_name NOT IN ('Global')
GROUP BY c.country_name
ORDER BY celkovo_umrti DESC
LIMIT 10;
```

---

### Graf 4: Počet typov prenosu ochorenia
Tento graf zobrazuje distribúciu záznamov v databáze podľa klasifikácie prenosu. Odfiltrované sú neznáme kategórie ('Unknown'). Demonštruje variabilitu dát v dimenzii prenosu a ukazuje, ktoré scenáre šírenia boli v hláseniach WHO najčastejšie zastúpené.

```sql
SELECT t.TRANSMISSION_CLASSIFICATION, COUNT(*) as pocet_zaznamov
FROM FACT_COVID f
JOIN dim_transmission_classification t ON f.transmission_id = t.transmission_id
WHERE t.TRANSMISSION_CLASSIFICATION != 'Unknown'
GROUP BY t.TRANSMISSION_CLASSIFICATION;
```

---

### Graf 5: Mesačný prírastok nových prípadov
graf zobrazuje dynamiku šírenia nákazy agregovanú na úrovni mesiacov čo umožňuje lepšie sledovanie dlhodobých trendov a sezónnych výkyvov. Dáta sú očistené o roky 2021 a 2023 pre lepšiu prehľadnosť špecifických vĺn pandémie.

```sql
SELECT DATE_TRUNC('month', d.date) as mesiac,
       SUM(f.cases_total_new) as mesacny_prirastok
FROM FACT_COVID f
JOIN dim_date d ON f.date_id = d.date_id
WHERE d.year != 2021 AND d.year != 2023
GROUP BY mesiac
ORDER BY mesiac ASC;
```

---
Autor: Dávid Plevka
---
