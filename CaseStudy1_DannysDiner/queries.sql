--Case Study Questions


-- 1. What is the total amount each customer spent at the restaurant?
SELECT
    s.customer_id,
    SUM(m.price) AS total_spent
FROM
    sales AS s
    JOIN menu AS m ON s.product_id = m.product_id
GROUP BY
    s.customer_id
ORDER BY
    s.customer_id;

-- 2. How many days has each customer visited the restaurant?
SELECT
    customer_id,
    COUNT(DISTINCT order_date) AS visit_count
FROM
    sales
GROUP BY
    customer_id;

-- 3. What was the first item from the menu purchased by each customer?
WITH customer_first_purchase AS (
    SELECT
        s.customer_id,
        m.product_name,
        s.order_date,
        ROW_NUMBER() OVER(
            PARTITION BY s.customer_id
            ORDER BY
                s.order_date
        ) AS purchase_rank
    FROM
        sales AS s
        JOIN menu AS m ON s.product_id = m.product_id
)
SELECT
    customer_id,
    product_name
FROM
    customer_first_purchase
WHERE
    purchase_rank = 1;

-- 4. What is the most purchased item on the menu and how many times was it purchased by all customers?
SELECT
    m.product_name,
    COUNT(s.product_id) AS times_purchased
FROM
    sales AS s
    JOIN menu AS m ON s.product_id = m.product_id
GROUP BY
    m.product_name
ORDER BY
    times_purchased DESC
LIMIT
    1;

-- 5. Which item was the most popular for each customer?
WITH item_popularity AS (
    SELECT
        s.customer_id,
        m.product_name,
        COUNT(s.product_id) AS purchase_count,
        DENSE_RANK() OVER(
            PARTITION BY s.customer_id
            ORDER BY
                COUNT(s.product_id) DESC
        ) AS ranking
    FROM
        sales AS s
        JOIN menu AS m ON s.product_id = m.product_id
    GROUP BY
        s.customer_id,
        m.product_name
)
SELECT
    customer_id,
    product_name,
    purchase_count
FROM
    item_popularity
WHERE
    ranking = 1;

-- 6. Which item was purchased first by the customer after they became a member?
WITH member_first_purchase AS (
    SELECT
        s.customer_id,
        s.order_date,
        m.product_name,
        DENSE_RANK() OVER(
            PARTITION BY s.customer_id
            ORDER BY
                s.order_date
        ) AS purchase_rank
    FROM
        sales AS s
        JOIN menu AS m ON s.product_id = m.product_id
        JOIN members AS mem ON s.customer_id = mem.customer_id
    WHERE
        s.order_date >= mem.join_date
)
SELECT
    customer_id,
    order_date,
    product_name
FROM
    member_first_purchase
WHERE
    purchase_rank = 1;

-- 7. Which item was purchased just before the customer became a member?
WITH pre_member_purchase AS (
    SELECT
        s.customer_id,
        s.order_date,
        m.product_name,
        ROW_NUMBER() OVER(
            PARTITION BY s.customer_id
            ORDER BY
                s.order_date DESC
        ) AS purchase_rank
    FROM
        sales AS s
        JOIN menu AS m ON s.product_id = m.product_id
        JOIN members AS mem ON s.customer_id = mem.customer_id
    WHERE
        s.order_date < mem.join_date
)
SELECT
    customer_id,
    product_name
FROM
    pre_member_purchase
WHERE
    purchase_rank = 1;

-- 8. What is the total items and amount spent for each member before they became a member?
SELECT
    s.customer_id,
    COUNT(s.product_id) AS total_items,
    SUM(m.price) AS total_spent
FROM
    sales AS s
    JOIN menu AS m ON s.product_id = m.product_id
    JOIN members AS mem ON s.customer_id = mem.customer_id
WHERE
    s.order_date < mem.join_date
GROUP BY
    s.customer_id
ORDER BY
    s.customer_id;

-- 9. If each $1 spent equates to 10 points and sushi has a 2x points multiplier - how many points would each customer have?
SELECT
    s.customer_id,
    SUM(
        CASE
            WHEN m.product_name = 'sushi' THEN m.price * 20
            ELSE m.price * 10
        END
    ) AS total_points
FROM
    sales AS s
    JOIN menu AS m ON s.product_id = m.product_id
GROUP BY
    s.customer_id
ORDER BY
    s.customer_id;

-- 10. In the first week after a customer joins the program (including their join date) they earn 2x points on all items, not just sushi - how many points do customer A and B have at the end of January?
SELECT
    s.customer_id,
    SUM(
        CASE
            WHEN s.order_date BETWEEN mem.join_date AND (mem.join_date + INTERVAL '6 day') THEN m.price * 20
            WHEN m.product_name = 'sushi' THEN m.price * 20
            ELSE m.price * 10
        END
    ) AS total_points
FROM
    sales AS s
    JOIN menu AS m ON s.product_id = m.product_id
    JOIN members AS mem ON s.customer_id = mem.customer_id
WHERE
    s.customer_id IN ('A', 'B')
    AND s.order_date <= '2021-01-31'
GROUP BY
    s.customer_id
ORDER BY
    s.customer_id;


--Bonus Questions


-- Join All The Things: Recreate the table with customer name, order date, product, price, and member status.
SELECT
    s.customer_id,
    s.order_date,
    m.product_name,
    m.price,
    CASE
        WHEN s.order_date >= mem.join_date THEN 'Y'
        ELSE 'N'
    END AS member
FROM
    sales AS s
    JOIN menu AS m ON s.product_id = m.product_id
    LEFT JOIN members AS mem ON s.customer_id = mem.customer_id
ORDER BY
    s.customer_id,
    s.order_date;

-- Rank All The Things: Add a ranking for member purchases.
WITH customer_summary AS (
    SELECT
        s.customer_id,
        s.order_date,
        m.product_name,
        m.price,
        CASE
            WHEN s.order_date >= mem.join_date THEN 'Y'
            ELSE 'N'
        END AS member
    FROM
        sales AS s
        JOIN menu AS m ON s.product_id = m.product_id
        LEFT JOIN members AS mem ON s.customer_id = mem.customer_id
)
SELECT
    *,
    CASE
        WHEN member = 'N' THEN NULL
        ELSE DENSE_RANK() OVER (
            PARTITION BY
                customer_id,
                member
            ORDER BY
                order_date
        )
    END AS ranking
FROM
    customer_summary
ORDER BY
    customer_id,
    order_date;
