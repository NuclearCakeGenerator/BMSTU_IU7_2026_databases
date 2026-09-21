import csv
import random
import secrets
from datetime import datetime, time, timedelta
from pathlib import Path

from faker import Faker

fake = Faker("en_US")
OUTPUT_DIR = Path(__file__).resolve().parent.parent / "data"

EMPLOYEES_COUNT = 1000
WORKING_HOURS_COUNT = 1000
ACCESS_CARDS_COUNT = 1000
ACCESS_ZONES_COUNT = 1000
PASSAGES_COUNT = 2000
CARD_ASSIGNMENTS_COUNT = 1000
ACCESS_LEVEL_SPREAD = (1, 15)


def write_csv(file_name, rows, fieldnames):
    OUTPUT_DIR.mkdir(parents=True, exist_ok=True)
    file_path = OUTPUT_DIR / file_name
    with file_path.open("w", newline="", encoding="utf-8") as csv_file:
        writer = csv.DictWriter(csv_file, fieldnames=fieldnames)
        writer.writeheader()
        writer.writerows(rows)


def to_bytea(value):
    return "\\x" + value.hex().upper()

def random_timestamp(start, end):
    seconds = int((end - start).total_seconds())
    return start + timedelta(seconds=random.randint(0, seconds))


def generate_working_hours(count=WORKING_HOURS_COUNT):
    rows = []

    for schedule_id in range(1, count + 1):
        start_minutes, end_minutes = sorted([random.randint(0, 1439), random.randint(0, 1439)])
        start_time = time(
            hour=start_minutes // 60,
            minute=start_minutes % 60,
        )
        end_time = time(
            hour=end_minutes // 60,
            minute=end_minutes % 60,
        )
        rows.append(
            {
                "id": schedule_id,
                "start_time": start_time.isoformat(),
                "end_time": end_time.isoformat(),
            }
        )

    write_csv(
        "working_hours.csv",
        rows,
        ["id", "start_time", "end_time"],
    )
    return rows


def generate_employees(working_hours, count=EMPLOYEES_COUNT):
    EMPLOYEE_HIRED_RANGE = (datetime(2001, 1, 1), datetime(2025, 12, 31))
    
    EMPLOYEE_EMAIL_DOMAIN_LENGTH_SPREAD = (3, 10)

    rows = []

    for employee_id in range(1, count + 1):
        first_name = fake.first_name()
        last_name = fake.last_name()
        hired_at = random_timestamp(*EMPLOYEE_HIRED_RANGE)
        rows.append(
            {
                "id": employee_id,
                "first_name": first_name,
                "last_name": last_name,
                "email": f"{first_name.lower()}.{last_name.lower()}{employee_id}@{fake.pystr(*EMPLOYEE_EMAIL_DOMAIN_LENGTH_SPREAD).lower()}.com",
                "access_level": random.randint(*ACCESS_LEVEL_SPREAD),
                "hired_at": hired_at.isoformat(sep=" "),
                "working_hours": random.choice(working_hours)["id"],
            }
        )

    write_csv(
        "employees.csv",
        rows,
        [
            "id",
            "first_name",
            "last_name",
            "email",
            "access_level",
            "hired_at",
            "working_hours",
        ],
    )
    return rows


def generate_access_cards(count=ACCESS_CARDS_COUNT):
    rows = []
    ACCESS_CARD_ISSUE_SPREAD = (datetime(2022, 1, 1), datetime(2025, 12, 31))
    ACCESS_CARD_DURABILITY_SPREAD = (180, 1095)
    ACCESS_CARD_STATUSES = ["active", "revoked", "expired"]
    ACCESS_CARD_STATUS_WEIGHTS = [80, 10, 10]
    
    for card_id in range(1, count + 1):
        issue_date = random_timestamp(*ACCESS_CARD_ISSUE_SPREAD)
        status = random.choices(
            ACCESS_CARD_STATUSES,
            weights=ACCESS_CARD_STATUS_WEIGHTS,
            k=1,
        )[0]
        expire_date = issue_date + timedelta(days=random.randint(*ACCESS_CARD_DURABILITY_SPREAD))
        rows.append(
            {
                "id": card_id,
                "uid_card": to_bytea(secrets.token_bytes(4)),
                "card_status": status,
                "issue_date": issue_date.isoformat(sep=" "),
                "expire_date": expire_date.isoformat(sep=" "),
            }
        )

    write_csv(
        "access_cards.csv",
        rows,
        ["id", "uid_card", "card_status", "issue_date", "expire_date"],
    )
    return rows


