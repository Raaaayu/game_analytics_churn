-- Krok 4h: retencja D1 w układzie platforma × źródło pozyskania × okres (przed i od 27.08.2018)
-- Cel:     rozplątać źródło i platformę: czy spadek retencji widać w każdej grupie źródła
--          (wtedy zmiana struktury źródeł go nie wyjaśnia), oraz jak zmieniły się proporcje platform.
-- Wynik:   data/step4h_retention_source_platform.csv
--            iOS: wszyscy gracze mają źródło (direct); udział iOS 27,2% → 40,3% graczy okresu.
--            Android google-play_organic: udział 36,2% → 23,8%; D1 29,8% → 14,8% (−14,9 pp ±4,7), istotne
--            Android direct:              udział 34,8% → 34,6%; D1 16,5% → 12,0% (−4,5 pp ±3,7), istotne
--            iOS direct:                                       D1 22,9% → 14,9% (−8,0 pp ±4,2), istotne
--            Android inne: 46 → 22 graczy, 0 z 21 w D1; za mała grupa, nie interpretuję.
-- Decyzja: wzrost udziału (direct) z kroku 4g to wzrost udziału iOS, a nie zmiana marketingu.
--          D1 spadło istotnie w każdym dużym segmencie, więc zmiana struktury źródeł nie wyjaśnia spadku.
--          Najmocniej spadł segment o najwyższej retencji (Android google-play organic: D1 o połowę).

WITH cohort AS (
  -- gracze z first_open w dniu pierwszego pojawienia się (4 307); dzień 0 = data first_open
  SELECT
    user_pseudo_id,
    ANY_VALUE(platform)                     AS platform,
    MIN(PARSE_DATE('%Y%m%d', event_date))   AS cohort_date,
    ANY_VALUE(traffic_source.source)        AS ts_source,
    ANY_VALUE(traffic_source.medium)        AS ts_medium
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
  -- jeden wiersz na gracza: platforma, grupa źródła, okres kohorty, liczba dni danych, aktywność w dniu 1
  SELECT
    c.user_pseudo_id,
    c.platform,
    CASE
      WHEN c.ts_source = 'google-play' AND c.ts_medium = 'organic' THEN 'google-play_organic'
      WHEN c.ts_source = '(direct)'                               THEN 'direct'
      ELSE 'inne'
    END                                                                        AS source_group,
    IF(c.cohort_date < DATE '2018-08-27', '1_do_2018-08-26', '2_od_2018-08-27')  AS cohort_period,
    DATE_DIFF(DATE '2018-10-03', c.cohort_date, DAY)                           AS days_observed,
    COUNTIF(DATE_DIFF(a.active_date, c.cohort_date, DAY) = 1) > 0              AS active_d1
  FROM cohort AS c
  INNER JOIN active_days AS a
    ON c.user_pseudo_id = a.user_pseudo_id
  GROUP BY c.user_pseudo_id, c.platform, c.ts_source, c.ts_medium, c.cohort_date
),
segment_periods AS (
  -- jeden wiersz na platformę × grupę źródła × okres
  SELECT
    platform,
    source_group,
    cohort_period,
    COUNT(*)                                                    AS players,
    COUNTIF(days_observed >= 1)                                 AS d1_eligible,
    COUNTIF(active_d1 AND days_observed >= 1)                   AS d1_retained,
    SAFE_DIVIDE(COUNTIF(active_d1 AND days_observed >= 1),
                COUNTIF(days_observed >= 1))                    AS d1_rate
  FROM player_retention
  GROUP BY platform, source_group, cohort_period
),
compared AS (
  -- udział segmentu w okresie oraz porównanie z poprzednim okresem tego samego segmentu
  SELECT
    *,
    SAFE_DIVIDE(players, SUM(players) OVER (PARTITION BY cohort_period))   AS share_of_period,
    SAFE_DIVIDE(d1_rate * (1 - d1_rate), d1_eligible)                      AS d1_var,
    d1_rate - LAG(d1_rate) OVER same_segment                               AS d1_change,
    2 * SQRT(SAFE_DIVIDE(d1_rate * (1 - d1_rate), d1_eligible)
             + LAG(SAFE_DIVIDE(d1_rate * (1 - d1_rate), d1_eligible)) OVER same_segment)
                                                                           AS d1_change_margin
  FROM segment_periods
  WINDOW same_segment AS (PARTITION BY platform, source_group ORDER BY cohort_period)
)
SELECT
  platform,
  source_group,
  cohort_period,
  players,
  ROUND(100 * share_of_period, 1)             AS pct_of_period,
  d1_eligible,
  d1_retained,
  ROUND(100 * d1_rate, 1)                     AS d1_retention_pct,
  ROUND(200 * SQRT(d1_var), 1)                AS d1_margin_pp,
  ROUND(100 * d1_change, 1)                   AS d1_change_pp,
  ROUND(100 * d1_change_margin, 1)            AS d1_change_margin_pp,
  ABS(d1_change) > d1_change_margin           AS d1_change_significant
FROM compared
ORDER BY platform, source_group, cohort_period
