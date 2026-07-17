/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0040_evaluations.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the evaluations table for Phase 2 of the agricultural trial lifecycle.
*
* An evaluation represents one field evaluation session performed for one trial.
*
* Supported evaluation categories are configured through evaluation_types:
*
*   • OBSERVATION
*   • TECHNICAL
*
* Business rules:
*
*   • Every evaluation belongs to exactly one trial.
*   • The parent trial must be active and approved.
*   • An evaluation may optionally focus on one trial variety.
*   • The selected trial variety must belong to the same trial.
*   • Evaluation type, growth stage, weather condition, recommendation, and
*     decision values must be active and not soft-deleted.
*   • Evaluation dates cannot occur before the trial installation date.
*   • Future evaluation dates are not permitted.
*   • Completed evaluations must include a completion timestamp.
*   • Draft evaluations cannot include a completion timestamp.
*   • Completed evaluations cannot be modified except for soft deletion.
*   • Physical deletion is prohibited.
*   • Detailed criterion results will be stored in evaluation_details.
*   • Evaluation images will be stored in evaluation_photos.
*   • RLS will be added in a later migration.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
*   • 0023_growth_stages.sql
*   • 0027_recommendation_types.sql
*   • 0028_decision_types.sql
*   • 0029_weather_conditions.sql
*   • 0030_trial_statuses.sql
*   • 0031_evaluation_types.sql
*   • 0036_trials.sql
*   • 0037_trial_varieties.sql
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
-- TABLE: evaluations
--------------------------------------------------------------------------------

