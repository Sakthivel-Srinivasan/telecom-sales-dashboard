-- =====================================================
-- TELECOM SALES DATA EXTRACTION QUERIES
-- Purpose: Extract sales, customer, and performance data
-- Author: Sakthivel Srinivasan
-- =====================================================

-- Query 1: Extract Daily Sales Performance
-- This query pulls all sales transactions with customer and product details
SELECT 
    s.sale_id,
    s.sale_date,
    s.customer_id,
    c.customer_name,
    c.region,
    c.customer_segment,
    s.agent_id,
    a.agent_name,
    a.team,
    s.product_id,
    p.product_name,
    p.product_category,
    p.plan_type,
    s.sale_amount,
    s.setup_fee,
    s.monthly_recurring_revenue AS mrr,
    s.contract_length_months,
    s.sale_status,
    s.order_completion_time_hours,
    s.source_channel
FROM sales s
LEFT JOIN customers c ON s.customer_id = c.customer_id
LEFT JOIN agents a ON s.agent_id = a.agent_id
LEFT JOIN products p ON s.product_id = p.product_id
WHERE s.sale_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
ORDER BY s.sale_date DESC;


-- Query 2: Calculate Key Performance Indicators (KPIs)
-- Aggregated daily metrics for dashboard
SELECT 
    DATE(sale_date) AS date,
    COUNT(*) AS total_orders,
    COUNT(CASE WHEN sale_status = 'Completed' THEN 1 END) AS completed_orders,
    COUNT(CASE WHEN sale_status = 'Failed' THEN 1 END) AS failed_orders,
    ROUND(COUNT(CASE WHEN sale_status = 'Completed' THEN 1 END) * 100.0 / COUNT(*), 2) AS completion_rate,
    SUM(sale_amount) AS total_revenue,
    SUM(monthly_recurring_revenue) AS total_mrr,
    ROUND(AVG(sale_amount), 2) AS avg_order_value,
    ROUND(AVG(monthly_recurring_revenue), 2) AS avg_mrr,
    COUNT(DISTINCT customer_id) AS unique_customers,
    COUNT(DISTINCT agent_id) AS active_agents
FROM sales
WHERE sale_date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
GROUP BY DATE(sale_date)
ORDER BY date DESC;


-- Query 3: Agent Performance Metrics
-- Individual agent KPIs for performance tracking
SELECT 
    a.agent_id,
    a.agent_name,
    a.team,
    a.hire_date,
    COUNT(s.sale_id) AS total_sales,
    COUNT(CASE WHEN s.sale_status = 'Completed' THEN 1 END) AS successful_sales,
    COUNT(CASE WHEN s.sale_status = 'Failed' THEN 1 END) AS failed_sales,
    ROUND(COUNT(CASE WHEN s.sale_status = 'Completed' THEN 1 END) * 100.0 / 
          NULLIF(COUNT(s.sale_id), 0), 2) AS conversion_rate,
    SUM(s.sale_amount) AS total_revenue,
    ROUND(AVG(s.sale_amount), 2) AS avg_deal_size,
    SUM(s.monthly_recurring_revenue) AS total_mrr,
    COUNT(CASE WHEN p.plan_type = 'Premium' THEN 1 END) AS premium_sales,
    ROUND(COUNT(CASE WHEN p.plan_type = 'Premium' THEN 1 END) * 100.0 / 
          NULLIF(COUNT(s.sale_id), 0), 2) AS premium_mix_pct,
    ROUND(AVG(s.order_completion_time_hours), 2) AS avg_completion_time
FROM agents a
LEFT JOIN sales s ON a.agent_id = s.agent_id 
    AND s.sale_date >= DATE_SUB(CURDATE(), INTERVAL 3 MONTH)
LEFT JOIN products p ON s.product_id = p.product_id
WHERE a.status = 'Active'
GROUP BY a.agent_id, a.agent_name, a.team, a.hire_date
ORDER BY total_revenue DESC;


-- Query 4: Product Performance Analysis
-- Which products are selling best
SELECT 
    p.product_id,
    p.product_name,
    p.product_category,
    p.plan_type,
    p.base_price,
    COUNT(s.sale_id) AS units_sold,
    SUM(s.sale_amount) AS total_revenue,
    SUM(s.monthly_recurring_revenue) AS total_mrr,
    ROUND(AVG(s.sale_amount), 2) AS avg_selling_price,
    COUNT(CASE WHEN s.sale_status = 'Completed' THEN 1 END) AS successful_sales,
    ROUND(COUNT(CASE WHEN s.sale_status = 'Completed' THEN 1 END) * 100.0 / 
          NULLIF(COUNT(s.sale_id), 0), 2) AS success_rate,
    COUNT(DISTINCT s.customer_id) AS unique_buyers
FROM products p
LEFT JOIN sales s ON p.product_id = s.product_id 
    AND s.sale_date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
