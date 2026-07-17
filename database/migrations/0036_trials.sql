/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0036_trials.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the central trials table for Phase 1 – Installation.
*
* Frozen business rule:
*
*   One Installation = One Trial
*
* Creating an installation therefore creates exactly one record in public.trials.
*
* A trial records:
*
*   • Crop
*   • Crop type
*   • Variety name entered manually by the Trial Officer
*   • Witness variety
*   • Product type
*   • Trial type
*   • Season
*   • Installation method
*   • Planting or sowing date
*   • Density per hectare
*   • Number of varieties
*   • Region and province
*   • Exactly one location:
*
*       1. Grower + Farm
*       2. Experimental Station
*
*   • Remarks
*   • Initial decision
*   • Workflow status
*   • Business identifier
*
* Business identifier format:
*
*   VARIETY-GROWERNAME-TRIALTYPE
*
* Example:
*
*   AXIOMA-BENALI-SCREENING-Y1
*
* For an experimental station:
*
*   VARIETY-STATIONNAME-TRIALTYPE
*
* Frozen workflow:
*
*   • New trials begin with PENDING_APPROVAL.
*   • A trial may later become APPROVED, REJECTED, or CORRECTIONS_REQUESTED.
*   • Workflow history is stored later in trial_status_history.
*   • Manager and General Director approval logic is implemented later.
*
* Location rules:
*
*   • A trial must use exactly one location type.
*   • Grower location requires grower_id and farm_id.
*   • Experimental-station location requires experimental_station_id.
*   • Grower and station locations cannot be selected together.
*   • Region and province must match the selected farm or station.
*
* Installation method rules:
*
*   • PLANT requires planting_date.
*   • SEED requires sowing_date.
*   • Only the date matching the selected method may be populated.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0003_domains.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
*   • 0011_profiles.sql
*   • 0012_regions.sql
*   • 0013_provinces.sql
*   • 0014_growers.sql
*   • 0015_farms.sql
*   • 0016_experimental_stations.sql
*   • 0017_seasons.sql
*   • 0018_crops.sql
*   • 0019_crop_types.sql
*   • 0020_product_types.sql
*   • 0021_trial_types.sql
*   • 0022_witness_varieties.sql
*   • 0028_decision_types.sql
*   • 0030_trial_statuses.sql
*
***************************************************************************************************/

BEGIN;

--------------------------------------------------------------------------------
-- Session Configuration
--------------------------------------------------------------------------------

SET LOCAL search_path = public;

SET LOCAL statement_timeout = '5min';

SET LOCAL lock_timeout = '30s';

SET LOCAL idle_in_transaction_session_timeout = '5min';

--------------------------------------------------------------------------------
-- FUNCTION: Normalize Business-ID Components
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_trial_business_component(
    p_value text
)
RETURNS text
LANGUAGE sql
IMMUTABLE
STRICT
PARALLEL SAFE
SET search_path = public
AS
$$
    SELECT trim(
        BOTH '-'
        FROM regexp_replace(
            upper(public.unaccent(btrim(p_value))),
            '[^A-Z0-9]+',
            '-',
            'g'
        )
    );
$$;

COMMENT ON FUNCTION public.fn_trial_business_component(text) IS
'Converts a trial business-ID component into uppercase ASCII text separated by hyphens.';

--------------------------------------------------------------------------------
-- TABLE: trials
--------------------------------------------------------------------------------