def generate_card_assignments(employees, access_cards, count=CARD_ASSIGNMENTS_COUNT):
    ASSIGNMENT_RATE = 0.9

    rows = []
    count = int(ASSIGNMENT_RATE * len(access_cards))
    random.shuffle(access_cards)

    for i in range(count):
        employee = random.choice(employees)
        card = access_cards[i]
        
        rows.append(
            {
                "id": i+1,
                "card_id": card["id"],
                "owner_id": employee["id"],
                "is_active_assignment": random.choice([True, False]),
            }
        )

    write_csv(
        "card_assignments.csv",
        rows,
        ["card_id", "owner_id", "id", "is_active_assignment"],
    )
    return rows


def generate_access_zones(count=ACCESS_ZONES_COUNT):
    ZONE_NAMES = [
        "Main Entrance",
        "Office Building",
        "Server Room",
        "Warehouse",
        "Laboratory",
        "Archive",
        "Conference Room",
        "Parking Lot",
        "Production Floor",
        "Security Room",
        "Finance Department",
        "Technical Floor",
    ]
    ROOT_ZONE_PROBABILITY = 0.55

    rows = []

    for area_id in range(1, count + 1):
        outer_zone_id = (
            random.randint(1, area_id - 1)
            if area_id > 1 and random.random() < 1-ROOT_ZONE_PROBABILITY
            else ""
        )
        rows.append(
            {
                "id": area_id,
                "zone_name": random.choice(ZONE_NAMES),
                "security_level": random.randint(*ACCESS_LEVEL_SPREAD),
                "outer_zone_id": outer_zone_id,
                "device_model": to_bytea(secrets.token_bytes(10)),
                "city": fake.city(),
            }
        )

    write_csv(
        "access_zones.csv",
        rows,
        [
            "id",
            "zone_name",
            "security_level",
            "outer_zone_id",
            "device_model",
            "city",
        ],
    )
    return rows


def generate_passages(employees, access_cards, access_areas, count=PASSAGES_COUNT):
    PASSAGE_TIME_SPREAD = (datetime(2025, 1, 1), datetime(2025, 12, 31, 23, 59, 59))


    rows = []
    
    active_cards = [card for card in access_cards if card["card_status"] == "active"]

    for passage_id in range(1, count + 1):
        employee = random.choice(employees)
        card = random.choice(active_cards or access_cards)
        area = random.choice(access_areas)
        granted = (
            card["card_status"] == "active"
            and employee["access_level"] >= area["security_level"]
        )
        rows.append(
            {
                "id": passage_id,
                "passage_time": random_timestamp(*PASSAGE_TIME_SPREAD).isoformat(sep=" "),
                "direction": random.choice(["IN", "OUT"]),
                "is_granted": str(granted).lower(),
                "person_id": employee["id"],
                "card_id": card["id"],
                "zone_id": area["id"],
            }
        )

    write_csv(
        "passages.csv",
        rows,
        ["id", "passage_time", "direction", "is_granted", "person_id", "card_id", "zone_id"],
    )
    return rows


def main():
    working_hours = generate_working_hours()
    employees = generate_employees(working_hours)
    access_cards = generate_access_cards()
    generate_card_assignments(employees, access_cards)
    access_areas = generate_access_zones()
    generate_passages(employees, access_cards, access_areas)


if __name__ == "__main__":
    main()
