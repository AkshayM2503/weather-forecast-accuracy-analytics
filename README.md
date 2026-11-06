# Weather Forecast Accuracy Analytics

**An end-to-end weather forecast verification and analytics platform built with Python, PostgreSQL, and Power BI.**

Evaluate how accurately weather forecasts predict future temperatures across 10 major Indian cities. The project collects hourly forecast snapshots, matches them against historical weather observations, calculates forecast error metrics, and presents performance insights through an interactive Power BI dashboard.

## Project Overview

Weather forecasts are useful only when their accuracy can be measured. This project builds a data pipeline to systematically capture forecasts, verify them against historical observations, and analyse how forecast accuracy changes across cities and forecast lead times.

Unlike a conventional weather dashboard that simply displays current conditions, this project focuses on **measuring forecast reliability over time**.

### Key Features

- **Forecast Snapshot Collection:** Preserves hourly forecast data from the Open-Meteo Forecast API without overwriting previous forecast runs.
- **Forecast Verification:** Matches saved forecasts with corresponding historical weather observations.
- **Accuracy Evaluation:** Calculates Mean Absolute Error (MAE) and Root Mean Squared Error (RMSE).
- **Lead-Time Analysis:** Compares forecast accuracy across 0–24, 24–48, 48–72, and 72+ hour lead-time buckets.
- **Multi-City Analytics:** Evaluates forecast performance across 10 Indian cities.
- **Data Quality Monitoring:** Tracks ingestion status, verification coverage, and data availability.
- **Automated Pipeline Execution:** Uses Python scripts and Windows Task Scheduler to schedule data collection and verification.
- **Interactive Power BI Dashboard:** Provides city-wise comparisons, accuracy trends, and monitoring insights.

## Project Architecture

The system follows a four-stage data pipeline:

1. **Data Sources – Open-Meteo APIs:** Forecast API, ERA5 reanalysis observations, and previous forecast runs.
2. **Processing – Python:** Forecast ingestion, observation collection, verification, and accuracy calculations.
3. **Storage – PostgreSQL:** Structured fact tables, dimension tables, and analytical SQL views.
4. **Visualisation – Power BI:** Forecast accuracy analysis, monitoring, and city-wise data quality.

## Technology Stack

| Component | Technology |
|---|---|
| Programming | Python |
| Data Processing | Pandas, NumPy |
| Database | PostgreSQL |
| Query Language | SQL |
| Database Connectivity | Psycopg |
| API Integration | Open-Meteo APIs, Requests |
| Forecast Evaluation | MAE, RMSE |
| Visualisation | Microsoft Power BI Desktop |
| Workflow Automation | Power Automate Desktop |
| Scheduling | Windows Task Scheduler, PowerShell |
| Configuration | Python dotenv |
| Version Control |	Git, GitHub |
## Cities Covered

The project analyses weather forecasts across 10 Indian cities:

Bengaluru, Mumbai, Delhi, Chennai, Hyderabad, Kolkata, Pune, Jaipur, Ahmedabad, and Kochi.

## Forecast Accuracy Metrics

The project evaluates forecast performance using two standard error metrics.

**Mean Absolute Error (MAE)**

Measures the average absolute difference between forecast and observed temperatures.

\[
MAE = \frac{1}{n}\sum_{i=1}^{n}|F_i-O_i|
\]

**Root Mean Squared Error (RMSE)**

Measures the square root of the average squared forecast error, giving greater weight to larger errors.

\[
RMSE = \sqrt{\frac{1}{n}\sum_{i=1}^{n}(F_i-O_i)^2}
\]

Where:
- \(F_i\) = Forecast temperature
- \(O_i\) = Reference observation temperature
- \(n\) = Number of verified forecast-observation pairs

Lower MAE and RMSE values indicate better forecast accuracy.

## Database Design

PostgreSQL stores the collected data and verification results.

### Core Tables

| Table | Purpose |
|---|---|
| `dim_city` | Stores city information |
| `fact_forecast_snapshot` | Preserves forecast snapshots |
| `fact_weather_observation` | Stores historical weather observations |
| `fact_forecast_verification` | Stores forecast verification results |
| `ingestion_run` | Tracks pipeline execution and ingestion status |

### Analytical Views

