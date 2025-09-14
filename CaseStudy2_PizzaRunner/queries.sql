--Cleaning the customer_orders Table

-- Create the cleaned table
CREATE TABLE customer_orders_clean AS
SELECT
    order_id,
    customer_id,
    pizza_id,
    -- Replace 'null' strings and empty strings with actual NULL values
    CASE
        WHEN exclusions = '' OR exclusions = 'null' THEN NULL
        ELSE exclusions
    END AS exclusions,
    CASE
        WHEN extras = '' OR extras = 'null' THEN NULL
        ELSE extras
    END AS extras,
    order_time
FROM customer_orders;

-- Verify the new table
SELECT * FROM customer_orders_clean;


--Cleaning the runner_orders Table

-- Step 1: Clean pickup_time
UPDATE runner_orders
SET pickup_time = NULL
WHERE pickup_time = 'null';

ALTER TABLE runner_orders
ALTER COLUMN pickup_time TYPE TIMESTAMP
USING (pickup_time::timestamp);

-- Step 2: Clean distance
UPDATE runner_orders
SET distance = NULL
WHERE distance = 'null';

UPDATE runner_orders
SET distance = TRIM('km' FROM distance);

ALTER TABLE runner_orders
ALTER COLUMN distance TYPE REAL
USING (distance::real);

-- Step 3: Clean duration
UPDATE runner_orders
SET duration = NULL
WHERE duration = 'null';

UPDATE runner_orders SET duration = REPLACE(duration, 'minutes', '');
UPDATE runner_orders SET duration = REPLACE(duration, 'minute', '');
UPDATE runner_orders SET duration = REPLACE(duration, 'mins', '');

ALTER TABLE runner_orders
ALTER COLUMN duration TYPE INT
USING (duration::integer);

-- Step 4: Clean cancellation
UPDATE runner_orders
SET cancellation = NULL
WHERE cancellation = 'null' OR cancellation = '';

-- Verify the cleaned table
SELECT * FROM runner_orders;


--A. Pizza Metrics
   

-- 1. How many pizzas were ordered?
SELECT COUNT(*) AS total_pizzas_ordered
FROM customer_orders_clean;

-- 2. How many unique customer orders were made?
SELECT COUNT(DISTINCT order_id) AS unique_orders
FROM customer_orders_clean;

-- 3. How many successful orders were delivered by each runner?
SELECT
    runner_id,
    COUNT(order_id) AS successful_orders
FROM runner_orders
WHERE cancellation IS NULL
GROUP BY runner_id
ORDER BY runner_id;

-- 4. How many of each type of pizza was delivered?
SELECT
    pn.pizza_name,
    COUNT(co.pizza_id) AS pizzas_delivered
FROM customer_orders_clean AS co
JOIN runner_orders AS ro ON co.order_id = ro.order_id
JOIN pizza_names AS pn ON co.pizza_id = pn.pizza_id
WHERE ro.cancellation IS NULL
GROUP BY pn.pizza_name
ORDER BY pizzas_delivered DESC;

-- 5. How many Vegetarian and Meatlovers pizzas were ordered by each customer?
SELECT
    co.customer_id,
    pn.pizza_name,
    COUNT(co.pizza_id) AS pizza_count
FROM customer_orders_clean AS co
JOIN pizza_names AS pn ON co.pizza_id = pn.pizza_id
GROUP BY co.customer_id, pn.pizza_name
ORDER BY co.customer_id, pn.pizza_name;

-- 6. What was the maximum number of pizzas delivered in a single order?
SELECT
    c.order_id,
    COUNT(pizza_id) AS pizza_count
FROM customer_orders_clean AS c
JOIN runner_orders AS r ON c.order_id = r.order_id
WHERE r.cancellation IS NULL
GROUP BY c.order_id
ORDER BY pizza_count DESC
LIMIT 1;

