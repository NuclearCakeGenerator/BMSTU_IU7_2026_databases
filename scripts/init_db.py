import time

import psycopg2

DB_CONFIG = {
    "host": "localhost",
    "port": 5433,
    "dbname": "lab_db",
    "user": "student",
    "password": "secretpassword",
}

SQL_FILES = [
    "01_init_schema.sql",
    "02_constraints.sql",
    "03_bulk_insert.sql",
]

def reset_database():
    print("Database reset...")
    start_total = time.perf_counter()

    conn = psycopg2.connect(**DB_CONFIG)
    cur = conn.cursor()

    for file_name in SQL_FILES:
        print(f"  Выполняется: {file_name} ...")
        t0 = time.perf_counter()
        
        with open(file_name, "r", encoding="utf-8") as f:
            cur.execute(f.read())
        
    conn.commit()
    print(f"готово за {time.perf_counter() - t0:.3f} сек.")

    cur.close()
    conn.close()

    print(f"Все скрипты применены за {time.perf_counter() - start_total:.3f} сек.")

if __name__ == "__main__":
    reset_database()
