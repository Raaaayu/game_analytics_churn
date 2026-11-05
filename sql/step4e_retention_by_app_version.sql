-- Krok 4e: retencja D1 według wersji gry w dniu instalacji
-- Cel:     sprawdzić, czy spadek retencji od 27.08 zbiega się z nową wersją gry
--          (trop: gra) czy wersje mają podobne D1 (trop: źródło pozyskania graczy).
-- Wynik:   data/step4e_retention_by_app_version.csv. 25 wersji, istotne cztery:
--            2.62:   2 840 graczy, 12.06–03.10 (1 885 przed / 955 od 27.08), D1 20,0% ±1,5 pp
--            2.6.31:   998 graczy, 16.07–03.10 (354 / 644), D1 17,2% ±2,4 pp
--            2.6.30:   307 graczy, 12.06–25.09 (299 / 8), D1 29,0% ±5,2 pp
--            2.63:      55 graczy, od 28.09, D1 0 z 29
--          Dwa schematy numeracji (2.62/2.63 i 2.6.x), prawdopodobnie dwie platformy (do sprawdzenia).
-- Decyzja: ok. 27.08 nie pojawiła się nowa wersja, a główna wersja 2.62 była instalowana przez cały
--          okres, więc nowa wersja nie wyjaśnia spadku. Następnie: D1 w układzie wersja × okres.
--          Wersji < ~50 graczy nie interpretuję (margines dla 0% / 100% wychodzi mylnie 0).

WITH cohort AS (
  -- gracze z first_open w dniu pierwszego pojawienia się (4 307); dzień 0 = data first_open
  -- install_version = wersja gry zapisana przy evencie first_open
  SELECT
    user_pseudo_id,
    MIN(PARSE_DATE('%Y%m%d', event_date))                    AS cohort_date,
    MIN(IF(event_name = 'first_open', app_info.version, NULL)) AS install_version
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
  -- jeden wiersz na gracza: wersja przy instalacji, dzień 0, liczba dni danych, aktywność w dniu 1
  SELECT
    c.user_pseudo_id,
    c.install_version,
    c.cohort_date,
    DATE_DIFF(DATE '2018-10-03', c.cohort_date, DAY)              AS days_observed,
    COUNTIF(DATE_DIFF(a.active_date, c.cohort_date, DAY) = 1) > 0 AS active_d1
  FROM cohort AS c
  INNER JOIN active_days AS a
    ON c.user_pseudo_id = a.user_pseudo_id
  GROUP BY c.user_pseudo_id, c.install_version, c.cohort_date
),
versions AS (
  -- jeden wiersz na wersję gry
  SELECT
    install_version,
    COUNT(*)                                                    AS players,
    MIN(cohort_date)                                            AS first_install_date,
    MAX(cohort_date)                                            AS last_install_date,
    COUNTIF(cohort_date <  DATE '2018-08-27')                   AS players_before_0827,
    COUNTIF(cohort_date >= DATE '2018-08-27')                   AS players_from_0827,
    COUNTIF(days_observed >= 1)                                 AS d1_eligible,
    SAFE_DIVIDE(COUNTIF(active_d1 AND days_observed >= 1),
                COUNTIF(days_observed >= 1))                    AS d1_rate
  FROM player_retention
  GROUP BY install_version
)
SELECT
  install_version,
  players,
  first_install_date,
  last_install_date,
  players_before_0827,
  players_from_0827,
  d1_eligible,
  ROUND(100 * d1_rate, 1)                                                   AS d1_retention_pct,
  ROUND(200 * SQRT(SAFE_DIVIDE(d1_rate * (1 - d1_rate), d1_eligible)), 1)   AS d1_margin_pp
FROM versions
ORDER BY first_install_date, install_version