-- 7. For each customer, pizzas with changes vs no changes
SELECT
    co.customer_id,
    SUM(
        CASE
            WHEN co.exclusions IS NOT NULL OR co.extras IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS pizzas_with_changes,
    SUM(
        CASE
            WHEN co.exclusions IS NULL AND co.extras IS NULL THEN 1
            ELSE 0
        END
    ) AS pizzas_with_no_changes
FROM customer_orders_clean AS co
JOIN runner_orders AS ro ON co.order_id = ro.order_id
WHERE ro.cancellation IS NULL
GROUP BY co.customer_id
ORDER BY co.customer_id;

-- 8. How many pizzas were delivered that had both exclusions and extras?
SELECT
    SUM(
        CASE
            WHEN c.exclusions IS NOT NULL AND c.extras IS NOT NULL THEN 1
            ELSE 0
        END
    ) AS pizzas_with_changes
FROM customer_orders_clean AS c
JOIN runner_orders AS r ON c.order_id = r.order_id
WHERE r.cancellation IS NULL;

-- 9. Total volume of pizzas ordered for each hour of the day
SELECT
    EXTRACT(HOUR FROM order_time) AS hour_of_day,
    COUNT(order_id) AS pizza_count
FROM customer_orders_clean
GROUP BY hour_of_day
ORDER BY hour_of_day;

-- 10. Volume of orders for each day of the week
SELECT
    TO_CHAR(order_time, 'FMDay') AS day_of_week,
    COUNT(order_id) AS pizza_count
FROM customer_orders_clean
GROUP BY day_of_week
ORDER BY pizza_count DESC;


--B. Runner and Customer Experience

--1.How many runners signed up for each 1 week period? (i.e. week starts 2021-01-01)
SELECT DATE_TRUNC('week', registration_date) AS registration_week,
       COUNT(runner_id) AS runners_signed_up
FROM runners
GROUP BY registration_week
ORDER BY registration_week;
--2.What was the average time in minutes it took for each runner to arrive at the Pizza Runner HQ to pickup the order?
WITH pickup_times AS (
  SELECT
    ro.runner_id,
    EXTRACT(EPOCH FROM (ro.pickup_time - co.order_time)) / 60 AS pickup_minutes
  FROM customer_orders_clean AS co
  JOIN runner_orders AS ro ON co.order_id = ro.order_id
  WHERE ro.pickup_time IS NOT NULL
)
SELECT runner_id,
       ROUND(AVG(pickup_minutes)) AS avg_pickup_minutes
FROM pickup_times
GROUP BY runner_id
ORDER BY runner_id;
--3. Is there any relationship between the number of pizzas and how long the order takes to prepare?
SELECT
  COUNT(co.pizza_id) AS number_of_pizzas,
  EXTRACT(EPOCH FROM (MIN(ro.pickup_time) - MIN(co.order_time))) / 60 AS prep_time_minutes
FROM customer_orders_clean AS co
JOIN runner_orders AS ro ON co.order_id = ro.order_id
WHERE ro.pickup_time IS NOT NULL
GROUP BY co.order_id
ORDER BY number_of_pizzas;
--4. What was the average distance travelled for each customer?
WITH customer_distances AS (
  SELECT DISTINCT co.customer_id, co.order_id, ro.distance
  FROM customer_orders_clean AS co
  JOIN runner_orders AS ro ON co.order_id = ro.order_id
  WHERE ro.distance IS NOT NULL
)
SELECT customer_id,
       ROUND(AVG(distance)::numeric, 2) AS avg_distance_km
FROM customer_distances
GROUP BY customer_id
ORDER BY customer_id;
--5.What was the difference between the longest and shortest delivery times for all orders?
SELECT MAX(duration) - MIN(duration) AS delivery_time_difference_minutes
FROM runner_orders
WHERE duration IS NOT NULL;
--6.What was the average speed for each runner for each delivery and do you notice any trend for these values?
SELECT
  runner_id,
  order_id,
  distance,
  duration AS duration_minutes,
  ROUND((distance / (duration / 60.0))::numeric, 2) AS speed_kmh
FROM runner_orders
WHERE distance IS NOT NULL
ORDER BY runner_id, order_id;
--7.What is the successful delivery percentage for each runner?
SELECT
  runner_id,
  ROUND((SUM(CASE WHEN cancellation IS NULL THEN 1 ELSE 0 END) * 100.0) / COUNT(order_id)) AS success_percentage
FROM runner_orders
GROUP BY runner_id
ORDER BY runner_id;


--C Ingredient Optimisation
--clean table for ingredients
CREATE TABLE pizza_recipes_normalized AS
SELECT
  pizza_id,
  UNNEST(STRING_TO_ARRAY(toppings, ', '))::integer AS topping_id
FROM
  pizza_recipes;

   SELECT * FROM pizza_recipes_normalized;
--1.What are the standard ingredients for each pizza?
SELECT
  pn.pizza_name,
  STRING_AGG(pt.topping_name, ', ' ORDER BY pt.topping_name) AS standard_ingredients
FROM
  pizza_recipes_normalized AS prn
  JOIN pizza_names AS pn ON prn.pizza_id = pn.pizza_id
  JOIN pizza_toppings AS pt ON prn.topping_id = pt.topping_id
GROUP BY
  pn.pizza_name
ORDER BY
  pn.pizza_name;
--2.What was the most commonly added extra?
WITH extras_unpacked AS (
  SELECT
    UNNEST(STRING_TO_ARRAY(extras, ', '))::integer AS topping_id
  FROM
    customer_orders_clean
  WHERE
    extras IS NOT NULL
)
SELECT
  pt.topping_name,
  COUNT(*) AS times_added
FROM
  extras_unpacked eu
  JOIN pizza_toppings pt ON eu.topping_id = pt.topping_id
GROUP BY
  pt.topping_name
ORDER BY
  times_added DESC
LIMIT
  1;
--3.What was the most common exclusion?
WITH exclusions_unpacked AS (
  SELECT
    UNNEST(STRING_TO_ARRAY(exclusions, ', '))::integer AS topping_id
  FROM
    customer_orders_clean
  WHERE
    exclusions IS NOT NULL
)
SELECT
  pt.topping_name,
  COUNT(*) AS times_excluded
FROM
  exclusions_unpacked eu
  JOIN pizza_toppings pt ON eu.topping_id = pt.topping_id
GROUP BY
  pt.topping_name
ORDER BY
  times_excluded DESC
LIMIT
  1;
--4.Generate an order item for each record in the customers_orders table in the format of one of the following:
--     Meat Lovers
--     Meat Lovers - Exclude Beef
--     Meat Lovers - Extra Bacon
--     Meat Lovers - Exclude Cheese, Bacon - Extra Mushroom, Peppers
-- Step 1: Give every single pizza in the orders table its own unique ID. This is the most important step.
WITH record_cte AS (
  SELECT
    ROW_NUMBER() OVER() AS record_id,
    order_id,
    pizza_id,
    exclusions,
    extras
  FROM
    customer_orders_clean
),
-- Step 2: Now, handle the exclusions. For each unique pizza (using record_id), create the exclusion text.
exclusions_cte AS (
  SELECT
    r.record_id,
    'Exclude ' || STRING_AGG(pt.topping_name, ', ') AS exclusion_text
  FROM
    record_cte AS r,
    -- This unpacks the string of exclusion IDs into separate rows
    UNNEST(STRING_TO_ARRAY(r.exclusions, ', ')) AS topping_id_str
    JOIN pizza_toppings AS pt ON pt.topping_id = topping_id_str::integer
  WHERE
    r.exclusions IS NOT NULL
  GROUP BY
    r.record_id -- We group by the unique ID we created in Step 1
),
-- Step 3: Do the exact same thing for the extras.
extras_cte AS (
  SELECT
    r.record_id,
    'Extra ' || STRING_AGG(pt.topping_name, ', ') AS extra_text
  FROM
    record_cte AS r,
    UNNEST(STRING_TO_ARRAY(r.extras, ', ')) AS topping_id_str
    JOIN pizza_toppings AS pt ON pt.topping_id = topping_id_str::integer
  WHERE
    r.extras IS NOT NULL
  GROUP BY
    r.record_id
)
-- Step 4: Finally, join everything together.
SELECT
  r.order_id,
  r.pizza_id,
  -- CONCAT_WS neatly combines the parts, skipping any that are NULL (like for pizzas with no changes)
  CONCAT_WS(' - ', 
    pn.pizza_name, 
    excl.exclusion_text, 
    extr.extra_text
  ) AS order_item
FROM
  record_cte AS r
  JOIN pizza_names AS pn ON r.pizza_id = pn.pizza_id
  -- Use LEFT JOIN because not every pizza will have exclusions or extras
  LEFT JOIN exclusions_cte AS excl ON r.record_id = excl.record_id
  LEFT JOIN extras_cte AS extr ON r.record_id = extr.record_id
ORDER BY
  r.order_id,
  r.record_id;

--5.Generate an alphabetically ordered comma separated ingredient list for each pizza order from the customer_orders table and add a 2x in front of any relevant ingredients
--     For example: "Meat Lovers: 2xBacon, Beef, ... , Salami"

WITH record_cte AS (
  SELECT
    ROW_NUMBER() OVER() AS record_id,
    order_id,
    pizza_id,
    exclusions,
    extras
  FROM
    customer_orders_clean
),
unpacked_toppings AS (
  SELECT
    r.record_id,
    prn.topping_id,
    'standard' AS topping_type
  FROM
    record_cte AS r
    JOIN pizza_recipes_normalized AS prn ON r.pizza_id = prn.pizza_id
  UNION ALL
  SELECT
    r.record_id,
    UNNEST(STRING_TO_ARRAY(r.extras, ', '))::integer AS topping_id,
    'extra' AS topping_type
  FROM
    record_cte AS r
  WHERE
    r.extras IS NOT NULL
  UNION ALL
  SELECT
    r.record_id,
    UNNEST(STRING_TO_ARRAY(r.exclusions, ', '))::integer AS topping_id,
    'exclusion' AS topping_type
  FROM
    record_cte AS r
  WHERE
    r.exclusions IS NOT NULL
),
final_ingredients_list AS (
  SELECT
    record_id,
    topping_id,
    MAX(
      CASE
        WHEN topping_type = 'extra' THEN 1
        ELSE 0
      END
    ) AS is_extra
  FROM
    unpacked_toppings
  GROUP BY
    record_id,
    topping_id
  HAVING
    COUNT(*) FILTER (
      WHERE
        topping_type = 'exclusion'
    ) = 0
)
SELECT
  r.order_id,
  r.record_id,
  pn.pizza_name || ': ' || STRING_AGG(
    CASE
      WHEN fil.is_extra = 1 THEN '2x ' || pt.topping_name
      ELSE pt.topping_name
    END,
    ', '
    ORDER BY
      pt.topping_name
  ) AS ingredient_list
FROM
  record_cte AS r
  JOIN final_ingredients_list AS fil ON r.record_id = fil.record_id
  JOIN pizza_toppings AS pt ON fil.topping_id = pt.topping_id
  JOIN pizza_names AS pn ON r.pizza_id = pn.pizza_id
GROUP BY
  r.order_id,
  r.record_id,
  pn.pizza_name
ORDER BY
  r.order_id,
  r.record_id;

--6.What is the total quantity of each ingredient used in all delivered pizzas sorted by most frequent first?
-- Step 1: Give each ordered pizza a unique ID to track it accurately.
WITH record_cte AS (
  SELECT
    ROW_NUMBER() OVER() AS record_id,
    order_id,
    pizza_id,
    exclusions,
    extras
  FROM
    customer_orders_clean
),
-- Step 2: From our unique pizzas, find out which ones were actually delivered.
delivered_pizzas AS (
  SELECT
    r.record_id,
    r.pizza_id,
    r.exclusions,
    r.extras
  FROM
    record_cte AS r
    JOIN runner_orders AS ro ON r.order_id = ro.order_id
  WHERE
    ro.cancellation IS NULL
),
-- Step 3: Unpack all topping transactions (standard, extra, exclusion) for ONLY the delivered pizzas.
unpacked_toppings AS (
  -- Standard ingredients
  SELECT
    dp.record_id,
    prn.topping_id,
    'standard' AS topping_type
  FROM
    delivered_pizzas AS dp
    JOIN pizza_recipes_normalized AS prn ON dp.pizza_id = prn.pizza_id
  UNION ALL
  -- Extra ingredients
  SELECT
    dp.record_id,
    UNNEST(STRING_TO_ARRAY(dp.extras, ', '))::integer,
    'extra'
  FROM
    delivered_pizzas AS dp
  WHERE
    dp.extras IS NOT NULL
  UNION ALL
  -- Excluded ingredients
  SELECT
    dp.record_id,
    UNNEST(STRING_TO_ARRAY(dp.exclusions, ', '))::integer,
    'exclusion'
  FROM
    delivered_pizzas AS dp
  WHERE
    dp.exclusions IS NOT NULL
),
-- Step 4: Create the final, correct ingredient list for each delivered pizza by removing exclusions.
final_ingredients AS (
  SELECT
    record_id,
    topping_id
  FROM
    unpacked_toppings
  GROUP BY
    record_id,
    topping_id
  HAVING
    -- This is the key: only keep toppings that were never marked as an 'exclusion'.
    COUNT(*) FILTER (
      WHERE
        topping_type = 'exclusion'
    ) = 0
)
-- Final Step: Count the toppings from our final, correct list.
SELECT
  pt.topping_name,
  COUNT(*) AS total_quantity
FROM
  final_ingredients AS fi
  JOIN pizza_toppings AS pt ON fi.topping_id = pt.topping_id
GROUP BY
  pt.topping_name
ORDER BY
  total_quantity DESC;

-- D. Pricing and Ratings
--1.If a Meat Lovers pizza costs $12 and Vegetarian costs $10 and there were no charges for changes - how much money has Pizza Runner made so far if there are no delivery fees?


SELECT SUM(CASE WHEN pn.pizza_name = 'Meatlovers' THEN 12 ELSE 10 END) AS total_revenue
FROM customer_orders_clean AS co
JOIN runner_orders AS ro ON co.order_id = ro.order_id
JOIN pizza_names AS pn ON co.pizza_id = pn.pizza_id
WHERE ro.cancellation IS NULL;

--2.What if there was an additional $1 charge for any pizza extras?
--Add cheese is $1 extra
WITH pizza_prices AS (
  SELECT
    CASE WHEN pn.pizza_name = 'Meatlovers' THEN 12 ELSE 10 END +
    CASE WHEN co.extras IS NULL THEN 0 ELSE CARDINALITY(STRING_TO_ARRAY(co.extras, ', ')) END AS total_price
  FROM customer_orders_clean AS co
  JOIN runner_orders AS ro ON co.order_id = ro.order_id
  JOIN pizza_names AS pn ON co.pizza_id = pn.pizza_id
  WHERE ro.cancellation IS NULL
)
SELECT SUM(total_price) AS total_revenue_with_extras FROM pizza_prices;

--3.The Pizza Runner team now wants to add an additional ratings system that allows customers to rate their runner, how would you design an additional table for this new dataset - generate a schema for this new table and insert your own data for ratings for each successful customer order between 1 to 5.

-- Create the new runner_ratings table
CREATE TABLE runner_ratings (
  rating_id SERIAL PRIMARY KEY,
  order_id INTEGER NOT NULL,
  rating INTEGER NOT NULL CHECK (rating >= 1 AND rating <= 5),
  review_text VARCHAR(255),
  rating_time TIMESTAMP NOT NULL DEFAULT NOW()
);

-- Insert some sample data
INSERT INTO runner_ratings (order_id, rating, review_text) VALUES
(1, 5, 'Perfect delivery! Arrived hot and fast.'), (2, 4, NULL),
(3, 1, 'Runner was very late and the pizza was cold.'), (4, 4, 'Good service.'),
(5, 5, 'Best delivery experience ever! So friendly!'), (7, 3, NULL);

SELECT * from runner_ratings;

--4.Using your newly generated table - can you join all of the information together to form a table which has the following information for successful deliveries?
--     customer_id
--     order_id
--     runner_id
--     rating
--     order_time
--     pickup_time
--     Time between order and pickup
--     Delivery duration
--     Average speed
--     Total number of pizzas

WITH customer_order_info AS (
  SELECT DISTINCT order_id, customer_id, order_time
  FROM customer_orders_clean
), pizza_counts AS (
  SELECT order_id, COUNT(pizza_id) AS total_pizzas
  FROM customer_orders_clean
  GROUP BY order_id
)
SELECT
  coi.customer_id, ro.order_id, ro.runner_id, rr.rating, coi.order_time, ro.pickup_time,
  ROUND(EXTRACT(EPOCH FROM (ro.pickup_time - coi.order_time)) / 60) AS pickup_minutes,
  ro.duration AS delivery_duration_minutes,
  ROUND((ro.distance / (ro.duration / 60.0))::numeric, 2) AS avg_speed_kmh,
  pc.total_pizzas
FROM runner_orders AS ro
JOIN customer_order_info AS coi ON ro.order_id = coi.order_id
JOIN pizza_counts AS pc ON ro.order_id = pc.order_id
LEFT JOIN runner_ratings AS rr ON ro.order_id = rr.order_id
WHERE ro.cancellation IS NULL
ORDER BY ro.order_id;

--5.If a Meat Lovers pizza was $12 and Vegetarian $10 fixed prices with no cost for extras and each runner is paid $0.30 per kilometre traveled - how much money does Pizza Runner have left over after these deliveries?
WITH revenue_calc AS (
  SELECT SUM(CASE WHEN pn.pizza_name = 'Meatlovers' THEN 12 ELSE 10 END) AS total_revenue
  FROM customer_orders_clean AS co
  JOIN runner_orders AS ro ON co.order_id = ro.order_id
  JOIN pizza_names AS pn ON co.pizza_id = pn.pizza_id
  WHERE ro.cancellation IS NULL
),
cost_calc AS (
  SELECT SUM(distance) * 0.30 AS total_runner_costs
  FROM runner_orders
  WHERE distance IS NOT NULL
)
SELECT r.total_revenue - c.total_runner_costs AS profit
FROM revenue_calc AS r, cost_calc AS c;

--E. Bonus Questions

-- If Danny wants to expand his range of pizzas - how would this impact the existing data design? Write an INSERT statement to demonstrate what would happen if a new Supreme pizza with all the toppings was added to the Pizza Runner menu?

-- Safely drop the table only IF IT EXISTS to prevent errors
DROP TABLE IF EXISTS pizza_recipes_normalized;

-- Create the new, more flexible table structure
CREATE TABLE pizza_recipes_normalized (
  pizza_id INTEGER,
  topping_id INTEGER
);

-- Populate it with the existing recipes for Meatlovers and Vegetarian
INSERT INTO pizza_recipes_normalized (pizza_id, topping_id)
SELECT
  pizza_id,
  UNNEST(STRING_TO_ARRAY(toppings, ', '))::integer AS topping_id
FROM
  pizza_recipes;

-- Now, it's easy to add the new Supreme pizza
-- (Assuming Supreme is pizza_id 3 and its toppings are...)
INSERT INTO pizza_recipes_normalized (pizza_id, topping_id) VALUES
(3, 1), (3, 2), (3, 4), (3, 5), (3, 6), (3, 7), (3, 9), (3, 10), (3, 11), (3, 12);

-- Verify the final table
SELECT * FROM pizza_recipes_normalized;