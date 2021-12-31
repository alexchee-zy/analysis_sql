-- 1. Identifying top website pages
SELECT 
    pageview_url,
    COUNT(DISTINCT website_session_id) AS sessions
FROM
    website_pageviews
WHERE
    created_at < '2012-06-09'
GROUP BY pageview_url
ORDER BY sessions DESC;

-- 2. Identifying top entry pages
with entry_page as (
SELECT 
    website_session_id,
    MIN(website_pageview_id) AS first_pageview_id,
    pageview_url as landing_page
FROM
    website_pageviews
WHERE
    created_at < '2012-06-12'
GROUP BY website_session_id)
SELECT 
    landing_page,
    COUNT(distinct website_session_id) AS sessions_hitting_page
FROM
    entry_page
GROUP BY landing_page;

-- 3. Calculating bounce rate
-- Method 1
CREATE TEMPORARY TABLE first_entry 
SELECT 
    website_session_id,
    MIN(website_pageview_id) AS min_pageview_id,
    pageview_url AS landing_page
FROM
    website_pageviews
WHERE
    created_at < '2012-06-14' and pageview_url = '/home'
GROUP BY website_session_id;

CREATE TABLE bounced
SELECT 
    fe.website_session_id,
    COUNT(wpv.website_pageview_id) AS num_pageviewed
FROM
    first_entry AS fe
        LEFT JOIN
    website_pageviews AS wpv ON fe.website_session_id = wpv.website_session_id
GROUP BY fe.website_session_id
HAVING num_pageviewed = 1;

SELECT 
    COUNT(DISTINCT fe.website_session_id) AS total_session,
    COUNT(DISTINCT b.website_session_id) AS bounced_sessions,
    COUNT(DISTINCT b.website_session_id) / COUNT(DISTINCT fe.website_session_id) AS bounce_rate
FROM
    first_entry AS fe
        LEFT JOIN
    bounced AS b ON fe.website_session_id = b.website_session_id;
    
-- Method 2
with bounced_session_only as (
SELECT 
    website_session_id,
    COUNT(DISTINCT website_pageview_id) AS num_pageviewed
FROM
    website_pageviews
WHERE
    created_at < '2012-06-14'
GROUP BY website_session_id
HAVING num_pageviewed = 1)
SELECT 
    COUNT(DISTINCT wpv.website_session_id) AS total_sessions,
    COUNT(DISTINCT b.website_session_id) AS bounced_session,
    COUNT(DISTINCT b.website_session_id) / COUNT(DISTINCT wpv.website_session_id) AS bounce_rate
FROM
    website_pageviews AS wpv
        LEFT JOIN
    bounced_session_only AS b ON wpv.website_session_id = b.website_session_id
where created_at < '2012-06-14';

-- 4. Analyzing landing page tests
-- Identifying the first date on which /lander-1 comes online
SELECT 
    website_pageview_id as first_pageview_id, created_at AS first_created_at
FROM
    website_pageviews
WHERE
    pageview_url = '/lander-1'
ORDER BY first_pageview_id , first_created_at
LIMIT 1; -- the first date is on 2012-06-19

-- Calcuating the bounce rate for /home and /lander-1
CREATE TEMPORARY TABLE landing
SELECT 
    wpv.website_session_id,
    MIN(wpv.website_pageview_id) AS min_pageview_id,
    wpv.pageview_url AS landing_page
FROM
    website_pageviews AS wpv
        INNER JOIN
    website_sessions AS ws ON wpv.website_session_id = ws.website_session_id
WHERE
    ws.created_at BETWEEN '2012-06-19' AND '2012-07-28'
        AND wpv.website_pageview_id > 23504
        AND ws.utm_source = 'gsearch'
        AND ws.utm_campaign = 'nonbrand'
        AND wpv.pageview_url IN ('/home' , '/lander-1')
GROUP BY wpv.website_session_id;

CREATE TEMPORARY TABLE bounced_session_only
SELECT 
    l.website_session_id,
    COUNT(DISTINCT wpv.website_pageview_id) AS num_pageviewed,
    l.landing_page
FROM
    landing AS l
        LEFT JOIN
    website_pageviews as wpv ON l.website_session_id = wpv.website_session_id
GROUP BY l.website_session_id
HAVING num_pageviewed = 1;

SELECT 
    l.landing_page,
    COUNT(DISTINCT l.website_session_id) AS total_sessions,
    COUNT(DISTINCT b.website_session_id) AS bounced_sessions,
    COUNT(DISTINCT b.website_session_id) / COUNT(DISTINCT l.website_session_id) AS bounce_rate
FROM
    landing AS l
        LEFT JOIN
    bounced_session_only AS b ON l.website_session_id = b.website_session_id
GROUP BY landing_page;

