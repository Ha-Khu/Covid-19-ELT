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
  Atribúty: cases_total, deaths_total, deaths_new, total_cases<br>
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

