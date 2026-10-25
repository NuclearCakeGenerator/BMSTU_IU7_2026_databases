import time
from pathlib import Path

import psycopg2

DB_CONFIG = {
    "host": "127.0.0.1",
    "port": 5433,
    "dbname": "lab_db",
    "user": "student",
    "password": "secretpassword",
}

SQL_FILES = [
    "01_init_schema.sql",
    "02_constraints.sql",
    "03_create_executables.sql",
    "04_bulk_insert.sql",
]
SQL_DIR = Path(__file__).resolve().parent

def reset_database():
    target_db = DB_CONFIG['dbname']
    admin_config = DB_CONFIG.copy()
    admin_config['dbname'] = 'postgres'
    admin_conn = psycopg2.connect(**admin_config)
    try:
        admin_conn.autocommit = True
        with admin_conn.cursor() as cur:
            cur.execute(f"DROP DATABASE IF EXISTS {target_db} WITH (FORCE);")
            cur.execute(f"CREATE DATABASE {target_db};")
        print("Database reset and recreated")
    finally:
        admin_conn.close()

    with psycopg2.connect(**DB_CONFIG) as conn:
        start_total = time.perf_counter()    
        with conn.cursor() as cur:
            for file_name in SQL_FILES:
                print(f"  Выполняется: {file_name} ...")
                t0 = time.perf_counter()
                
                with (SQL_DIR / file_name).open("r", encoding="utf-8") as f:
                    cur.execute(f.read())
                print(f"готово за {time.perf_counter() - t0:.3f} сек.")
        conn.commit()

    print(f"Все скрипты применены за {time.perf_counter() - start_total:.3f} сек.")

if __name__ == "__main__":
    reset_database()
