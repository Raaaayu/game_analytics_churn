-- Krok 3b: odstępy między kolejnymi dniami aktywności graczy z kohort
-- Cel:     ustalić, po ilu dniach od ostatniej aktywności gracze jeszcze wracają, i na tej podstawie
--          wybrać N dni nieaktywności oznaczające churn.
-- Uwaga:   days_since_last_active to różnica dat, a nie liczba dni bez gry.
--          1 = powrót następnego dnia (0 dni bez gry), 3 = 2 dni bez gry.
-- Wynik v1 (aktywność = jakikolwiek event): 6 822 powroty.
--          Narastająco: 1 dzień 46%, 7 dni 82%, 14 dni 91%, 23 dni 95%, 30 dni 97%.
--          Błąd: app_remove (odinstalowanie) był liczony jako aktywny dzień, co tworzyło fałszywe powroty.
-- Wynik v2 (bez app_remove i app_clear_data), data/step3b_return_gaps.csv: 6 349 powrotów (−473, ok. 7%).
--          Narastająco: 1 dzień 48%, 7 dni 84%, 14 dni 92%, 21 dni 95%, 30 dni 97%.
-- Decyzja: N = 14 (utrzymana po poprawce). Aktywność = jakikolwiek event oprócz app_remove i app_clear_data.
--          Churn = brak aktywności przez 14 dni od ostatniego aktywnego dnia.
--          Powroty po > 14 dniach (9%) to reaktywacje. Graczy aktywnych po 19.09.2018
--          nie da się ocenić (za mało dni do końca danych).

WITH cohort AS (
  -- gracze z first_open w dniu pierwszego pojawienia się (4 307, decyzja z kroku 2c)
  SELECT
    user_pseudo_id
  FROM `firebase-public-project.analytics_153293282.events_*`
  GROUP BY user_pseudo_id
  HAVING MIN(IF(event_name = 'first_open', PARSE_DATE('%Y%m%d', event_date), NULL))
         = MIN(PARSE_DATE('%Y%m%d', event_date))
),
active_days AS (
  -- jeden wiersz na gracza i dzień, w którym miał jakikolwiek event (oprócz odinstalowania i czyszczenia danych)
  SELECT DISTINCT
    e.user_pseudo_id,
    PARSE_DATE('%Y%m%d', e.event_date) AS active_date
  FROM `firebase-public-project.analytics_153293282.events_*` AS e
  INNER JOIN cohort AS c
    ON e.user_pseudo_id = c.user_pseudo_id
  WHERE e.event_name NOT IN ('app_remove', 'app_clear_data')
),
gaps AS (
  -- liczba dni od poprzedniego aktywnego dnia tego samego gracza
  SELECT
    user_pseudo_id,
    active_date,
    DATE_DIFF(
      active_date,
      LAG(active_date) OVER (PARTITION BY user_pseudo_id ORDER BY active_date),
      DAY
    ) AS days_since_last_active
  FROM active_days
)
SELECT
  days_since_last_active,
  COUNT(*)                                                                                   AS returns,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (), 2)                                           AS pct_of_returns,
  ROUND(100 * SUM(COUNT(*)) OVER (ORDER BY days_since_last_active) / SUM(COUNT(*)) OVER (), 2) AS cumulative_pct
FROM gaps
WHERE days_since_last_active IS NOT NULL
GROUP BY days_since_last_active
ORDER BY days_since_last_active
