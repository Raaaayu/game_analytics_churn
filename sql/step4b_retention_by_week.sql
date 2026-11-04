-- Krok 4b: retencja D1, D7, D30 według tygodniowych kohort
-- Cel:     sprawdzić, czy retencja jest stabilna w czasie, czy zmienia się między kohortami
--          (np. po aktualizacji gry lub w tygodniu od 25.06 ze spadkiem first_open).
-- Wynik:   data/step4b_retention_by_week.csv (17 tygodni, suma 4 307 graczy).
--          D1 łącznie dla kohort do 26.08: 23,1% ±1,7 pp (n = 2 605); od 27.08: 13,7% ±1,7 pp (n = 1 634).
--          Spadek o ~9 pp (~40% względnie) widoczny w 5 kolejnych tygodniach; D7 spada podobnie.
--          Tydzień od 25.06 (68 graczy): D1 32,4% ±11,3 pp, retencja bez anomalii.
--          Kontrola artefaktu: średnia liczba eventów na gracza dziennie w próbce we wrześniu (98)
--          podobna do lipca/sierpnia (105–109), więc spadek nie wygląda na efekt zmiany próbkowania.
-- Decyzja: spadek retencji od końca sierpnia jest istotny i wymaga wyjaśnienia
--          (wersja gry, źródło pozyskania graczy).

WITH cohort AS (
  -- gracze z first_open w dniu pierwszego pojawienia się (4 307); dzień 0 = data first_open
  SELECT
    user_pseudo_id,
    MIN(PARSE_DATE('%Y%m%d', event_date))   AS cohort_date
  FROM `firebase-public-project.analytics_153293282.events_*`
  GROUP BY user_pseudo_id
  HAVING MIN(IF(event_name = 'first_open', PARSE_DATE('%Y%m%d', event_date), NULL))
         = MIN(PARSE_DATE('%Y%m%d', event_date))
),
active_days AS (
  -- jeden wiersz na gracza i aktywny dzień (bez odinstalowania i czyszczenia danych)
  SELECT DISTINCT
    user_pseudo_id,
    PARSE_DATE('%Y%m%d', event_date) AS active_date
  FROM `firebase-public-project.analytics_153293282.events_*`
  WHERE event_name NOT IN ('app_remove', 'app_clear_data')
),
player_retention AS (
  -- jeden wiersz na gracza: dzień 0, liczba dni danych po instalacji, aktywność w dniu 1, 7, 30
  SELECT
    c.user_pseudo_id,
    c.cohort_date,
    DATE_DIFF(DATE '2018-10-03', c.cohort_date, DAY)                    AS days_observed,
    COUNTIF(DATE_DIFF(a.active_date, c.cohort_date, DAY) = 1)  > 0      AS active_d1,
    COUNTIF(DATE_DIFF(a.active_date, c.cohort_date, DAY) = 7)  > 0      AS active_d7,
    COUNTIF(DATE_DIFF(a.active_date, c.cohort_date, DAY) = 30) > 0      AS active_d30
  FROM cohort AS c
  INNER JOIN active_days AS a
    ON c.user_pseudo_id = a.user_pseudo_id
  GROUP BY c.user_pseudo_id, c.cohort_date
),
weekly AS (
  -- jeden wiersz na tygodniową kohortę: mianowniki i odsetki retencji (0–1)
  SELECT
    DATE_TRUNC(cohort_date, WEEK(MONDAY))                                                  AS cohort_week,
    COUNT(*)                                                                               AS cohort_players,
    COUNTIF(days_observed >= 1)                                                            AS d1_eligible,
    SAFE_DIVIDE(COUNTIF(active_d1  AND days_observed >= 1),  COUNTIF(days_observed >= 1))  AS d1_rate,
    COUNTIF(days_observed >= 7)                                                            AS d7_eligible,
    SAFE_DIVIDE(COUNTIF(active_d7  AND days_observed >= 7),  COUNTIF(days_observed >= 7))  AS d7_rate,
    COUNTIF(days_observed >= 30)                                                           AS d30_eligible,
    SAFE_DIVIDE(COUNTIF(active_d30 AND days_observed >= 30), COUNTIF(days_observed >= 30)) AS d30_rate
  FROM player_retention
  GROUP BY cohort_week
)
SELECT
  cohort_week,
  cohort_players,
  d1_eligible,
  ROUND(100 * d1_rate, 1)                                               AS d1_retention_pct,
  ROUND(200 * SQRT(SAFE_DIVIDE(d1_rate * (1 - d1_rate), d1_eligible)), 1) AS d1_margin_pp,
  d7_eligible,
  ROUND(100 * d7_rate, 1)                                               AS d7_retention_pct,
  d30_eligible,
  ROUND(100 * d30_rate, 1)                                              AS d30_retention_pct
FROM weekly
ORDER BY cohort_week
