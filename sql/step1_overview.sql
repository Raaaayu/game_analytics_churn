-- Krok 1: ogólny rozmiar zbioru
-- Cel:    ile jest eventów, graczy i dni w całym zbiorze.
-- Wynik:  5 700 000 eventów, 15 175 graczy, 114 dni (~376 eventów na gracza).
-- Uwaga:  5 700 000 / 114 = dokładnie 50 000, stąd sprawdzenie w step1b_events_per_day.sql.

SELECT
  COUNT(*)                       AS event_count,
  COUNT(DISTINCT user_pseudo_id) AS user_count,
  COUNT(DISTINCT event_date)     AS day_count
FROM `firebase-public-project.analytics_153293282.events_*`
