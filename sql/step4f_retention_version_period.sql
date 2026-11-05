-- Krok 4f: retencja D1 w układzie wersja gry × platforma × okres (przed i od 27.08.2018)
-- Cel:     sprawdzić, czy spadek retencji widać w obrębie tej samej wersji gry
--          (wtedy przyczyna leży poza aplikacją) oraz która numeracja wersji należy do której platformy.
-- Wynik:   data/step4f_retention_version_period.csv. Numeracja: 2.62/2.63 = Android, 2.6.x = iOS.
--            2.62 Android:  D1 23,3% (n = 1 885) → 13,4% (n = 919); zmiana −9,9 pp ±3,0 pp, istotna
--            2.6.31 iOS:    D1 20,9% (n = 354)   → 15,2% (n = 639); zmiana −5,7 pp ±5,2 pp, istotna
--            2.6.30 iOS:    po 27.08 tylko 8 graczy, zmiana nieistotna (±34,6 pp)
--          Margines zmiany = 2·√(var1 + var2), var = p(1−p)/n (przedział Walda).
-- Decyzja: spadek występuje w obrębie tej samej wersji gry, na obu platformach, więc jego przyczyna
--          leży poza kodem aplikacji (źródło graczy, sezonowość lub zmiany po stronie serwera).
--          Następny krok: źródło pozyskania graczy (traffic_source).

WITH cohort AS (
  -- gracze z first_open w dniu pierwszego pojawienia się (4 307); dzień 0 = data first_open
  SELECT
    user_pseudo_id,
    ANY_VALUE(platform)                                        AS platform,
    MIN(PARSE_DATE('%Y%m%d', event_date))                      AS cohort_date,
    MIN(IF(event_name = 'first_open', app_info.version, NULL)) AS install_version
  FROM `firebase-public-project.analytics_153293282.events_*`
  GROUP BY user_pseudo_id
  HAVING MIN(IF(event_name = 'first_open', PARSE_DATE('%Y%m%d', event_date), NULL))
         = MIN(PARSE_DATE('%Y%m%d', event_date))
),
main_versions AS (
  -- tylko wersje z co najmniej 50 graczami (mniejszych nie interpretuję, decyzja z kroku 4e)
  SELECT install_version
  FROM cohort
  GROUP BY install_version
  HAVING COUNT(*) >= 50
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
  -- jeden wiersz na gracza: wersja, platforma, okres kohorty, liczba dni danych, aktywność w dniu 1
  SELECT
    c.user_pseudo_id,
    c.install_version,
    c.platform,
    IF(c.cohort_date < DATE '2018-08-27', '1_do_2018-08-26', '2_od_2018-08-27')  AS cohort_period,
    DATE_DIFF(DATE '2018-10-03', c.cohort_date, DAY)                           AS days_observed,
    COUNTIF(DATE_DIFF(a.active_date, c.cohort_date, DAY) = 1) > 0              AS active_d1
  FROM cohort AS c
  INNER JOIN main_versions AS v
    ON c.install_version = v.install_version
  INNER JOIN active_days AS a
    ON c.user_pseudo_id = a.user_pseudo_id
  GROUP BY c.user_pseudo_id, c.install_version, c.platform, c.cohort_date
),
version_periods AS (
  -- jeden wiersz na wersję × platformę × okres
  SELECT
    install_version,
    platform,
    cohort_period,
    COUNT(*)                                                    AS players,
    COUNTIF(days_observed >= 1)                                 AS d1_eligible,
    COUNTIF(active_d1 AND days_observed >= 1)                   AS d1_retained,
    SAFE_DIVIDE(COUNTIF(active_d1 AND days_observed >= 1),
                COUNTIF(days_observed >= 1))                    AS d1_rate
  FROM player_retention
  GROUP BY install_version, platform, cohort_period
),
with_variance AS (
  -- wariancja odsetka p(1−p)/n: kwadrat błędu standardowego, potrzebny do marginesu różnicy
  SELECT
    *,
    SAFE_DIVIDE(d1_rate * (1 - d1_rate), d1_eligible)           AS d1_var
  FROM version_periods
),
compared AS (
  -- porównanie z poprzednim okresem tej samej wersji i platformy (pierwszy okres: NULL)
  SELECT
    *,
    d1_rate - LAG(d1_rate) OVER same_version                    AS d1_change,
    2 * SQRT(d1_var + LAG(d1_var) OVER same_version)            AS d1_change_margin
  FROM with_variance
  WINDOW same_version AS (PARTITION BY install_version, platform ORDER BY cohort_period)
)
SELECT
  install_version,
  platform,
  cohort_period,
  players,
  d1_eligible,
  d1_retained,
  ROUND(100 * d1_rate, 1)                     AS d1_retention_pct,
  ROUND(200 * SQRT(d1_var), 1)                AS d1_margin_pp,
  ROUND(100 * d1_change, 1)                   AS d1_change_pp,
  ROUND(100 * d1_change_margin, 1)            AS d1_change_margin_pp,
  ABS(d1_change) > d1_change_margin           AS d1_change_significant
FROM compared
ORDER BY install_version, platform, cohort_period