CREATE TABLE public.evaluations
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                          uuid
                                PRIMARY KEY
                                DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Parent Trial and Optional Variety
    --------------------------------------------------------------------------

    trial_id                    uuid
                                NOT NULL,

    trial_variety_id            uuid,

    --------------------------------------------------------------------------
    -- Evaluation Classification
    --------------------------------------------------------------------------

    evaluation_type_id          uuid
                                NOT NULL,

    growth_stage_id             uuid,

    weather_condition_id        uuid,

    recommendation_type_id      uuid,

    decision_type_id            uuid,

    --------------------------------------------------------------------------
    -- Evaluation Identity
    --------------------------------------------------------------------------

    evaluation_number           integer
                                NOT NULL,

    evaluation_date             date
                                NOT NULL
                                DEFAULT CURRENT_DATE,

    title                       varchar(250),

    --------------------------------------------------------------------------
    -- Evaluation Context
    --------------------------------------------------------------------------

    evaluator_id                uuid,

    technical_expert_name       varchar(200),

    technical_expert_contact    varchar(150),

    location_notes              text,

    weather_notes               text,

    --------------------------------------------------------------------------
    -- Evaluation Summary
    --------------------------------------------------------------------------

    general_observations        text,

    plant_observations          text,

    fruit_observations          text,

    disease_observations        text,

    defect_observations         text,

    recommendation_notes        text,

    decision_notes              text,

    --------------------------------------------------------------------------
    -- Optional Measurements
    --------------------------------------------------------------------------

    temperature_celsius         numeric(5,2),

    humidity_percentage         numeric(5,2),

    brix_value                  numeric(6,2),

    average_fruit_weight_grams  numeric(12,3),

    --------------------------------------------------------------------------
    -- Workflow State
    --------------------------------------------------------------------------

    evaluation_status           varchar(30)
                                NOT NULL
                                DEFAULT 'DRAFT',

    completed_at                timestamptz,

    completed_by                uuid,

    --------------------------------------------------------------------------
    -- Display and State
    --------------------------------------------------------------------------

    is_active                   boolean
                                NOT NULL
                                DEFAULT true,

    --------------------------------------------------------------------------
    -- Audit and Soft Delete
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

    CONSTRAINT fk_evaluations_trial
        FOREIGN KEY (trial_id)
        REFERENCES public.trials(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_evaluations_trial_variety
        FOREIGN KEY (trial_variety_id)
        REFERENCES public.trial_varieties(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_evaluations_evaluation_type
        FOREIGN KEY (evaluation_type_id)
        REFERENCES public.evaluation_types(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_evaluations_growth_stage
        FOREIGN KEY (growth_stage_id)
        REFERENCES public.growth_stages(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_evaluations_weather_condition
        FOREIGN KEY (weather_condition_id)
        REFERENCES public.weather_conditions(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_evaluations_recommendation_type
        FOREIGN KEY (recommendation_type_id)
        REFERENCES public.recommendation_types(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_evaluations_decision_type
        FOREIGN KEY (decision_type_id)
        REFERENCES public.decision_types(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_evaluations_evaluator
        FOREIGN KEY (evaluator_id)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_evaluations_completed_by
        FOREIGN KEY (completed_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_evaluations_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_evaluations_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_evaluations_number
        CHECK
        (
            evaluation_number > 0
        ),

    CONSTRAINT chk_evaluations_date
        CHECK
        (
            evaluation_date <= CURRENT_DATE + 1
        ),

    CONSTRAINT chk_evaluations_title
        CHECK
        (
            title IS NULL
            OR
            (
                length(btrim(title)) > 0
                AND char_length(btrim(title)) <= 250
            )
        ),

    CONSTRAINT chk_evaluations_technical_expert_name
        CHECK
        (
            technical_expert_name IS NULL
            OR
            (
                length(btrim(technical_expert_name)) > 0
                AND char_length(btrim(technical_expert_name)) <= 200
            )
        ),

    CONSTRAINT chk_evaluations_technical_expert_contact
        CHECK
        (
            technical_expert_contact IS NULL
            OR
            (
                length(btrim(technical_expert_contact)) > 0
                AND char_length(btrim(technical_expert_contact)) <= 150
            )
        ),

    CONSTRAINT chk_evaluations_location_notes
        CHECK
        (
            location_notes IS NULL
            OR char_length(btrim(location_notes)) BETWEEN 1 AND 5000
        ),

    CONSTRAINT chk_evaluations_weather_notes
        CHECK
        (
            weather_notes IS NULL
            OR char_length(btrim(weather_notes)) BETWEEN 1 AND 5000
        ),

    CONSTRAINT chk_evaluations_general_observations
        CHECK
        (
            general_observations IS NULL
            OR char_length(btrim(general_observations)) BETWEEN 1 AND 10000
        ),

    CONSTRAINT chk_evaluations_plant_observations
        CHECK
        (
            plant_observations IS NULL
            OR char_length(btrim(plant_observations)) BETWEEN 1 AND 10000
        ),

    CONSTRAINT chk_evaluations_fruit_observations
        CHECK
        (
            fruit_observations IS NULL
            OR char_length(btrim(fruit_observations)) BETWEEN 1 AND 10000
        ),

    CONSTRAINT chk_evaluations_disease_observations
        CHECK
        (
            disease_observations IS NULL
            OR char_length(btrim(disease_observations)) BETWEEN 1 AND 10000
        ),

    CONSTRAINT chk_evaluations_defect_observations
        CHECK
        (
            defect_observations IS NULL
            OR char_length(btrim(defect_observations)) BETWEEN 1 AND 10000
        ),

    CONSTRAINT chk_evaluations_recommendation_notes
        CHECK
        (
            recommendation_notes IS NULL
            OR char_length(btrim(recommendation_notes)) BETWEEN 1 AND 10000
        ),

    CONSTRAINT chk_evaluations_decision_notes
        CHECK
        (
            decision_notes IS NULL
            OR char_length(btrim(decision_notes)) BETWEEN 1 AND 10000
        ),

    CONSTRAINT chk_evaluations_temperature
        CHECK
        (
            temperature_celsius IS NULL
            OR temperature_celsius BETWEEN -50 AND 80
        ),

    CONSTRAINT chk_evaluations_humidity
        CHECK
        (
            humidity_percentage IS NULL
            OR humidity_percentage BETWEEN 0 AND 100
        ),

    CONSTRAINT chk_evaluations_brix
        CHECK
        (
            brix_value IS NULL
            OR brix_value BETWEEN 0 AND 100
        ),

    CONSTRAINT chk_evaluations_average_weight
        CHECK
        (
            average_fruit_weight_grams IS NULL
            OR average_fruit_weight_grams >= 0
        ),

    CONSTRAINT chk_evaluations_status
        CHECK
        (
            evaluation_status IN
            (
                'DRAFT',
                'COMPLETED'
            )
        ),

    CONSTRAINT chk_evaluations_completion_state
        CHECK
        (
            (
                evaluation_status = 'DRAFT'
                AND completed_at IS NULL
                AND completed_by IS NULL
            )
            OR
            (
                evaluation_status = 'COMPLETED'
                AND completed_at IS NOT NULL
            )
        ),

    CONSTRAINT chk_evaluations_completed_at
        CHECK
        (
            completed_at IS NULL
            OR completed_at <= timezone('UTC', now()) + interval '1 day'
        ),

    CONSTRAINT chk_evaluations_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_evaluations_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        ),

    CONSTRAINT chk_evaluations_active_deleted
        CHECK
        (
            deleted_at IS NULL
            OR is_active = false
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.evaluations IS
'Phase 2 field and technical evaluation sessions performed for approved agricultural trials.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.evaluations.id IS
'Internal UUID primary key of the evaluation session.';

COMMENT ON COLUMN public.evaluations.trial_id IS
'Approved parent agricultural trial being evaluated.';

COMMENT ON COLUMN public.evaluations.trial_variety_id IS
'Optional candidate or witness variety on which the evaluation session is focused.';

COMMENT ON COLUMN public.evaluations.evaluation_type_id IS
'Configured evaluation type, such as observation or technical evaluation.';

COMMENT ON COLUMN public.evaluations.growth_stage_id IS
'Optional crop growth stage observed during the evaluation.';

COMMENT ON COLUMN public.evaluations.weather_condition_id IS
'Optional configured weather condition during the evaluation.';

COMMENT ON COLUMN public.evaluations.recommendation_type_id IS
'Optional configured recommendation resulting from the evaluation.';

COMMENT ON COLUMN public.evaluations.decision_type_id IS
'Optional configured decision resulting from the evaluation.';

COMMENT ON COLUMN public.evaluations.evaluation_number IS
'Sequential evaluation number within the trial.';

COMMENT ON COLUMN public.evaluations.evaluation_date IS
'Calendar date on which the field evaluation was performed.';

COMMENT ON COLUMN public.evaluations.title IS
'Optional human-readable title for the evaluation session.';

COMMENT ON COLUMN public.evaluations.evaluator_id IS
'Supabase Auth user responsible for performing or recording the evaluation.';

COMMENT ON COLUMN public.evaluations.technical_expert_name IS
'Optional agronomist or technical expert participating in the evaluation.';

COMMENT ON COLUMN public.evaluations.technical_expert_contact IS
'Optional contact information for the participating technical expert.';

COMMENT ON COLUMN public.evaluations.location_notes IS
'Optional notes describing the exact field or plot evaluation location.';

COMMENT ON COLUMN public.evaluations.weather_notes IS
'Optional free-text weather observations.';

COMMENT ON COLUMN public.evaluations.general_observations IS
'General evaluation observations and field notes.';

COMMENT ON COLUMN public.evaluations.plant_observations IS
'Summary observations about plant vigor, balance, uniformity, and growth.';

COMMENT ON COLUMN public.evaluations.fruit_observations IS
'Summary observations about fruit quality, shape, color, firmness, setting, and taste.';

COMMENT ON COLUMN public.evaluations.disease_observations IS
'Summary observations about disease incidence or tolerance.';

COMMENT ON COLUMN public.evaluations.defect_observations IS
'Summary observations about fruit or plant defects.';

COMMENT ON COLUMN public.evaluations.recommendation_notes IS
'Optional explanation supporting the configured recommendation.';

COMMENT ON COLUMN public.evaluations.decision_notes IS
'Optional explanation supporting the configured evaluation decision.';

COMMENT ON COLUMN public.evaluations.temperature_celsius IS
'Optional measured field temperature in degrees Celsius.';

COMMENT ON COLUMN public.evaluations.humidity_percentage IS
'Optional measured relative humidity percentage.';

COMMENT ON COLUMN public.evaluations.brix_value IS
'Optional summary BRIX measurement for the evaluated fruit.';

COMMENT ON COLUMN public.evaluations.average_fruit_weight_grams IS
'Optional summary average fruit weight in grams.';

COMMENT ON COLUMN public.evaluations.evaluation_status IS
'Internal evaluation state. Allowed values are DRAFT and COMPLETED.';

COMMENT ON COLUMN public.evaluations.completed_at IS
'UTC timestamp when the evaluation was completed.';

COMMENT ON COLUMN public.evaluations.completed_by IS
'Supabase Auth user who completed the evaluation.';

COMMENT ON COLUMN public.evaluations.is_active IS
'Indicates whether the evaluation is available in active trial views and reports.';

COMMENT ON COLUMN public.evaluations.created_at IS
'UTC timestamp when the evaluation record was created.';

COMMENT ON COLUMN public.evaluations.updated_at IS
'UTC timestamp when the evaluation record was most recently updated.';

COMMENT ON COLUMN public.evaluations.created_by IS
'Supabase Auth user who created the evaluation record.';

COMMENT ON COLUMN public.evaluations.updated_by IS
'Supabase Auth user who most recently updated the evaluation record.';

COMMENT ON COLUMN public.evaluations.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the evaluation has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_evaluations_trial_number
    ON public.evaluations
    (
        trial_id,
        evaluation_number
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- RELATIONSHIP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluations_trial_id
    ON public.evaluations (trial_id);

CREATE INDEX idx_evaluations_trial_variety_id
    ON public.evaluations (trial_variety_id)
    WHERE trial_variety_id IS NOT NULL;

CREATE INDEX idx_evaluations_evaluation_type_id
    ON public.evaluations (evaluation_type_id);

CREATE INDEX idx_evaluations_growth_stage_id
    ON public.evaluations (growth_stage_id)
    WHERE growth_stage_id IS NOT NULL;

CREATE INDEX idx_evaluations_weather_condition_id
    ON public.evaluations (weather_condition_id)
    WHERE weather_condition_id IS NOT NULL;

CREATE INDEX idx_evaluations_recommendation_type_id
    ON public.evaluations (recommendation_type_id)
    WHERE recommendation_type_id IS NOT NULL;

CREATE INDEX idx_evaluations_decision_type_id
    ON public.evaluations (decision_type_id)
    WHERE decision_type_id IS NOT NULL;

CREATE INDEX idx_evaluations_evaluator_id
    ON public.evaluations (evaluator_id)
    WHERE evaluator_id IS NOT NULL;

--------------------------------------------------------------------------------
-- APPLICATION QUERY INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluations_trial_timeline
    ON public.evaluations
    (
        trial_id,
        evaluation_date DESC,
        evaluation_number DESC
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluations_trial_status
    ON public.evaluations
    (
        trial_id,
        evaluation_status,
        evaluation_date DESC
    )
    WHERE deleted_at IS NULL;

CREATE INDEX idx_evaluations_type_date
    ON public.evaluations
    (
        evaluation_type_id,
        evaluation_date DESC
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluations_drafts
    ON public.evaluations
    (
        evaluator_id,
        updated_at DESC
    )
    WHERE evaluation_status = 'DRAFT'
      AND is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluations_completed
    ON public.evaluations
    (
        completed_at DESC,
        trial_id
    )
    WHERE evaluation_status = 'COMPLETED'
      AND is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluations_deleted_at
    ON public.evaluations (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- AUDIT INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluations_created_by
    ON public.evaluations (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_evaluations_updated_by
    ON public.evaluations (updated_by)
    WHERE updated_by IS NOT NULL;

CREATE INDEX idx_evaluations_completed_by
    ON public.evaluations (completed_by)
    WHERE completed_by IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluations_title_trgm
    ON public.evaluations
    USING gin
    (
        title gin_trgm_ops
    )
    WHERE title IS NOT NULL
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluations_general_observations_trgm
    ON public.evaluations
    USING gin
    (
        general_observations gin_trgm_ops
    )
    WHERE general_observations IS NOT NULL
      AND deleted_at IS NULL;

--------------------------------------------------------------------------------
-- FUNCTION: NEXT EVALUATION NUMBER
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_next_evaluation_number(
    p_trial_id uuid
)
RETURNS integer
LANGUAGE sql
STABLE
SECURITY INVOKER
SET search_path = public
AS
$$
    SELECT COALESCE(MAX(e.evaluation_number), 0) + 1
    FROM public.evaluations e
    WHERE e.trial_id = p_trial_id
      AND e.deleted_at IS NULL;
$$;

COMMENT ON FUNCTION public.fn_next_evaluation_number(uuid) IS
'Returns the next sequential evaluation number for a trial.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_evaluation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_trial_deleted_at              timestamptz;
    v_trial_status_code             text;
    v_trial_installation_date       date;

    v_variety_trial_id              uuid;
    v_variety_is_active             boolean;
    v_variety_deleted_at            timestamptz;

    v_lookup_active                 boolean;
    v_lookup_deleted_at             timestamptz;
BEGIN
    --------------------------------------------------------------------------
    -- Normalize evaluation state
    --------------------------------------------------------------------------

    NEW.evaluation_status :=
        upper(NULLIF(btrim(NEW.evaluation_status), ''));

    --------------------------------------------------------------------------
    -- Normalize optional short text
    --------------------------------------------------------------------------

    NEW.title :=
        CASE
            WHEN NEW.title IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.title), '')
        END;

    NEW.technical_expert_name :=
        CASE
            WHEN NEW.technical_expert_name IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.technical_expert_name), '')
        END;

    NEW.technical_expert_contact :=
        CASE
            WHEN NEW.technical_expert_contact IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.technical_expert_contact), '')
        END;

    --------------------------------------------------------------------------
    -- Normalize optional long text
    --------------------------------------------------------------------------

    NEW.location_notes :=
        CASE
            WHEN NEW.location_notes IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.location_notes), '')
        END;

    NEW.weather_notes :=
        CASE
            WHEN NEW.weather_notes IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.weather_notes), '')
        END;

    NEW.general_observations :=
        CASE
            WHEN NEW.general_observations IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.general_observations), '')
        END;

    NEW.plant_observations :=
        CASE
            WHEN NEW.plant_observations IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.plant_observations), '')
        END;

    NEW.fruit_observations :=
        CASE
            WHEN NEW.fruit_observations IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.fruit_observations), '')
        END;

    NEW.disease_observations :=
        CASE
            WHEN NEW.disease_observations IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.disease_observations), '')
        END;

    NEW.defect_observations :=
        CASE
            WHEN NEW.defect_observations IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.defect_observations), '')
        END;

    NEW.recommendation_notes :=
        CASE
            WHEN NEW.recommendation_notes IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.recommendation_notes), '')
        END;

    NEW.decision_notes :=
        CASE
            WHEN NEW.decision_notes IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.decision_notes), '')
        END;

    --------------------------------------------------------------------------
    -- Default actor and evaluation number
    --------------------------------------------------------------------------

    NEW.evaluator_id :=
        COALESCE(
            NEW.evaluator_id,
            auth.uid(),
            NEW.created_by
        );

    IF NEW.evaluation_number IS NULL
       OR NEW.evaluation_number <= 0 THEN
        NEW.evaluation_number :=
            public.fn_next_evaluation_number(NEW.trial_id);
    END IF;

    --------------------------------------------------------------------------
    -- Validate parent trial and retrieve installation date
    --------------------------------------------------------------------------

    SELECT
        t.deleted_at,
        upper(btrim(ts.code)),
        CASE
            WHEN t.installation_method = 'PLANT'
                THEN t.planting_date
            WHEN t.installation_method = 'SEED'
                THEN t.sowing_date
            ELSE COALESCE(t.planting_date, t.sowing_date)
        END
    INTO
        v_trial_deleted_at,
        v_trial_status_code,
        v_trial_installation_date
    FROM public.trials t
    JOIN public.trial_statuses ts
        ON ts.id = t.status_id
    WHERE t.id = NEW.trial_id
    FOR UPDATE OF t;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Evaluation validation failed: trial %s does not exist.',
                    NEW.trial_id
                );
    END IF;

    IF v_trial_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation validation failed: evaluations cannot be attached to a soft-deleted trial.';
    END IF;

    IF v_trial_status_code <> 'APPROVED' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = format(
                    'Evaluation validation failed: trial must be APPROVED before evaluation. Current status is %s.',
                    v_trial_status_code
                );
    END IF;

    IF v_trial_installation_date IS NOT NULL
       AND NEW.evaluation_date < v_trial_installation_date THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation validation failed: evaluation date cannot be earlier than the trial installation date.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate optional trial variety
    --------------------------------------------------------------------------

    IF NEW.trial_variety_id IS NOT NULL THEN
        SELECT
            tv.trial_id,
            tv.is_active,
            tv.deleted_at
        INTO
            v_variety_trial_id,
            v_variety_is_active,
            v_variety_deleted_at
        FROM public.trial_varieties tv
        WHERE tv.id = NEW.trial_variety_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE =
                        'Evaluation validation failed: selected trial variety does not exist.';
        END IF;

        IF v_variety_trial_id IS DISTINCT FROM NEW.trial_id THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation validation failed: selected trial variety belongs to another trial.';
        END IF;

        IF v_variety_is_active = false
           OR v_variety_deleted_at IS NOT NULL THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation validation failed: selected trial variety is unavailable.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Validate mandatory evaluation type
    --------------------------------------------------------------------------

    SELECT
        et.is_active,
        et.deleted_at
    INTO
        v_lookup_active,
        v_lookup_deleted_at
    FROM public.evaluation_types et
    WHERE et.id = NEW.evaluation_type_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE =
                    'Evaluation validation failed: evaluation type does not exist.';
    END IF;

    IF v_lookup_active = false
       OR v_lookup_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation validation failed: evaluation type is unavailable.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate optional growth stage
    --------------------------------------------------------------------------

    IF NEW.growth_stage_id IS NOT NULL THEN
        SELECT
            gs.is_active,
            gs.deleted_at
        INTO
            v_lookup_active,
            v_lookup_deleted_at
        FROM public.growth_stages gs
        WHERE gs.id = NEW.growth_stage_id;

        IF NOT FOUND
           OR v_lookup_active = false
           OR v_lookup_deleted_at IS NOT NULL THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation validation failed: selected growth stage is unavailable.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Validate optional weather condition
    --------------------------------------------------------------------------

    IF NEW.weather_condition_id IS NOT NULL THEN
        SELECT
            wc.is_active,
            wc.deleted_at
        INTO
            v_lookup_active,
            v_lookup_deleted_at
        FROM public.weather_conditions wc
        WHERE wc.id = NEW.weather_condition_id;

        IF NOT FOUND
           OR v_lookup_active = false
           OR v_lookup_deleted_at IS NOT NULL THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation validation failed: selected weather condition is unavailable.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Validate optional recommendation
    --------------------------------------------------------------------------

    IF NEW.recommendation_type_id IS NOT NULL THEN
        SELECT
            rt.is_active,
            rt.deleted_at
        INTO
            v_lookup_active,
            v_lookup_deleted_at
        FROM public.recommendation_types rt
        WHERE rt.id = NEW.recommendation_type_id;

        IF NOT FOUND
           OR v_lookup_active = false
           OR v_lookup_deleted_at IS NOT NULL THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation validation failed: selected recommendation type is unavailable.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Validate optional decision
    --------------------------------------------------------------------------

    IF NEW.decision_type_id IS NOT NULL THEN
        SELECT
            dt.is_active,
            dt.deleted_at
        INTO
            v_lookup_active,
            v_lookup_deleted_at
        FROM public.decision_types dt
        WHERE dt.id = NEW.decision_type_id;

        IF NOT FOUND
           OR v_lookup_active = false
           OR v_lookup_deleted_at IS NOT NULL THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation validation failed: selected decision type is unavailable.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Completion state
    --------------------------------------------------------------------------

    IF NEW.evaluation_status = 'COMPLETED' THEN
        NEW.completed_at :=
            COALESCE(
                NEW.completed_at,
                timezone('UTC', now())
            );

        NEW.completed_by :=
            COALESCE(
                NEW.completed_by,
                auth.uid(),
                NEW.updated_by,
                NEW.evaluator_id,
                NEW.created_by
            );
    ELSE
        NEW.completed_at := NULL;
        NEW.completed_by := NULL;
    END IF;

    --------------------------------------------------------------------------
    -- Soft deletion state
    --------------------------------------------------------------------------

    IF NEW.deleted_at IS NOT NULL THEN
        NEW.is_active := false;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_evaluation() IS
