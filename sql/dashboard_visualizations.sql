-- (1) Top 10 obchodov
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

-- (2) Top 10 najpredávanejších produktov v obchodoch
SELECT DISTINCT
    p.possible_name AS "Name",
    pc.count_shops_selling AS "Koľko obchodov predáva"
FROM fact_product_pricing pc
JOIN dim_product p ON pc.ean = p.ean
ORDER BY pc.count_shops_selling DESC
LIMIT 10;

-- (3) 10 najlepších obchodov s nízkymi cenami vo Švajčiarsku
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

-- (4) Priemerná pozícia produktov v Google Shopping u obchodov
SELECT 
    s.name AS "Shop Name",
    AVG(pc.position) AS "Average position"
FROM fact_product_pricing pc
JOIN dim_shop s ON pc.idshop = s.idshop
GROUP BY s.name
ORDER BY AVG(pc.position) ASC
LIMIT 10;

-- (5) Priemerná cena podľa krajín
SELECT
    o.country AS "Country",
    AVG(pc.price) AS "Average price"
FROM fact_product_pricing pc
JOIN dim_offer o ON pc.idoffer = o.idoffer
GROUP BY o.country
ORDER BY AVG(pc.price) ASC
LIMIT 10;

-- (6) Ceny 5 najobľúbenejších produktov v CHF
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

 -- (7) Top 10 krajín podľa počtu inzerátov
SELECT
    o.country AS "Country",
    SUM(pc.count_shops_selling) AS "Počet inzerátov"
FROM fact_product_pricing pc
JOIN dim_offer o ON pc.idoffer = o.idoffer
GROUP BY o.country
ORDER BY SUM(pc.count_shops_selling) DESC
LIMIT 10;