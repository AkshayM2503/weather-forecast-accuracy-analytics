--
-- PostgreSQL database dump
--

\restrict Yq4S4iAJBtY6Y34tQgwRQeewSaRhQ8DrwpYIMaZ08thHGjEpqNErrewrXWskstT

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

SET default_tablespace = '';

SET default_table_access_method = heap;

--
-- Name: dim_city; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.dim_city (
    city_id bigint NOT NULL,
    city_name text NOT NULL,
    state_name text NOT NULL,
    country_code character(2) DEFAULT 'IN'::bpchar NOT NULL,
    latitude double precision NOT NULL,
    longitude double precision NOT NULL,
    is_active boolean DEFAULT true NOT NULL,
    created_at timestamp with time zone DEFAULT now() NOT NULL,
    CONSTRAINT dim_city_latitude_check CHECK (((latitude >= ('-90'::integer)::double precision) AND (latitude <= (90)::double precision))),
    CONSTRAINT dim_city_longitude_check CHECK (((longitude >= ('-180'::integer)::double precision) AND (longitude <= (180)::double precision)))
);


--
-- Name: dim_city_city_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.dim_city_city_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: dim_city_city_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.dim_city_city_id_seq OWNED BY public.dim_city.city_id;


--
-- Name: fact_forecast_snapshot; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fact_forecast_snapshot (
    forecast_snapshot_id bigint NOT NULL,
    run_id uuid NOT NULL,
    city_id bigint NOT NULL,
    retrieved_at timestamp with time zone NOT NULL,
    target_timestamp timestamp with time zone NOT NULL,
    forecast_temperature_c double precision,
    forecast_relative_humidity_pct double precision,
    forecast_precipitation_mm double precision,
    forecast_wind_speed_kmh double precision,
    forecast_weather_code integer,
    source_name text DEFAULT 'open-meteo-forecast-api'::text NOT NULL
);


--
-- Name: fact_forecast_snapshot_forecast_snapshot_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fact_forecast_snapshot_forecast_snapshot_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fact_forecast_snapshot_forecast_snapshot_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fact_forecast_snapshot_forecast_snapshot_id_seq OWNED BY public.fact_forecast_snapshot.forecast_snapshot_id;


--
-- Name: fact_forecast_verification; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fact_forecast_verification (
    verification_id bigint NOT NULL,
    forecast_snapshot_id bigint NOT NULL,
    observation_id bigint,
    verified_at timestamp with time zone,
    verification_status text DEFAULT 'pending'::text NOT NULL,
    temperature_error_c double precision,
    absolute_temperature_error_c double precision,
    squared_temperature_error_c double precision,
    verification_note text,
    CONSTRAINT fact_forecast_verification_verification_status_check CHECK ((verification_status = ANY (ARRAY['pending'::text, 'verified'::text, 'unavailable'::text, 'rejected'::text])))
);


--
-- Name: fact_forecast_verification_verification_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fact_forecast_verification_verification_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fact_forecast_verification_verification_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fact_forecast_verification_verification_id_seq OWNED BY public.fact_forecast_verification.verification_id;


--
-- Name: fact_weather_observation; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.fact_weather_observation (
    observation_id bigint NOT NULL,
    city_id bigint NOT NULL,
    observed_at timestamp with time zone NOT NULL,
    temperature_c double precision,
    precipitation_mm double precision,
    source_name text NOT NULL,
    retrieved_at timestamp with time zone DEFAULT now() NOT NULL
);


--
-- Name: fact_weather_observation_observation_id_seq; Type: SEQUENCE; Schema: public; Owner: -
--

CREATE SEQUENCE public.fact_weather_observation_observation_id_seq
    START WITH 1
    INCREMENT BY 1
    NO MINVALUE
    NO MAXVALUE
    CACHE 1;


--
-- Name: fact_weather_observation_observation_id_seq; Type: SEQUENCE OWNED BY; Schema: public; Owner: -
--

ALTER SEQUENCE public.fact_weather_observation_observation_id_seq OWNED BY public.fact_weather_observation.observation_id;


--
-- Name: ingestion_run; Type: TABLE; Schema: public; Owner: -
--

CREATE TABLE public.ingestion_run (
    run_id uuid NOT NULL,
    started_at timestamp with time zone NOT NULL,
    finished_at timestamp with time zone,
    status text NOT NULL,
    cities_requested integer DEFAULT 0 NOT NULL,
    cities_succeeded integer DEFAULT 0 NOT NULL,
    forecast_rows_inserted integer DEFAULT 0 NOT NULL,
    error_message text,
    CONSTRAINT ingestion_run_status_check CHECK ((status = ANY (ARRAY['running'::text, 'success'::text, 'partial_success'::text, 'failed'::text])))
);