| View | Purpose |
|---|---|
| `vw_current_forecast_verification_detail` | Detailed forecast verification records |
| `vw_current_forecast_accuracy_daily` | Daily forecast accuracy analysis |
| `vw_current_forecast_accuracy_rolling` | Rolling accuracy analysis |

## Power BI Dashboard

The Power BI report is organised into four analytical pages.

1. **Weather Forecast Accuracy:** Overall forecast performance and key accuracy indicators.
2. **Forecast Accuracy Analysis:** Error comparisons across cities and forecast lead times.
3. **Forecast Monitoring & Data Quality:** Ingestion monitoring, verification coverage, and data availability.
4. **City-Wise Data Quality:** City-level verification and observation coverage.

## Project Structure

```text
weather-forecast-accuracy/
│
├── src/
│   ├── ingest.py
│   ├── ingest_observations.py
│   ├── verify_forecasts.py
│   └── cities.py
│
├── scripts/
│   ├── ingest_historical_forecasts.py
│   ├── ingest_previous_runs.py
│   ├── run_forecast_verification.ps1
│   ├── run_hourly_ingestion.ps1
│   └── run_observation_ingestion.ps1
│
├── sql/
│   ├── schema.sql
│   └── views.sql
│
├── Power BI/
│   └── Weather_analytics_phase6.pbix
│
├── Screenshots/
│
├── logs/
├── .env.example
├── .gitignore
├── requirements.txt
└── README.md
```

## Setup and Installation

### 1. Prerequisites

- Python 3.11 or later
- PostgreSQL
- Internet connection
- Power BI Desktop (for dashboard access)

### 2. Clone the Repository

```bash
git clone <your-repository-url>
cd weather-forecast-accuracy
```

### 3. Create a Virtual Environment

```bash
python -m venv .venv
```

Activate it on Windows:

```powershell
.venv\Scripts\activate
```

### 4. Install Dependencies

```bash
python -m pip install -r requirements.txt
```

### 5. Configure Environment Variables

Copy `.env.example` to `.env` and configure your PostgreSQL connection.

Example:

```env
DATABASE_URL=postgresql://postgres:your_password@localhost:5432/weather_analytics
```

Use your own database credentials. Never commit `.env` to GitHub.

### 6. Create the Database

Create a PostgreSQL database named `weather_analytics`.

Then execute the schema:

```bash
psql -U postgres -d weather_analytics -f sql/schema.sql
```

Create the analytical views:

```bash
psql -U postgres -d weather_analytics -f sql/views.sql
```

## Running the Pipeline

Run the following scripts from the project root.

**Forecast ingestion**

```bash
python src/ingest.py
```

**Weather observation ingestion**

```bash
python src/ingest_observations.py
```

**Forecast verification**

```bash
python src/verify_forecasts.py
```

The ingestion pipeline preserves forecast snapshots from separate runs, allowing forecasts to be evaluated against observations available for their corresponding target timestamps.

## Automation

Python ingestion and verification scripts can be scheduled through Windows Task Scheduler.

The configured workflow supports recurring data collection and verification without manually executing each script.

Power BI Desktop is used for local report refresh and analysis; its refresh automation depends on the local desktop configuration.

## Data Interpretation and Limitations

- Forecast accuracy is calculated only for eligible forecast-observation pairs.
- ERA5 reanalysis is used as a historical reference dataset. It is not equivalent to independent, real-time weather station measurements.
- Reanalysis data may become available with a delay, so the latest forecast ingestion date and latest verification date may differ.
- Forecast lead time is calculated relative to the forecast retrieval timestamp.
- Accuracy metrics depend on the available verification records and should be interpreted alongside data coverage.

## Screenshots

See the `Screenshots/` directory for the dashboard pages, database structure, pipeline execution, automation setup, and project architecture.

## Future Improvements

- Expand coverage to additional cities and weather variables.
- Introduce additional forecast providers for comparative evaluation.
- Extend historical backtesting across longer periods.
- Add more detailed forecast reliability and bias analysis.
- Deploy the analytics pipeline and dashboard to a cloud environment.

## Author

**Akshay Murali**

M.Sc. Computer Science

GitHub: [AkshayM2503](https://github.com/AkshayM2503)

---

*Built as a data engineering and analytics project to evaluate weather forecast accuracy using Python, SQL, and Power BI.*