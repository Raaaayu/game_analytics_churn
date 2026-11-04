-- Krok 3c: walidacja definicji churnu przez app_remove (tylko Android)
-- Cel:     sprawdzić, czy gracze uznani za churned (brak aktywności przez 14 dni)
--          częściej odinstalowują grę niż gracze nadal aktywni.
-- Wynik:   data/step3c_churn_validation.csv. 2 913 graczy z Androida w kohortach.
--            churned:      2 373 graczy, 58,3% z app_remove
--            still_active:   540 graczy, 27,4% z app_remove
-- Decyzja: gracze uznani za churned odinstalowują grę ponad 2 razy częściej, więc definicja
--          (14 dni bez aktywności) odróżnia odchodzących od zostających i ją przyjmuję.

WITH cohort AS (
  -- gracze z Androida z first_open w dniu pierwszego pojawienia się
  SELECT
    user_pseudo_id
  FROM `firebase-public-project.analytics_153293282.events_*`
  WHERE platform = 'ANDROID'
  GROUP BY user_pseudo_id
  HAVING MIN(IF(event_name = 'first_open', PARSE_DATE('%Y%m%d', event_date), NULL))
         = MIN(PARSE_DATE('%Y%m%d', event_date))
),
player_status AS (
  -- jeden wiersz na gracza: ostatni aktywny dzień i czy odinstalował grę
  SELECT
    e.user_pseudo_id,
    MAX(IF(e.event_name NOT IN ('app_remove', 'app_clear_data'),
           PARSE_DATE('%Y%m%d', e.event_date), NULL))  AS last_active_date,
    COUNTIF(e.event_name = 'app_remove') > 0           AS has_app_remove
  FROM `firebase-public-project.analytics_153293282.events_*` AS e
  INNER JOIN cohort AS c
    ON e.user_pseudo_id = c.user_pseudo_id
  GROUP BY e.user_pseudo_id
)
SELECT
  IF(last_active_date <= DATE '2018-09-19', 'churned', 'still_active')  AS churn_status,
  COUNT(*)                                                              AS players,
  COUNTIF(has_app_remove)                                               AS players_with_app_remove,
  ROUND(100 * COUNTIF(has_app_remove) / COUNT(*), 1)                    AS pct_app_remove
FROM player_status
GROUP BY churn_status
ORDER BY churn_status
