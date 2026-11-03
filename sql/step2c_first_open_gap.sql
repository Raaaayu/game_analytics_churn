-- Krok 2c: jak duży jest odstęp między pierwszym eventem a first_open
-- Cel:     sprawdzić, czy eventy przed first_open to techniczne opóźnienie (ten sam dzień),
--          czy realny problem (inny dzień).
-- Wynik:   4 319 graczy z first_open:
--            first_open jako pierwszy event  721  (16,7%)
--            odstęp do 1 min                2 459 (56,9%)
--            > 1 min, ale ten sam dzień     1 127 (26,1%)
--            first_open w późniejszym dniu     12  (0,3%)
-- Decyzja: dzień 0 = data first_open. Wykluczam 12 graczy z first_open w późniejszym dniu,
--          więc kohorty tworzy 4 307 graczy.

WITH user_first AS (
  SELECT
    user_pseudo_id,
    MIN(PARSE_DATE('%Y%m%d', event_date))                                       AS first_seen_date,
    MIN(IF(event_name = 'first_open', PARSE_DATE('%Y%m%d', event_date), NULL))  AS first_open_date,
    MIN(event_timestamp)                                                        AS first_event_ts,
    MIN(IF(event_name = 'first_open', event_timestamp, NULL))                   AS first_open_ts
  FROM `firebase-public-project.analytics_153293282.events_*`
  GROUP BY user_pseudo_id
)
SELECT
  COUNT(*)                                                            AS users_with_first_open,
  COUNTIF(first_open_ts = first_event_ts)                             AS first_open_is_first,
  COUNTIF(first_open_ts - first_event_ts BETWEEN 1 AND 60 * 1000000)  AS gap_up_to_1_min,
  COUNTIF(first_open_ts - first_event_ts > 60 * 1000000
          AND first_open_date = first_seen_date)                      AS gap_over_1_min_same_day,
  COUNTIF(first_open_date > first_seen_date)                          AS first_open_on_later_day
FROM user_first
WHERE first_open_ts IS NOT NULL
