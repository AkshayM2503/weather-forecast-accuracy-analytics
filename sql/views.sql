--
-- PostgreSQL database dump
--

\restrict f5RKH706nHKyqBnYT1E7t7Diu6WfWcB7EtNpK5KNd7GcgDeGJo6PtEdh9muCvha

-- Dumped from database version 18.4
-- Dumped by pg_dump version 18.4

SET statement_timeout = 0;
SET lock_timeout = 0;
SET idle_in_transaction_session_timeout = 0;
SET transaction_timeout = 0;
SET client_encoding = 'UTF8';
SET standard_conforming_strings = on;
SELECT pg_catalog.set_config('search_path', '', false);
SET check_function_bodies = false;
SET xmloption = content;
SET client_min_messages = warning;
SET row_security = off;

--
-- Name: vw_current_forecast_verification_detail; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_current_forecast_verification_detail AS
 SELECT f.forecast_snapshot_id,
    f.run_id,
    f.city_id,
    c.city_name,
    f.retrieved_at,
    f.target_timestamp,
    ((f.target_timestamp AT TIME ZONE 'UTC'::text))::date AS target_date_utc,
    round((EXTRACT(epoch FROM (f.target_timestamp - f.retrieved_at)) / (3600)::numeric), 2) AS lead_time_hours,
        CASE
            WHEN ((f.target_timestamp - f.retrieved_at) < '24:00:00'::interval) THEN '0–24 hours'::text
            WHEN ((f.target_timestamp - f.retrieved_at) < '48:00:00'::interval) THEN '24–48 hours'::text
            WHEN ((f.target_timestamp - f.retrieved_at) < '72:00:00'::interval) THEN '48–72 hours'::text
            ELSE '72+ hours'::text
        END AS lead_time_bucket,
    f.forecast_temperature_c,
    o.temperature_c AS actual_temperature_c,
    v.temperature_error_c,
    v.absolute_temperature_error_c,
    v.squared_temperature_error_c,
    v.verified_at,
    v.verification_status
   FROM (((public.fact_forecast_verification v
     JOIN public.fact_forecast_snapshot f ON ((f.forecast_snapshot_id = v.forecast_snapshot_id)))
     JOIN public.fact_weather_observation o ON ((o.observation_id = v.observation_id)))
     JOIN public.dim_city c ON ((c.city_id = f.city_id)))
  WHERE ((f.source_name = 'open-meteo-forecast-api'::text) AND (o.source_name = 'open_meteo_era5_reanalysis'::text) AND (v.verification_status = 'verified'::text) AND (f.target_timestamp > f.retrieved_at));


--
-- Name: vw_current_forecast_accuracy_daily; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_current_forecast_accuracy_daily AS
 SELECT target_date_utc AS target_date,
    city_id,
    city_name,
    lead_time_bucket,
    count(*) AS verified_forecasts,
    sum(absolute_temperature_error_c) AS absolute_error_sum,
    sum(squared_temperature_error_c) AS squared_error_sum,
    round((avg(absolute_temperature_error_c))::numeric, 3) AS daily_mae_c,
    round((sqrt(avg(squared_temperature_error_c)))::numeric, 3) AS daily_rmse_c
   FROM public.vw_current_forecast_verification_detail
  GROUP BY target_date_utc, city_id, city_name, lead_time_bucket;


--
-- Name: vw_current_forecast_accuracy_rolling; Type: VIEW; Schema: public; Owner: -
--

