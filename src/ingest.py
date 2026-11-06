import logging
import os
import uuid
from datetime import datetime, timezone

import psycopg
import requests
from dotenv import load_dotenv

from cities import CITIES

API_URL = "https://api.open-meteo.com/v1/forecast"
HOURLY_VARIABLES = [
    "temperature_2m",
    "relative_humidity_2m",
    "precipitation",
    "wind_speed_10m",
    "weather_code",
]

logging.basicConfig(level=logging.INFO, format="%(asctime)s | %(levelname)s | %(message)s")
logger = logging.getLogger("weather_ingestion")


def utc_now():
    return datetime.now(timezone.utc)


def fetch_forecast(city):
    """Fetch hourly forecast values for one city; API timestamps are requested in UTC."""
    params = {
        "latitude": city["latitude"],
        "longitude": city["longitude"],
        "hourly": ",".join(HOURLY_VARIABLES),
        "forecast_days": 3,
        "timezone": "UTC",
        "temperature_unit": "celsius",
        "wind_speed_unit": "kmh",
        "precipitation_unit": "mm",
    }
    response = requests.get(API_URL, params=params, timeout=30)
    response.raise_for_status()
    payload = response.json()
    hourly = payload.get("hourly")

    if not hourly or "time" not in hourly:
        raise ValueError(f"No hourly time series returned for {city['city_name']}")

    records = []
    for i, raw_time in enumerate(hourly["time"]):
        target_time = datetime.fromisoformat(raw_time).replace(tzinfo=timezone.utc)

        def value(key):
            values = hourly.get(key, [])
            return values[i] if i < len(values) else None

        records.append({
            "target_timestamp": target_time,
            "temperature_c": value("temperature_2m"),
            "relative_humidity_pct": value("relative_humidity_2m"),
            "precipitation_mm": value("precipitation"),
            "wind_speed_kmh": value("wind_speed_10m"),
            "weather_code": value("weather_code"),
        })
    return records


def ensure_cities(conn):
    city_ids = {}
    for city in CITIES:
        row = conn.execute(
            """
            INSERT INTO dim_city
                (city_name, state_name, country_code, latitude, longitude, is_active)
            VALUES (%s, %s, 'IN', %s, %s, TRUE)
            ON CONFLICT (city_name) DO UPDATE SET
                state_name = EXCLUDED.state_name,
                latitude = EXCLUDED.latitude,
                longitude = EXCLUDED.longitude,
                is_active = TRUE
            RETURNING city_id
            """,
            (city["city_name"], city["state_name"], city["latitude"], city["longitude"]),
        ).fetchone()
        city_ids[city["city_name"]] = row[0]
    return city_ids


def main():
    load_dotenv()
    database_url = os.getenv("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL is missing. Copy .env.example to .env and configure it.")

    run_id = uuid.uuid4()
    started_at = utc_now()
    succeeded = 0
    inserted_total = 0
    errors = []

    # Autocommit ensures run status can be recorded even when one city fails.
    with psycopg.connect(database_url, autocommit=True) as conn:
        city_ids = ensure_cities(conn)
        conn.execute(
            """
            INSERT INTO ingestion_run (run_id, started_at, status, cities_requested)
            VALUES (%s, %s, 'running', %s)
            """,
            (run_id, started_at, len(CITIES)),
        )

        for city in CITIES:
            try:
                forecast_rows = fetch_forecast(city)
                # Timestamp the snapshot after the API response has been received.
                retrieved_at = utc_now()
                city_id = city_ids[city["city_name"]]

                with conn.transaction():
                    for item in forecast_rows:
                        conn.execute(
                            """
                            INSERT INTO fact_forecast_snapshot (
                                run_id, city_id, retrieved_at, target_timestamp,
                                forecast_temperature_c, forecast_relative_humidity_pct,
                                forecast_precipitation_mm, forecast_wind_speed_kmh,
                                forecast_weather_code
                            )
                            VALUES (%s, %s, %s, %s, %s, %s, %s, %s, %s)
                            ON CONFLICT (run_id, city_id, target_timestamp) DO NOTHING
                            """,
                            (
                                run_id, city_id, retrieved_at, item["target_timestamp"],
                                item["temperature_c"], item["relative_humidity_pct"],
                                item["precipitation_mm"], item["wind_speed_kmh"],
                                item["weather_code"],
                            ),
                        )
                succeeded += 1
                inserted_total += len(forecast_rows)
                logger.info("%s: processed %s forecast rows", city["city_name"], len(forecast_rows))
            except Exception as exc:
                message = f"{city['city_name']}: {type(exc).__name__}: {exc}"
                errors.append(message)
                logger.exception("Failed to ingest %s", city["city_name"])

        status = "success" if succeeded == len(CITIES) else ("partial_success" if succeeded else "failed")
        conn.execute(
            """
            UPDATE ingestion_run
            SET finished_at = %s, status = %s, cities_succeeded = %s,
                forecast_rows_inserted = %s, error_message = %s
            WHERE run_id = %s
            """,
            (
                utc_now(), status, succeeded, inserted_total,
                "\n".join(errors)[:8000] if errors else None, run_id,
            ),
        )

    logger.info(
        "Run %s finished: status=%s, cities=%s/%s, rows processed=%s",
        run_id, status, succeeded, len(CITIES), inserted_total
    )
    if succeeded == 0:
        raise SystemExit("No cities were ingested successfully. Check the logs and database/API connectivity.")


if __name__ == "__main__":
    main()
