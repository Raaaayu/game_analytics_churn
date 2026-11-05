-- Krok 4g: jakie wartości ma traffic_source u graczy z kohort, przed i od 27.08.2018
-- Cel:     rozpoznanie pola traffic_source (źródło pozyskania gracza) przed analizą retencji:
--          czy wartości są użyteczne (a nie zastępcze: NULL, pusty tekst, <Other>)
--          i czy struktura źródeł zmieniła się po 27.08.
-- Wynik:   data/step4g_traffic_source_values.csv. Dwa istotne źródła (razem ~98% graczy):
--            (direct)/(none):        62,0% przed → 74,9% od 27.08
--            google-play/organic:    36,1% przed → 23,8% od 27.08
--          Pozostałe (google organic, invite_a_friend, dynamic_link, NULL) < 1% każde.
--          Płatne kampanie praktycznie nie występują (1 gracz z cpc/spring_sale).
-- Decyzja: brak nowej kampanii płatnej po 27.08, ale udział źródeł przesunął się o ~13 pp.
--          (direct) oznacza brak informacji o źródle (m.in. iOS nie przekazuje źródła instalacji),
--          więc źródło jest splecione z platformą. Następnie: D1 według platformy × źródła × okresu.

WITH cohort AS (
  -- gracze z first_open w dniu pierwszego pojawienia się (4 307); dzień 0 = data first_open
  -- traffic_source to STRUCT z pierwszym źródłem pozyskania gracza: source, medium, name (kampania)
  SELECT
    user_pseudo_id,
    MIN(PARSE_DATE('%Y%m%d', event_date))  AS cohort_date,
    ANY_VALUE(traffic_source.source)       AS ts_source,
    ANY_VALUE(traffic_source.medium)       AS ts_medium,
    ANY_VALUE(traffic_source.name)         AS ts_campaign
  FROM `firebase-public-project.analytics_153293282.events_*`
  GROUP BY user_pseudo_id
  HAVING MIN(IF(event_name = 'first_open', PARSE_DATE('%Y%m%d', event_date), NULL))
         = MIN(PARSE_DATE('%Y%m%d', event_date))
),
labeled AS (
  -- okres kohorty i czytelne etykiety dla brakujących wartości (NULL i pusty tekst osobno)
  SELECT
    IF(cohort_date < DATE '2018-08-27', '1_do_2018-08-26', '2_od_2018-08-27')  AS cohort_period,
    CASE WHEN ts_source   IS NULL THEN '(null)' WHEN ts_source   = '' THEN '(pusty)' ELSE ts_source   END AS ts_source,
    CASE WHEN ts_medium   IS NULL THEN '(null)' WHEN ts_medium   = '' THEN '(pusty)' ELSE ts_medium   END AS ts_medium,
    CASE WHEN ts_campaign IS NULL THEN '(null)' WHEN ts_campaign = '' THEN '(pusty)' ELSE ts_campaign END AS ts_campaign
  FROM cohort
)
SELECT
  ts_source,
  ts_medium,
  ts_campaign,
  cohort_period,
  COUNT(*)                                                                   AS players,
  ROUND(100 * COUNT(*) / SUM(COUNT(*)) OVER (PARTITION BY cohort_period), 1) AS pct_of_period
FROM labeled
GROUP BY ts_source, ts_medium, ts_campaign, cohort_period
ORDER BY ts_source, ts_medium, ts_campaign, cohort_period
