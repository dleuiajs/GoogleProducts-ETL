# ETL proces datasetu Google Shopping Products Prices
Tento repozitár ukazuje implementáciu procesu ELT v Snowflake na tému "Produkty Google Shopping" a vytvorenie dátového skladu so schémou Star. Projekt pracuje s dátovým súborom "Google Shopping Products Prices Dataset" prevzatým z Snowflake marketplace. Projekt umožňuje posúdiť trh elektronických obchodov, ich reklám a produktov.
Výsledný dátový model umožňuje multidimenzionálnu analýzu a vizualizáciu kľúčových metrik.

---
## 1. Úvod a popis zdrojových dát
Témou projektu je analýza trhu obchodov a ich tovaru, možnosť sledovať ceny, obľúbené tovary a obchody, analyzovať údaje podľa krajín a prispôsobiť tak svoj obchod najlepším cenám, tovarom a krajinám v porovnaní s konkurenciou.

Projekt podporuje nasledujúce biznis procesy *(Analýza trhu)*:
- Zlepšite cenotvorbu produktov, aby ste dosiahli zdravú maržu z predaja.
- Upravte cenovú hladinu populárnych položiek.
- Zvýšte ceny, aby ste dosiahli zdravú maržu, ak je to možné.
- Zvýšte predaj a konverzný pomer.
- Zobraziť všetky obchody, ktoré predávajú rovnaké položky: získajte prehľad o konkurencii podľa položky, kategórie, značky.
- Identifikujte trendy na trhu, v kategórii alebo krajine a identifikujte preferencie spotrebiteľov.
- Získajte prehľad o svojej značke: kto predáva ktoré položky a za aké ceny

