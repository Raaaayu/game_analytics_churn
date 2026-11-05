-- Krok 5a: tabela cech zachowania w dniu 0 (jeden wiersz na gracza) pod regresję logistyczną
-- Cel:     dla każdego gracza z kohort, który mógł wrócić w D1 (instalacja do 2018-10-02),
--          zebrać cechy z dnia instalacji oraz cel: czy wrócił w dniu 1 (returned_d1).
-- Wynik:   data/step5a_player_features_d0.csv: 4 239 graczy, 826 wróciło w D1 (19,5%),
--          zgodnie z krokami 4a i 4c (602 + 224). Skan 1,1 GB (kolumna event_params).
--          quickplay_win_rate_d0 = NULL u 2 466 graczy (58%), którzy nie zakończyli żadnego poziomu quickplay.
--          Rozkłady liczbowe mocno skośne (czas gry: mediana 2,6 min, max 273 min).
-- Decyzja: tabela gotowa do przygotowania pod model; obsługa NULL i skośności w kolejnym kroku.

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
day0 AS (
  -- cechy z dnia 0: zliczenia eventów i czas gry
  SELECT
    e.user_pseudo_id,
    -- czas gry: parametr engagement_time_msec „wyciągnięty” z listy event_params przez UNNEST
    COALESCE(SUM(IF(e.event_name = 'user_engagement',
                    (SELECT ep.value.int_value
                     FROM UNNEST(e.event_params) AS ep
                     WHERE ep.key = 'engagement_time_msec'),
                    NULL)), 0) / 60000                       AS engagement_minutes_d0,
    COUNTIF(e.event_name = 'level_start_quickplay')          AS quickplay_levels_started_d0,
    COUNTIF(e.event_name = 'level_end_quickplay')            AS quickplay_levels_ended_d0,
    COUNTIF(e.event_name = 'level_complete_quickplay')       AS quickplay_levels_completed_d0,
    COUNTIF(e.event_name = 'level_start') > 0                AS played_level_mode_d0,
    COUNTIF(e.event_name = 'level_up') > 0                   AS leveled_up_d0,
    COUNTIF(e.event_name = 'no_more_extra_steps') > 0        AS ran_out_of_extra_steps_d0,
    COUNTIF(e.event_name = 'use_extra_steps') > 0            AS used_extra_steps_d0,
    COUNTIF(e.event_name IN ('app_exception', 'error')) > 0  AS had_error_d0
  FROM `firebase-public-project.analytics_153293282.events_*` AS e
  INNER JOIN cohort AS c
    ON e.user_pseudo_id = c.user_pseudo_id
  WHERE PARSE_DATE('%Y%m%d', e.event_date) = c.cohort_date
  GROUP BY e.user_pseudo_id
),
day1 AS (
  -- gracze aktywni w dniu 1 (bez odinstalowania i czyszczenia danych)
  SELECT DISTINCT
    e.user_pseudo_id
  FROM `firebase-public-project.analytics_153293282.events_*` AS e
  INNER JOIN cohort AS c
    ON e.user_pseudo_id = c.user_pseudo_id
  WHERE PARSE_DATE('%Y%m%d', e.event_date) = DATE_ADD(c.cohort_date, INTERVAL 1 DAY)
    AND e.event_name NOT IN ('app_remove', 'app_clear_data')
)
SELECT
  c.user_pseudo_id,
  c.cohort_date,
  IF(c.cohort_date < DATE '2018-08-27', '1_do_2018-08-26', '2_od_2018-08-27')  AS cohort_period,
  c.platform,
  CASE
    WHEN c.ts_source = 'google-play' AND c.ts_medium = 'organic' THEN 'google-play_organic'
    WHEN c.ts_source = '(direct)'                               THEN 'direct'
    ELSE 'inne'
  END                                                                          AS source_group,
  ROUND(d0.engagement_minutes_d0, 2)                                           AS engagement_minutes_d0,
  d0.quickplay_levels_started_d0,
  d0.quickplay_levels_ended_d0,
  d0.quickplay_levels_completed_d0,
  ROUND(SAFE_DIVIDE(d0.quickplay_levels_completed_d0,
                    d0.quickplay_levels_ended_d0), 3)                          AS quickplay_win_rate_d0,
  d0.played_level_mode_d0,
  d0.leveled_up_d0,
  d0.ran_out_of_extra_steps_d0,
  d0.used_extra_steps_d0,
  d0.had_error_d0,
  d1.user_pseudo_id IS NOT NULL                                                AS returned_d1
FROM cohort AS c
LEFT JOIN day0 AS d0
  ON c.user_pseudo_id = d0.user_pseudo_id
LEFT JOIN day1 AS d1
  ON c.user_pseudo_id = d1.user_pseudo_id
WHERE c.cohort_date <= DATE '2018-10-02'
ORDER BY c.cohort_date, c.user_pseudo_id
