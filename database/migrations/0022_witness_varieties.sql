/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0022_witness_varieties.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the witness_varieties configuration table.
*
* Witness varieties represent reference or control varieties used to compare
* candidate varieties during Agrimatco Morocco field trials.
*
* Frozen architectural rules:
*
*   • Every witness variety belongs to exactly one crop.
*   • A selected witness variety must belong to the same crop as the trial.
*   • Witness variety values are managed dynamically by the Manager.
*   • Flutter loads witness varieties dynamically from the database.
*   • Every crop must have exactly one "Other" witness-variety option.
*   • Selecting "Other" requires a custom user-entered witness variety value.
*   • The custom-value requirement will be enforced in the trials migration.
*   • Witness varieties support soft deletion and historical references.
*   • Row Level Security policies are intentionally deferred.
*
* Important business rule:
*
*   • The witness variety must be used in the same locality or grower context
*     as the trial. This contextual validation will be enforced when the
*     trials table and installation validation trigger are created.
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
-- TABLE: witness_varieties
--------------------------------------------------------------------------------

CREATE TABLE public.witness_varieties
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
    -- Witness Variety Information
    --------------------------------------------------------------------------

    code                long_code
                        NOT NULL,

    name                varchar(200)
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

    CONSTRAINT fk_witness_varieties_crop
        FOREIGN KEY (crop_id)
        REFERENCES public.crops(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_witness_varieties_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_witness_varieties_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_witness_varieties_code_not_blank
        CHECK
        (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_witness_varieties_name
        CHECK
        (
            char_length(btrim(name)) BETWEEN 1 AND 200
        ),

    CONSTRAINT chk_witness_varieties_other_custom_value
        CHECK
        (
            is_other = false
            OR allows_custom_value = true
        ),

    CONSTRAINT chk_witness_varieties_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_witness_varieties_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_witness_varieties_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.witness_varieties IS
'Configurable crop-specific witness varieties used as reference controls in Agrimatco Morocco field trials. Every crop includes one Other option for custom user-entered values.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.witness_varieties.id IS
'Internal UUID primary key of the witness variety.';

COMMENT ON COLUMN public.witness_varieties.crop_id IS
'Crop to which the witness variety belongs. The selected trial crop must match this crop.';

COMMENT ON COLUMN public.witness_varieties.code IS
'Unique business code identifying the witness variety. Stored in uppercase by trigger.';

COMMENT ON COLUMN public.witness_varieties.name IS
'Witness-variety display name shown in Flutter forms, evaluations, dashboards, and reports.';

COMMENT ON COLUMN public.witness_varieties.description IS
'Optional agronomic or commercial description of the witness variety.';

COMMENT ON COLUMN public.witness_varieties.is_other IS
'Indicates that this record represents the Other witness-variety option for its crop.';

COMMENT ON COLUMN public.witness_varieties.allows_custom_value IS
'Indicates that selecting this witness variety allows or requires a custom user-entered value in the trial.';

COMMENT ON COLUMN public.witness_varieties.is_active IS
'Indicates whether the witness variety is available for new trial installations.';

COMMENT ON COLUMN public.witness_varieties.display_order IS
'Controls the ordering of witness varieties within a crop in Flutter dropdowns.';

COMMENT ON COLUMN public.witness_varieties.created_at IS
'UTC timestamp when the witness variety record was created.';

COMMENT ON COLUMN public.witness_varieties.updated_at IS
'UTC timestamp when the witness variety record was most recently updated.';

COMMENT ON COLUMN public.witness_varieties.created_by IS
'Supabase Auth user who created the witness variety record.';

COMMENT ON COLUMN public.witness_varieties.updated_by IS
'Supabase Auth user who most recently updated the witness variety record.';

COMMENT ON COLUMN public.witness_varieties.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the witness variety has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

-- Witness variety codes are globally unique regardless of casing and whitespace.
CREATE UNIQUE INDEX uq_witness_varieties_code_ci
    ON public.witness_varieties
    (
        lower(btrim(code::text))
    );

-- Witness variety names are unique within the same crop.
CREATE UNIQUE INDEX uq_witness_varieties_crop_name_normalized
    ON public.witness_varieties
    (
        crop_id,
        public.fn_normalize_text(name)
    );

-- Every crop may have only one Other witness-variety record.
CREATE UNIQUE INDEX uq_witness_varieties_one_other_per_crop
    ON public.witness_varieties (crop_id)
    WHERE is_other = true;

--------------------------------------------------------------------------------
-- RELATIONSHIP AND FILTERING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_witness_varieties_crop_id
    ON public.witness_varieties (crop_id);

CREATE INDEX idx_witness_varieties_crop_active_display
    ON public.witness_varieties
    (
        crop_id,
        display_order,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_witness_varieties_is_active
    ON public.witness_varieties (is_active)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_witness_varieties_custom_values
    ON public.witness_varieties
    (
        crop_id,
        allows_custom_value
    )
    WHERE allows_custom_value = true
      AND deleted_at IS NULL;

CREATE INDEX idx_witness_varieties_deleted_at
    ON public.witness_varieties (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEX
--------------------------------------------------------------------------------

CREATE INDEX idx_witness_varieties_name_trgm
    ON public.witness_varieties
    USING gin
    (
        name gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_witness_varieties_created_by
    ON public.witness_varieties (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_witness_varieties_updated_by
    ON public.witness_varieties (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------
-- Ensures:
--
--   • The selected crop exists.
--   • Soft-deleted crops cannot receive new witness varieties.
--   • Active witness varieties cannot belong to inactive crops.
--   • Other records always allow custom values.
--   • The reserved name Other requires is_other = true.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_witness_variety()
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
                    'Witness variety validation failed: crop %s does not exist.',
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
                    'Witness variety validation failed: crop %s is soft-deleted.',
                    NEW.crop_id
                );
    END IF;

    --------------------------------------------------------------------------
    -- Active witness variety cannot belong to inactive crop
    --------------------------------------------------------------------------

    IF NEW.is_active = true
       AND parent_crop_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = format(
                    'Witness variety validation failed: an active witness variety cannot belong to inactive crop %s.',
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
                    'Witness variety validation failed: the name "Other" requires is_other = true.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_witness_variety() IS
'Validates crop ownership and state and ensures that Other witness varieties support custom user-entered values.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_witness_varieties_validate
    BEFORE INSERT OR UPDATE OF
        crop_id,
        name,
        is_other,
        allows_custom_value,
        is_active
    ON public.witness_varieties
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_witness_variety();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_witness_varieties_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.witness_varieties
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

CREATE TRIGGER trg_witness_varieties_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.witness_varieties
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

CREATE TRIGGER trg_witness_varieties_timestamps
    BEFORE INSERT OR UPDATE
    ON public.witness_varieties
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_witness_varieties_created_by
    BEFORE INSERT
    ON public.witness_varieties
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_witness_varieties_updated_by
    BEFORE UPDATE
    ON public.witness_varieties
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- SEED DATA: OTHER OPTION FOR EVERY EXISTING CROP
--------------------------------------------------------------------------------
-- Specific witness variety names are not seeded because they depend on
-- Agrimatco Morocco's confirmed local and commercial reference varieties.
--
-- Every crop receives an Other option so the Trial Officer can enter a
-- witness variety that is not yet configured.
--------------------------------------------------------------------------------

INSERT INTO public.witness_varieties
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
    left(c.code::text || '_WITNESS_OTHER', 50),
    'Other',
    'Custom witness variety entered by the user.',
    true,
    true,
    999
FROM public.crops c
WHERE c.deleted_at IS NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM public.witness_varieties wv
      WHERE wv.crop_id = c.id
        AND wv.is_other = true
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

    IF to_regclass('public.witness_varieties') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0022_witness_varieties.sql failed: public.witness_varieties was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'witness_varieties'
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
            'Migration 0022_witness_varieties.sql failed: witness_varieties has % of 14 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.witness_varieties'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0022_witness_varieties.sql failed: primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify crop relationship
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.witness_varieties'::regclass
          AND conname = 'fk_witness_varieties_crop'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0022_witness_varieties.sql failed: crop foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify audit foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.witness_varieties'::regclass
          AND conname = 'fk_witness_varieties_created_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0022_witness_varieties.sql failed: created_by foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.witness_varieties'::regclass
          AND conname = 'fk_witness_varieties_updated_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0022_witness_varieties.sql failed: updated_by foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_witness_varieties_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0022_witness_varieties.sql failed: unique witness-variety code index is missing.';
    END IF;

    IF to_regclass('public.uq_witness_varieties_crop_name_normalized') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0022_witness_varieties.sql failed: unique crop/witness-name index is missing.';
    END IF;

    IF to_regclass('public.uq_witness_varieties_one_other_per_crop') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0022_witness_varieties.sql failed: one-Other-per-crop index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify business validation
    --------------------------------------------------------------------------

    IF to_regprocedure('public.trg_validate_witness_variety()') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0022_witness_varieties.sql failed: validation function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.witness_varieties'::regclass
          AND tgname = 'trg_witness_varieties_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0022_witness_varieties.sql failed: validation trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify generic triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.witness_varieties'::regclass
          AND tgname = 'trg_witness_varieties_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0022_witness_varieties.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.witness_varieties'::regclass
          AND tgname = 'trg_witness_varieties_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0022_witness_varieties.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.witness_varieties'::regclass
          AND tgname = 'trg_witness_varieties_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0022_witness_varieties.sql failed: updated_by trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify every existing crop has exactly one Other option
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
          FROM public.witness_varieties wv
          WHERE wv.crop_id = c.id
            AND wv.is_other = true
            AND wv.allows_custom_value = true
      ) = 1;

    IF existing_crop_count <> crops_with_other THEN
        RAISE EXCEPTION
            'Migration 0022_witness_varieties.sql failed: only % of % crops have exactly one valid Other witness variety.',
            crops_with_other,
            existing_crop_count;
    END IF;
END;
$$;

COMMIT;