Údaje sú prevzaté z dátového súboru, ktorý sa nachádza na Snowflake Marketplace na [tomto odkaze](https://app.snowflake.com/marketplace/listing/GZTDZSU79C/dataedis-google-shopping-products-prices-dataset)

V dátovom súbore sa nachádza 1 tabuľka so všetkými údajmi, z ktorých môžeme zistiť:
- `product` - EAN tovaru
- `shop` – názov obchodu, jeho hodnotenie a počet recenzií
- `promotion` – text štítku
- `offer` – odkaz na tovar, jeho aktuálnu a starú cenu, cenu dopravy, konečnú cenu, pozíciu v reklame, menu, v ktorej sa predáva, krajinu, či je potvrdený, či sa predáva priamo v Google, ako aj dodatočný komentár.
A tiež zistiť dátum a čas aktualizácie údajov.

Účelom ELT procesu bolo tieto dáta pripraviť, transformovať a sprístupniť pre viacdimenzionálnu analýzu.

---
### 1.1 Dátová architektúra

### ERD diagram
Údaje sú uložené v jednej tabuľke v rámci relačnej databázy, avšak bez rozdelenia na viacero entít:

<p align="center">
  <img src="https://github.com/dleuiajs/GoogleProducts-ETL/blob/main/img/erd_schema.png" alt="ERD Schema">
  <br>
  <em>Obrázok 1. Entitno-relačná schéma Google Shopping</em>
</p>

---
## 2. Dimenzionálny model
V ukážke bola navrhnutá **schéma hviezdy (star schema)** podľa Kimballovej metodológie, ktorá obsahuje 1 tabuľku faktov **`fact_product_pricing`**, ktorá je prepojená s nasledujúcimi 6 dimenziami:
- **`dim_product`** - obsahuje údaje o tovare (jeho EAN a možný názov *(ktorý bude rozpoznaný z URL)*). Vzťah 1:N, SCD 1
- **`dim_shop`** - obsahuje údaje o obchode (jeho názov, ako aj odkaz *(ktorý sa rozpozná z URL)*). Vzťah 1:N, SCD 1
- **`dim_promotion`** - obsahuje údaje o propagácii tovaru (text na propagáciu). Vzťah 1:N, SCD 1
- **`dim_offer`** - obsahuje údaje o tovare v obchode (odkaz na tovar, mena, v ktorej sa predáva, krajina, či je tovar potvrdený a či sa predáva priamo v Google). Vzťah 1:N, SCD 0
- **`dim_time`** – obsahuje údaje o čase (celkový čas, hodina, minúta, sekunda, am alebo pm). Vzťah 1:N, SCD 0
- **`dim_date`** – obsahuje údaje o dátume (celý dátum, rok, mesiac, deň, štvrťrok, názov dňa). Vzťah 1:N, SCD 0
- **`fact_product_pricing`** - obsahuje primárny kľúč `id_product_pricing`, cudzie kľúče: `idshop`, `ean`, `idoffer`, `idpromotion`, `iddate`, `idtime` a hlavné metriky: `price`, `old_price`, `shipping_cost`, `total_cost`, `position`, `shop_review_rating`, `shop_review_count`, `avg_product_price` a `count_shops_selling`.

Štruktúra hviezdicového modelu je znázornená na diagrame nižšie. Diagram ukazuje prepojenia medzi faktovou tabuľkou a dimenziami, čo zjednodušuje pochopenie a implementáciu modelu.

<p align="center">
  <img src="https://github.com/dleuiajs/GoogleProducts-ETL/blob/main/img/star_schema.png" alt="Star Schema">
  <br>
  <em>Obrázok 2. Schéma hviezdy pre Google Shopping</em>
</p>

---
## 3. ELT proces v Snowflake
ETL proces pozostáva z: `extrahovanie` (Extract), `načítanie` (Load) a `transformácia` (Transform). Tento proces bol implementovaný v Snowflake s cieľom pripraviť zdrojové dáta zo staging vrstvy do viacdimenzionálneho modelu vhodného na analýzu a vizualizáciu.

---
### 3.1 Extract
Údaje z pôvodného datasetu (ktorý bol získaný zo Snowflake Marketplace [tu](https://app.snowflake.com/marketplace/listing/GZTDZSU79C/dataedis-google-shopping-products-prices-dataset)) boli importované do mojej databázy z získanej databázy `GOOGLE_SHOPPING_PRODUCTS_PRICES_DATASET` a jej schémy `PUBLIC` prostredníctvom tabuľky stage.

#### Kód:
```sql
CREATE OR REPLACE TABLE products_staging AS
SELECT * FROM GOOGLE_SHOPPING_PRODUCTS_PRICES_DATASET.PUBLIC.GOOGLE_SHOPPING;
```
Tento príkaz vytvorí alebo nahradí tabuľku `products_staging`, v ktorej sa údaje čerpajú z tabuľky `GOOGLE_SHOPPING` datasetu.

Po importe som skontroloval, či je všetko v poriadku, pomocou príkazu:
```sql
SELECT * FROM products_staging;
```

---
### 3.2 Load
Získané údaje zo stage tabuliek je teraz potrebné použiť na vyplnenie tabuľky faktov a tabuliek dimenzií vo vytvorenej schéme Star.

#### Príklad kódu:
```sql
CREATE OR REPLACE TABLE dim_offer AS
SELECT
    ROW_NUMBER() OVER (ORDER BY url) AS idoffer,
    url,
    currency,
    country,
    verified,
    directly_sold_on_google,
    offer_additional_comment AS additional_comment
FROM (
    SELECT *
    FROM (
        SELECT
            url,
            currency,
            country,
            verified,
            directly_sold_on_google,
            offer_additional_comment,
            ROW_NUMBER() OVER (PARTITION BY url ORDER BY position) AS rn
        FROM products_staging
    ) t
    WHERE rn = 1
);
```
V tomto príkaze sa vytvára alebo nahrádza tabuľka `dim_offer`, ktorá preberá údaje z tabuľky `products_staging`, a to `url`, `currency`, `country`, `verified`, `directly_sold_on_google` a `offer_additional_comment`. V príkaze boli použité window funkcie a poddotaz, ktorý pomáha odstrániť duplikáty, ale to bude podrobnejšie rozoberané v [3.3 Transform](#33-transform).

---
### 3.3 Transform
V tejto fáze odstránime nadbytočné údaje, odstránime duplicity, zjednotíme typy, vytvoríme dodatočné atribúty, ktoré budú užitočné pre naše diagramy a použijeme window funkcie.

Pozrime sa na transformáciu tabuľky `dim_offer`, ktorú sme rozoberali v časti [3.2 Load](#32-load):
#### Kód:
```sql
CREATE OR REPLACE TABLE dim_offer AS
SELECT
    ROW_NUMBER() OVER (ORDER BY url) AS idoffer,
    url,
    currency,
    country,
    verified,
    directly_sold_on_google,
    offer_additional_comment AS additional_comment
FROM (
    SELECT *
    FROM (
        SELECT
            url,
            currency,
            country,
            verified,
            directly_sold_on_google,
            offer_additional_comment,
            ROW_NUMBER() OVER (PARTITION BY url ORDER BY position) AS rn
        FROM products_staging
    ) t
    WHERE rn = 1
);
```
Tu používame funkciu Window **ROW_NUMBER()** pre `idoffer`, ktorá čísluje každý tovar z objednávky podľa odkazu, v poddotaze opäť používame **ROW_NUMBER()** pre `rn`, avšak už s poradím tovaru v reklamných oznámeniach, potom vyberieme všetky riadky, kde `rn` = 1, t. j. odstránime duplicitné záznamy.

Určite skontrolujeme, či sú všetky údaje správne zaznamenané:
#### Kód:
```sql
SELECT * FROM dim_offer;
```

Teraz sa pozrime na tabuľku `dim_product`:
#### Kód:
```sql
CREATE OR REPLACE TABLE dim_product AS
WITH withName AS (
    SELECT
        ean,
        SPLIT(
            SPLIT(url, '/')[ARRAY_SIZE(SPLIT(url, '/')) - 1], '?'
        )[0]::TEXT AS possible_name
    FROM products_staging
)
SELECT
    ean,
    possible_name
FROM withName
QUALIFY ROW_NUMBER() OVER (
    PARTITION BY ean
    ORDER BY
        CASE
            WHEN possible_name RLIKE '^[A-Za-z-]+$' THEN 0
            ELSE 1
        END,
        LENGTH(possible_name) DESC,
        possible_name
) = 1;
```

Tu používame **CTE**, v ktorom vyberáme z tabuľky `products_staging` `EAN` tovaru, a potom pomocou `URL` najprv ho rozdelíme pomocou prikazu **SPLIT()** s oddeľovačom '/' a pomocou **ARRAY_SIZE() - 1** vyberieme poslednú časť v tomto poli, t. j. zvyčajne názov tovaru  *(nie vždy je to však názov tovaru, ďalej sa pozrieme na to, ako vybrať názov z viacerých obchodov)*. Ďalej opäť použijeme **SPLIT()**, ale už s oddeľovačom '?', aby sme oddelili reťazec požiadavky a vybrali prvý prvok. Nezabudnime previesť na typ **TEXT** pomocou `::TEXT`, pretože **SPLIT()** vracia iný typ. Nazvime tento atribút `possible_name`.
Ďalej v prikaze vyberieme ten istý `ean` a `possible_name`, avšak potom použijeme **QUALIFY** (ktorý je analógiou **WHERE**, ale môže sa používať s Window funkciami) a použijeme **ROW_NUMBER()**, kde zoskupíme podľa `ean` a urobíme poradie pomocou **CASE**, v ktorom použijeme **RLIKE**, ktorý kontroluje zhodu s **regulárnym výrazom** '^[A-Za-z-]+$'.
Rozložme si náš výraz podrobnejšie:
- `^` - začiatok riadku
- `A-Z` - písmená od A do Z
- `a-z` písmená od a do z
- `-` - zahrnieme spojovník
- `+` - jeden alebo viac znakov
- `$` - koniec riadku

Výraz kontroluje, či celý riadok pozostáva iba z latinských písmen a spojovníkov
Ak náš `possible_name` zodpovedá výrazu, umiestnime ho na miesto 0 v poradí, inak ho umiestnime na vyššie miesto 1. Tým pádom budeme mať na prvom mieste najvhodnejší význam pre nás.
Ďalej skontrolujeme riadok, ktorý je na prvom mieste, vrátime ho a dostaneme možný názov tovaru.

Teraz sa pozrime na tabuľku `dim_shop`:
#### Kód:
```sql
CREATE OR REPLACE TABLE dim_shop AS
SELECT
    ROW_NUMBER() OVER (ORDER BY shop_name) AS idshop,
    shop_name AS name,
    shop_url AS url
FROM (
    SELECT DISTINCT shop_name, CONCAT('https://', SPLIT_PART(url, '/', 3)) AS shop_url FROM products_staging
);
```

V nej pomocou **ROW_NUMBER()** stále robíme `idshop`, a v poddotaze vyberáme jedinečné hodnoty podľa `shop_name` a `url`, ale url obchodu sme dodatočne pridali pre pohodlie analytikov pomocou **SPLIT_PART()**, ktorá rozdeľuje url tovaru na časti s oddeľovačom '/'' a berie 3. časť (pretože názov obchodu bude v tretej časti), a ďalej používame **CONCAT()**, aby sme vrátili 'https://' na začiatok.

Teraz sa pozrime na tabuľku `dim_date`, ktorá je podobná tabuľke `dim_time`:
#### Kód:
```sql
CREATE OR REPLACE TABLE dim_date AS
SELECT DISTINCT
    TO_CHAR(DATE(lu), 'YYYYMMDD') AS iddate,
    DATE(lu) AS date,
    YEAR(lu) AS year,
    MONTH(lu) AS month,
    DAY(lu) AS day,
    QUARTER(lu) AS quarter,
    CASE DAYNAME(lu)
        WHEN 'Mon' THEN 'Monday'
        WHEN 'Tue' THEN 'Tuesda y'
        WHEN 'Wed' THEN 'Wednesday'
        WHEN 'Thu' THEN 'Thursday'
        WHEN 'Fri' THEN 'Friday'
        WHEN 'Sat' THEN 'Saturday'
        WHEN 'Sun' THEN 'Sunday' END AS weekday
FROM (
    SELECT TO_TIMESTAMP_LTZ(latest_update) as lu FROM products_staging
);
```

Tu najprv v poddotaze premeníme `latest_update` cez **TO_TIMESTAMP_LTZ()**, pretože tento atribút je pôvodne v nevhodnom formáte, potom pre `iddate` použijeme **DATE()** a cez **TO_CHAR()** premeníme na náš formát:
- `YYYY` - rok
- `MM` - mesiac
- `DD` - deň
Ďalej zapíšeme **DATE()** ako `date`, **YEAR()** ako `year`, **MONTH()** ako `month`, **DAY()** ako `day`, **QUARTER()** ako `quarter` a pomocou **CASE** a **DAYNAME()** zapíšeme celý názov dňa ako `weekname`.

A na záver sa pozrime na `fact_product_pricing`:
#### Kód:
```sql
CREATE OR REPLACE TABLE fact_product_pricing AS
SELECT
    ROW_NUMBER() OVER (ORDER BY ean, idshop) AS id_product_pricing,
    idshop,
    ean,
    idoffer,
    idpromotion,
    iddate,
    idtime,
    price,
    old_price,
    shipping_cost,
    total_cost,
    position,
    shop_review_rating,
    shop_review_count,
    avg_product_price,
    count_shops_selling
FROM (
    SELECT DISTINCT
        s.idshop,
        p.ean,
        o.idoffer,
        pr.idpromotion,
        ddate.iddate,
        dtime.idtime,
        ps.price,
        ps.old_price,
        ps.shipping_cost,
        ps.total_cost,
        ps.position,
        ps.shop_review_rating,
        ps.shop_review_count,
        -- ELT - Transform (Window functions)
        AVG(ps.price) OVER (PARTITION BY p.ean) AS avg_product_price,
        COUNT(DISTINCT ps.shop_name) OVER (PARTITION BY p.ean) AS count_shops_selling,
        -- Removing duplicates
        ROW_NUMBER() OVER (PARTITION BY o.url, ddate.date, dtime.time ORDER BY position) AS rn
    FROM products_staging ps
    JOIN dim_product p ON ps.ean = p.ean
    JOIN dim_shop s ON ps.shop_name = s.name
    JOIN dim_promotion pr ON COALESCE(ps.promotion_label_text, 'N/A') = pr.label_text
    JOIN dim_offer o ON ps.url = o.url
    JOIN dim_date ddate ON TO_CHAR(DATE(TO_TIMESTAMP_LTZ(latest_update)), 'YYYYMMDD') = ddate.iddate
    JOIN dim_time dtime ON TO_CHAR(TIME(TO_TIMESTAMP_LTZ(latest_update))::TIME(0), 'HH24MISS') = dtime.idtime
)
WHERE rn = 1;
```

V poddotaze pripojíme `products_staging`, `dim_product`, `dim_shop`, `dim_promotion`, `dim_offer`, `dim_date` a `dim_time` a vyberieme `idshop`, `ean`, `idoffer`, `idpromotion`, `iddate`, `idtime`, `price`, `old_price`, `shipping_cost`, `total_cost`, `position`, `shop_review_rating`, `shop_review_count`, a potom pomocou Window funkcie **AVG()** vypočítame priemernú cenu tovaru pomocou **PARTITION BY p.ean** a priradíme ju ako `avg_product_price`, ďalej pomocou **COUNT(DISTINCT ps.shop_name)** a **PARTITION BY p.ean** vypočítame počet obchodov, ktoré predávajú daný tovar, a na konci použijeme **ROW_NUMBER()** na odstránenie duplikátov, ale už s **PARTITION BY o.url, ddate.date, dtime.time**, aby sme ponechali riadky, ak má tovar rôzny čas aktualizácie údajov pre správne zobrazenie histórie. A v hlavnem dotaze pridáme `id_product_pricing` ako zvyčajne a opäť zapíšeme všetky atribúty okrem `rn`.

Na samom konci, keď sme už vykonali všetky kroky so stage tabuľkou, ju odstránime:

#### Kód:
```sql
DROP TABLE IF EXISTS products_staging;
```

---
## 4. Vizualizácia dát
Dashboard obsahuje **7 vizualizácií**, z ktorých každá pomôže analyzovať trh, obchody, ich tovary a ich reklamu.

### Graf 1: Top 10 obchodov
Táto vizualizácia zobrazí 10 najlepších obchodov na základe ich hodnotenia, počtu recenzií a množstva predávaného tovaru. Pomáha analyzovať konkurenciu a na základe toho vylepšiť svoj obchod.

<p align="center">
  <img src="https://github.com/dleuiajs/GoogleProducts-ETL/blob/main/img/graf1.png" alt="Graf 1">
  <br>
  <em>Obrazok 3. Graf 1 - Top 10 obchodov</em>
</p>

```sql
SELECT
    s.name AS "Shop",
    pc.shop_review_rating AS "Shop Rating",
    pc.shop_review_count AS "Shop Reviews Count",
    COUNT(pc.idoffer) AS "Offers Count"
FROM fact_product_pricing pc
JOIN dim_shop s ON pc.idshop = s.idshop 
WHERE pc.shop_review_count > 1000
GROUP BY s.name, pc.shop_review_rating, shop_review_count
ORDER BY pc.shop_review_rating DESC, shop_review_count DESC, COUNT(pc.idoffer) DESC
LIMIT 10;
```

---
### Graf 2: Top 10 najpredávanejších produktov v obchodoch
Táto vizualizácia zobrazuje 10 najpredávanejších produktov v obchodoch. Umožňuje zistiť, ktoré produkty sú momentálne najpopulárnejšie, aby ste ich mohli pridať do svojho obchodu.

<p align="center">
  <img src="https://github.com/dleuiajs/GoogleProducts-ETL/blob/main/img/graf2.png" alt="Graf 2">
  <br>
  <em>Obrazok 4. Graf 2 - Top 10 najpredávanejších produktov v obchodoch</em>
</p>

```sql
SELECT DISTINCT
    p.possible_name AS "Name",
    pc.count_shops_selling AS "Koľko obchodov predáva"
FROM fact_product_pricing pc
JOIN dim_product p ON pc.ean = p.ean
ORDER BY pc.count_shops_selling DESC
LIMIT 10;
```

---
### Graf 3: 10 najlepších obchodov s nízkymi cenami vo Švajčiarsku
Táto vizualizácia zobrazí 10 obchodov s najnižšími cenami, aby ste mohli svoje ceny stanoviť na základe nich.

<p align="center">
  <img src="https://github.com/dleuiajs/GoogleProducts-ETL/blob/main/img/graf3.png" alt="Graf 3">
  <br>
  <em>Obrazok 5. Graf 3 - 10 najlepších obchodov s nízkymi cenami vo Švajčiarsku</em>
</p>

```sql
SELECT
    s.name AS "Shop",
    AVG(pc.price) AS "Min Avg Price"
FROM fact_product_pricing pc
JOIN dim_shop s ON pc.idshop = s.idshop 
JOIN dim_offer o ON pc.idoffer = o.idoffer
WHERE o.country = 'CH'
GROUP BY s.name
ORDER BY AVG(pc.price) ASC
LIMIT 10;
```

---
### Graf 4: Priemerná pozícia produktov v Google Shopping u obchodov
Táto vizualizácia zobrazí 10 obchodov, ktoré majú najnižšiu priemernú pozíciu produktu v reklamných oznámeniach. Umožňuje nám pochopiť, ktoré obchody nakupujú najviac reklamy, zistiť, do akej miery reklama ovplyvňuje obchod, a určiť cenu oznámení pre svoj obchod.

<p align="center">
  <img src="https://github.com/dleuiajs/GoogleProducts-ETL/blob/main/img/graf4.png" alt="Graf 4">
  <br>
  <em>Obrazok 6. Graf 4 - Priemerná pozícia produktov v Google Shopping u obchodov</em>
</p>

```sql
SELECT 
    s.name AS "Shop Name",
    AVG(pc.position) AS "Average position"
FROM fact_product_pricing pc
JOIN dim_shop s ON pc.idshop = s.idshop
GROUP BY s.name
ORDER BY AVG(pc.position) ASC
LIMIT 10;
```

---
### Graf 5: Priemerná cena podľa krajín
Táto vizualizácia ukazuje 10 krajín s najnižšou priemernou cenou produktu. Umožňuje zorientovať sa, v ktorých krajinách je možné predávať produkt za vyššiu cenu.

<p align="center">
  <img src="https://github.com/dleuiajs/GoogleProducts-ETL/blob/main/img/graf5.png" alt="Graf 5">
  <br>
  <em>Obrazok 7. Graf 5 - Priemerná cena podľa krajín</em>
</p>

```sql
SELECT
    o.country AS "Country",
    AVG(pc.price) AS "Average price"
FROM fact_product_pricing pc
JOIN dim_offer o ON pc.idoffer = o.idoffer
GROUP BY o.country
ORDER BY AVG(pc.price) ASC
LIMIT 10;
```

---
### Graf 6: Ceny 5 najobľúbenejších produktov v CHF
Táto vizualizácia zobrazí minimálnu, priemernú a maximálnu cenu 5 najpredávanejších produktov. Umožňuje analyzovať ceny populárnych produktov a na základe nich stanoviť cenu svojich produktov.

<p align="center">
  <img src="https://github.com/dleuiajs/GoogleProducts-ETL/blob/main/img/graf6.png" alt="Graf 6">
  <br>
  <em>Obrazok 8. Graf 6 - Ceny 5 najobľúbenejších produktov v CHF</em>
</p>

```sql
SELECT
    p.possible_name AS "Product Name",
    pc.count_shops_selling AS "Koľko obchodov predáva",
    MIN(pc.price) AS "Min Price",
    pc.avg_product_price AS "Avg Price",
    MAX(pc.price) AS "Max Price",
FROM fact_product_pricing pc
JOIN dim_product p ON pc.ean = p.ean
JOIN dim_offer o ON pc.idoffer = o.idoffer
WHERE o.currency = 'CHF'
GROUP BY p.possible_name, count_shops_selling, pc.avg_product_price
ORDER BY count_shops_selling DESC
LIMIT 5;
```

---
### Graf 7: Top 10 krajín podľa počtu inzerátov
Táto vizualizácia ukazuje 10 krajín s najvyšším počtom predaných produktov a umožňuje zistiť, v ktorých krajinách sa predáva najmenej produktov, aby bolo možné tento deficit doplniť vlastnými produktmi.

<p align="center">
  <img src="https://github.com/dleuiajs/GoogleProducts-ETL/blob/main/img/graf7.png" alt="Graf 7">
  <br>
  <em>Obrazok 9. Graf 7 - Top 10 krajín podľa počtu inzerátov</em>
</p>

```sql
SELECT
    o.country AS "Country",
    SUM(pc.count_shops_selling) AS "Počet inzerátov"
FROM fact_product_pricing pc
JOIN dim_offer o ON pc.idoffer = o.idoffer
GROUP BY o.country
ORDER BY SUM(pc.count_shops_selling) DESC
LIMIT 10;
```

---

**Autor:** Mykyta Nikiforov

---