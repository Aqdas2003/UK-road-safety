-- =====================================================================
-- 01_create_tables.sql
-- Layer 1 (staging): exact copies of the CSVs, every column TEXT.
-- Layer 2 (clean):   typed tables with only the columns we analyse.
-- =====================================================================

CREATE SCHEMA IF NOT EXISTS staging;

DROP TABLE IF EXISTS staging.collision_raw CASCADE;
CREATE TABLE staging.collision_raw (
    collision_index                               TEXT,
    collision_year                                TEXT,
    collision_ref_no                              TEXT,
    location_easting_osgr                         TEXT,
    location_northing_osgr                        TEXT,
    longitude                                     TEXT,
    latitude                                      TEXT,
    police_force                                  TEXT,
    collision_severity                            TEXT,
    number_of_vehicles                            TEXT,
    number_of_casualties                          TEXT,
    date                                          TEXT,
    day_of_week                                   TEXT,
    time                                          TEXT,
    local_authority_district                      TEXT,
    local_authority_ons_district                  TEXT,
    local_authority_highway                       TEXT,
    local_authority_highway_current               TEXT,
    first_road_class                              TEXT,
    first_road_number                             TEXT,
    road_type                                     TEXT,
    speed_limit                                   TEXT,
    junction_detail_historic                      TEXT,
    junction_detail                               TEXT,
    junction_control                              TEXT,
    second_road_class                             TEXT,
    second_road_number                            TEXT,
    pedestrian_crossing_human_control_historic    TEXT,
    pedestrian_crossing_physical_facilities_historic TEXT,
    pedestrian_crossing                           TEXT,
    light_conditions                              TEXT,
    weather_conditions                            TEXT,
    road_surface_conditions                       TEXT,
    special_conditions_at_site                    TEXT,
    carriageway_hazards_historic                  TEXT,
    carriageway_hazards                           TEXT,
    urban_or_rural_area                           TEXT,
    did_police_officer_attend_scene_of_accident   TEXT,
    trunk_road_flag                               TEXT,
    lsoa_of_accident_location                     TEXT,
    enhanced_severity_collision                   TEXT,
    collision_injury_based                        TEXT,
    collision_adjusted_severity_serious           TEXT,
    collision_adjusted_severity_slight            TEXT
);

DROP TABLE IF EXISTS staging.vehicle_raw CASCADE;
CREATE TABLE staging.vehicle_raw (
    collision_index                               TEXT,
    collision_year                                TEXT,
    collision_ref_no                              TEXT,
    vehicle_reference                             TEXT,
    vehicle_type                                  TEXT,
    towing_and_articulation                       TEXT,
    vehicle_manoeuvre_historic                    TEXT,
    vehicle_manoeuvre                             TEXT,
    vehicle_direction_from                        TEXT,
    vehicle_direction_to                          TEXT,
    vehicle_location_restricted_lane_historic     TEXT,
    vehicle_location_restricted_lane              TEXT,
    junction_location                             TEXT,
    skidding_and_overturning                      TEXT,
    hit_object_in_carriageway                     TEXT,
    vehicle_leaving_carriageway                   TEXT,
    hit_object_off_carriageway                    TEXT,
    first_point_of_impact                         TEXT,
    vehicle_left_hand_drive                       TEXT,
    journey_purpose_of_driver_historic            TEXT,
    journey_purpose_of_driver                     TEXT,
    sex_of_driver                                 TEXT,
    age_of_driver                                 TEXT,
    age_band_of_driver                            TEXT,
    engine_capacity_cc                            TEXT,
    propulsion_code                               TEXT,
    age_of_vehicle                                TEXT,
    generic_make_model                            TEXT,
    driver_imd_decile                             TEXT,
    lsoa_of_driver                                TEXT,
    escooter_flag                                 TEXT,
    driver_distance_banding                       TEXT
);

