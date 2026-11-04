-- Krok 4c: retencja D1 i D7 w dwóch okresach kohort (przed i od 27.08.2018)
-- Cel:     policzyć dokładnie (bez odtwarzania z zaokrąglonych procentów) retencję w obu okresach
--          oraz spadek w punktach procentowych (pp) i względny (%).
-- Wynik:   data/step4c_retention_two_periods.csv
--            do 26.08: D1 602/2 605 = 23,1% ±1,7 pp; D7 165/2 605 = 6,3% ±1,0 pp
--            od 27.08: D1 224/1 634 = 13,7% ±1,7 pp; D7  47/1 381 = 3,4% ±1,0 pp
--            zmiana:   D1 −9,4 pp (−40,7% względnie); D7 −2,9 pp (−46,3% względnie)
-- Decyzja: spadek retencji od 27.08 jest istotny (przedziały się nie nakładają) i dotyczy
--          zarówno D1, jak i D7. Kolejny krok: wyjaśnić przyczynę (wersja gry, źródło graczy).

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
  -- jeden wiersz na gracza: okres kohorty, liczba dni danych po instalacji, aktywność w dniu 1 i 7
  SELECT
    c.user_pseudo_id,
    IF(c.cohort_date < DATE '2018-08-27', '1_do_2018-08-26', '2_od_2018-08-27')  AS cohort_period,
    DATE_DIFF(DATE '2018-10-03', c.cohort_date, DAY)                           AS days_observed,
    COUNTIF(DATE_DIFF(a.active_date, c.cohort_date, DAY) = 1) > 0              AS active_d1,
    COUNTIF(DATE_DIFF(a.active_date, c.cohort_date, DAY) = 7) > 0              AS active_d7
  FROM cohort AS c
  INNER JOIN active_days AS a
    ON c.user_pseudo_id = a.user_pseudo_id
  GROUP BY c.user_pseudo_id, c.cohort_date
),
periods AS (
  -- jeden wiersz na okres: mianowniki, liczby powrotów i retencja jako ułamek (0–1)
  SELECT
    cohort_period,
    COUNT(*)                                                    AS cohort_players,
    COUNTIF(days_observed >= 1)                                 AS d1_eligible,
    COUNTIF(active_d1 AND days_observed >= 1)                   AS d1_retained,
    SAFE_DIVIDE(COUNTIF(active_d1 AND days_observed >= 1),
                COUNTIF(days_observed >= 1))                    AS d1_rate,
    COUNTIF(days_observed >= 7)                                 AS d7_eligible,
    COUNTIF(active_d7 AND days_observed >= 7)                   AS d7_retained,
    SAFE_DIVIDE(COUNTIF(active_d7 AND days_observed >= 7),
                COUNTIF(days_observed >= 7))                    AS d7_rate
  FROM player_retention
  GROUP BY cohort_period
)
SELECT
  cohort_period,
  cohort_players,
  d1_eligible,
  d1_retained,
  ROUND(100 * d1_rate, 1)                                                          AS d1_retention_pct,
  ROUND(200 * SQRT(d1_rate * (1 - d1_rate) / d1_eligible), 1)                      AS d1_margin_pp,
  ROUND(100 * (d1_rate - FIRST_VALUE(d1_rate) OVER (ORDER BY cohort_period)), 1)   AS d1_change_pp,
  ROUND(100 * (d1_rate / FIRST_VALUE(d1_rate) OVER (ORDER BY cohort_period) - 1), 1) AS d1_change_relative_pct,
  d7_eligible,
  d7_retained,
  ROUND(100 * d7_rate, 1)                                                          AS d7_retention_pct,
  ROUND(200 * SQRT(d7_rate * (1 - d7_rate) / d7_eligible), 1)                      AS d7_margin_pp,
  ROUND(100 * (d7_rate - FIRST_VALUE(d7_rate) OVER (ORDER BY cohort_period)), 1)   AS d7_change_pp,
  ROUND(100 * (d7_rate / FIRST_VALUE(d7_rate) OVER (ORDER BY cohort_period) - 1), 1) AS d7_change_relative_pct
FROM periods
ORDER BY cohort_period
