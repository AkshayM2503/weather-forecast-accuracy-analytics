
import logging
import os
from datetime import date, datetime, timedelta, timezone

import psycopg
import requests
from dotenv import load_dotenv

from cities import CITIES


API_URL = "https://archive-api.open-meteo.com/v1/archive"
SOURCE_NAME = "open_meteo_era5_reanalysis"

# Retain the existing five-day availability buffer.
AVAILABILITY_DELAY_DAYS = 5

# Recheck an overlapping seven-day window on every execution.
LOOKBACK_DAYS = 7

HOURLY_VARIABLES = "temperature_2m,precipitation"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
)
logger = logging.getLogger("observation_ingestion")


def utc_now():
    return datetime.now(timezone.utc)


def fetch_observations(city, start_date, end_date):
    """Fetch hourly ERA5 observations for one city in UTC."""

    params = {
        "latitude": city["latitude"],
        "longitude": city["longitude"],
        "start_date": start_date.isoformat(),
        "end_date": end_date.isoformat(),
        "hourly": HOURLY_VARIABLES,
        "timezone": "GMT",
        "timeformat": "unixtime",
    }

    response = requests.get(API_URL, params=params, timeout=60)
    response.raise_for_status()

    payload = response.json()
    hourly = payload.get("hourly")

    if not hourly:
        raise ValueError(
            f"No hourly observation data returned for {city['city_name']}"
        )

    timestamps = hourly.get("time", [])
    temperatures = hourly.get("temperature_2m", [])
    precipitation = hourly.get("precipitation", [])

    if not timestamps:
        raise ValueError(
            f"No observation timestamps returned for {city['city_name']}"
        )

    if not (
        len(timestamps) == len(temperatures) == len(precipitation)
    ):
        raise ValueError(
            f"Observation array length mismatch for {city['city_name']}"
        )

    records = []

    for timestamp, temperature, rainfall in zip(
        timestamps, temperatures, precipitation
    ):
        if temperature is None:
            continue

        records.append(
            {
                "observed_at": datetime.fromtimestamp(
                    timestamp, tz=timezone.utc
                ),
                "temperature_c": temperature,
                "precipitation_mm": rainfall,
            }
        )

    return records


def main():
    load_dotenv()

    database_url = os.getenv("DATABASE_URL")

    if not database_url:
        raise RuntimeError("DATABASE_URL is missing from .env")

    # Calculate dates using UTC because the API returns UTC timestamps.
    utc_today = utc_now().date()

    end_date = utc_today - timedelta(days=AVAILABILITY_DELAY_DAYS)
    start_date = end_date - timedelta(days=LOOKBACK_DAYS - 1)

    total_inserted = 0
    successful_cities = 0
    failed_cities = []

    logger.info("Starting ERA5 observation ingestion")
    logger.info("Observation window: %s to %s", start_date, end_date)

    with psycopg.connect(database_url, autocommit=True) as conn:

        for city in CITIES:
            city_name = city["city_name"]

            try:
                records = fetch_observations(
                    city, start_date, end_date
                )

                with conn.transaction():

                    city_row = conn.execute(
                        """
                        SELECT city_id
                        FROM dim_city
                        WHERE city_name = %s
                        """,
                        (city_name,),
                    ).fetchone()

                    if city_row is None:
                        raise ValueError(
                            f"{city_name} was not found in dim_city"
                        )

                    city_id = city_row[0]
                    retrieved_at = utc_now()
                    inserted_for_city = 0

                    for item in records:
                        result = conn.execute(
                            """
                            INSERT INTO fact_weather_observation (
                                city_id,
                                observed_at,
                                temperature_c,
                                precipitation_mm,
                                source_name,
                                retrieved_at
                            )
                            VALUES (%s, %s, %s, %s, %s, %s)
                            ON CONFLICT (
                                city_id,
                                observed_at,
                                source_name
                            ) DO NOTHING
                            RETURNING observation_id
                            """,
                            (
                                city_id,
                                item["observed_at"],
                                item["temperature_c"],
                                item["precipitation_mm"],
                                SOURCE_NAME,
                                retrieved_at,
                            ),
                        ).fetchone()

                        if result is not None:
                            inserted_for_city += 1

                total_inserted += inserted_for_city
                successful_cities += 1

                logger.info(
                    "%s: fetched=%s, newly inserted=%s",
                    city_name,
                    len(records),
                    inserted_for_city,
                )

            except Exception as exc:
                failed_cities.append(city_name)

                logger.exception(
                    "Observation ingestion failed for %s: %s",
                    city_name,
                    exc,
                )

    logger.info("----------------------------------------")
    logger.info("ERA5 observation ingestion completed")
    logger.info("Successful cities: %s/%s", successful_cities, len(CITIES))
    logger.info("Failed cities: %s", failed_cities or "None")
    logger.info("New observation rows inserted: %s", total_inserted)
    logger.info("Observation window: %s to %s", start_date, end_date)

    if successful_cities == 0:
        raise SystemExit("Observation ingestion failed for every city.")

    if failed_cities:
        raise SystemExit(
            f"Observation ingestion partially failed: {failed_cities}"
        )


if __name__ == "__main__":
    main()