-- 5. Landing page trend analysis
CREATE TEMPORARY TABLE firstpage
SELECT 
	ws.created_at,
    wpv.website_session_id,
    MIN(DISTINCT wpv.website_pageview_id) AS first_pageviewed,
    COUNT(DISTINCT wpv.website_pageview_id) AS num_sessions,
    wpv.pageview_url AS landing_page
FROM
    website_sessions AS ws
        RIGHT JOIN
    website_pageviews AS wpv ON ws.website_session_id = wpv.website_session_id
WHERE
    ws.created_at > '2012-06-01'
        AND ws.created_at < '2012-08-31'
        AND ws.utm_source = 'gsearch'
        AND ws.utm_campaign = 'nonbrand'
GROUP BY wpv.website_session_id;

SELECT 
    MIN(DATE(created_at)) AS week_start_date,
    COUNT(CASE
        WHEN num_sessions = 1 THEN website_session_id
        ELSE NULL
    END) / COUNT(DISTINCT website_session_id) AS bounce_rate, -- bounce session / total session
    COUNT(CASE
        WHEN landing_page = '/home' THEN website_session_id
        ELSE NULL
    END) AS home_sessions,
    COUNT(CASE
        WHEN landing_page = '/lander-1' THEN website_session_id
        ELSE NULL
    END) AS lander_sessions
FROM
    firstpage
GROUP BY WEEK(created_at);

-- 6. Analyzing conversion funnels (homepage > product page > add to cart > sale/checkout)
CREATE TEMPORARY TABLE summary -- create a summary table for subsequent calculation
SELECT 
    ws.website_session_id,
    wpv.pageview_url AS url,
    CASE
        WHEN pageview_url = '/products' THEN 1
        ELSE 0
    END AS product_page,
    CASE
        WHEN pageview_url = '/the-original-mr-fuzzy' THEN 1
        ELSE 0
    END AS fuzzy_page,
    CASE
        WHEN pageview_url = '/cart' THEN 1
        ELSE 0
    END AS cart_page,
    CASE
        WHEN pageview_url = '/shipping' THEN 1
        ELSE 0
    END AS shipping_page,
    CASE
        WHEN pageview_url = '/billing' THEN 1
        ELSE 0
    END AS billing_page,
    CASE
        WHEN pageview_url = '/thank-you-for-your-order' THEN 1
        ELSE 0
    END AS thankyou_page
FROM
    website_sessions AS ws
        LEFT JOIN
    website_pageviews AS wpv ON ws.website_session_id = wpv.website_session_id
WHERE
    ws.created_at BETWEEN '2012-08-05' AND '2012-09-05'
        AND ws.utm_source = 'gsearch'
        AND ws.utm_campaign = 'nonbrand'
ORDER BY ws.website_session_id , wpv.created_at;

CREATE TEMPORARY TABLE num_session_per_page -- calculating number of sessiosn for each page
SELECT 
    COUNT(DISTINCT website_session_id) AS total_sessions,
    SUM(product_page) AS product_make_it,
    SUM(fuzzy_page) AS fuzzy_make_it,
    SUM(cart_page) AS cart_make_it,
    SUM(shipping_page) AS shipping_make_it,
    SUM(billing_page) AS billing_make_it,
    SUM(thankyou_page) AS payment_done
FROM
    summary;

SELECT 
    product_make_it / total_sessions AS product_clickthrough_rate,
    fuzzy_make_it / product_make_it AS fuzzy_clickthrough_rate,
    cart_make_it / fuzzy_make_it AS cart_clickthrough_rate,
    shipping_make_it / cart_make_it AS shipping_clickthrough_rate,
    billing_make_it / shipping_make_it AS billing_clickthrough_rate,
    payment_done / billing_make_it AS thankyou_clickthrough_rate
FROM
    num_session_per_page;
    
-- 7. Analyzing conversion funnel tests (/billing vs /billing-2)
SELECT -- finding the date on which /billing-2 went online
    website_pageview_id, created_at
FROM
    website_pageviews
WHERE
    pageview_url = '/billing-2'
ORDER BY website_pageview_id , created_at; -- first cretaed on 2012-09-10 with wpv_id = 53550

with testing as (SELECT 
    wpv.website_session_id,
    wpv.pageview_url AS billing_session_seen,
    o.order_id
FROM
    website_pageviews AS wpv
        LEFT JOIN
    orders AS o ON wpv.website_session_id = o.website_session_id
WHERE
    wpv.created_at BETWEEN '2012-09-10' AND '2012-11-10'
        AND wpv.pageview_url IN ('/billing' , '/billing-2'))
SELECT 
    billing_session_seen,
    COUNT(DISTINCT website_session_id) AS billing_session,
    COUNT(DISTINCT order_id) AS orders,
    COUNT(DISTINCT order_id) / COUNT(DISTINCT website_session_id) AS billing_to_order_rt
FROM
    testing
GROUP BY billing_session_seen;