CREATE TABLE public.trials
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                          uuid
                                PRIMARY KEY
                                DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Business Identity
    --------------------------------------------------------------------------

    business_id                 varchar(300)
                                NOT NULL,

    variety_name                varchar(200)
                                NOT NULL,

    --------------------------------------------------------------------------
    -- Agricultural Classification
    --------------------------------------------------------------------------

    crop_id                     uuid
                                NOT NULL,

    crop_type_id                uuid
                                NOT NULL,

    witness_variety_id          uuid,

    witness_variety_custom      varchar(200),

    product_type_id             uuid
                                NOT NULL,

    trial_type_id               uuid
                                NOT NULL,

    season_id                   uuid
                                NOT NULL,

    --------------------------------------------------------------------------
    -- Installation Method
    --------------------------------------------------------------------------

    installation_method         varchar(20)
                                NOT NULL,

    planting_date               date,

    sowing_date                 date,

    density_per_hectare         numeric(14,2)
                                NOT NULL,

    number_of_varieties         integer
                                NOT NULL
                                DEFAULT 1,

    --------------------------------------------------------------------------
    -- Administrative Location
    --------------------------------------------------------------------------

    region_id                   uuid
                                NOT NULL,

    province_id                 uuid
                                NOT NULL,

    --------------------------------------------------------------------------
    -- Grower/Farm Location
    --------------------------------------------------------------------------

    grower_id                   uuid,

    farm_id                     uuid,

    --------------------------------------------------------------------------
    -- Experimental Station Location
    --------------------------------------------------------------------------

    experimental_station_id     uuid,

    --------------------------------------------------------------------------
    -- Installation Information
    --------------------------------------------------------------------------

    remarks                     text,

    initial_decision_type_id    uuid,

    status_id                   uuid
                                NOT NULL,

    --------------------------------------------------------------------------
    -- Workflow Dates
    --------------------------------------------------------------------------

    submitted_at                timestamptz,

    approved_at                 timestamptz,

    rejected_at                 timestamptz,

    corrections_requested_at    timestamptz,

    completed_at                timestamptz,

    --------------------------------------------------------------------------
    -- Audit and Soft-Delete Columns
    --------------------------------------------------------------------------

    created_at                  timestamptz
                                NOT NULL
                                DEFAULT timezone('UTC', now()),

    updated_at                  timestamptz
                                NOT NULL
                                DEFAULT timezone('UTC', now()),

    created_by                  uuid,

    updated_by                  uuid,

    deleted_at                  timestamptz,

    --------------------------------------------------------------------------
    -- Foreign Keys
    --------------------------------------------------------------------------

    CONSTRAINT fk_trials_crop
        FOREIGN KEY (crop_id)
        REFERENCES public.crops(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trials_crop_type
        FOREIGN KEY (crop_type_id)
        REFERENCES public.crop_types(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trials_witness_variety
        FOREIGN KEY (witness_variety_id)
        REFERENCES public.witness_varieties(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trials_product_type
        FOREIGN KEY (product_type_id)
        REFERENCES public.product_types(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trials_trial_type
        FOREIGN KEY (trial_type_id)
        REFERENCES public.trial_types(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trials_season
        FOREIGN KEY (season_id)
        REFERENCES public.seasons(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trials_region
        FOREIGN KEY (region_id)
        REFERENCES public.regions(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trials_province
        FOREIGN KEY (province_id)
        REFERENCES public.provinces(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trials_grower
        FOREIGN KEY (grower_id)
        REFERENCES public.growers(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trials_farm
        FOREIGN KEY (farm_id)
        REFERENCES public.farms(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trials_experimental_station
        FOREIGN KEY (experimental_station_id)
        REFERENCES public.experimental_stations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trials_initial_decision_type
        FOREIGN KEY (initial_decision_type_id)
        REFERENCES public.decision_types(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trials_status
        FOREIGN KEY (status_id)
        REFERENCES public.trial_statuses(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trials_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_trials_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_trials_business_id
        CHECK
        (
            char_length(btrim(business_id)) BETWEEN 3 AND 300
        ),

    CONSTRAINT chk_trials_variety_name
        CHECK
        (
            char_length(btrim(variety_name)) BETWEEN 1 AND 200
        ),

    CONSTRAINT chk_trials_witness_custom
        CHECK
        (
            witness_variety_custom IS NULL
            OR
            (
                length(btrim(witness_variety_custom)) > 0
                AND char_length(btrim(witness_variety_custom)) <= 200
            )
        ),

    CONSTRAINT chk_trials_witness_source
        CHECK
        (
            witness_variety_id IS NULL
            OR witness_variety_custom IS NULL
        ),

    CONSTRAINT chk_trials_installation_method
        CHECK
        (
            installation_method IN
            (
                'PLANT',
                'SEED'
            )
        ),

    CONSTRAINT chk_trials_installation_date
        CHECK
        (
            (
                installation_method = 'PLANT'
                AND planting_date IS NOT NULL
                AND sowing_date IS NULL
            )
            OR
            (
                installation_method = 'SEED'
                AND sowing_date IS NOT NULL
                AND planting_date IS NULL
            )
        ),

    CONSTRAINT chk_trials_density_per_hectare
        CHECK
        (
            density_per_hectare > 0
        ),

    CONSTRAINT chk_trials_number_of_varieties
        CHECK
        (
            number_of_varieties >= 1
        ),

    CONSTRAINT chk_trials_exactly_one_location
        CHECK
        (
            (
                grower_id IS NOT NULL
                AND farm_id IS NOT NULL
                AND experimental_station_id IS NULL
            )
            OR
            (
                grower_id IS NULL
                AND farm_id IS NULL
                AND experimental_station_id IS NOT NULL
            )
        ),

    CONSTRAINT chk_trials_remarks
        CHECK
        (
            remarks IS NULL
            OR
            (
                length(btrim(remarks)) > 0
                AND char_length(btrim(remarks)) <= 10000
            )
        ),

    CONSTRAINT chk_trials_workflow_dates
        CHECK
        (
            approved_at IS NULL
            OR submitted_at IS NULL
            OR approved_at >= submitted_at
        ),

    CONSTRAINT chk_trials_rejected_date
        CHECK
        (
            rejected_at IS NULL
            OR submitted_at IS NULL
            OR rejected_at >= submitted_at
        ),

    CONSTRAINT chk_trials_corrections_date
        CHECK
        (
            corrections_requested_at IS NULL
            OR submitted_at IS NULL
            OR corrections_requested_at >= submitted_at
        ),

    CONSTRAINT chk_trials_completed_date
        CHECK
        (
            completed_at IS NULL
            OR approved_at IS NULL
            OR completed_at >= approved_at
        ),

    CONSTRAINT chk_trials_mutually_exclusive_resolution_dates
        CHECK
        (
            num_nonnulls(
                approved_at,
                rejected_at,
                corrections_requested_at
            ) <= 1
        ),

    CONSTRAINT chk_trials_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_trials_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.trials IS
'Central Phase 1 installation table. One installation creates exactly one agricultural variety trial.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.trials.id IS
'Internal UUID primary key of the trial.';

COMMENT ON COLUMN public.trials.business_id IS
'Generated human-readable identifier using variety, grower or station name, and trial type.';

COMMENT ON COLUMN public.trials.variety_name IS
'Candidate variety entered manually by the Trial Officer.';

COMMENT ON COLUMN public.trials.crop_id IS
'Vegetable crop being evaluated in the trial.';

COMMENT ON COLUMN public.trials.crop_type_id IS
'Crop subtype or commercial classification associated with the selected crop.';

COMMENT ON COLUMN public.trials.witness_variety_id IS
'Optional configured witness variety used for comparison in the same locality.';

COMMENT ON COLUMN public.trials.witness_variety_custom IS
'Optional manually entered witness variety when the configured value is unavailable.';

COMMENT ON COLUMN public.trials.product_type_id IS
'Product or resistance classification associated with the candidate variety.';

COMMENT ON COLUMN public.trials.trial_type_id IS
'Trial progression type such as Screening Y1, Demonstrative Y2, or Large Demo.';

COMMENT ON COLUMN public.trials.season_id IS
'Agricultural season in which the trial is installed.';

COMMENT ON COLUMN public.trials.installation_method IS
'Installation method. Allowed values are PLANT and SEED.';

COMMENT ON COLUMN public.trials.planting_date IS
'Planting date required when installation_method is PLANT.';

COMMENT ON COLUMN public.trials.sowing_date IS
'Sowing date required when installation_method is SEED.';

COMMENT ON COLUMN public.trials.density_per_hectare IS
'Installed plant or seed density per hectare.';

COMMENT ON COLUMN public.trials.number_of_varieties IS
'Number of candidate or comparative varieties represented by the installation.';

COMMENT ON COLUMN public.trials.region_id IS
'Moroccan administrative region of the selected trial location.';

COMMENT ON COLUMN public.trials.province_id IS
'Province associated with the selected trial location.';

COMMENT ON COLUMN public.trials.grower_id IS
'Grower responsible for the farm location. Required only for grower-based trials.';

COMMENT ON COLUMN public.trials.farm_id IS
'Farm where the trial is installed. Required only for grower-based trials.';

COMMENT ON COLUMN public.trials.experimental_station_id IS
'Experimental station where the trial is installed. Used instead of grower and farm.';

COMMENT ON COLUMN public.trials.remarks IS
'Additional installation observations entered by the Trial Officer.';

COMMENT ON COLUMN public.trials.initial_decision_type_id IS
'Optional initial decision recorded during installation.';

COMMENT ON COLUMN public.trials.status_id IS
'Current workflow status of the trial. New trials begin with PENDING_APPROVAL.';

COMMENT ON COLUMN public.trials.submitted_at IS
'UTC timestamp when the trial installation was submitted for approval.';

COMMENT ON COLUMN public.trials.approved_at IS
'UTC timestamp when the trial was approved.';

COMMENT ON COLUMN public.trials.rejected_at IS
'UTC timestamp when the trial was rejected.';

COMMENT ON COLUMN public.trials.corrections_requested_at IS
'UTC timestamp when corrections were requested.';

COMMENT ON COLUMN public.trials.completed_at IS
'UTC timestamp when the complete trial lifecycle was finished.';

COMMENT ON COLUMN public.trials.created_at IS
'UTC timestamp when the trial was created.';

COMMENT ON COLUMN public.trials.updated_at IS
'UTC timestamp when the trial was most recently updated.';

COMMENT ON COLUMN public.trials.created_by IS
'Supabase Auth user who created the trial installation.';

COMMENT ON COLUMN public.trials.updated_by IS
'Supabase Auth user who most recently updated the trial.';

COMMENT ON COLUMN public.trials.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the trial has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_trials_business_id_ci
    ON public.trials
    (
        lower(btrim(business_id))
    );

--------------------------------------------------------------------------------
-- RELATIONSHIP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_trials_crop_id
    ON public.trials (crop_id);

CREATE INDEX idx_trials_crop_type_id
    ON public.trials (crop_type_id);

CREATE INDEX idx_trials_witness_variety_id
    ON public.trials (witness_variety_id)
    WHERE witness_variety_id IS NOT NULL;

CREATE INDEX idx_trials_product_type_id
    ON public.trials (product_type_id);

CREATE INDEX idx_trials_trial_type_id
    ON public.trials (trial_type_id);

CREATE INDEX idx_trials_season_id
    ON public.trials (season_id);

CREATE INDEX idx_trials_region_id
    ON public.trials (region_id);

CREATE INDEX idx_trials_province_id
    ON public.trials (province_id);

CREATE INDEX idx_trials_grower_id
    ON public.trials (grower_id)
    WHERE grower_id IS NOT NULL;

CREATE INDEX idx_trials_farm_id
    ON public.trials (farm_id)
    WHERE farm_id IS NOT NULL;

CREATE INDEX idx_trials_experimental_station_id
    ON public.trials (experimental_station_id)
    WHERE experimental_station_id IS NOT NULL;

CREATE INDEX idx_trials_status_id
    ON public.trials (status_id);

CREATE INDEX idx_trials_initial_decision_type_id
    ON public.trials (initial_decision_type_id)
    WHERE initial_decision_type_id IS NOT NULL;

--------------------------------------------------------------------------------
-- DASHBOARD AND FILTERING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_trials_status_created
    ON public.trials
    (
        status_id,
        created_at DESC
    )
    WHERE deleted_at IS NULL;

CREATE INDEX idx_trials_crop_status
    ON public.trials
    (
        crop_id,
        status_id,
        created_at DESC
    )
    WHERE deleted_at IS NULL;

CREATE INDEX idx_trials_season_status
    ON public.trials
    (
        season_id,
        status_id,
        created_at DESC
    )
    WHERE deleted_at IS NULL;

CREATE INDEX idx_trials_region_province
    ON public.trials
    (
        region_id,
        province_id,
        created_at DESC
    )
    WHERE deleted_at IS NULL;

CREATE INDEX idx_trials_pending_approval
    ON public.trials
    (
        submitted_at,
        created_at
    )
    WHERE deleted_at IS NULL
      AND approved_at IS NULL
      AND rejected_at IS NULL;

CREATE INDEX idx_trials_created_by_active
    ON public.trials
    (
        created_by,
        created_at DESC
    )
    WHERE deleted_at IS NULL;

CREATE INDEX idx_trials_deleted_at
    ON public.trials (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_trials_business_id_trgm
    ON public.trials
    USING gin
    (
        business_id gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

CREATE INDEX idx_trials_variety_name_trgm
    ON public.trials
    USING gin
    (
        variety_name gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_trials_created_by
    ON public.trials (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_trials_updated_by
    ON public.trials (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION AND BUSINESS-ID GENERATION FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_prepare_trial()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_crop_active                    boolean;
    v_crop_deleted_at                timestamptz;

    v_crop_type_crop_id              uuid;
    v_crop_type_active               boolean;
    v_crop_type_deleted_at           timestamptz;

    v_product_type_active            boolean;
    v_product_type_deleted_at        timestamptz;

    v_trial_type_code                text;
    v_trial_type_active              boolean;
    v_trial_type_deleted_at          timestamptz;

    v_season_active                  boolean;
    v_season_deleted_at              timestamptz;

    v_region_active                  boolean;
    v_region_deleted_at              timestamptz;

    v_province_region_id             uuid;
    v_province_active                boolean;
    v_province_deleted_at            timestamptz;

    v_grower_name                    text;
    v_grower_active                  boolean;
    v_grower_deleted_at              timestamptz;

    v_farm_grower_id                 uuid;
    v_farm_province_id               uuid;
    v_farm_active                    boolean;
    v_farm_deleted_at                timestamptz;

    v_station_name                   text;
    v_station_province_id            uuid;
    v_station_active                 boolean;
    v_station_deleted_at             timestamptz;

    v_witness_crop_id                uuid;
    v_witness_active                 boolean;
    v_witness_deleted_at             timestamptz;

    v_decision_active                boolean;
    v_decision_deleted_at            timestamptz;

    v_status_code                    text;
    v_status_active                  boolean;
    v_status_deleted_at              timestamptz;

    v_location_name                  text;
    v_generated_business_id          text;
BEGIN
    --------------------------------------------------------------------------
    -- Normalize input
    --------------------------------------------------------------------------

    NEW.variety_name := NULLIF(btrim(NEW.variety_name), '');

    NEW.witness_variety_custom :=
        CASE
            WHEN NEW.witness_variety_custom IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.witness_variety_custom), '')
        END;

    NEW.remarks :=
        CASE
            WHEN NEW.remarks IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.remarks), '')
        END;

    NEW.installation_method := upper(btrim(NEW.installation_method));

    IF NEW.variety_name IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial validation failed: variety name is required.';
    END IF;

    --------------------------------------------------------------------------
    -- Default new trials to PENDING_APPROVAL
    --------------------------------------------------------------------------

    IF NEW.status_id IS NULL THEN
        SELECT ts.id
        INTO NEW.status_id
        FROM public.trial_statuses ts
        WHERE ts.code::text = 'PENDING_APPROVAL'
          AND ts.is_active = true
          AND ts.deleted_at IS NULL
        LIMIT 1;

        IF NEW.status_id IS NULL THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Trial validation failed: active PENDING_APPROVAL status was not found.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Validate crop
    --------------------------------------------------------------------------

    SELECT
        c.is_active,
        c.deleted_at
    INTO
        v_crop_active,
        v_crop_deleted_at
    FROM public.crops c
    WHERE c.id = NEW.crop_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Trial validation failed: crop %s does not exist.',
                    NEW.crop_id
                );
    END IF;

    IF v_crop_deleted_at IS NOT NULL
       OR v_crop_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial validation failed: the selected crop is unavailable.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate crop type and crop compatibility
    --------------------------------------------------------------------------

    SELECT
        ct.crop_id,
        ct.is_active,
        ct.deleted_at
    INTO
        v_crop_type_crop_id,
        v_crop_type_active,
        v_crop_type_deleted_at
    FROM public.crop_types ct
    WHERE ct.id = NEW.crop_type_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Trial validation failed: crop type %s does not exist.',
                    NEW.crop_type_id
                );
    END IF;

    IF v_crop_type_deleted_at IS NOT NULL
       OR v_crop_type_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial validation failed: the selected crop type is unavailable.';
    END IF;

    IF v_crop_type_crop_id IS DISTINCT FROM NEW.crop_id THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial validation failed: the selected crop type does not belong to the selected crop.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate product type
    --------------------------------------------------------------------------

    SELECT
        pt.is_active,
        pt.deleted_at
    INTO
        v_product_type_active,
        v_product_type_deleted_at
    FROM public.product_types pt
    WHERE pt.id = NEW.product_type_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Trial validation failed: product type %s does not exist.',
                    NEW.product_type_id
                );
    END IF;

    IF v_product_type_deleted_at IS NOT NULL
       OR v_product_type_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial validation failed: the selected product type is unavailable.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate trial type and capture code
    --------------------------------------------------------------------------

    SELECT
        tt.code::text,
        tt.is_active,
        tt.deleted_at
    INTO
        v_trial_type_code,
        v_trial_type_active,
        v_trial_type_deleted_at
    FROM public.trial_types tt
    WHERE tt.id = NEW.trial_type_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Trial validation failed: trial type %s does not exist.',
                    NEW.trial_type_id
                );
    END IF;

    IF v_trial_type_deleted_at IS NOT NULL
       OR v_trial_type_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial validation failed: the selected trial type is unavailable.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate season
    --------------------------------------------------------------------------

    SELECT
        s.is_active,
        s.deleted_at
    INTO
        v_season_active,
        v_season_deleted_at
    FROM public.seasons s
    WHERE s.id = NEW.season_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Trial validation failed: season %s does not exist.',
                    NEW.season_id
                );
    END IF;

    IF v_season_deleted_at IS NOT NULL
       OR v_season_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial validation failed: the selected season is unavailable.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate region
    --------------------------------------------------------------------------

    SELECT
        r.is_active,
        r.deleted_at
    INTO
        v_region_active,
        v_region_deleted_at
    FROM public.regions r
    WHERE r.id = NEW.region_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Trial validation failed: region %s does not exist.',
                    NEW.region_id
                );
    END IF;

    IF v_region_deleted_at IS NOT NULL
       OR v_region_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial validation failed: the selected region is unavailable.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate province and region compatibility
    --------------------------------------------------------------------------

    SELECT
        p.region_id,
        p.is_active,
        p.deleted_at
    INTO
        v_province_region_id,
        v_province_active,
        v_province_deleted_at
    FROM public.provinces p
    WHERE p.id = NEW.province_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Trial validation failed: province %s does not exist.',
                    NEW.province_id
                );
    END IF;

    IF v_province_deleted_at IS NOT NULL
       OR v_province_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial validation failed: the selected province is unavailable.';
    END IF;

    IF v_province_region_id IS DISTINCT FROM NEW.region_id THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial validation failed: the selected province does not belong to the selected region.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate grower/farm location
    --------------------------------------------------------------------------

    IF NEW.farm_id IS NOT NULL THEN
        SELECT
            g.name,
            g.is_active,
            g.deleted_at
        INTO
            v_grower_name,
            v_grower_active,
            v_grower_deleted_at
        FROM public.growers g
        WHERE g.id = NEW.grower_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE =
                        'Trial validation failed: the selected grower does not exist.';
        END IF;

        IF v_grower_deleted_at IS NOT NULL
           OR v_grower_active = false THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Trial validation failed: the selected grower is unavailable.';
        END IF;

        SELECT
            f.grower_id,
            f.province_id,
            f.is_active,
            f.deleted_at
        INTO
            v_farm_grower_id,
            v_farm_province_id,
            v_farm_active,
            v_farm_deleted_at
        FROM public.farms f
        WHERE f.id = NEW.farm_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE =
                        'Trial validation failed: the selected farm does not exist.';
        END IF;

        IF v_farm_deleted_at IS NOT NULL
           OR v_farm_active = false THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Trial validation failed: the selected farm is unavailable.';
        END IF;

        IF v_farm_grower_id IS DISTINCT FROM NEW.grower_id THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Trial validation failed: the selected farm does not belong to the selected grower.';
        END IF;

        IF v_farm_province_id IS DISTINCT FROM NEW.province_id THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Trial validation failed: the farm province does not match the selected province.';
        END IF;

        v_location_name := v_grower_name;
    END IF;

    --------------------------------------------------------------------------
    -- Validate experimental-station location
    --------------------------------------------------------------------------

    IF NEW.experimental_station_id IS NOT NULL THEN
        SELECT
            es.name,
            es.province_id,
            es.is_active,
            es.deleted_at
        INTO
            v_station_name,
            v_station_province_id,
            v_station_active,
            v_station_deleted_at
        FROM public.experimental_stations es
        WHERE es.id = NEW.experimental_station_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE =
                        'Trial validation failed: the selected experimental station does not exist.';
        END IF;

        IF v_station_deleted_at IS NOT NULL
           OR v_station_active = false THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Trial validation failed: the selected experimental station is unavailable.';
        END IF;

        IF v_station_province_id IS DISTINCT FROM NEW.province_id THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Trial validation failed: the experimental-station province does not match the selected province.';
        END IF;

        v_location_name := v_station_name;
    END IF;

    --------------------------------------------------------------------------
    -- Validate witness variety
    --------------------------------------------------------------------------

    IF NEW.witness_variety_id IS NOT NULL THEN
        SELECT
            wv.crop_id,
            wv.is_active,
            wv.deleted_at
        INTO
            v_witness_crop_id,
            v_witness_active,
            v_witness_deleted_at
        FROM public.witness_varieties wv
        WHERE wv.id = NEW.witness_variety_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE =
                        'Trial validation failed: the selected witness variety does not exist.';
        END IF;

        IF v_witness_deleted_at IS NOT NULL
           OR v_witness_active = false THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Trial validation failed: the selected witness variety is unavailable.';
        END IF;

        IF v_witness_crop_id IS DISTINCT FROM NEW.crop_id THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Trial validation failed: the witness variety does not belong to the selected crop.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Validate optional initial decision
    --------------------------------------------------------------------------

    IF NEW.initial_decision_type_id IS NOT NULL THEN
        SELECT
            dt.is_active,
            dt.deleted_at
        INTO
            v_decision_active,
            v_decision_deleted_at
        FROM public.decision_types dt
        WHERE dt.id = NEW.initial_decision_type_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE =
                        'Trial validation failed: the selected initial decision does not exist.';
        END IF;

        IF v_decision_deleted_at IS NOT NULL
           OR v_decision_active = false THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Trial validation failed: the selected initial decision is unavailable.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Validate workflow status
    --------------------------------------------------------------------------

    SELECT
        ts.code::text,
        ts.is_active,
        ts.deleted_at
    INTO
        v_status_code,
        v_status_active,
        v_status_deleted_at
    FROM public.trial_statuses ts
    WHERE ts.id = NEW.status_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE =
                    'Trial validation failed: the selected workflow status does not exist.';
    END IF;

    IF v_status_deleted_at IS NOT NULL
       OR v_status_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial validation failed: the selected workflow status is unavailable.';
    END IF;

    --------------------------------------------------------------------------
    -- New records must begin in PENDING_APPROVAL
    --------------------------------------------------------------------------

    IF TG_OP = 'INSERT'
       AND v_status_code <> 'PENDING_APPROVAL' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial validation failed: a new trial must begin with PENDING_APPROVAL status.';
    END IF;

    --------------------------------------------------------------------------
    -- Generate the immutable business identifier
    --------------------------------------------------------------------------

    v_generated_business_id :=
        public.fn_trial_business_component(NEW.variety_name)
        || '-'
        || public.fn_trial_business_component(v_location_name)
        || '-'
        || public.fn_trial_business_component(v_trial_type_code);

    IF TG_OP = 'INSERT' THEN
        NEW.business_id := v_generated_business_id;
    ELSIF NEW.business_id IS DISTINCT FROM OLD.business_id THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial validation failed: business_id is immutable after trial creation.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_prepare_trial() IS
'Validates Phase 1 installation relationships and generates the immutable variety-location-trial-type business identifier.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trials_prepare
    BEFORE INSERT OR UPDATE
    ON public.trials
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_prepare_trial();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trials_timestamps
    BEFORE INSERT OR UPDATE
    ON public.trials
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_trials_created_by
    BEFORE INSERT
    ON public.trials
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_trials_updated_by
    BEFORE UPDATE
    ON public.trials
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- MIGRATION VALIDATION
--------------------------------------------------------------------------------

DO
$$
DECLARE
    expected_column_count integer;
BEGIN
    --------------------------------------------------------------------------
    -- Verify table creation
    --------------------------------------------------------------------------

    IF to_regclass('public.trials') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0036_trials.sql failed: public.trials was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'trials'
      AND column_name IN
      (
          'id',
          'business_id',
          'variety_name',
          'crop_id',
          'crop_type_id',
          'witness_variety_id',
          'witness_variety_custom',
          'product_type_id',
          'trial_type_id',
          'season_id',
          'installation_method',
          'planting_date',
          'sowing_date',
          'density_per_hectare',
          'number_of_varieties',
          'region_id',
          'province_id',
          'grower_id',
          'farm_id',
          'experimental_station_id',
          'remarks',
          'initial_decision_type_id',
          'status_id',
          'submitted_at',
          'approved_at',
          'rejected_at',
          'corrections_requested_at',
          'completed_at',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF expected_column_count <> 33 THEN
        RAISE EXCEPTION
            'Migration 0036_trials.sql failed: trials has % of 33 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trials'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0036_trials.sql failed: primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify major foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trials'::regclass
          AND conname = 'fk_trials_crop'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0036_trials.sql failed: crop foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trials'::regclass
          AND conname = 'fk_trials_crop_type'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0036_trials.sql failed: crop-type foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trials'::regclass
          AND conname = 'fk_trials_status'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0036_trials.sql failed: status foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trials'::regclass
          AND conname = 'fk_trials_farm'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0036_trials.sql failed: farm foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trials'::regclass
          AND conname = 'fk_trials_experimental_station'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0036_trials.sql failed: experimental-station foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify business-ID function
    --------------------------------------------------------------------------

    IF to_regprocedure(
        'public.fn_trial_business_component(text)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0036_trials.sql failed: business-component function is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify preparation function and trigger
    --------------------------------------------------------------------------

    IF to_regprocedure(
        'public.trg_prepare_trial()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0036_trials.sql failed: trial preparation function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trials'::regclass
          AND tgname = 'trg_trials_prepare'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0036_trials.sql failed: trial preparation trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify generic triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trials'::regclass
          AND tgname = 'trg_trials_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0036_trials.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trials'::regclass
          AND tgname = 'trg_trials_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0036_trials.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trials'::regclass
          AND tgname = 'trg_trials_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0036_trials.sql failed: updated_by trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify business-ID unique index
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_trials_business_id_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0036_trials.sql failed: unique business-ID index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify required default status
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM public.trial_statuses
        WHERE code::text = 'PENDING_APPROVAL'
          AND is_active = true
          AND deleted_at IS NULL
    ) THEN
        RAISE EXCEPTION
            'Migration 0036_trials.sql failed: active PENDING_APPROVAL status is missing.';
    END IF;
END;
$$;

COMMIT;
