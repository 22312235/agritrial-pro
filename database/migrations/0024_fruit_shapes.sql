
/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0024_fruit_shapes.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the fruit_shapes configuration table.
*
* Fruit shapes represent crop-specific fruit or harvested-product shapes used
* during observations and technical evaluations.
*
* Examples:
*
*   • Round
*   • Oval
*   • Elongated
*   • Cylindrical
*   • Blocky
*   • Conical
*   • Flattened
*   • Pear Shaped
*
* Frozen architectural rules:
*
*   • Every fruit shape belongs to exactly one crop.
*   • Fruit shapes are managed dynamically by the Manager.
*   • Flutter loads fruit shapes dynamically from the database.
*   • Every crop must have exactly one "Other" fruit-shape option.
*   • Selecting "Other" requires a custom user-entered value.
*   • The custom-value requirement will be enforced by the dynamic evaluation
*     engine through evaluation_details.
*   • Fruit shapes support soft deletion and historical references.
*   • Row Level Security policies are intentionally deferred.
*
* General configurable-value rule:
*
*   • When a predefined value does not exist, the user may select "Other".
*   • The related evaluation record must then require a custom text value.
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
-- TABLE: fruit_shapes
--------------------------------------------------------------------------------

CREATE TABLE public.fruit_shapes
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
    -- Fruit Shape Information
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

    CONSTRAINT fk_fruit_shapes_crop
        FOREIGN KEY (crop_id)
        REFERENCES public.crops(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_fruit_shapes_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_fruit_shapes_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_fruit_shapes_code_not_blank
        CHECK
        (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_fruit_shapes_name
        CHECK
        (
            char_length(btrim(name)) BETWEEN 1 AND 150
        ),

    CONSTRAINT chk_fruit_shapes_other_custom_value
        CHECK
        (
            is_other = false
            OR allows_custom_value = true
        ),

    CONSTRAINT chk_fruit_shapes_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_fruit_shapes_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_fruit_shapes_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.fruit_shapes IS
'Crop-specific fruit and harvested-product shapes used in observations and technical evaluations. Every crop includes one Other option for custom user-entered values.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.fruit_shapes.id IS
'Internal UUID primary key of the fruit shape.';

COMMENT ON COLUMN public.fruit_shapes.crop_id IS
'Crop to which the fruit shape belongs.';

COMMENT ON COLUMN public.fruit_shapes.code IS
'Unique business code identifying the fruit shape. Stored in uppercase by trigger.';

COMMENT ON COLUMN public.fruit_shapes.name IS
'Fruit-shape display name shown in dynamic Flutter evaluation forms.';

COMMENT ON COLUMN public.fruit_shapes.description IS
'Optional agronomic description of the fruit or harvested-product shape.';

COMMENT ON COLUMN public.fruit_shapes.is_other IS
'Indicates that this record represents the Other fruit-shape option for its crop.';

COMMENT ON COLUMN public.fruit_shapes.allows_custom_value IS
'Indicates that selecting this fruit shape allows or requires a custom user-entered value.';

COMMENT ON COLUMN public.fruit_shapes.is_active IS
'Indicates whether the fruit shape is available for new evaluations.';

COMMENT ON COLUMN public.fruit_shapes.display_order IS
'Controls the ordering of fruit shapes within a crop in Flutter forms.';

COMMENT ON COLUMN public.fruit_shapes.created_at IS
'UTC timestamp when the fruit-shape record was created.';

COMMENT ON COLUMN public.fruit_shapes.updated_at IS
'UTC timestamp when the fruit-shape record was most recently updated.';

COMMENT ON COLUMN public.fruit_shapes.created_by IS
'Supabase Auth user who created the fruit-shape record.';

COMMENT ON COLUMN public.fruit_shapes.updated_by IS
'Supabase Auth user who most recently updated the fruit-shape record.';

COMMENT ON COLUMN public.fruit_shapes.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the fruit shape has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_fruit_shapes_code_ci
    ON public.fruit_shapes
    (
        lower(btrim(code::text))
    );

CREATE UNIQUE INDEX uq_fruit_shapes_crop_name_normalized
    ON public.fruit_shapes
    (
        crop_id,
        public.fn_normalize_text(name)
    );

CREATE UNIQUE INDEX uq_fruit_shapes_one_other_per_crop
    ON public.fruit_shapes (crop_id)
    WHERE is_other = true;

--------------------------------------------------------------------------------
-- RELATIONSHIP AND FILTERING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_fruit_shapes_crop_id
    ON public.fruit_shapes (crop_id);

CREATE INDEX idx_fruit_shapes_crop_active_display
    ON public.fruit_shapes
    (
        crop_id,
        display_order,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_fruit_shapes_is_active
    ON public.fruit_shapes (is_active)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_fruit_shapes_custom_values
    ON public.fruit_shapes
    (
        crop_id,
        allows_custom_value
    )
    WHERE allows_custom_value = true
      AND deleted_at IS NULL;

CREATE INDEX idx_fruit_shapes_deleted_at
    ON public.fruit_shapes (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEX
--------------------------------------------------------------------------------

CREATE INDEX idx_fruit_shapes_name_trgm
    ON public.fruit_shapes
    USING gin
    (
        name gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_fruit_shapes_created_by
    ON public.fruit_shapes (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_fruit_shapes_updated_by
    ON public.fruit_shapes (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_fruit_shape()
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
                    'Fruit shape validation failed: crop %s does not exist.',
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
                    'Fruit shape validation failed: crop %s is soft-deleted.',
                    NEW.crop_id
                );
    END IF;

    --------------------------------------------------------------------------
    -- Active fruit shape cannot belong to inactive crop
    --------------------------------------------------------------------------

    IF NEW.is_active = true
       AND parent_crop_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = format(
                    'Fruit shape validation failed: an active fruit shape cannot belong to inactive crop %s.',
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
                    'Fruit shape validation failed: the name "Other" requires is_other = true.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_fruit_shape() IS
'Validates crop ownership and configuration state and ensures that Other fruit shapes support custom user-entered values.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_fruit_shapes_validate
    BEFORE INSERT OR UPDATE OF
        crop_id,
        name,
        is_other,
        allows_custom_value,
        is_active
    ON public.fruit_shapes
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_fruit_shape();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_fruit_shapes_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.fruit_shapes
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

CREATE TRIGGER trg_fruit_shapes_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.fruit_shapes
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

CREATE TRIGGER trg_fruit_shapes_timestamps
    BEFORE INSERT OR UPDATE
    ON public.fruit_shapes
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_fruit_shapes_created_by
    BEFORE INSERT
    ON public.fruit_shapes
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_fruit_shapes_updated_by
    BEFORE UPDATE
    ON public.fruit_shapes
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- SEED DATA
--------------------------------------------------------------------------------
-- Common fruit shapes are seeded for every existing crop.
--
-- The Manager may deactivate, reorder, rename, or add crop-specific shapes.
--------------------------------------------------------------------------------

INSERT INTO public.fruit_shapes
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
    left(c.code::text || '_SHAPE_' || seed.code_suffix, 50),
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
            'ROUND',
            'Round',
            'Generally circular or spherical fruit shape.',
            false,
            false,
            10
        ),
        (
            'OVAL',
            'Oval',
            'Elliptical fruit shape with rounded ends.',
            false,
            false,
            20
        ),
        (
            'ELONGATED',
            'Elongated',
            'Fruit shape noticeably longer than it is wide.',
            false,
            false,
            30
        ),
        (
            'CYLINDRICAL',
            'Cylindrical',
            'Fruit shape with mostly parallel sides and a cylindrical profile.',
            false,
            false,
            40
        ),
        (
            'BLOCKY',
            'Blocky',
            'Compact fruit shape with broad shoulders and relatively straight sides.',
            false,
            false,
            50
        ),
        (
            'CONICAL',
            'Conical',
            'Fruit shape that narrows progressively toward one end.',
            false,
            false,
            60
        ),
        (
            'FLATTENED',
            'Flattened',
            'Fruit shape with reduced height relative to its width.',
            false,
            false,
            70
        ),
        (
            'PEAR_SHAPED',
            'Pear Shaped',
            'Fruit shape wider at one end and narrower at the opposite end.',
            false,
            false,
            80
        ),
        (
            'OTHER',
            'Other',
            'Custom fruit shape entered by the user.',
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

INSERT INTO public.fruit_shapes
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
    left(c.code::text || '_SHAPE_OTHER', 50),
    'Other',
    'Custom fruit shape entered by the user.',
    true,
    true,
    999
FROM public.crops c
WHERE c.deleted_at IS NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM public.fruit_shapes fs
      WHERE fs.crop_id = c.id
        AND fs.is_other = true
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

    IF to_regclass('public.fruit_shapes') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0024_fruit_shapes.sql failed: public.fruit_shapes was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'fruit_shapes'
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
            'Migration 0024_fruit_shapes.sql failed: fruit_shapes has % of 14 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.fruit_shapes'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0024_fruit_shapes.sql failed: primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify crop foreign key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.fruit_shapes'::regclass
          AND conname = 'fk_fruit_shapes_crop'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0024_fruit_shapes.sql failed: crop foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify audit foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.fruit_shapes'::regclass
          AND conname = 'fk_fruit_shapes_created_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0024_fruit_shapes.sql failed: created_by foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.fruit_shapes'::regclass
          AND conname = 'fk_fruit_shapes_updated_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0024_fruit_shapes.sql failed: updated_by foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_fruit_shapes_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0024_fruit_shapes.sql failed: unique fruit-shape code index is missing.';
    END IF;

    IF to_regclass('public.uq_fruit_shapes_crop_name_normalized') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0024_fruit_shapes.sql failed: unique crop/shape-name index is missing.';
    END IF;

    IF to_regclass('public.uq_fruit_shapes_one_other_per_crop') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0024_fruit_shapes.sql failed: one-Other-per-crop index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify business validation function and trigger
    --------------------------------------------------------------------------

    IF to_regprocedure('public.trg_validate_fruit_shape()') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0024_fruit_shapes.sql failed: validation function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.fruit_shapes'::regclass
          AND tgname = 'trg_fruit_shapes_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0024_fruit_shapes.sql failed: validation trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify generic triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.fruit_shapes'::regclass
          AND tgname = 'trg_fruit_shapes_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0024_fruit_shapes.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.fruit_shapes'::regclass
          AND tgname = 'trg_fruit_shapes_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0024_fruit_shapes.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.fruit_shapes'::regclass
          AND tgname = 'trg_fruit_shapes_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0024_fruit_shapes.sql failed: updated_by trigger is missing.';
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
          FROM public.fruit_shapes fs
          WHERE fs.crop_id = c.id
            AND fs.is_other = true
            AND fs.allows_custom_value = true
      ) = 1;

    IF existing_crop_count <> crops_with_other THEN
        RAISE EXCEPTION
            'Migration 0024_fruit_shapes.sql failed: only % of % crops have exactly one valid Other fruit shape.',
            crops_with_other,
            existing_crop_count;
    END IF;
END;
$$;

COMMIT;