GROUP BY p.product_id, p.product_name, p.product_category, p.plan_type, p.base_price
ORDER BY total_revenue DESC;


-- Query 5: Customer Segmentation Data
-- Segment customers by value and behavior
SELECT 
    c.customer_id,
    c.customer_name,
    c.region,
    c.customer_segment,
    c.acquisition_date,
    COUNT(s.sale_id) AS total_purchases,
    SUM(s.sale_amount) AS lifetime_value,
    SUM(s.monthly_recurring_revenue) AS total_mrr,
    ROUND(AVG(s.sale_amount), 2) AS avg_purchase_value,
    MAX(s.sale_date) AS last_purchase_date,
    DATEDIFF(CURDATE(), MAX(s.sale_date)) AS days_since_last_purchase,
    CASE 
        WHEN SUM(s.monthly_recurring_revenue) >= 100 THEN 'High Value'
        WHEN SUM(s.monthly_recurring_revenue) >= 50 THEN 'Medium Value'
        ELSE 'Low Value'
    END AS value_tier
FROM customers c
LEFT JOIN sales s ON c.customer_id = s.customer_id 
    AND s.sale_status = 'Completed'
GROUP BY c.customer_id, c.customer_name, c.region, c.customer_segment, c.acquisition_date
ORDER BY lifetime_value DESC;


-- Query 6: Sales Funnel Analysis
-- Track conversion through the sales pipeline
SELECT 
    DATE_FORMAT(interaction_date, '%Y-%m') AS month,
    COUNT(*) AS total_interactions,
    COUNT(CASE WHEN stage = 'Inquiry' THEN 1 END) AS inquiries,
    COUNT(CASE WHEN stage = 'Qualified' THEN 1 END) AS qualified,
    COUNT(CASE WHEN stage = 'Proposal' THEN 1 END) AS proposals,
    COUNT(CASE WHEN stage = 'Negotiation' THEN 1 END) AS negotiations,
    COUNT(CASE WHEN stage = 'Closed-Won' THEN 1 END) AS closed_won,
    COUNT(CASE WHEN stage = 'Closed-Lost' THEN 1 END) AS closed_lost,
    ROUND(COUNT(CASE WHEN stage = 'Qualified' THEN 1 END) * 100.0 / 
          NULLIF(COUNT(CASE WHEN stage = 'Inquiry' THEN 1 END), 0), 2) AS inquiry_to_qualified_rate,
    ROUND(COUNT(CASE WHEN stage = 'Closed-Won' THEN 1 END) * 100.0 / 
          NULLIF(COUNT(CASE WHEN stage = 'Qualified' THEN 1 END), 0), 2) AS qualified_to_win_rate
FROM sales_pipeline
WHERE interaction_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
GROUP BY DATE_FORMAT(interaction_date, '%Y-%m')
ORDER BY month DESC;


-- Query 7: Regional Performance Comparison
-- Compare sales performance across different regions
SELECT 
    c.region,
    COUNT(DISTINCT s.customer_id) AS unique_customers,
    COUNT(s.sale_id) AS total_orders,
    SUM(s.sale_amount) AS total_revenue,
    SUM(s.monthly_recurring_revenue) AS total_mrr,
    ROUND(AVG(s.sale_amount), 2) AS avg_order_value,
    ROUND(AVG(s.monthly_recurring_revenue), 2) AS avg_mrr_per_customer,
    COUNT(CASE WHEN s.sale_status = 'Completed' THEN 1 END) AS completed_orders,
    ROUND(COUNT(CASE WHEN s.sale_status = 'Completed' THEN 1 END) * 100.0 / 
          NULLIF(COUNT(s.sale_id), 0), 2) AS completion_rate
FROM customers c
LEFT JOIN sales s ON c.customer_id = s.customer_id 
    AND s.sale_date >= DATE_SUB(CURDATE(), INTERVAL 6 MONTH)
GROUP BY c.region
ORDER BY total_revenue DESC;


-- Query 8: Time-Based Trend Analysis
-- Identify seasonal patterns and trends
SELECT 
    YEAR(sale_date) AS year,
    MONTH(sale_date) AS month,
    MONTHNAME(sale_date) AS month_name,
    DAYOFWEEK(sale_date) AS day_of_week,
    DAYNAME(sale_date) AS day_name,
    COUNT(*) AS total_orders,
    SUM(sale_amount) AS revenue,
    SUM(monthly_recurring_revenue) AS mrr,
    ROUND(AVG(sale_amount), 2) AS avg_order_value
FROM sales
WHERE sale_date >= DATE_SUB(CURDATE(), INTERVAL 12 MONTH)
GROUP BY YEAR(sale_date), MONTH(sale_date), MONTHNAME(sale_date), 
         DAYOFWEEK(sale_date), DAYNAME(sale_date)
ORDER BY year DESC, month DESC;