'Validates approved trial ownership, variety ownership, lookup availability, evaluation dates, completion state, text normalization, and soft deletion.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_evaluations_validate
    BEFORE INSERT OR UPDATE OF
        trial_id,
        trial_variety_id,
        evaluation_type_id,
        growth_stage_id,
        weather_condition_id,
        recommendation_type_id,
        decision_type_id,
        evaluation_number,
        evaluation_date,
        title,
        evaluator_id,
        technical_expert_name,
        technical_expert_contact,
        location_notes,
        weather_notes,
        general_observations,
        plant_observations,
        fruit_observations,
        disease_observations,
        defect_observations,
        recommendation_notes,
        decision_notes,
        temperature_celsius,
        humidity_percentage,
        brix_value,
        average_fruit_weight_grams,
        evaluation_status,
        completed_at,
        completed_by,
        is_active,
        deleted_at
    ON public.evaluations
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_evaluation();

--------------------------------------------------------------------------------
-- COMPLETED EVALUATION PROTECTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_protect_completed_evaluation()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
BEGIN
    IF OLD.evaluation_status = 'COMPLETED'
       AND
       (
           NEW.trial_id IS DISTINCT FROM OLD.trial_id
           OR NEW.trial_variety_id IS DISTINCT FROM OLD.trial_variety_id
           OR NEW.evaluation_type_id IS DISTINCT FROM OLD.evaluation_type_id
           OR NEW.growth_stage_id IS DISTINCT FROM OLD.growth_stage_id
           OR NEW.weather_condition_id IS DISTINCT FROM OLD.weather_condition_id
           OR NEW.recommendation_type_id IS DISTINCT FROM OLD.recommendation_type_id
           OR NEW.decision_type_id IS DISTINCT FROM OLD.decision_type_id
           OR NEW.evaluation_number IS DISTINCT FROM OLD.evaluation_number
           OR NEW.evaluation_date IS DISTINCT FROM OLD.evaluation_date
           OR NEW.evaluator_id IS DISTINCT FROM OLD.evaluator_id
           OR NEW.general_observations IS DISTINCT FROM OLD.general_observations
           OR NEW.plant_observations IS DISTINCT FROM OLD.plant_observations
           OR NEW.fruit_observations IS DISTINCT FROM OLD.fruit_observations
           OR NEW.disease_observations IS DISTINCT FROM OLD.disease_observations
           OR NEW.defect_observations IS DISTINCT FROM OLD.defect_observations
           OR NEW.temperature_celsius IS DISTINCT FROM OLD.temperature_celsius
           OR NEW.humidity_percentage IS DISTINCT FROM OLD.humidity_percentage
           OR NEW.brix_value IS DISTINCT FROM OLD.brix_value
           OR NEW.average_fruit_weight_grams IS DISTINCT FROM OLD.average_fruit_weight_grams
           OR NEW.evaluation_status IS DISTINCT FROM OLD.evaluation_status
           OR NEW.completed_at IS DISTINCT FROM OLD.completed_at
           OR NEW.completed_by IS DISTINCT FROM OLD.completed_by
       ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Completed evaluation protection failed: completed evaluation data is immutable.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_protect_completed_evaluation() IS
'Prevents modification or reopening of completed evaluation data while permitting audit metadata and soft deletion.';

CREATE TRIGGER trg_evaluations_protect_completed
    BEFORE UPDATE
    ON public.evaluations
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_protect_completed_evaluation();

--------------------------------------------------------------------------------
-- PHYSICAL DELETE PROTECTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_prevent_evaluation_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
BEGIN
    RAISE EXCEPTION
        USING
            ERRCODE = '23514',
            MESSAGE =
                'Evaluation protection failed: evaluations cannot be physically deleted. Use soft deletion.';

    RETURN OLD;
END;
$$;

COMMENT ON FUNCTION public.trg_prevent_evaluation_delete() IS
'Prevents physical deletion of evaluation records.';

CREATE TRIGGER trg_evaluations_prevent_delete
    BEFORE DELETE
    ON public.evaluations
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_prevent_evaluation_delete();

--------------------------------------------------------------------------------
-- GENERIC AUDIT TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_evaluations_timestamps
    BEFORE INSERT OR UPDATE
    ON public.evaluations
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_evaluations_created_by
    BEFORE INSERT
    ON public.evaluations
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_evaluations_updated_by
    BEFORE UPDATE
    ON public.evaluations
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- MIGRATION VALIDATION
--------------------------------------------------------------------------------

DO
$$
DECLARE
    v_expected_column_count integer;
BEGIN
    IF to_regclass('public.evaluations') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0040_evaluations.sql failed: public.evaluations was not created.';
    END IF;

    SELECT count(*)
    INTO v_expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'evaluations'
      AND column_name IN
      (
          'id',
          'trial_id',
          'trial_variety_id',
          'evaluation_type_id',
          'growth_stage_id',
          'weather_condition_id',
          'recommendation_type_id',
          'decision_type_id',
          'evaluation_number',
          'evaluation_date',
          'title',
          'evaluator_id',
          'technical_expert_name',
          'technical_expert_contact',
          'location_notes',
          'weather_notes',
          'general_observations',
          'plant_observations',
          'fruit_observations',
          'disease_observations',
          'defect_observations',
          'recommendation_notes',
          'decision_notes',
          'temperature_celsius',
          'humidity_percentage',
          'brix_value',
          'average_fruit_weight_grams',
          'evaluation_status',
          'completed_at',
          'completed_by',
          'is_active',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF v_expected_column_count <> 36 THEN
        RAISE EXCEPTION
            'Migration 0040_evaluations.sql failed: evaluations has % of 36 required columns.',
            v_expected_column_count;
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluations'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0040_evaluations.sql failed: primary key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluations'::regclass
          AND conname = 'fk_evaluations_trial'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0040_evaluations.sql failed: trial foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluations'::regclass
          AND conname = 'fk_evaluations_evaluation_type'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0040_evaluations.sql failed: evaluation-type foreign key is missing.';
    END IF;

    IF to_regclass('public.uq_evaluations_trial_number') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0040_evaluations.sql failed: trial/evaluation-number unique index is missing.';
    END IF;

    IF to_regprocedure(
        'public.fn_next_evaluation_number(uuid)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0040_evaluations.sql failed: next-number function is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_validate_evaluation()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0040_evaluations.sql failed: validation function is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_protect_completed_evaluation()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0040_evaluations.sql failed: completed-evaluation protection function is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_prevent_evaluation_delete()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0040_evaluations.sql failed: delete-protection function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluations'::regclass
          AND tgname = 'trg_evaluations_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0040_evaluations.sql failed: validation trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluations'::regclass
          AND tgname = 'trg_evaluations_protect_completed'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0040_evaluations.sql failed: completed-evaluation protection trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluations'::regclass
          AND tgname = 'trg_evaluations_prevent_delete'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0040_evaluations.sql failed: physical-delete protection trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluations'::regclass
          AND tgname = 'trg_evaluations_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0040_evaluations.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluations'::regclass
          AND tgname = 'trg_evaluations_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0040_evaluations.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluations'::regclass
          AND tgname = 'trg_evaluations_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0040_evaluations.sql failed: updated_by trigger is missing.';
    END IF;
END;
$$;

COMMIT;
