-- 1. Finding top traffic sources
SELECT 
    utm_source,
    utm_campaign,
    http_referer,
    COUNT(DISTINCT website_session_id) AS num_sessions
FROM
    website_sessions
where created_at < '2012-04-12'
GROUP BY utm_source , utm_campaign, http_referer
ORDER BY num_sessions desc;

-- 2. Deep dive into the top traffic sources (gsearch, nonbrand)
SELECT DISTINCT
    COUNT(DISTINCT ws.website_session_id) AS sessions,
    COUNT(DISTINCT o.order_id) AS orders,
    COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id) as session_to_order_conv_rate
FROM
    website_sessions AS ws
        LEFT JOIN
    orders AS o ON ws.website_session_id = o.website_session_id
WHERE
    ws.created_at < '2012-04-14'
        AND ws.utm_source = 'gsearch'
        AND ws.utm_campaign = 'nonbrand';

-- 3. Calculate conversion rates based on utm_content
SELECT 
    ws.utm_content,
    COUNT(DISTINCT ws.website_session_id) AS num_sessions,
    COUNT(DISTINCT o.order_id) AS num_orders,
    count(distinct o.order_id) / count(distinct ws.website_session_id) as conversion_rate
FROM
    website_sessions AS ws
        LEFT JOIN
    orders AS o ON ws.website_session_id = o.website_session_id
GROUP BY ws.utm_content
ORDER BY num_sessions DESC;

-- 4. Traffic source trending (breakdown top traffic sources into week)
SELECT 
	-- weekofyear(created_at) as num_week, -- Monday as the beginning of the week 
    -- week/yearweek(created_at) as num_week, in which Sunday as the start of week
    MIN(DATE(created_at)) AS week_start_date,
    COUNT(DISTINCT website_session_id) AS num_sessions
FROM
    website_sessions
WHERE
    created_at < '2012-05-10'
        AND utm_source = 'gsearch'
        AND utm_campaign = 'nonbrand'
GROUP BY week(created_at);

-- 5. Traffic source bid optimization, by device type
SELECT 
    ws.device_type,
    COUNT(DISTINCT ws.website_session_id) AS num_sessions,
    COUNT(DISTINCT o.order_id) AS num_order,
    COUNT(DISTINCT o.order_id) / COUNT(DISTINCT ws.website_session_id) AS sessions_to_sales_conv_rate
FROM
    website_sessions AS ws
        LEFT JOIN
    orders AS o ON ws.website_session_id = o.website_session_id
WHERE
    ws.created_at < '2012-05-11'
        AND ws.utm_source = 'gsearch'
        AND ws.utm_campaign = 'nonbrand'
GROUP BY ws.device_type;

-- 6. Traffic source segnment trending
SELECT 
    DATE(created_at) AS week_start_date,
    COUNT(CASE
        WHEN device_type = 'desktop' THEN device_type
        ELSE NULL
    END) AS dtop_sessions,
    COUNT(CASE
        WHEN device_type = 'mobile' THEN device_type
        ELSE NULL
    END) AS mob_sessions
FROM
    website_sessions
WHERE
    created_at BETWEEN '2012-04-15' AND '2012-06-09'
        AND utm_source = 'gsearch'
        AND utm_campaign = 'nonbrand'
GROUP BY WEEK(created_at);
