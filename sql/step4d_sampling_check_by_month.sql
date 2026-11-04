-- Krok 4d: kontrola artefaktu próbkowania w podziale na miesiące
-- Cel:     sprawdzić, czy spadek retencji od końca sierpnia może wynikać z rzadszego próbkowania graczy.
--          Każdy dzień ma stałe 50 000 eventów, więc jeśli we wrześniu graczy w próbce jest dużo więcej,
--          na jednego gracza przypada mniej eventów i łatwiej „zgubić” jego aktywny dzień.
-- Wynik:   data/step4d_sampling_check_by_month.csv. Eventy na gracza dziennie w próbce:
--          czerwiec 71,9 | lipiec 109,2 | sierpień 104,7 | wrzesień 97,7 | październik 102,6.
--          Graczy dziennie: 696 | 458 | 478 | 512 | 487.
-- Decyzja: wrzesień różni się od lipca/sierpnia o ~7–10%, a retencja spadła o ~41%, więc próbkowanie
--          nie wyjaśnia spadku. Dodatkowo czerwiec miał najrzadsze próbkowanie (72), a najwyższą
--          retencję, czyli rzadsze próbkowanie nie przekłada się automatycznie na niższą retencję.

WITH user_days AS (
  -- jeden wiersz na gracza i dzień: ile jego eventów trafiło do próbki tego dnia
  SELECT
    PARSE_DATE('%Y%m%d', event_date)  AS event_day,
    user_pseudo_id,
    COUNT(*)                          AS events
  FROM `firebase-public-project.analytics_153293282.events_*`
  GROUP BY event_day, user_pseudo_id
)
SELECT
  FORMAT_DATE('%Y-%m', event_day)                     AS event_month,
  COUNT(DISTINCT event_day)                           AS days,
  ROUND(COUNT(*) / COUNT(DISTINCT event_day))         AS avg_users_per_day,
  ROUND(AVG(events), 1)                               AS avg_events_per_user_day
FROM user_days
GROUP BY event_month
ORDER BY event_month
