-- Krok 2: mapa eventów
-- Cel:     jakie eventy rejestruje gra, jak często i jaki % graczy wywołał każdy z nich.
-- Wynik:   data/step2_event_names.csv (37 rodzajów eventów).
--          63% eventów to screen_view + user_engagement; dwa tryby gry (quickplay i poziomy);
--          first_open tylko u 28,5% graczy, session_start u 80,8%, app_remove u 17,4%.
-- Decyzja: aktywność danego dnia = jakikolwiek event (session_start gubi ~19% graczy przez próbkowanie).

WITH total AS (
  SELECT COUNT(DISTINCT user_pseudo_id) AS all_users
  FROM `firebase-public-project.analytics_153293282.events_*`
)
SELECT
  e.event_name,
  COUNT(*)                                                                    AS event_count,
  COUNT(DISTINCT e.user_pseudo_id)                                            AS user_count,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)                            AS pct_of_events,
  ROUND(100 * COUNT(DISTINCT e.user_pseudo_id) / ANY_VALUE(t.all_users), 1)   AS pct_of_users
FROM `firebase-public-project.analytics_153293282.events_*` AS e
CROSS JOIN total AS t
GROUP BY e.event_name
ORDER BY event_count DESC
