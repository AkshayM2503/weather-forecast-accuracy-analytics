
import logging
import os
import uuid
from datetime import date, datetime, timezone

import psycopg
import requests
from dotenv import load_dotenv

from cities import CITIES

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
)

API_URL = "https://historical-forecast-api.open-meteo.com/v1/forecast"
SOURCE_NAME = "open_meteo_historical_forecast_backtest"

# Match the dates of the existing historical reference dataset.
START_DATE = date(2026, 10, 10)
END_DATE = date(2026, 10, 12)


def main():
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL is missing from .env")

    all_rows = []
    succeeded_cities = 0

    # Fetch all cities before writing to the database.
    with psycopg.connect(database_url) as conn:
        with conn.cursor() as cur:
            for city in CITIES:
                name = city["city_name"]
                latitude = city["latitude"]
                longitude = city["longitude"]

                response = requests.get(
                    API_URL,
                    params={
                        "latitude": latitude,
                        "longitude": longitude,
                        "start_date": START_DATE.isoformat(),
                        "end_date": END_DATE.isoformat(),
                        "hourly": (
                            "temperature_2m,"
                            "relative_humidity_2m,"
                            "precipitation,"
                            "wind_speed_10m,"
                            "weather_code"
                        ),
                        "timezone": "GMT",
                        "timeformat": "unixtime",
                        "wind_speed_unit": "kmh",
                    },
                    timeout=60,
                )
                response.raise_for_status()

                hourly = response.json()["hourly"]

                cur.execute(
                    "SELECT city_id FROM dim_city WHERE city_name = %s",
                    (name,),
                )
                result = cur.fetchone()

                if result is None:
                    raise ValueError(
                        f"City {name!r} not found in dim_city"
                    )

                city_id = result[0]
                city_rows = 0

                for i, timestamp in enumerate(hourly["time"]):
                    temperature = hourly["temperature_2m"][i]

                    if temperature is None:
                        continue

                    target_timestamp = datetime.fromtimestamp(
                        int(timestamp),
                        tz=timezone.utc,
                    )

                    all_rows.append(
                        (
                            city_id,
                            target_timestamp,
                            temperature,
                            hourly["relative_humidity_2m"][i],
                            hourly["precipitation"][i],
                            hourly["wind_speed_10m"][i],
                            hourly["weather_code"][i],
                        )
                    )
                    city_rows += 1

                succeeded_cities += 1
                logging.info(
                    "%s: retrieved %s historical forecast rows",
                    name,
                    city_rows,
                )

    # Store this backtest as a separate forecast run.
    run_id = uuid.uuid4()
    started_at = datetime.now(timezone.utc)

    with psycopg.connect(database_url) as conn:
        with conn.cursor() as cur:
            cur.execute(
                """
                INSERT INTO ingestion_run
                    (run_id, started_at, status, cities_requested)
                VALUES (%s, %s, %s, %s)
                """,
                (run_id, started_at, "running", len(CITIES)),
            )

            cur.executemany(
                """
                INSERT INTO fact_forecast_snapshot (
                    run_id, city_id, retrieved_at, target_timestamp,
                    forecast_temperature_c,
                    forecast_relative_humidity_pct,
                    forecast_precipitation_mm,
                    forecast_wind_speed_kmh,
                    forecast_weather_code,
                    source_name
                )
                VALUES (
                    %s, %s, %s, %s, %s, %s, %s, %s, %s, %s
                )
                """,
                [
                    (
                        run_id,
                        city_id,
                        started_at,
                        target_timestamp,
                        temperature,
                        humidity,
                        precipitation,
                        wind_speed,
                        weather_code,
                        SOURCE_NAME,
                    )
                    for (
                        city_id,
                        target_timestamp,
                        temperature,
                        humidity,
                        precipitation,
                        wind_speed,
                        weather_code,
                    ) in all_rows
                ],
            )

            cur.execute(
                """
                UPDATE ingestion_run
                SET finished_at = %s,
                    status = %s,
                    cities_succeeded = %s,
                    forecast_rows_inserted = %s
                WHERE run_id = %s
                """,
                (
                    datetime.now(timezone.utc),
                    "success",
                    succeeded_cities,
                    len(all_rows),
                    run_id,
                ),
            )

        conn.commit()

    logging.info("Backtest run ID: %s", run_id)
    logging.info("Cities succeeded: %s/%s", succeeded_cities, len(CITIES))
    logging.info("Forecast rows inserted: %s", len(all_rows))


if __name__ == "__main__":
    main()
