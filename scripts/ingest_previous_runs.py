
import logging
import os
import uuid
from datetime import datetime, timezone

import psycopg
import requests
from dotenv import load_dotenv

from cities import CITIES

load_dotenv()

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
)

API_URL = "https://previous-runs-api.open-meteo.com/v1/forecast"

START_DATE = "2026-10-10"
END_DATE = "2026-10-12"

LEADS = (1, 2, 3)

logging.info("Starting previous model runs ingestion")


def main():
    database_url = os.environ.get("DATABASE_URL")
    if not database_url:
        raise RuntimeError("DATABASE_URL is missing from .env")

    all_rows = {lead: [] for lead in LEADS}

    with psycopg.connect(database_url) as conn:
        with conn.cursor() as cur:
            for city in CITIES:
                name = city.get("city_name", city.get("name"))
                latitude = city["latitude"]
                longitude = city["longitude"]

                response = requests.get(
                    API_URL,
                    params={
                        "latitude": latitude,
                        "longitude": longitude,
                        "start_date": START_DATE,
                        "end_date": END_DATE,
                        "hourly": ",".join(
                            f"temperature_2m_previous_day{lead}"
                            for lead in LEADS
                        ),
                        "timezone": "GMT",
                        "timeformat": "unixtime",
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
                    raise ValueError(f"City {name!r} not found")

                city_id = result[0]

                for lead in LEADS:
                    key = f"temperature_2m_previous_day{lead}"
                    temperatures = hourly.get(key)

                    if temperatures is None:
                        raise ValueError(
                            f"{name}: API did not return {key}"
                        )

                    for timestamp, temperature in zip(
                        hourly["time"], temperatures
                    ):
                        if temperature is None:
                            continue

                        target_timestamp = datetime.fromtimestamp(
                            int(timestamp), tz=timezone.utc
                        )

                        all_rows[lead].append(
                            (city_id, target_timestamp, temperature)
                        )

                logging.info("%s: retrieved forecast data", name)

    # One separate ingestion run per lead time, preserving the
    # existing unique constraint on run_id, city_id, target_timestamp.
    with psycopg.connect(database_url) as conn:
        with conn.cursor() as cur:
            for lead in LEADS:
                run_id = uuid.uuid4()
                started_at = datetime.now(timezone.utc)
                source_name = f"open_meteo_previous_runs_day{lead}"

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
                        forecast_temperature_c, source_name
                    )
                    VALUES (%s, %s, %s, %s, %s, %s)
                    """,
                    [
                        (
                            run_id,
                            city_id,
                            started_at,
                            target_timestamp,
                            temperature,
                            source_name,
                        )
                        for city_id, target_timestamp, temperature
                        in all_rows[lead]
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
                        len(CITIES),
                        len(all_rows[lead]),
                        run_id,
                    ),
                )

                logging.info(
                    "Lead %s day(s): inserted %s rows; run ID %s",
                    lead,
                    len(all_rows[lead]),
                    run_id,
                )

        conn.commit()

    logging.info("Previous model runs ingestion completed")


if __name__ == "__main__":
    main()
