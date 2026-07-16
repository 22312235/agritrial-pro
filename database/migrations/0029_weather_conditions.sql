/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0029_weather_conditions.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the weather_conditions configuration table.
*
* Weather conditions represent observable field conditions recorded during
* trial visits, observations, and technical evaluations.
*
* Examples:
*
*   • Sunny
*   • Partly Cloudy
*   • Cloudy
*   • Rainy
*   • Windy
*   • Hot
*   • Cold
*   • Humid
*   • Dry
*
* Frozen architectural rules:
*
*   • Weather conditions are configurable master data.
*   • Weather conditions are managed dynamically by the Manager.
*   • Flutter loads weather conditions dynamically from the database.
*   • Exactly one "Other" weather condition is included.
*   • Selecting "Other" requires a custom user-entered value.
*   • The custom-value requirement will be enforced in evaluations.
*   • Weather conditions support soft deletion and historical references.
*   • Row Level Security policies are intentionally deferred.
*
* General configurable-value rule:
*
*   • When a predefined value does not exist, the user may select "Other".
*   • The related evaluation record must require a custom text value.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0003_domains.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
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
-- TABLE: weather_conditions
--------------------------------------------------------------------------------

CREATE TABLE public.weather_conditions
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                  uuid
                        PRIMARY KEY
                        DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Weather Condition Information
    --------------------------------------------------------------------------

    code                long_code
                        NOT NULL,

    name                varchar(150)
                        NOT NULL,

    description         description_text,

    --------------------------------------------------------------------------
    -- Custom-Value Support
    --------------------------------------------------------------------------

    is_other            boolean
                        NOT NULL
                        DEFAULT false,

    allows_custom_value boolean
                        NOT NULL
                        DEFAULT false,

    --------------------------------------------------------------------------
    -- Configuration State
    --------------------------------------------------------------------------

    is_active           boolean
                        NOT NULL
                        DEFAULT true,

    display_order       integer
                        NOT NULL
                        DEFAULT 0,

    --------------------------------------------------------------------------
    -- Audit and Soft-Delete Columns
    --------------------------------------------------------------------------

    created_at          timestamptz
                        NOT NULL
                        DEFAULT timezone('UTC', now()),

    updated_at          timestamptz
                        NOT NULL
                        DEFAULT timezone('UTC', now()),

    created_by          uuid,

    updated_by          uuid,

    deleted_at          timestamptz,

    --------------------------------------------------------------------------
    -- Foreign Keys
    --------------------------------------------------------------------------

    CONSTRAINT fk_weather_conditions_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_weather_conditions_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_weather_conditions_code_not_blank
        CHECK
        (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_weather_conditions_name
        CHECK
        (
            char_length(btrim(name)) BETWEEN 1 AND 150
        ),

    CONSTRAINT chk_weather_conditions_other_custom_value
        CHECK
        (
            is_other = false
            OR allows_custom_value = true
        ),

    CONSTRAINT chk_weather_conditions_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_weather_conditions_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_weather_conditions_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.weather_conditions IS
'Configurable weather conditions recorded during field observations and technical evaluations. Includes one Other option for custom user-entered values.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.weather_conditions.id IS
'Internal UUID primary key of the weather condition.';

COMMENT ON COLUMN public.weather_conditions.code IS
'Unique Agrimatco business code identifying the weather condition. Stored in uppercase by trigger.';

COMMENT ON COLUMN public.weather_conditions.name IS
'Weather-condition display name shown in Flutter evaluation and observation forms.';

COMMENT ON COLUMN public.weather_conditions.description IS
'Optional description explaining the weather condition.';

COMMENT ON COLUMN public.weather_conditions.is_other IS
'Indicates that this record represents the Other weather-condition option.';

COMMENT ON COLUMN public.weather_conditions.allows_custom_value IS
'Indicates that selecting this weather condition allows or requires a custom user-entered value.';

COMMENT ON COLUMN public.weather_conditions.is_active IS
'Indicates whether the weather condition is available for new observations and evaluations.';

COMMENT ON COLUMN public.weather_conditions.display_order IS
'Controls the ordering of weather conditions in Flutter dropdowns and configuration screens.';

COMMENT ON COLUMN public.weather_conditions.created_at IS
'UTC timestamp when the weather-condition record was created.';

COMMENT ON COLUMN public.weather_conditions.updated_at IS
'UTC timestamp when the weather-condition record was most recently updated.';

COMMENT ON COLUMN public.weather_conditions.created_by IS
'Supabase Auth user who created the weather-condition record.';

COMMENT ON COLUMN public.weather_conditions.updated_by IS
'Supabase Auth user who most recently updated the weather-condition record.';

COMMENT ON COLUMN public.weather_conditions.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the weather condition has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_weather_conditions_code_ci
    ON public.weather_conditions
    (
        lower(btrim(code::text))
    );

CREATE UNIQUE INDEX uq_weather_conditions_name_normalized
    ON public.weather_conditions
    (
        public.fn_normalize_text(name)
    );

CREATE UNIQUE INDEX uq_weather_conditions_single_other
    ON public.weather_conditions (is_other)
    WHERE is_other = true;

--------------------------------------------------------------------------------
-- FILTERING AND SORTING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_weather_conditions_active_display
    ON public.weather_conditions
    (
        display_order,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_weather_conditions_is_active
    ON public.weather_conditions (is_active)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_weather_conditions_custom_values
    ON public.weather_conditions (allows_custom_value)
    WHERE allows_custom_value = true
      AND deleted_at IS NULL;

CREATE INDEX idx_weather_conditions_deleted_at
    ON public.weather_conditions (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEX
--------------------------------------------------------------------------------

CREATE INDEX idx_weather_conditions_name_trgm
    ON public.weather_conditions
    USING gin
    (
        name gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_weather_conditions_created_by
    ON public.weather_conditions (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_weather_conditions_updated_by
    ON public.weather_conditions (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_weather_condition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
BEGIN
    --------------------------------------------------------------------------
    -- Normalize the Other option
    --------------------------------------------------------------------------

    IF NEW.is_other = true THEN
        NEW.name := 'Other';
        NEW.allows_custom_value := true;
    END IF;

    --------------------------------------------------------------------------
    -- Reserve the name Other
    --------------------------------------------------------------------------

    IF public.fn_normalize_text(NEW.name) = 'other'
       AND NEW.is_other = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Weather condition validation failed: the name "Other" requires is_other = true.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_weather_condition() IS
'Ensures that the reserved Other weather condition is correctly configured to support a custom user-entered value.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_weather_conditions_validate
    BEFORE INSERT OR UPDATE OF
        name,
        is_other,
        allows_custom_value
    ON public.weather_conditions
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_weather_condition();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_weather_conditions_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.weather_conditions
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

CREATE TRIGGER trg_weather_conditions_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.weather_conditions
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

CREATE TRIGGER trg_weather_conditions_timestamps
    BEFORE INSERT OR UPDATE
    ON public.weather_conditions
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_weather_conditions_created_by
    BEFORE INSERT
    ON public.weather_conditions
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_weather_conditions_updated_by
    BEFORE UPDATE
    ON public.weather_conditions
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- SEED DATA
--------------------------------------------------------------------------------

INSERT INTO public.weather_conditions
(
    code,
    name,
    description,
    is_other,
    allows_custom_value,
    display_order
)
VALUES
    (
        'SUNNY',
        'Sunny',
        'Clear sky with direct sunlight.',
        false,
        false,
        10
    ),
    (
        'PARTLY_CLOUDY',
        'Partly Cloudy',
        'Combination of clouds and visible sunlight.',
        false,
        false,
        20
    ),
    (
        'CLOUDY',
        'Cloudy',
        'Predominantly cloudy or overcast conditions.',
        false,
        false,
        30
    ),
    (
        'RAINY',
        'Rainy',
        'Rainfall occurring during or near the field visit.',
        false,
        false,
        40
    ),
    (
        'WINDY',
        'Windy',
        'Noticeable or strong wind during the field visit.',
        false,
        false,
        50
    ),
    (
        'HOT',
        'Hot',
        'High-temperature conditions affecting the trial environment.',
        false,
        false,
        60
    ),
    (
        'COLD',
        'Cold',
        'Low-temperature conditions affecting the trial environment.',
        false,
        false,
        70
    ),
    (
        'HUMID',
        'Humid',
        'High atmospheric humidity during the field visit.',
        false,
        false,
        80
    ),
    (
        'DRY',
        'Dry',
        'Dry atmospheric or field conditions.',
        false,
        false,
        90
    ),
    (
        'FOGGY',
        'Foggy',
        'Reduced visibility caused by fog or mist.',
        false,
        false,
        100
    ),
    (
        'STORMY',
        'Stormy',
        'Storm, thunderstorm, or severe weather conditions.',
        false,
        false,
        110
    ),
    (
        'OTHER',
        'Other',
        'Custom weather condition entered by the user.',
        true,
        true,
        999
    )
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- MIGRATION VALIDATION
--------------------------------------------------------------------------------

DO
$$
DECLARE
    expected_column_count integer;
    seeded_condition_count integer;
    other_count            integer;
BEGIN
    --------------------------------------------------------------------------
    -- Verify table creation
    --------------------------------------------------------------------------

    IF to_regclass('public.weather_conditions') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0029_weather_conditions.sql failed: public.weather_conditions was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'weather_conditions'
      AND column_name IN
      (
          'id',
          'code',
          'name',
          'description',
          'is_other',
          'allows_custom_value',
          'is_active',
          'display_order',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF expected_column_count <> 13 THEN
        RAISE EXCEPTION
            'Migration 0029_weather_conditions.sql failed: weather_conditions has % of 13 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.weather_conditions'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0029_weather_conditions.sql failed: primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify audit foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.weather_conditions'::regclass
          AND conname = 'fk_weather_conditions_created_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0029_weather_conditions.sql failed: created_by foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.weather_conditions'::regclass
          AND conname = 'fk_weather_conditions_updated_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0029_weather_conditions.sql failed: updated_by foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_weather_conditions_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0029_weather_conditions.sql failed: unique weather-condition code index is missing.';
    END IF;

    IF to_regclass('public.uq_weather_conditions_name_normalized') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0029_weather_conditions.sql failed: unique weather-condition name index is missing.';
    END IF;

    IF to_regclass('public.uq_weather_conditions_single_other') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0029_weather_conditions.sql failed: single-Other index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify validation function and trigger
    --------------------------------------------------------------------------

    IF to_regprocedure('public.trg_validate_weather_condition()') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0029_weather_conditions.sql failed: validation function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.weather_conditions'::regclass
          AND tgname = 'trg_weather_conditions_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0029_weather_conditions.sql failed: validation trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify generic triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.weather_conditions'::regclass
          AND tgname = 'trg_weather_conditions_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0029_weather_conditions.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.weather_conditions'::regclass
          AND tgname = 'trg_weather_conditions_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0029_weather_conditions.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.weather_conditions'::regclass
          AND tgname = 'trg_weather_conditions_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0029_weather_conditions.sql failed: updated_by trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify predefined weather conditions
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO seeded_condition_count
    FROM public.weather_conditions
    WHERE code::text IN
    (
        'SUNNY',
        'PARTLY_CLOUDY',
        'CLOUDY',
        'RAINY',
        'WINDY',
        'HOT',
        'COLD',
        'HUMID',
        'DRY',
        'FOGGY',
        'STORMY'
    )
      AND deleted_at IS NULL;

    IF seeded_condition_count <> 11 THEN
        RAISE EXCEPTION
            'Migration 0029_weather_conditions.sql failed: only % of 11 predefined weather conditions were inserted.',
            seeded_condition_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify exactly one valid Other option
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO other_count
    FROM public.weather_conditions
    WHERE is_other = true
      AND allows_custom_value = true;

    IF other_count <> 1 THEN
        RAISE EXCEPTION
            'Migration 0029_weather_conditions.sql failed: expected exactly one valid Other option, found %.',
            other_count;
    END IF;
END;
$$;

COMMIT;
