
import logging
import os

import psycopg
from dotenv import load_dotenv


SOURCE_NAME = "open-meteo-forecast-api"
OBSERVATION_SOURCE = "open_meteo_era5_reanalysis"

logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s | %(levelname)s | %(message)s",
)

logger = logging.getLogger("forecast_verification")


def main():
    load_dotenv()

    database_url = os.getenv("DATABASE_URL")

    if not database_url:
        raise RuntimeError("DATABASE_URL is missing from .env")

    logger.info("Starting automated forecast verification")

    with psycopg.connect(database_url) as conn:

        with conn.cursor() as cur:

            # Insert one verification record per eligible forecast snapshot.
            cur.execute(
                """
                INSERT INTO fact_forecast_verification (
                    forecast_snapshot_id,
                    observation_id,
                    verified_at,
                    verification_status,
                    temperature_error_c,
                    absolute_temperature_error_c,
                    squared_temperature_error_c,
                    verification_note
                )
                SELECT
                    f.forecast_snapshot_id,
                    o.observation_id,
                    CURRENT_TIMESTAMP,
                    'verified',
                    f.forecast_temperature_c - o.temperature_c,
                    ABS(f.forecast_temperature_c - o.temperature_c),
                    POWER(
                        f.forecast_temperature_c - o.temperature_c,
                        2
                    ),
                    'Automated verification using ERA5 reanalysis'
                FROM fact_forecast_snapshot f

                INNER JOIN fact_weather_observation o
                    ON o.city_id = f.city_id
                    AND o.observed_at = f.target_timestamp
                    AND o.source_name = %s

                LEFT JOIN fact_forecast_verification v
                    ON v.forecast_snapshot_id = f.forecast_snapshot_id

                WHERE f.source_name = %s
                    AND f.target_timestamp > f.retrieved_at
                    AND f.target_timestamp <= CURRENT_TIMESTAMP
                    AND f.forecast_temperature_c IS NOT NULL
                    AND o.temperature_c IS NOT NULL
                    AND v.verification_id IS NULL

                ON CONFLICT (forecast_snapshot_id) DO NOTHING
                """,
                (OBSERVATION_SOURCE, SOURCE_NAME),
            )

            inserted = cur.rowcount

        conn.commit()

    logger.info("----------------------------------------")
    logger.info("Forecast verification completed")
    logger.info("New verification records inserted: %s", inserted)
    logger.info("Forecast source: %s", SOURCE_NAME)
    logger.info("Observation source: %s", OBSERVATION_SOURCE)


if __name__ == "__main__":
    main()