--
-- Name: dim_city city_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dim_city ALTER COLUMN city_id SET DEFAULT nextval('public.dim_city_city_id_seq'::regclass);


--
-- Name: fact_forecast_snapshot forecast_snapshot_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_forecast_snapshot ALTER COLUMN forecast_snapshot_id SET DEFAULT nextval('public.fact_forecast_snapshot_forecast_snapshot_id_seq'::regclass);


--
-- Name: fact_forecast_verification verification_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_forecast_verification ALTER COLUMN verification_id SET DEFAULT nextval('public.fact_forecast_verification_verification_id_seq'::regclass);


--
-- Name: fact_weather_observation observation_id; Type: DEFAULT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_weather_observation ALTER COLUMN observation_id SET DEFAULT nextval('public.fact_weather_observation_observation_id_seq'::regclass);


--
-- Name: dim_city dim_city_city_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dim_city
    ADD CONSTRAINT dim_city_city_name_key UNIQUE (city_name);


--
-- Name: dim_city dim_city_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.dim_city
    ADD CONSTRAINT dim_city_pkey PRIMARY KEY (city_id);


--
-- Name: fact_forecast_snapshot fact_forecast_snapshot_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_forecast_snapshot
    ADD CONSTRAINT fact_forecast_snapshot_pkey PRIMARY KEY (forecast_snapshot_id);


--
-- Name: fact_forecast_snapshot fact_forecast_snapshot_run_id_city_id_target_timestamp_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_forecast_snapshot
    ADD CONSTRAINT fact_forecast_snapshot_run_id_city_id_target_timestamp_key UNIQUE (run_id, city_id, target_timestamp);


--
-- Name: fact_forecast_verification fact_forecast_verification_forecast_snapshot_id_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_forecast_verification
    ADD CONSTRAINT fact_forecast_verification_forecast_snapshot_id_key UNIQUE (forecast_snapshot_id);


--
-- Name: fact_forecast_verification fact_forecast_verification_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_forecast_verification
    ADD CONSTRAINT fact_forecast_verification_pkey PRIMARY KEY (verification_id);


--
-- Name: fact_weather_observation fact_weather_observation_city_id_observed_at_source_name_key; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_weather_observation
    ADD CONSTRAINT fact_weather_observation_city_id_observed_at_source_name_key UNIQUE (city_id, observed_at, source_name);


--
-- Name: fact_weather_observation fact_weather_observation_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_weather_observation
    ADD CONSTRAINT fact_weather_observation_pkey PRIMARY KEY (observation_id);


--
-- Name: ingestion_run ingestion_run_pkey; Type: CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.ingestion_run
    ADD CONSTRAINT ingestion_run_pkey PRIMARY KEY (run_id);


--
-- Name: ix_forecast_city_target; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_forecast_city_target ON public.fact_forecast_snapshot USING btree (city_id, target_timestamp);


--
-- Name: ix_forecast_retrieved_at; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_forecast_retrieved_at ON public.fact_forecast_snapshot USING btree (retrieved_at);


--
-- Name: ix_verification_status; Type: INDEX; Schema: public; Owner: -
--

CREATE INDEX ix_verification_status ON public.fact_forecast_verification USING btree (verification_status);


--
-- Name: fact_forecast_snapshot fact_forecast_snapshot_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_forecast_snapshot
    ADD CONSTRAINT fact_forecast_snapshot_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.dim_city(city_id);


--
-- Name: fact_forecast_snapshot fact_forecast_snapshot_run_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_forecast_snapshot
    ADD CONSTRAINT fact_forecast_snapshot_run_id_fkey FOREIGN KEY (run_id) REFERENCES public.ingestion_run(run_id);


--
-- Name: fact_forecast_verification fact_forecast_verification_forecast_snapshot_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_forecast_verification
    ADD CONSTRAINT fact_forecast_verification_forecast_snapshot_id_fkey FOREIGN KEY (forecast_snapshot_id) REFERENCES public.fact_forecast_snapshot(forecast_snapshot_id);


--
-- Name: fact_forecast_verification fact_forecast_verification_observation_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_forecast_verification
    ADD CONSTRAINT fact_forecast_verification_observation_id_fkey FOREIGN KEY (observation_id) REFERENCES public.fact_weather_observation(observation_id);


--
-- Name: fact_weather_observation fact_weather_observation_city_id_fkey; Type: FK CONSTRAINT; Schema: public; Owner: -
--

ALTER TABLE ONLY public.fact_weather_observation
    ADD CONSTRAINT fact_weather_observation_city_id_fkey FOREIGN KEY (city_id) REFERENCES public.dim_city(city_id);


--
-- PostgreSQL database dump complete
--

\unrestrict Yq4S4iAJBtY6Y34tQgwRQeewSaRhQ8DrwpYIMaZ08thHGjEpqNErrewrXWskstT