CREATE VIEW public.vw_current_forecast_accuracy_rolling AS
 WITH rolling_metrics AS (
         SELECT vw_current_forecast_accuracy_daily.target_date,
            vw_current_forecast_accuracy_daily.city_id,
            vw_current_forecast_accuracy_daily.city_name,
            vw_current_forecast_accuracy_daily.lead_time_bucket,
            vw_current_forecast_accuracy_daily.verified_forecasts,
            vw_current_forecast_accuracy_daily.daily_mae_c,
            vw_current_forecast_accuracy_daily.daily_rmse_c,
            sum(vw_current_forecast_accuracy_daily.verified_forecasts) OVER (PARTITION BY vw_current_forecast_accuracy_daily.city_id, vw_current_forecast_accuracy_daily.lead_time_bucket ORDER BY ((vw_current_forecast_accuracy_daily.target_date)::timestamp without time zone) RANGE BETWEEN '6 days'::interval PRECEDING AND CURRENT ROW) AS rolling_7d_count,
            sum(vw_current_forecast_accuracy_daily.absolute_error_sum) OVER (PARTITION BY vw_current_forecast_accuracy_daily.city_id, vw_current_forecast_accuracy_daily.lead_time_bucket ORDER BY ((vw_current_forecast_accuracy_daily.target_date)::timestamp without time zone) RANGE BETWEEN '6 days'::interval PRECEDING AND CURRENT ROW) AS rolling_7d_absolute_error,
            sum(vw_current_forecast_accuracy_daily.squared_error_sum) OVER (PARTITION BY vw_current_forecast_accuracy_daily.city_id, vw_current_forecast_accuracy_daily.lead_time_bucket ORDER BY ((vw_current_forecast_accuracy_daily.target_date)::timestamp without time zone) RANGE BETWEEN '6 days'::interval PRECEDING AND CURRENT ROW) AS rolling_7d_squared_error,
            sum(vw_current_forecast_accuracy_daily.verified_forecasts) OVER (PARTITION BY vw_current_forecast_accuracy_daily.city_id, vw_current_forecast_accuracy_daily.lead_time_bucket ORDER BY ((vw_current_forecast_accuracy_daily.target_date)::timestamp without time zone) RANGE BETWEEN '29 days'::interval PRECEDING AND CURRENT ROW) AS rolling_30d_count,
            sum(vw_current_forecast_accuracy_daily.absolute_error_sum) OVER (PARTITION BY vw_current_forecast_accuracy_daily.city_id, vw_current_forecast_accuracy_daily.lead_time_bucket ORDER BY ((vw_current_forecast_accuracy_daily.target_date)::timestamp without time zone) RANGE BETWEEN '29 days'::interval PRECEDING AND CURRENT ROW) AS rolling_30d_absolute_error,
            sum(vw_current_forecast_accuracy_daily.squared_error_sum) OVER (PARTITION BY vw_current_forecast_accuracy_daily.city_id, vw_current_forecast_accuracy_daily.lead_time_bucket ORDER BY ((vw_current_forecast_accuracy_daily.target_date)::timestamp without time zone) RANGE BETWEEN '29 days'::interval PRECEDING AND CURRENT ROW) AS rolling_30d_squared_error
           FROM public.vw_current_forecast_accuracy_daily
        )
 SELECT target_date,
    city_id,
    city_name,
    lead_time_bucket,
    verified_forecasts,
    daily_mae_c,
    daily_rmse_c,
    rolling_7d_count,
    round(((rolling_7d_absolute_error / (NULLIF(rolling_7d_count, (0)::numeric))::double precision))::numeric, 3) AS rolling_7d_mae_c,
    round((sqrt((rolling_7d_squared_error / (NULLIF(rolling_7d_count, (0)::numeric))::double precision)))::numeric, 3) AS rolling_7d_rmse_c,
    rolling_30d_count,
    round(((rolling_30d_absolute_error / (NULLIF(rolling_30d_count, (0)::numeric))::double precision))::numeric, 3) AS rolling_30d_mae_c,
    round((sqrt((rolling_30d_squared_error / (NULLIF(rolling_30d_count, (0)::numeric))::double precision)))::numeric, 3) AS rolling_30d_rmse_c
   FROM rolling_metrics;


--
-- PostgreSQL database dump complete
--

\unrestrict f5RKH706nHKyqBnYT1E7t7Diu6WfWcB7EtNpK5KNd7GcgDeGJo6PtEdh9muCvha

