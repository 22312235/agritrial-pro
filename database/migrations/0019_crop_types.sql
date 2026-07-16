
/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0019_crop_types.sql
* Version      : 1.2.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the crop_types configuration table.
*
* Crop types represent configurable commercial or agronomic classifications
* belonging to a specific crop.
*
* Examples:
*
*   • Tomato     → Cherry, Cluster, Beef, Roma, Round
*   • Pepper     → G, GG, GGG, Bell, Long, Blocky
*   • Cucumber   → Slicer, Beit Alpha, Mini, Long
*   • Melon      → Cantaloupe, Galia, Charentais
*   • Watermelon → Seedless, Seeded, Mini
*
* Frozen architectural rules:
*
*   • Every crop type belongs to exactly one crop.
*   • Crop type values are managed dynamically by the Manager.
*   • Flutter loads crop types dynamically from the database.
*   • Each crop must have exactly one "Other" option.
*   • Selecting "Other" allows the user to enter a custom value.
*   • The related custom value will be stored and validated in the trials table.
*   • One-character classifications such as G are valid.
*   • Crop types support soft deletion and historical references.
*   • Row Level Security policies are intentionally deferred.
*
* General configurable-value rule:
*
*   • Where a predefined value does not exist, the user may select "Other".
*   • The related workflow record must then require a custom text value.
*   • This rule applies to all relevant future configurable lookup tables.
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
-- TABLE: crop_types
--------------------------------------------------------------------------------

