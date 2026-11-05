"""Uruchamia zapytania z folderu sql/ w BigQuery i zapisuje wyniki jako CSV w data/ pod tą samą nazwą.

Uruchomienie (z folderu projektu, z aktywnym .venv):

    python run_sql.py step4c_retention_two_periods
    python run_sql.py sql/step4c_retention_two_periods.sql
    python run_sql.py step4b_retention_by_week step4c_retention_two_periods   # kilka zapytań naraz

* Wynik sql/<nazwa>.sql trafia do data/<nazwa>.csv (istniejący plik zostaje nadpisany).
* Przed wykonaniem robi darmowy dry run i pokazuje, ile danych przetworzy zapytanie.
* Bezpiecznik: zapytanie, które przetworzyłoby więcej niż MAX_BYTES, zostanie odrzucone przez BigQuery.
* Przy błędzie BigQuery pokazuje jedną linijkę z komunikatem (zamiast tracebacku) i przechodzi do kolejnego zapytania.
* ID projektu GCP jest w .env (GCP_PROJECT_ID); logowanie przez `gcloud auth application-default login`.
"""
import os
import sys
from pathlib import Path

from dotenv import load_dotenv
from google.api_core.exceptions import GoogleAPICallError
from google.auth.exceptions import RefreshError
from google.cloud import bigquery

PROJECT_DIR = Path(__file__).parent
SQL_DIR = PROJECT_DIR / "sql"
DATA_DIR = PROJECT_DIR / "data"
MAX_BYTES = 1_000_000_000                       # bezpiecznik: 1 GB na zapytanie

load_dotenv(PROJECT_DIR / ".env")               # wczytuje zmienne z .env do os.environ
PROJECT_ID = os.getenv("GCP_PROJECT_ID")
if not PROJECT_ID:
    sys.exit("Brak GCP_PROJECT_ID w pliku .env (wzór w .env.example).")

client = bigquery.Client(project=PROJECT_ID)


def resolve_sql_path(name: str) -> Path:
    """Zamienia 'step4c_x', 'step4c_x.sql' albo 'sql/step4c_x.sql' na pełną ścieżkę pliku w sql/."""
    sql_path = SQL_DIR / f"{Path(name).stem}.sql"
    if not sql_path.exists():
        sys.exit(f"Nie ma pliku: {sql_path}")
    return sql_path


def run_sql_file(sql_path: Path):
    """Wykonuje zapytanie z pliku, zapisuje wynik do data/<nazwa>.csv i zwraca DataFrame."""
    sql = sql_path.read_text(encoding="utf-8")

    # 1) Dry run: BigQuery sprawdza SQL i liczy, ile danych przetworzy, ale niczego nie wykonuje (darmowe)
    dry = client.query(sql, job_config=bigquery.QueryJobConfig(dry_run=True, use_query_cache=False))
    print(f"{sql_path.name}: zapytanie przetworzy {dry.total_bytes_processed / 1e6:.1f} MB")

    # 2) Właściwe wykonanie z limitem kosztu
    job = client.query(sql, job_config=bigquery.QueryJobConfig(maximum_bytes_billed=MAX_BYTES))
    df = job.to_dataframe(create_bqstorage_client=False)

    # 3) Zapis wyniku pod tą samą nazwą co plik SQL
    csv_path = DATA_DIR / f"{sql_path.stem}.csv"
    df.to_csv(csv_path, index=False)
    print(f"  zapisano {len(df)} wierszy -> {csv_path.relative_to(PROJECT_DIR)}")
    return df


if __name__ == "__main__":
    if len(sys.argv) < 2:
        sys.exit("Podaj nazwę zapytania, np.: python run_sql.py step4c_retention_two_periods")

    DATA_DIR.mkdir(exist_ok=True)
    failed = []
    for name in sys.argv[1:]:
        sql_path = resolve_sql_path(name)
        try:
            result = run_sql_file(sql_path)
        except GoogleAPICallError as error:
            # Błąd zwrócony przez BigQuery (składnia SQL, brak dostępu, przekroczony limit):
            # zamiast długiego tracebacku pokazujemy sam komunikat, a w nim wiersz i kolumnę [wiersz:kolumna]
            message = error.errors[0]["message"] if error.errors else error.message
            print(f"{sql_path.name}: BŁĄD BigQuery: {message}\n")
            failed.append(sql_path.name)
            continue
        except RefreshError:
            sys.exit("Logowanie wygasło. Uruchom: gcloud auth application-default login")
        print(result.head(20).to_string(index=False), end="\n\n")

    if failed:
        sys.exit(f"Nieudane zapytania: {', '.join(failed)}")
