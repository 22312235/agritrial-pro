/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0023_growth_stages.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the growth_stages configuration table.
*
* Growth stages represent crop-specific development stages used when recording
* observations and technical evaluations.
*
* Examples:
*
*   • Germination
*   • Seedling
*   • Vegetative Growth
*   • Flowering
*   • Fruit Setting
*   • Fruit Development
*   • Maturity
*   • Harvest
*
* Frozen architectural rules:
*
*   • Every growth stage belongs to exactly one crop.
*   • Growth stages are managed dynamically by the Manager.
*   • Flutter loads growth stages dynamically from the database.
*   • Every crop must have exactly one "Other" growth-stage option.
*   • Selecting "Other" requires a custom user-entered value.
*   • The custom-value requirement will be enforced in the evaluation workflow.
*   • Growth stages support soft deletion and historical references.
*   • Row Level Security policies are intentionally deferred.
*
* General configurable-value rule:
*
*   • When a predefined value does not exist, the user may select "Other".
*   • The related workflow record must require a custom text value.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0003_domains.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
*   • 0018_crops.sql
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
-- TABLE: growth_stages
--------------------------------------------------------------------------------

CREATE TABLE public.growth_stages
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                  uuid
                        PRIMARY KEY
                        DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Parent Crop
    --------------------------------------------------------------------------

    crop_id             uuid
                        NOT NULL,

    --------------------------------------------------------------------------
    -- Growth Stage Information
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

    CONSTRAINT fk_growth_stages_crop
        FOREIGN KEY (crop_id)
        REFERENCES public.crops(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_growth_stages_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_growth_stages_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_growth_stages_code_not_blank
        CHECK
        (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_growth_stages_name
        CHECK
        (
            char_length(btrim(name)) BETWEEN 1 AND 150
        ),

    CONSTRAINT chk_growth_stages_other_custom_value
        CHECK
        (
            is_other = false
            OR allows_custom_value = true
        ),

    CONSTRAINT chk_growth_stages_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_growth_stages_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_growth_stages_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.growth_stages IS
'Crop-specific development stages used during observations and technical evaluations. Every crop includes one Other option for custom user-entered values.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.growth_stages.id IS
'Internal UUID primary key of the growth stage.';

COMMENT ON COLUMN public.growth_stages.crop_id IS
'Crop to which the growth stage belongs.';

COMMENT ON COLUMN public.growth_stages.code IS
'Unique business code identifying the growth stage. Stored in uppercase by trigger.';

COMMENT ON COLUMN public.growth_stages.name IS
'Growth-stage display name shown in dynamic Flutter evaluation forms.';

COMMENT ON COLUMN public.growth_stages.description IS
'Optional agronomic description of the growth stage.';

COMMENT ON COLUMN public.growth_stages.is_other IS
'Indicates that this record represents the Other growth-stage option for its crop.';

COMMENT ON COLUMN public.growth_stages.allows_custom_value IS
'Indicates that selecting this growth stage allows or requires a custom user-entered value.';

COMMENT ON COLUMN public.growth_stages.is_active IS
'Indicates whether the growth stage is available for new evaluations.';

COMMENT ON COLUMN public.growth_stages.display_order IS
'Controls the ordering of growth stages within a crop in Flutter forms.';

COMMENT ON COLUMN public.growth_stages.created_at IS
'UTC timestamp when the growth-stage record was created.';

COMMENT ON COLUMN public.growth_stages.updated_at IS
'UTC timestamp when the growth-stage record was most recently updated.';

COMMENT ON COLUMN public.growth_stages.created_by IS
'Supabase Auth user who created the growth-stage record.';

COMMENT ON COLUMN public.growth_stages.updated_by IS
'Supabase Auth user who most recently updated the growth-stage record.';

COMMENT ON COLUMN public.growth_stages.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the growth stage has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

-- Growth-stage codes are globally unique.
CREATE UNIQUE INDEX uq_growth_stages_code_ci
    ON public.growth_stages
    (
        lower(btrim(code::text))
    );

-- Growth-stage names are unique within the same crop.
CREATE UNIQUE INDEX uq_growth_stages_crop_name_normalized
    ON public.growth_stages
    (
        crop_id,
        public.fn_normalize_text(name)
    );

-- Every crop may have only one Other growth-stage record.
CREATE UNIQUE INDEX uq_growth_stages_one_other_per_crop
    ON public.growth_stages (crop_id)
    WHERE is_other = true;

--------------------------------------------------------------------------------
-- RELATIONSHIP AND FILTERING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_growth_stages_crop_id
    ON public.growth_stages (crop_id);

CREATE INDEX idx_growth_stages_crop_active_display
    ON public.growth_stages
    (
        crop_id,
        display_order,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_growth_stages_is_active
    ON public.growth_stages (is_active)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_growth_stages_custom_values
    ON public.growth_stages
    (
        crop_id,
        allows_custom_value
    )
    WHERE allows_custom_value = true
      AND deleted_at IS NULL;

CREATE INDEX idx_growth_stages_deleted_at
    ON public.growth_stages (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEX
--------------------------------------------------------------------------------

CREATE INDEX idx_growth_stages_name_trgm
    ON public.growth_stages
    USING gin
    (
        name gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_growth_stages_created_by
    ON public.growth_stages (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_growth_stages_updated_by
    ON public.growth_stages (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------
-- Ensures:
--
--   • The selected crop exists.
--   • Soft-deleted crops cannot receive new growth stages.
--   • Active growth stages cannot belong to inactive crops.
--   • Other records always allow custom values.
--   • The reserved name Other requires is_other = true.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_growth_stage()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    parent_crop_active       boolean;
    parent_crop_deleted_at   timestamptz;
BEGIN
    --------------------------------------------------------------------------
    -- Resolve parent crop state
    --------------------------------------------------------------------------

    SELECT
        c.is_active,
        c.deleted_at
    INTO
        parent_crop_active,
        parent_crop_deleted_at
    FROM public.crops c
    WHERE c.id = NEW.crop_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Growth stage validation failed: crop %s does not exist.',
                    NEW.crop_id
                );
    END IF;

    --------------------------------------------------------------------------
    -- Prevent references to soft-deleted crops
    --------------------------------------------------------------------------

    IF parent_crop_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = format(
                    'Growth stage validation failed: crop %s is soft-deleted.',
                    NEW.crop_id
                );
    END IF;

    --------------------------------------------------------------------------
    -- Active growth stage cannot belong to inactive crop
    --------------------------------------------------------------------------

    IF NEW.is_active = true
       AND parent_crop_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = format(
                    'Growth stage validation failed: an active growth stage cannot belong to inactive crop %s.',
                    NEW.crop_id
                );
    END IF;

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
                    'Growth stage validation failed: the name "Other" requires is_other = true.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_growth_stage() IS
'Validates crop ownership and state and ensures that Other growth stages support custom user-entered values.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_growth_stages_validate
    BEFORE INSERT OR UPDATE OF
        crop_id,
        name,
        is_other,
        allows_custom_value,
        is_active
    ON public.growth_stages
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_growth_stage();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_growth_stages_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.growth_stages
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

CREATE TRIGGER trg_growth_stages_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.growth_stages
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

CREATE TRIGGER trg_growth_stages_timestamps
    BEFORE INSERT OR UPDATE
    ON public.growth_stages
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_growth_stages_created_by
    BEFORE INSERT
    ON public.growth_stages
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_growth_stages_updated_by
    BEFORE UPDATE
    ON public.growth_stages
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- SEED DATA
--------------------------------------------------------------------------------
-- Common growth stages are seeded for every existing crop.
--
-- The Manager may deactivate, reorder, rename, or add stages later.
--------------------------------------------------------------------------------

INSERT INTO public.growth_stages
(
    crop_id,
    code,
    name,
    description,
    is_other,
    allows_custom_value,
    display_order
)
SELECT
    c.id,
    left(c.code::text || '_' || seed.code_suffix, 50),
    seed.name,
    seed.description,
    seed.is_other,
    seed.allows_custom_value,
    seed.display_order
FROM public.crops c
CROSS JOIN
(
    VALUES
        (
            'GERMINATION',
            'Germination',
            'Stage during which the seed germinates and initial growth begins.',
            false,
            false,
            10
        ),
        (
            'SEEDLING',
            'Seedling',
            'Early stage following germination when the young plant is developing.',
            false,
            false,
            20
        ),
        (
            'VEGETATIVE',
            'Vegetative Growth',
            'Stage characterized primarily by leaf, stem, and root development.',
            false,
            false,
            30
        ),
        (
            'FLOWERING',
            'Flowering',
            'Stage during which flowers develop and open.',
            false,
            false,
            40
        ),
        (
            'FRUIT_SETTING',
            'Fruit Setting',
            'Stage during which pollinated flowers begin developing into fruits.',
            false,
            false,
            50
        ),
        (
            'FRUIT_DEVELOPMENT',
            'Fruit Development',
            'Stage during which fruits increase in size and develop commercial characteristics.',
            false,
            false,
            60
        ),
        (
            'MATURITY',
            'Maturity',
            'Stage during which the crop or fruit reaches physiological or commercial maturity.',
            false,
            false,
            70
        ),
        (
            'HARVEST',
            'Harvest',
            'Stage during which mature products are collected and evaluated.',
            false,
            false,
            80
        ),
        (
            'OTHER',
            'Other',
            'Custom growth stage entered by the user.',
            true,
            true,
            999
        )
) AS seed
(
    code_suffix,
    name,
    description,
    is_other,
    allows_custom_value,
    display_order
)
WHERE c.deleted_at IS NULL
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- ADD OTHER OPTION TO ANY CROP WITHOUT ONE
--------------------------------------------------------------------------------
-- Ensures crops added before or during deployment always have an Other option.
--------------------------------------------------------------------------------

INSERT INTO public.growth_stages
(
    crop_id,
    code,
    name,
    description,
    is_other,
    allows_custom_value,
    display_order
)
SELECT
    c.id,
    left(c.code::text || '_GROWTH_OTHER', 50),
    'Other',
    'Custom growth stage entered by the user.',
    true,
    true,
    999
FROM public.crops c
WHERE c.deleted_at IS NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM public.growth_stages gs
      WHERE gs.crop_id = c.id
        AND gs.is_other = true
  )
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- MIGRATION VALIDATION
--------------------------------------------------------------------------------

DO
$$
DECLARE
    expected_column_count integer;
    existing_crop_count   integer;
    crops_with_other      integer;
BEGIN
    --------------------------------------------------------------------------
    -- Verify table creation
    --------------------------------------------------------------------------

    IF to_regclass('public.growth_stages') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0023_growth_stages.sql failed: public.growth_stages was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'growth_stages'
      AND column_name IN
      (
          'id',
          'crop_id',
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

    IF expected_column_count <> 14 THEN
        RAISE EXCEPTION
            'Migration 0023_growth_stages.sql failed: growth_stages has % of 14 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.growth_stages'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0023_growth_stages.sql failed: primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify crop foreign key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.growth_stages'::regclass
          AND conname = 'fk_growth_stages_crop'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0023_growth_stages.sql failed: crop foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify audit foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.growth_stages'::regclass
          AND conname = 'fk_growth_stages_created_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0023_growth_stages.sql failed: created_by foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.growth_stages'::regclass
          AND conname = 'fk_growth_stages_updated_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0023_growth_stages.sql failed: updated_by foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_growth_stages_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0023_growth_stages.sql failed: unique growth-stage code index is missing.';
    END IF;

    IF to_regclass('public.uq_growth_stages_crop_name_normalized') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0023_growth_stages.sql failed: unique crop/stage-name index is missing.';
    END IF;

    IF to_regclass('public.uq_growth_stages_one_other_per_crop') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0023_growth_stages.sql failed: one-Other-per-crop index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify business validation
    --------------------------------------------------------------------------

    IF to_regprocedure('public.trg_validate_growth_stage()') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0023_growth_stages.sql failed: validation function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.growth_stages'::regclass
          AND tgname = 'trg_growth_stages_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0023_growth_stages.sql failed: validation trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify generic triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.growth_stages'::regclass
          AND tgname = 'trg_growth_stages_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0023_growth_stages.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.growth_stages'::regclass
          AND tgname = 'trg_growth_stages_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0023_growth_stages.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.growth_stages'::regclass
          AND tgname = 'trg_growth_stages_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0023_growth_stages.sql failed: updated_by trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify every existing crop has exactly one valid Other option
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO existing_crop_count
    FROM public.crops
    WHERE deleted_at IS NULL;

    SELECT count(*)
    INTO crops_with_other
    FROM public.crops c
    WHERE c.deleted_at IS NULL
      AND
      (
          SELECT count(*)
          FROM public.growth_stages gs
          WHERE gs.crop_id = c.id
            AND gs.is_other = true
            AND gs.allows_custom_value = true
      ) = 1;

    IF existing_crop_count <> crops_with_other THEN
        RAISE EXCEPTION
            'Migration 0023_growth_stages.sql failed: only % of % crops have exactly one valid Other growth stage.',
            crops_with_other,
            existing_crop_count;
    END IF;
END;
$$;

COMMIT;
