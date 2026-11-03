-- Krok 2b: gracze z first_open i bez, według tygodnia pierwszego pojawienia się
-- Cel:     ustalić, czy brak first_open to weterani sprzed 12.06 (hipoteza A),
--          czy efekt próbkowania (hipoteza B).
-- Wynik:   data/step2b_first_open_check.csv.
--          Pierwsze 3 tygodnie: 93% bez first_open (weterani). Od lipca: stabilnie ~58% bez first_open
--          (mieszanka próbkowania i rzadko grających weteranów).
--          83% graczy z first_open ma eventy wcześniejsze niż first_open, stąd step2c_first_open_gap.sql.
-- Decyzja: do kohort biorę tylko graczy z first_open.

WITH user_first AS (
  SELECT
    user_pseudo_id,
    MIN(PARSE_DATE('%Y%m%d', event_date))                      AS first_seen_date,
    MIN(event_timestamp)                                       AS first_event_ts,
    MIN(IF(event_name = 'first_open', event_timestamp, NULL))  AS first_open_ts
  FROM `firebase-public-project.analytics_153293282.events_*`
  GROUP BY user_pseudo_id
)
SELECT
  DATE_TRUNC(first_seen_date, WEEK(MONDAY))  AS first_seen_week,
  COUNT(*)                                   AS users,
  COUNTIF(first_open_ts IS NOT NULL)         AS with_first_open,
  COUNTIF(first_open_ts IS NULL)             AS without_first_open,
  COUNTIF(first_open_ts > first_event_ts)    AS events_before_first_open
FROM user_first
GROUP BY first_seen_week
ORDER BY first_seen_week
