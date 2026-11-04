-- Krok 4: retencja D1, D7, D30 (wersja klasyczna) łącznie i w podziale na platformę
-- Cel:     policzyć, jaki % graczy z kohort był aktywny dokładnie w dniu 1, 7 i 30 od first_open.
--          Mianownik każdej miary to tylko gracze, od których instalacji minęło co najmniej N dni
--          (koniec danych: 2018-10-03).
-- Wynik:   data/step4_retention_by_platform.csv
--            ALL:     4 307 graczy, D1 19,5%, D7 5,3%, D30 1,9%
--            Android: 2 913 graczy, D1 19,7%, D7 5,5%, D30 1,8%
--            iOS:     1 394 graczy, D1 18,9%, D7 5,0%, D30 2,3%
-- Decyzja: różnice między platformami mieszczą się w błędzie losowym (np. D1 ±2 pp dla iOS),
--          więc dalsze analizy prowadzę na wszystkich graczach razem. Największy spadek to D0 → D1
--          (ok. 80% nowych graczy nie wraca następnego dnia), więc tam skupiam szukanie przyczyn.

WITH cohort AS (
  -- gracze z first_open w dniu pierwszego pojawienia się (4 307); dzień 0 = data first_open
  SELECT
    user_pseudo_id,
    ANY_VALUE(platform)                     AS platform,
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
  -- jeden wiersz na gracza: czy był aktywny w dniu 1, 7, 30 i ile dni danych miał po instalacji
  SELECT
    c.user_pseudo_id,
    c.platform,
    DATE_DIFF(DATE '2018-10-03', c.cohort_date, DAY)                    AS days_observed,
    COUNTIF(DATE_DIFF(a.active_date, c.cohort_date, DAY) = 1)  > 0      AS active_d1,
    COUNTIF(DATE_DIFF(a.active_date, c.cohort_date, DAY) = 7)  > 0      AS active_d7,
    COUNTIF(DATE_DIFF(a.active_date, c.cohort_date, DAY) = 30) > 0      AS active_d30
  FROM cohort AS c
  INNER JOIN active_days AS a
    ON c.user_pseudo_id = a.user_pseudo_id
  GROUP BY c.user_pseudo_id, c.platform, c.cohort_date
)
SELECT
  COALESCE(platform, 'ALL')                                                       AS platform_group,
  COUNT(*)                                                                        AS cohort_players,
  COUNTIF(days_observed >= 1)                                                     AS d1_eligible,
  ROUND(100 * COUNTIF(active_d1  AND days_observed >= 1)  / COUNTIF(days_observed >= 1), 1)  AS d1_retention_pct,
  COUNTIF(days_observed >= 7)                                                     AS d7_eligible,
  ROUND(100 * COUNTIF(active_d7  AND days_observed >= 7)  / COUNTIF(days_observed >= 7), 1)  AS d7_retention_pct,
  COUNTIF(days_observed >= 30)                                                    AS d30_eligible,
  ROUND(100 * COUNTIF(active_d30 AND days_observed >= 30) / COUNTIF(days_observed >= 30), 1) AS d30_retention_pct
FROM player_retention
GROUP BY ROLLUP(platform)
ORDER BY platform_group
