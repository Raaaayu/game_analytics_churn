-- Krok 2d: jak wybrano 50 000 eventów dziennie
-- Cel:     sprawdzić, czy eventy pokrywają cały dzień (losowa próbka),
--          czy urywają się przed północą (pierwsze 50 000 eventów dnia).
-- Wynik:   data/step2d_day_time_span.csv. Wszystkie 114 dni obejmują 23,9–24 h
--          (od ~07:00 UTC do ~07:00 UTC następnego dnia), niezależnie od liczby graczy.
--          Dzień zaczyna się o 07:00 UTC, czyli event_date jest w czasie pacyficznym (UTC-7).
-- Decyzja: próbka jest losowa w obrębie dnia, a nie „pierwsze 50 000 eventów”, więc pory dnia
--          nie są ucięte. Ograniczenie zostaje: gracze z małą liczbą eventów mają mniejszą
--          szansę trafić do próbki.

WITH daily AS (
  SELECT
    event_date,
    TIMESTAMP_MICROS(MIN(event_timestamp))  AS first_event_at,
    TIMESTAMP_MICROS(MAX(event_timestamp))  AS last_event_at,
    COUNT(DISTINCT user_pseudo_id)          AS user_count
  FROM `firebase-public-project.analytics_153293282.events_*`
  GROUP BY event_date
)
SELECT
  event_date,
  first_event_at,
  last_event_at,
  ROUND(TIMESTAMP_DIFF(last_event_at, first_event_at, MINUTE) / 60, 1)  AS span_hours,
  user_count
FROM daily
ORDER BY event_date
