-- Krok 1b: eventy i gracze dzień po dniu
-- Cel:     sprawdzić, czy każdy dzień ma dokładnie 50 000 eventów (hipoteza przycięcia/próbkowania).
-- Wynik:   okres 2018-06-12 – 2018-10-03; każdy dzień ma 50 000 eventów (min = max);
--          graczy dziennie od 346 do 1283, średnio 518. Skan: 239 MB.
-- Decyzja: dane są przycięte/spróbkowane, więc nie analizuję wolumenu eventów w czasie,
--          a retencję interpretuję głównie przez porównania między grupami.

WITH daily AS (
  SELECT
    event_date,
    COUNT(*)                       AS event_count,
    COUNT(DISTINCT user_pseudo_id) AS user_count
  FROM `firebase-public-project.analytics_153293282.events_*`
  GROUP BY event_date
)
SELECT
  MIN(event_date)        AS first_day,
  MAX(event_date)        AS last_day,
  MIN(event_count)       AS min_events_per_day,
  MAX(event_count)       AS max_events_per_day,
  MIN(user_count)        AS min_users_per_day,
  MAX(user_count)        AS max_users_per_day,
  ROUND(AVG(user_count)) AS avg_users_per_day
FROM daily
