/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0025_fruit_colors.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the fruit_colors configuration table.
*
* Fruit colors represent crop-specific fruit or harvested-product colors used
* during observations and technical evaluations.
*
* Examples:
*
*   • Green
*   • Light Green
*   • Dark Green
*   • Red
*   • Yellow
*   • Orange
*   • White
*   • Purple
*   • Black
*
* Frozen architectural rules:
*
*   • Every fruit color belongs to exactly one crop.
*   • Fruit colors are managed dynamically by the Manager.
*   • Flutter loads fruit colors dynamically from the database.
*   • Every crop must have exactly one "Other" fruit-color option.
*   • Selecting "Other" requires a custom user-entered value.
*   • The custom-value requirement will be enforced by the dynamic evaluation
*     engine through evaluation_details.
*   • Fruit colors support soft deletion and historical references.
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
-- TABLE: fruit_colors
--------------------------------------------------------------------------------

CREATE TABLE public.fruit_colors
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
    -- Fruit Color Information
    --------------------------------------------------------------------------

    code                long_code
                        NOT NULL,

    name                varchar(150)
                        NOT NULL,

    hex_code            varchar(7),

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

    CONSTRAINT fk_fruit_colors_crop
        FOREIGN KEY (crop_id)
        REFERENCES public.crops(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_fruit_colors_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_fruit_colors_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_fruit_colors_code_not_blank
        CHECK
        (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_fruit_colors_name
        CHECK
        (
            char_length(btrim(name)) BETWEEN 1 AND 150
        ),

    CONSTRAINT chk_fruit_colors_hex_code
        CHECK
        (
            hex_code IS NULL
            OR hex_code ~ '^#[0-9A-Fa-f]{6}$'
        ),

    CONSTRAINT chk_fruit_colors_other_custom_value
        CHECK
        (
            is_other = false
            OR allows_custom_value = true
        ),

    CONSTRAINT chk_fruit_colors_other_hex_code
        CHECK
        (
            is_other = false
            OR hex_code IS NULL
        ),

    CONSTRAINT chk_fruit_colors_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_fruit_colors_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_fruit_colors_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.fruit_colors IS
'Crop-specific fruit and harvested-product colors used in observations and technical evaluations. Every crop includes one Other option for custom user-entered values.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.fruit_colors.id IS
'Internal UUID primary key of the fruit color.';

COMMENT ON COLUMN public.fruit_colors.crop_id IS
'Crop to which the fruit color belongs.';

COMMENT ON COLUMN public.fruit_colors.code IS
'Unique business code identifying the fruit color. Stored in uppercase by trigger.';

COMMENT ON COLUMN public.fruit_colors.name IS
'Fruit-color display name shown in dynamic Flutter evaluation forms.';

COMMENT ON COLUMN public.fruit_colors.hex_code IS
'Optional six-digit hexadecimal display color used by Flutter interfaces.';

COMMENT ON COLUMN public.fruit_colors.description IS
'Optional agronomic description of the fruit or harvested-product color.';

COMMENT ON COLUMN public.fruit_colors.is_other IS
'Indicates that this record represents the Other fruit-color option for its crop.';

COMMENT ON COLUMN public.fruit_colors.allows_custom_value IS
'Indicates that selecting this fruit color allows or requires a custom user-entered value.';

COMMENT ON COLUMN public.fruit_colors.is_active IS
'Indicates whether the fruit color is available for new evaluations.';

COMMENT ON COLUMN public.fruit_colors.display_order IS
'Controls the ordering of fruit colors within a crop in Flutter forms.';

COMMENT ON COLUMN public.fruit_colors.created_at IS
'UTC timestamp when the fruit-color record was created.';

COMMENT ON COLUMN public.fruit_colors.updated_at IS
'UTC timestamp when the fruit-color record was most recently updated.';

COMMENT ON COLUMN public.fruit_colors.created_by IS
'Supabase Auth user who created the fruit-color record.';

COMMENT ON COLUMN public.fruit_colors.updated_by IS
'Supabase Auth user who most recently updated the fruit-color record.';

COMMENT ON COLUMN public.fruit_colors.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the fruit color has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_fruit_colors_code_ci
    ON public.fruit_colors
    (
        lower(btrim(code::text))
    );

CREATE UNIQUE INDEX uq_fruit_colors_crop_name_normalized
    ON public.fruit_colors
    (
        crop_id,
        public.fn_normalize_text(name)
    );

CREATE UNIQUE INDEX uq_fruit_colors_one_other_per_crop
    ON public.fruit_colors (crop_id)
    WHERE is_other = true;

--------------------------------------------------------------------------------
-- RELATIONSHIP AND FILTERING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_fruit_colors_crop_id
    ON public.fruit_colors (crop_id);

CREATE INDEX idx_fruit_colors_crop_active_display
    ON public.fruit_colors
    (
        crop_id,
        display_order,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_fruit_colors_is_active
    ON public.fruit_colors (is_active)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_fruit_colors_custom_values
    ON public.fruit_colors
    (
        crop_id,
        allows_custom_value
    )
    WHERE allows_custom_value = true
      AND deleted_at IS NULL;

CREATE INDEX idx_fruit_colors_deleted_at
    ON public.fruit_colors (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEX
--------------------------------------------------------------------------------

CREATE INDEX idx_fruit_colors_name_trgm
    ON public.fruit_colors
    USING gin
    (
        name gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_fruit_colors_created_by
    ON public.fruit_colors (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_fruit_colors_updated_by
    ON public.fruit_colors (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_fruit_color()
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
                    'Fruit color validation failed: crop %s does not exist.',
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
                    'Fruit color validation failed: crop %s is soft-deleted.',
                    NEW.crop_id
                );
    END IF;

    --------------------------------------------------------------------------
    -- Active fruit color cannot belong to inactive crop
    --------------------------------------------------------------------------

    IF NEW.is_active = true
       AND parent_crop_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = format(
                    'Fruit color validation failed: an active fruit color cannot belong to inactive crop %s.',
                    NEW.crop_id
                );
    END IF;

    --------------------------------------------------------------------------
    -- Normalize the Other option
    --------------------------------------------------------------------------

    IF NEW.is_other = true THEN
        NEW.name := 'Other';
        NEW.hex_code := NULL;
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
                    'Fruit color validation failed: the name "Other" requires is_other = true.';
    END IF;

    --------------------------------------------------------------------------
    -- Normalize hexadecimal color value
    --------------------------------------------------------------------------

    IF NEW.hex_code IS NOT NULL THEN
        NEW.hex_code := upper(btrim(NEW.hex_code));
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_fruit_color() IS
'Validates crop ownership and configuration state, normalizes hexadecimal color codes, and ensures that Other fruit colors support custom values.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_fruit_colors_validate
    BEFORE INSERT OR UPDATE OF
        crop_id,
        name,
        hex_code,
        is_other,
        allows_custom_value,
        is_active
    ON public.fruit_colors
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_fruit_color();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_fruit_colors_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.fruit_colors
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

CREATE TRIGGER trg_fruit_colors_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.fruit_colors
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

CREATE TRIGGER trg_fruit_colors_timestamps
    BEFORE INSERT OR UPDATE
    ON public.fruit_colors
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_fruit_colors_created_by
    BEFORE INSERT
    ON public.fruit_colors
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_fruit_colors_updated_by
    BEFORE UPDATE
    ON public.fruit_colors
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- SEED DATA
--------------------------------------------------------------------------------
-- Common fruit colors are seeded for every existing crop.
--
-- The Manager may deactivate, reorder, rename, or add crop-specific colors.
--------------------------------------------------------------------------------

INSERT INTO public.fruit_colors
(
    crop_id,
    code,
    name,
    hex_code,
    description,
    is_other,
    allows_custom_value,
    display_order
)
SELECT
    c.id,
    left(c.code::text || '_COLOR_' || seed.code_suffix, 50),
    seed.name,
    seed.hex_code,
    seed.description,
    seed.is_other,
    seed.allows_custom_value,
    seed.display_order
FROM public.crops c
CROSS JOIN
(
    VALUES
        (
            'GREEN',
            'Green',
            '#008000',
            'Standard green fruit or harvested-product color.',
            false,
            false,
            10
        ),
        (
            'LIGHT_GREEN',
            'Light Green',
            '#90EE90',
            'Light green fruit or harvested-product color.',
            false,
            false,
            20
        ),
        (
            'DARK_GREEN',
            'Dark Green',
            '#006400',
            'Dark green fruit or harvested-product color.',
            false,
            false,
            30
        ),
        (
            'RED',
            'Red',
            '#FF0000',
            'Red fruit or harvested-product color.',
            false,
            false,
            40
        ),
        (
            'YELLOW',
            'Yellow',
            '#FFFF00',
            'Yellow fruit or harvested-product color.',
            false,
            false,
            50
        ),
        (
            'ORANGE',
            'Orange',
            '#FFA500',
            'Orange fruit or harvested-product color.',
            false,
            false,
            60
        ),
        (
            'WHITE',
            'White',
            '#FFFFFF',
            'White or cream fruit or harvested-product color.',
            false,
            false,
            70
        ),
        (
            'PURPLE',
            'Purple',
            '#800080',
            'Purple fruit or harvested-product color.',
            false,
            false,
            80
        ),
        (
            'BLACK',
            'Black',
            '#000000',
            'Black or near-black fruit or harvested-product color.',
            false,
            false,
            90
        ),
        (
            'OTHER',
            'Other',
            NULL,
            'Custom fruit color entered by the user.',
            true,
            true,
            999
        )
) AS seed
(
    code_suffix,
    name,
    hex_code,
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

INSERT INTO public.fruit_colors
(
    crop_id,
    code,
    name,
    hex_code,
    description,
    is_other,
    allows_custom_value,
    display_order
)
SELECT
    c.id,
    left(c.code::text || '_COLOR_OTHER', 50),
    'Other',
    NULL,
    'Custom fruit color entered by the user.',
    true,
    true,
    999
FROM public.crops c
WHERE c.deleted_at IS NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM public.fruit_colors fc
      WHERE fc.crop_id = c.id
        AND fc.is_other = true
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

    IF to_regclass('public.fruit_colors') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0025_fruit_colors.sql failed: public.fruit_colors was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'fruit_colors'
      AND column_name IN
      (
          'id',
          'crop_id',
          'code',
          'name',
          'hex_code',
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

    IF expected_column_count <> 15 THEN
        RAISE EXCEPTION
            'Migration 0025_fruit_colors.sql failed: fruit_colors has % of 15 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.fruit_colors'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0025_fruit_colors.sql failed: primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify crop foreign key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.fruit_colors'::regclass
          AND conname = 'fk_fruit_colors_crop'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0025_fruit_colors.sql failed: crop foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify audit foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.fruit_colors'::regclass
          AND conname = 'fk_fruit_colors_created_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0025_fruit_colors.sql failed: created_by foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.fruit_colors'::regclass
          AND conname = 'fk_fruit_colors_updated_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0025_fruit_colors.sql failed: updated_by foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_fruit_colors_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0025_fruit_colors.sql failed: unique fruit-color code index is missing.';
    END IF;

    IF to_regclass('public.uq_fruit_colors_crop_name_normalized') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0025_fruit_colors.sql failed: unique crop/color-name index is missing.';
    END IF;

    IF to_regclass('public.uq_fruit_colors_one_other_per_crop') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0025_fruit_colors.sql failed: one-Other-per-crop index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify business validation function and trigger
    --------------------------------------------------------------------------

    IF to_regprocedure('public.trg_validate_fruit_color()') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0025_fruit_colors.sql failed: validation function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.fruit_colors'::regclass
          AND tgname = 'trg_fruit_colors_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0025_fruit_colors.sql failed: validation trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify generic triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.fruit_colors'::regclass
          AND tgname = 'trg_fruit_colors_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0025_fruit_colors.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.fruit_colors'::regclass
          AND tgname = 'trg_fruit_colors_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0025_fruit_colors.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.fruit_colors'::regclass
          AND tgname = 'trg_fruit_colors_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0025_fruit_colors.sql failed: updated_by trigger is missing.';
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
          FROM public.fruit_colors fc
          WHERE fc.crop_id = c.id
            AND fc.is_other = true
            AND fc.allows_custom_value = true
            AND fc.hex_code IS NULL
      ) = 1;

    IF existing_crop_count <> crops_with_other THEN
        RAISE EXCEPTION
            'Migration 0025_fruit_colors.sql failed: only % of % crops have exactly one valid Other fruit color.',
            crops_with_other,
            existing_crop_count;
    END IF;
END;
$$;

COMMIT;