CREATE TABLE public.crop_types
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
    -- Crop Type Information
    --------------------------------------------------------------------------
    -- varchar(100) is intentionally used instead of the short_name domain
    -- because valid crop classifications may contain one character, such as G.
    --------------------------------------------------------------------------

    code                long_code
                        NOT NULL,

    name                varchar(100)
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

    CONSTRAINT fk_crop_types_crop
        FOREIGN KEY (crop_id)
        REFERENCES public.crops(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_crop_types_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_crop_types_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_crop_types_code_not_blank
        CHECK
        (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_crop_types_name
        CHECK
        (
            char_length(btrim(name)) BETWEEN 1 AND 100
        ),

    CONSTRAINT chk_crop_types_other_custom_value
        CHECK
        (
            is_other = false
            OR allows_custom_value = true
        ),

    CONSTRAINT chk_crop_types_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_crop_types_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_crop_types_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.crop_types IS
'Configurable crop classifications belonging to crops. Each crop has one Other option that supports a custom value entered by the user.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.crop_types.id IS
'Internal UUID primary key of the crop type.';

COMMENT ON COLUMN public.crop_types.crop_id IS
'Crop to which the crop type belongs.';

COMMENT ON COLUMN public.crop_types.code IS
'Unique business code identifying the crop type. Stored in uppercase by trigger.';

COMMENT ON COLUMN public.crop_types.name IS
'Crop-type display name shown in Flutter dropdowns. Supports one-character values such as G.';

COMMENT ON COLUMN public.crop_types.description IS
'Optional agronomic or commercial description of the crop type.';

COMMENT ON COLUMN public.crop_types.is_other IS
'Indicates that this record represents the Other option for its crop.';

COMMENT ON COLUMN public.crop_types.allows_custom_value IS
'Indicates that selecting this crop type allows a custom user-entered value in the related workflow record.';

COMMENT ON COLUMN public.crop_types.is_active IS
'Indicates whether the crop type is available for new trial installations.';

COMMENT ON COLUMN public.crop_types.display_order IS
'Controls the ordering of crop types within a crop in Flutter dropdowns.';

COMMENT ON COLUMN public.crop_types.created_at IS
'UTC timestamp when the crop type record was created.';

COMMENT ON COLUMN public.crop_types.updated_at IS
'UTC timestamp when the crop type record was most recently updated.';

COMMENT ON COLUMN public.crop_types.created_by IS
'Supabase Auth user who created the crop type record.';

COMMENT ON COLUMN public.crop_types.updated_by IS
'Supabase Auth user who most recently updated the crop type record.';

COMMENT ON COLUMN public.crop_types.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the crop type has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

-- Crop type codes are globally unique regardless of casing and whitespace.
CREATE UNIQUE INDEX uq_crop_types_code_ci
    ON public.crop_types
    (
        lower(btrim(code::text))
    );

-- Crop type names are unique within the same crop regardless of casing,
-- accents, and surrounding whitespace.
CREATE UNIQUE INDEX uq_crop_types_crop_name_normalized
    ON public.crop_types
    (
        crop_id,
        public.fn_normalize_text(name)
    );

-- Each crop may have exactly one historical or active Other record.
CREATE UNIQUE INDEX uq_crop_types_one_other_per_crop
    ON public.crop_types (crop_id)
    WHERE is_other = true;

--------------------------------------------------------------------------------
-- RELATIONSHIP AND FILTERING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_crop_types_crop_id
    ON public.crop_types (crop_id);

CREATE INDEX idx_crop_types_crop_active_display
    ON public.crop_types
    (
        crop_id,
        display_order,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_crop_types_is_active
    ON public.crop_types (is_active)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_crop_types_custom_values
    ON public.crop_types
    (
        crop_id,
        allows_custom_value
    )
    WHERE allows_custom_value = true
      AND deleted_at IS NULL;

CREATE INDEX idx_crop_types_deleted_at
    ON public.crop_types (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEX
--------------------------------------------------------------------------------

CREATE INDEX idx_crop_types_name_trgm
    ON public.crop_types
    USING gin
    (
        name gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_crop_types_created_by
    ON public.crop_types (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_crop_types_updated_by
    ON public.crop_types (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------
-- Ensures:
--
--   • The selected crop exists.
--   • Soft-deleted crops cannot receive new crop types.
--   • Active crop types cannot belong to inactive crops.
--   • An Other record always allows a custom value.
--   • The reserved name Other requires is_other = true.
--   • Normal crop types may optionally allow custom values.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_crop_type()
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
                    'Crop type validation failed: crop %s does not exist.',
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
                    'Crop type validation failed: crop %s is soft-deleted.',
                    NEW.crop_id
                );
    END IF;

    --------------------------------------------------------------------------
    -- Active crop type cannot belong to inactive crop
    --------------------------------------------------------------------------

    IF NEW.is_active = true
       AND parent_crop_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = format(
                    'Crop type validation failed: an active crop type cannot belong to inactive crop %s.',
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
    -- Reserve the name Other for explicitly marked records
    --------------------------------------------------------------------------

    IF public.fn_normalize_text(NEW.name) = 'other'
       AND NEW.is_other = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Crop type validation failed: the name "Other" requires is_other = true.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_crop_type() IS
'Validates crop ownership and state and ensures that Other crop types support custom user-entered values.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_crop_types_validate
    BEFORE INSERT OR UPDATE OF
        crop_id,
        name,
        is_other,
        allows_custom_value,
        is_active
    ON public.crop_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_crop_type();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_crop_types_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.crop_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

CREATE TRIGGER trg_crop_types_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.crop_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

CREATE TRIGGER trg_crop_types_timestamps
    BEFORE INSERT OR UPDATE
    ON public.crop_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_crop_types_created_by
    BEFORE INSERT
    ON public.crop_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_crop_types_updated_by
    BEFORE UPDATE
    ON public.crop_types
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- SEED DATA
--------------------------------------------------------------------------------
-- Confirmed crop-type examples and one Other option for every confirmed crop.
--
-- Codes include the crop prefix to remain globally unique.
--------------------------------------------------------------------------------

INSERT INTO public.crop_types
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
    seed.code,
    seed.name,
    seed.description,
    seed.is_other,
    seed.allows_custom_value,
    seed.display_order
FROM public.crops c
JOIN
(
    VALUES
        ----------------------------------------------------------------------
        -- Tomato
        ----------------------------------------------------------------------

        (
            'TOMATO',
            'TOMATO_CHERRY',
            'Cherry',
            'Cherry tomato crop type.',
            false,
            false,
            10
        ),
        (
            'TOMATO',
            'TOMATO_CLUSTER',
            'Cluster',
            'Cluster tomato crop type.',
            false,
            false,
            20
        ),
        (
            'TOMATO',
            'TOMATO_BEEF',
            'Beef',
            'Beef tomato crop type.',
            false,
            false,
            30
        ),
        (
            'TOMATO',
            'TOMATO_ROMA',
            'Roma',
            'Roma tomato crop type.',
            false,
            false,
            40
        ),
        (
            'TOMATO',
            'TOMATO_ROUND',
            'Round',
            'Round tomato crop type.',
            false,
            false,
            50
        ),
        (
            'TOMATO',
            'TOMATO_OTHER',
            'Other',
            'Custom tomato crop type entered by the user.',
            true,
            true,
            999
        ),

        ----------------------------------------------------------------------
        -- Pepper
        ----------------------------------------------------------------------

        (
            'PEPPER',
            'PEPPER_G',
            'G',
            'Pepper commercial size or classification G.',
            false,
            false,
            10
        ),
        (
            'PEPPER',
            'PEPPER_GG',
            'GG',
            'Pepper commercial size or classification GG.',
            false,
            false,
            20
        ),
        (
            'PEPPER',
            'PEPPER_GGG',
            'GGG',
            'Pepper commercial size or classification GGG.',
            false,
            false,
            30
        ),
        (
            'PEPPER',
            'PEPPER_BELL',
            'Bell',
            'Bell pepper crop type.',
            false,
            false,
            40
        ),
        (
            'PEPPER',
            'PEPPER_LONG',
            'Long',
            'Long pepper crop type.',
            false,
            false,
            50
        ),
        (
            'PEPPER',
            'PEPPER_BLOCKY',
            'Blocky',
            'Blocky pepper crop type.',
            false,
            false,
            60
        ),
        (
            'PEPPER',
            'PEPPER_OTHER',
            'Other',
            'Custom pepper crop type entered by the user.',
            true,
            true,
            999
        ),

        ----------------------------------------------------------------------
        -- Cucumber
        ----------------------------------------------------------------------

        (
            'CUCUMBER',
            'CUCUMBER_SLICER',
            'Slicer',
            'Slicer cucumber crop type.',
            false,
            false,
            10
        ),
        (
            'CUCUMBER',
            'CUCUMBER_BEIT_ALPHA',
            'Beit Alpha',
            'Beit Alpha cucumber crop type.',
            false,
            false,
            20
        ),
        (
            'CUCUMBER',
            'CUCUMBER_MINI',
            'Mini',
            'Mini cucumber crop type.',
            false,
            false,
            30
        ),
        (
            'CUCUMBER',
            'CUCUMBER_LONG',
            'Long',
            'Long cucumber crop type.',
            false,
            false,
            40
        ),
        (
            'CUCUMBER',
            'CUCUMBER_OTHER',
            'Other',
            'Custom cucumber crop type entered by the user.',
            true,
            true,
            999
        ),

        ----------------------------------------------------------------------
        -- Melon
        ----------------------------------------------------------------------

        (
            'MELON',
            'MELON_CANTALOUPE',
            'Cantaloupe',
            'Cantaloupe melon crop type.',
            false,
            false,
            10
        ),
        (
            'MELON',
            'MELON_GALIA',
            'Galia',
            'Galia melon crop type.',
            false,
            false,
            20
        ),
        (
            'MELON',
            'MELON_CHARENTAIS',
            'Charentais',
            'Charentais melon crop type.',
            false,
            false,
            30
        ),
        (
            'MELON',
            'MELON_OTHER',
            'Other',
            'Custom melon crop type entered by the user.',
            true,
            true,
            999
        ),

        ----------------------------------------------------------------------
        -- Watermelon
        ----------------------------------------------------------------------

        (
            'WATERMELON',
            'WATERMELON_SEEDLESS',
            'Seedless',
            'Seedless watermelon crop type.',
            false,
            false,
            10
        ),
        (
            'WATERMELON',
            'WATERMELON_SEEDED',
            'Seeded',
            'Seeded watermelon crop type.',
            false,
            false,
            20
        ),
        (
            'WATERMELON',
            'WATERMELON_MINI',
            'Mini',
            'Mini watermelon crop type.',
            false,
            false,
            30
        ),
        (
            'WATERMELON',
            'WATERMELON_OTHER',
            'Other',
            'Custom watermelon crop type entered by the user.',
            true,
            true,
            999
        ),

        ----------------------------------------------------------------------
        -- Potato
        ----------------------------------------------------------------------

        (
            'POTATO',
            'POTATO_EARLY',
            'Early',
            'Early-season potato crop type.',
            false,
            false,
            10
        ),
        (
            'POTATO',
            'POTATO_MID',
            'Mid',
            'Mid-season potato crop type.',
            false,
            false,
            20
        ),
        (
            'POTATO',
            'POTATO_LATE',
            'Late',
            'Late-season potato crop type.',
            false,
            false,
            30
        ),
        (
            'POTATO',
            'POTATO_OTHER',
            'Other',
            'Custom potato crop type entered by the user.',
            true,
            true,
            999
        ),

        ----------------------------------------------------------------------
        -- Onion
        ----------------------------------------------------------------------

        (
            'ONION',
            'ONION_RED',
            'Red',
            'Red onion crop type.',
            false,
            false,
            10
        ),
        (
            'ONION',
            'ONION_YELLOW',
            'Yellow',
            'Yellow onion crop type.',
            false,
            false,
            20
        ),
        (
            'ONION',
            'ONION_WHITE',
            'White',
            'White onion crop type.',
            false,
            false,
            30
        ),
        (
            'ONION',
            'ONION_OTHER',
            'Other',
            'Custom onion crop type entered by the user.',
            true,
            true,
            999
        ),

        ----------------------------------------------------------------------
        -- Carrot
        ----------------------------------------------------------------------

        (
            'CARROT',
            'CARROT_NANTES',
            'Nantes',
            'Nantes carrot crop type.',
            false,
            false,
            10
        ),
        (
            'CARROT',
            'CARROT_CHANTENAY',
            'Chantenay',
            'Chantenay carrot crop type.',
            false,
            false,
            20
        ),
        (
            'CARROT',
            'CARROT_IMPERATOR',
            'Imperator',
            'Imperator carrot crop type.',
            false,
            false,
            30
        ),
        (
            'CARROT',
            'CARROT_OTHER',
            'Other',
            'Custom carrot crop type entered by the user.',
            true,
            true,
            999
        ),

        ----------------------------------------------------------------------
        -- Aubergine
        ----------------------------------------------------------------------

        (
            'AUBERGINE',
            'AUBERGINE_LONG',
            'Long',
            'Long aubergine crop type.',
            false,
            false,
            10
        ),
        (
            'AUBERGINE',
            'AUBERGINE_OVAL',
            'Oval',
            'Oval aubergine crop type.',
            false,
            false,
            20
        ),
        (
            'AUBERGINE',
            'AUBERGINE_ROUND',
            'Round',
            'Round aubergine crop type.',
            false,
            false,
            30
        ),
        (
            'AUBERGINE',
            'AUBERGINE_OTHER',
            'Other',
            'Custom aubergine crop type entered by the user.',
            true,
            true,
            999
        ),

        ----------------------------------------------------------------------
        -- Courgette
        ----------------------------------------------------------------------

        (
            'COURGETTE',
            'COURGETTE_GREEN',
            'Green',
            'Green courgette crop type.',
            false,
            false,
            10
        ),
        (
            'COURGETTE',
            'COURGETTE_LIGHT_GREEN',
            'Light Green',
            'Light-green courgette crop type.',
            false,
            false,
            20
        ),
        (
            'COURGETTE',
            'COURGETTE_DARK_GREEN',
            'Dark Green',
            'Dark-green courgette crop type.',
            false,
            false,
            30
        ),
        (
            'COURGETTE',
            'COURGETTE_OTHER',
            'Other',
            'Custom courgette crop type entered by the user.',
            true,
            true,
            999
        ),

        ----------------------------------------------------------------------
        -- Beetroot
        ----------------------------------------------------------------------

        (
            'BEETROOT',
            'BEETROOT_ROUND',
            'Round',
            'Round beetroot crop type.',
            false,
            false,
            10
        ),
        (
            'BEETROOT',
            'BEETROOT_CYLINDRICAL',
            'Cylindrical',
            'Cylindrical beetroot crop type.',
            false,
            false,
            20
        ),
        (
            'BEETROOT',
            'BEETROOT_OTHER',
            'Other',
            'Custom beetroot crop type entered by the user.',
            true,
            true,
            999
        )
) AS seed
(
    crop_code,
    code,
    name,
    description,
    is_other,
    allows_custom_value,
    display_order
)
    ON c.code::text = seed.crop_code
WHERE c.deleted_at IS NULL
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- ADD "OTHER" TO ANY CURRENT CROP WITHOUT ONE
--------------------------------------------------------------------------------
-- Ensures that every crop currently in the crops table receives an Other option,
-- including crops that are not part of the initial confirmed seed list.
--------------------------------------------------------------------------------

INSERT INTO public.crop_types
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
    left(c.code::text || '_OTHER', 50),
    'Other',
    'Custom crop type entered by the user.',
    true,
    true,
    999
FROM public.crops c
WHERE c.deleted_at IS NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM public.crop_types ct
      WHERE ct.crop_id = c.id
        AND ct.is_other = true
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

    IF to_regclass('public.crop_types') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0019_crop_types.sql failed: public.crop_types was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'crop_types'
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
            'Migration 0019_crop_types.sql failed: crop_types has % of 14 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.crop_types'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0019_crop_types.sql failed: primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify crop relationship
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.crop_types'::regclass
          AND conname = 'fk_crop_types_crop'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0019_crop_types.sql failed: crop foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify audit foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.crop_types'::regclass
          AND conname = 'fk_crop_types_created_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0019_crop_types.sql failed: created_by foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.crop_types'::regclass
          AND conname = 'fk_crop_types_updated_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0019_crop_types.sql failed: updated_by foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_crop_types_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0019_crop_types.sql failed: unique crop-type code index is missing.';
    END IF;

    IF to_regclass('public.uq_crop_types_crop_name_normalized') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0019_crop_types.sql failed: unique crop/type-name index is missing.';
    END IF;

    IF to_regclass('public.uq_crop_types_one_other_per_crop') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0019_crop_types.sql failed: one-Other-per-crop index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify business validation function
    --------------------------------------------------------------------------

    IF to_regprocedure('public.trg_validate_crop_type()') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0019_crop_types.sql failed: crop-type validation function is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify business validation trigger
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.crop_types'::regclass
          AND tgname = 'trg_crop_types_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0019_crop_types.sql failed: crop-type validation trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify generic triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.crop_types'::regclass
          AND tgname = 'trg_crop_types_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0019_crop_types.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.crop_types'::regclass
          AND tgname = 'trg_crop_types_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0019_crop_types.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.crop_types'::regclass
          AND tgname = 'trg_crop_types_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0019_crop_types.sql failed: updated_by trigger is missing.';
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
          FROM public.crop_types ct
          WHERE ct.crop_id = c.id
            AND ct.is_other = true
            AND ct.allows_custom_value = true
      ) = 1;

    IF existing_crop_count <> crops_with_other THEN
        RAISE EXCEPTION
            'Migration 0019_crop_types.sql failed: only % of % crops have exactly one valid Other option.',
            crops_with_other,
            existing_crop_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify one-character Pepper classification
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM public.crop_types ct
        JOIN public.crops c
            ON c.id = ct.crop_id
        WHERE c.code::text = 'PEPPER'
          AND ct.name = 'G'
    ) THEN
        RAISE EXCEPTION
            'Migration 0019_crop_types.sql failed: Pepper classification G was not inserted.';
    END IF;
END;
$$;

COMMIT;
