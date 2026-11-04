-- Krok 3: app_remove w podziale na platformę
-- Cel:     sprawdzić, czy app_remove (odinstalowanie) występuje na obu platformach,
--          czyli czy może być sygnałem churnu dla wszystkich graczy.
-- Wynik:   data/step3_app_remove_by_platform.csv. Suma graczy = 15 175 (każdy gracz ma jedną platformę).
--          iOS: 7 765 graczy, 1 406 z first_open, 0 z app_remove.
--          Android: 7 410 graczy, 2 913 z first_open, 2 635 z app_remove (35,6%).
-- Decyzja: app_remove nie jest rejestrowany na iOS, więc churn definiuję przez brak aktywności,
--          a app_remove służy do walidacji tej definicji na Androidzie.
--          Kohorty są w ~2/3 z Androida, więc retencję pokazuję też w podziale na platformę.

SELECT
  platform,
  COUNT(DISTINCT user_pseudo_id)                                                AS users,
  COUNT(DISTINCT IF(event_name = 'first_open', user_pseudo_id, NULL))           AS users_with_first_open,
  COUNT(DISTINCT IF(event_name = 'app_remove', user_pseudo_id, NULL))           AS users_with_app_remove,
  ROUND(100 * COUNT(DISTINCT IF(event_name = 'app_remove', user_pseudo_id, NULL))
            / COUNT(DISTINCT user_pseudo_id), 1)                                AS pct_app_remove
FROM `firebase-public-project.analytics_153293282.events_*`
GROUP BY platform
ORDER BY users DESC
