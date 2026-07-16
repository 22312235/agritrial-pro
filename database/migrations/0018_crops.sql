/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0018_crops.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the crops configuration table.
*
* Crops represent the agricultural vegetables used in Agrimatco Morocco
* seed variety trials.
*
* Examples include:
*
*   • Tomatoes
*   • Peppers
*   • Cucumbers
*   • Onions
*   • Carrots
*   • Aubergines
*   • Courgettes
*   • Beetroots
*   • Watermelons
*   • Melons
*   • Potatoes
*
* Frozen architectural rules:
*
*   • Crops are configurable master data.
*   • Crop names and codes must be unique.
*   • Crop types are stored separately in 0019_crop_types.sql.
*   • Variety names remain manually entered at trial level.
*   • Crops may include an emoji for Flutter interfaces.
*   • Soft-deleted crops remain available for historical trial references.
*   • Row Level Security policies are intentionally deferred.
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
-- TABLE: crops
--------------------------------------------------------------------------------

CREATE TABLE public.crops
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                  uuid
                        PRIMARY KEY
                        DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Crop Information
    --------------------------------------------------------------------------

    code                short_code
                        NOT NULL,

    name                short_name
                        NOT NULL,

    emoji               varchar(20),

    description         description_text,

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

    CONSTRAINT fk_crops_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_crops_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_crops_code_not_blank
        CHECK (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_crops_name_not_blank
        CHECK (
            length(btrim(name::text)) > 0
        ),

    CONSTRAINT chk_crops_emoji
        CHECK (
            emoji IS NULL
            OR (
                length(btrim(emoji)) > 0
                AND char_length(emoji) <= 20
            )
        ),

    CONSTRAINT chk_crops_display_order
        CHECK (
            display_order >= 0
        ),

    CONSTRAINT chk_crops_updated_at
        CHECK (
            updated_at >= created_at
        ),

    CONSTRAINT chk_crops_deleted_at
        CHECK (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.crops IS
'Configurable agricultural crops used in Agrimatco Morocco seed variety trials. Crop types are stored separately.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.crops.id IS
'Internal UUID primary key of the crop.';

COMMENT ON COLUMN public.crops.code IS
'Unique Agrimatco business code identifying the crop. Stored in uppercase by trigger.';

COMMENT ON COLUMN public.crops.name IS
'Display name of the crop used in Flutter forms, dashboards, evaluations, and reports.';

COMMENT ON COLUMN public.crops.emoji IS
'Optional crop emoji displayed in Flutter interfaces.';

COMMENT ON COLUMN public.crops.description IS
'Optional agricultural or operational description of the crop.';

COMMENT ON COLUMN public.crops.is_active IS
'Indicates whether the crop is available for new trial installations and configuration assignments.';

COMMENT ON COLUMN public.crops.display_order IS
'Controls the order in which crops appear in Flutter dropdowns and configuration screens.';

COMMENT ON COLUMN public.crops.created_at IS
'UTC timestamp when the crop record was created.';

COMMENT ON COLUMN public.crops.updated_at IS
'UTC timestamp when the crop record was most recently updated.';

COMMENT ON COLUMN public.crops.created_by IS
'Supabase Auth user who created the crop record.';

COMMENT ON COLUMN public.crops.updated_by IS
'Supabase Auth user who most recently updated the crop record.';

COMMENT ON COLUMN public.crops.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the crop has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

-- Crop codes are unique regardless of casing and surrounding whitespace.
CREATE UNIQUE INDEX uq_crops_code_ci
    ON public.crops
    (
        lower(btrim(code::text))
    );

-- Crop names are unique regardless of casing, accents, and whitespace.
CREATE UNIQUE INDEX uq_crops_name_normalized
    ON public.crops
    (
        public.fn_normalize_text(name::text)
    );

--------------------------------------------------------------------------------
-- FILTERING AND SORTING INDEXES
--------------------------------------------------------------------------------

-- Supports active crop dropdowns ordered for Flutter interfaces.
CREATE INDEX idx_crops_active_display
    ON public.crops
    (
        display_order,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

-- Supports administrative filtering by active state.
CREATE INDEX idx_crops_is_active
    ON public.crops (is_active)
    WHERE deleted_at IS NULL;

-- Supports soft-delete administration and restoration.
CREATE INDEX idx_crops_deleted_at
    ON public.crops (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEXES
--------------------------------------------------------------------------------

-- Supports fuzzy and partial crop-name searches.
CREATE INDEX idx_crops_name_trgm
    ON public.crops
    USING gin
    (
        (name::text) gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_crops_created_by
    ON public.crops (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_crops_updated_by
    ON public.crops (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

-- Trims leading and trailing whitespace from crop names.
CREATE TRIGGER trg_crops_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.crops
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

-- Trims and converts crop codes to uppercase.
CREATE TRIGGER trg_crops_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.crops
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

-- Maintains created_at and updated_at timestamps.
CREATE TRIGGER trg_crops_timestamps
    BEFORE INSERT OR UPDATE
    ON public.crops
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

-- Stores the authenticated Supabase user who creates the record.
CREATE TRIGGER trg_crops_created_by
    BEFORE INSERT
    ON public.crops
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

-- Stores the authenticated Supabase user who updates the record.
CREATE TRIGGER trg_crops_updated_by
    BEFORE UPDATE
    ON public.crops
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- SEED DATA
--------------------------------------------------------------------------------
-- Initial confirmed vegetable crops.
--
-- The seed statement is idempotent by crop code.
--------------------------------------------------------------------------------

INSERT INTO public.crops
(
    code,
    name,
    emoji,
    description,
    display_order
)
VALUES
    (
        'CUCUMBER',
        'Cucumber',
        '🥒',
        'Cucumber crops used in seed variety trials.',
        10
    ),
    (
        'TOMATO',
        'Tomato',
        '🍅',
        'Tomato crops used in seed variety trials.',
        20
    ),
    (
        'ONION',
        'Onion',
        '🧅',
        'Onion crops used in seed variety trials.',
        30
    ),
    (
        'PEPPER',
        'Pepper',
        '🫑',
        'Pepper and poivron crops used in seed variety trials.',
        40
    ),
    (
        'CARROT',
        'Carrot',
        '🥕',
        'Carrot crops used in seed variety trials.',
        50
    ),
    (
        'AUBERGINE',
        'Aubergine',
        '🍆',
        'Aubergine and eggplant crops used in seed variety trials.',
        60
    ),
    (
        'COURGETTE',
        'Courgette',
        '🥒',
        'Courgette and zucchini crops used in seed variety trials.',
        70
    ),
    (
        'BEETROOT',
        'Beetroot',
        NULL,
        'Beetroot crops used in seed variety trials.',
        80
    ),
    (
        'WATERMELON',
        'Watermelon',
        '🍉',
        'Watermelon crops used in seed variety trials.',
        90
    ),
    (
        'MELON',
        'Melon',
        '🍈',
        'Melon crops used in seed variety trials.',
        100
    ),
    (
        'POTATO',
        'Potato',
        '🥔',
        'Potato crops used in seed variety trials.',
        110
    )
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- MIGRATION VALIDATION
--------------------------------------------------------------------------------

DO
$$
DECLARE
    expected_column_count integer;
    expected_seed_count   integer;
BEGIN
    --------------------------------------------------------------------------
    -- Verify table creation
    --------------------------------------------------------------------------

    IF to_regclass('public.crops') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0018_crops.sql failed: public.crops was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'crops'
      AND column_name IN
      (
          'id',
          'code',
          'name',
          'emoji',
          'description',
          'is_active',
          'display_order',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF expected_column_count <> 12 THEN
        RAISE EXCEPTION
            'Migration 0018_crops.sql failed: crops has % of 12 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.crops'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0018_crops.sql failed: crops primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify audit foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.crops'::regclass
          AND conname = 'fk_crops_created_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0018_crops.sql failed: created_by foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.crops'::regclass
          AND conname = 'fk_crops_updated_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0018_crops.sql failed: updated_by foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_crops_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0018_crops.sql failed: unique crop-code index is missing.';
    END IF;

    IF to_regclass('public.uq_crops_name_normalized') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0018_crops.sql failed: unique crop-name index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify required triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.crops'::regclass
          AND tgname = 'trg_crops_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0018_crops.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.crops'::regclass
          AND tgname = 'trg_crops_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0018_crops.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.crops'::regclass
          AND tgname = 'trg_crops_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0018_crops.sql failed: updated_by trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify confirmed seed data
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_seed_count
    FROM public.crops
    WHERE code::text IN
    (
        'CUCUMBER',
        'TOMATO',
        'ONION',
        'PEPPER',
        'CARROT',
        'AUBERGINE',
        'COURGETTE',
        'BEETROOT',
        'WATERMELON',
        'MELON',
        'POTATO'
    );

    IF expected_seed_count <> 11 THEN
        RAISE EXCEPTION
            'Migration 0018_crops.sql failed: only % of 11 confirmed crops were inserted.',
            expected_seed_count;
    END IF;
END;
$$;

COMMIT;
