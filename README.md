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