DROP TABLE IF EXISTS staging.casualty_raw CASCADE;
CREATE TABLE staging.casualty_raw (
    collision_index                               TEXT,
    collision_year                                TEXT,
    collision_ref_no                              TEXT,
    vehicle_reference                             TEXT,
    casualty_reference                            TEXT,
    casualty_class                                TEXT,
    sex_of_casualty                               TEXT,
    age_of_casualty                               TEXT,
    age_band_of_casualty                          TEXT,
    casualty_severity                             TEXT,
    pedestrian_location                           TEXT,
    pedestrian_movement                           TEXT,
    car_passenger                                 TEXT,
    bus_or_coach_passenger                        TEXT,
    pedestrian_road_maintenance_worker            TEXT,
    casualty_type                                 TEXT,
    casualty_imd_decile                           TEXT,
    lsoa_of_casualty                              TEXT,
    enhanced_casualty_severity                    TEXT,
    casualty_injury_based                         TEXT,
    casualty_adjusted_severity_serious            TEXT,
    casualty_adjusted_severity_slight             TEXT,
    casualty_distance_banding                     TEXT,
    escooter_flag                                 TEXT
);
-- Lookup table: every code in the dataset -> readable label
DROP TABLE IF EXISTS public.lookups CASCADE;
CREATE TABLE public.lookups (
    field  TEXT NOT NULL,
    code   TEXT NOT NULL,
    label  TEXT NOT NULL,
    PRIMARY KEY (field, code)
);

-- ---------------------------------------------------------------------
-- Clean tables. Three levels of detail ("grain"), linked by collision_id:
--   one collision  ->  many vehicles  ->  many casualties
-- ---------------------------------------------------------------------
DROP TABLE IF EXISTS public.casualties CASCADE;
DROP TABLE IF EXISTS public.vehicles CASCADE;
DROP TABLE IF EXISTS public.collisions CASCADE;

CREATE TABLE public.collisions (
    collision_id          TEXT PRIMARY KEY,
    collision_date        DATE NOT NULL,
    collision_hour        SMALLINT,                -- 0-23, NULL if time missing
    day_of_week           SMALLINT NOT NULL,       -- 1 = Sunday ... 7 = Saturday
    la_code               TEXT,                    -- ONS local authority code, e.g. E08000021
    latitude              NUMERIC(9,6),
    longitude             NUMERIC(9,6),
    severity              SMALLINT NOT NULL CHECK (severity IN (1,2,3)),  -- 1 Fatal, 2 Serious, 3 Slight
    adj_serious           NUMERIC(8,6),            -- DfT severity-adjusted probability of "serious"
    number_of_vehicles    SMALLINT,
    number_of_casualties  SMALLINT,
    road_type             TEXT,
    speed_limit           SMALLINT,
    light_conditions      TEXT,
    weather_conditions    TEXT,
    road_surface          TEXT,
    urban_rural           TEXT
);

CREATE TABLE public.vehicles (
    collision_id        TEXT NOT NULL REFERENCES public.collisions (collision_id),
    vehicle_ref         SMALLINT NOT NULL,
    vehicle_type        TEXT,
    driver_sex          TEXT,
    driver_age_band     TEXT,
    PRIMARY KEY (collision_id, vehicle_ref)
);

CREATE TABLE public.casualties (
    collision_id        TEXT NOT NULL REFERENCES public.collisions (collision_id),
    vehicle_ref         SMALLINT NOT NULL,
    casualty_ref        SMALLINT NOT NULL,
    casualty_class      TEXT,                     -- Driver/rider, Passenger, Pedestrian
    casualty_type       TEXT,
    sex                 TEXT,
    age                 SMALLINT,
    age_band            TEXT,
    severity            SMALLINT NOT NULL CHECK (severity IN (1,2,3)),
    adj_serious         NUMERIC(8,6),
    PRIMARY KEY (collision_id, vehicle_ref, casualty_ref)
);
