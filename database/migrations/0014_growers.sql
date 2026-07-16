/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0014_growers.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the growers operational table.
*
* Growers represent agricultural producers whose farms may host Agrimatco
* seed variety trials.
*
* Frozen architectural rules:
*
*   • Every grower belongs to exactly one province.
*   • A grower name and primary contact phone are required.
*   • Farms are created separately in 0015_farms.sql.
*   • Region is derived through the grower's province.
*   • No company or country tables are introduced.
*   • Soft-deleted growers remain available for historical trial references.
*   • Row Level Security policies are intentionally deferred.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0003_domains.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
*   • 0013_provinces.sql
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
-- TABLE: growers
--------------------------------------------------------------------------------

CREATE TABLE public.growers
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                  uuid
                        PRIMARY KEY
                        DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Administrative Location
    --------------------------------------------------------------------------

    province_id         uuid
                        NOT NULL,

    --------------------------------------------------------------------------
    -- Grower Information
    --------------------------------------------------------------------------

    code                long_code
                        NOT NULL,

    name                long_name
                        NOT NULL,

    phone               phone_number
                        NOT NULL,

    email               email_address,

    address             text,

    remarks             description_text,

    --------------------------------------------------------------------------
    -- Operational State
    --------------------------------------------------------------------------

    is_active           boolean
                        NOT NULL
                        DEFAULT true,

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

    CONSTRAINT fk_growers_province
        FOREIGN KEY (province_id)
        REFERENCES public.provinces(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_growers_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_growers_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_growers_code_not_blank
        CHECK (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_growers_name_not_blank
        CHECK (
            length(btrim(name::text)) > 0
        ),

    CONSTRAINT chk_growers_phone_not_blank
        CHECK (
            length(btrim(phone::text)) > 0
        ),

    CONSTRAINT chk_growers_address_not_blank
        CHECK (
            address IS NULL
            OR length(btrim(address)) > 0
        ),

    CONSTRAINT chk_growers_address_length
        CHECK (
            address IS NULL
            OR char_length(btrim(address)) <= 1000
        ),

    CONSTRAINT chk_growers_updated_at
        CHECK (
            updated_at >= created_at
        ),

    CONSTRAINT chk_growers_deleted_at
        CHECK (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.growers IS
'Agricultural growers whose farms may host Agrimatco Morocco seed variety trials. Each grower belongs to one province.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.growers.id IS
'Internal UUID primary key of the grower.';

COMMENT ON COLUMN public.growers.province_id IS
'Province in which the grower operates. The associated region is derived through the province.';

COMMENT ON COLUMN public.growers.code IS
'Unique Agrimatco business code identifying the grower. Stored in uppercase by trigger.';

COMMENT ON COLUMN public.growers.name IS
'Full name or registered operational name of the grower.';

COMMENT ON COLUMN public.growers.phone IS
'Required primary contact phone number of the grower.';

COMMENT ON COLUMN public.growers.email IS
'Optional professional contact email address of the grower.';

COMMENT ON COLUMN public.growers.address IS
'Optional postal or descriptive address of the grower.';

COMMENT ON COLUMN public.growers.remarks IS
'Optional operational remarks concerning the grower.';

COMMENT ON COLUMN public.growers.is_active IS
'Indicates whether the grower is currently available for new trial installations.';

COMMENT ON COLUMN public.growers.created_at IS
'UTC timestamp when the grower record was created.';

COMMENT ON COLUMN public.growers.updated_at IS
'UTC timestamp when the grower record was most recently updated.';

COMMENT ON COLUMN public.growers.created_by IS
'Supabase Auth user who created the grower record.';

COMMENT ON COLUMN public.growers.updated_by IS
'Supabase Auth user who most recently updated the grower record.';

COMMENT ON COLUMN public.growers.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the grower has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

-- Grower codes are unique across Agrimatco Morocco regardless of casing
-- and surrounding whitespace.
CREATE UNIQUE INDEX uq_growers_code_ci
    ON public.growers
    (
        lower(btrim(code::text))
    );

-- Prevents duplicate growers with the same normalized name and phone number
-- inside the same province.
CREATE UNIQUE INDEX uq_growers_province_name_phone
    ON public.growers
    (
        province_id,
        public.fn_normalize_text(name::text),
        btrim(phone::text)
    );

--------------------------------------------------------------------------------
-- RELATIONSHIP AND FILTERING INDEXES
--------------------------------------------------------------------------------

-- Supports filtering growers by province.
CREATE INDEX idx_growers_province_id
    ON public.growers (province_id);

-- Supports active grower dropdowns filtered by province.
CREATE INDEX idx_growers_province_active_name
    ON public.growers
    (
        province_id,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

-- Supports administrative filtering by active state.
CREATE INDEX idx_growers_is_active
    ON public.growers (is_active)
    WHERE deleted_at IS NULL;

-- Supports lookups by telephone number.
CREATE INDEX idx_growers_phone
    ON public.growers
    (
        btrim(phone::text)
    )
    WHERE deleted_at IS NULL;

-- Supports optional email lookups.
CREATE INDEX idx_growers_email
    ON public.growers
    (
        lower(btrim(email::text))
    )
    WHERE email IS NOT NULL
      AND deleted_at IS NULL;

-- Supports soft-delete administration and restoration.
CREATE INDEX idx_growers_deleted_at
    ON public.growers (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEXES
--------------------------------------------------------------------------------

-- Supports fuzzy and partial grower-name searches.
CREATE INDEX idx_growers_name_trgm
    ON public.growers
    USING gin
    (
        (name::text) gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_growers_created_by
    ON public.growers (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_growers_updated_by
    ON public.growers (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

-- Trims leading and trailing whitespace from the grower name.
CREATE TRIGGER trg_growers_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.growers
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

-- Trims and converts grower codes to uppercase.
CREATE TRIGGER trg_growers_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.growers
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

-- Maintains created_at and updated_at timestamps.
CREATE TRIGGER trg_growers_timestamps
    BEFORE INSERT OR UPDATE
    ON public.growers
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

-- Stores the authenticated Supabase user who creates the record.
CREATE TRIGGER trg_growers_created_by
    BEFORE INSERT
    ON public.growers
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

-- Stores the authenticated Supabase user who updates the record.
CREATE TRIGGER trg_growers_updated_by
    BEFORE UPDATE
    ON public.growers
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

    IF to_regclass('public.growers') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0014_growers.sql failed: public.growers was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'growers'
      AND column_name IN
      (
          'id',
          'province_id',
          'code',
          'name',
          'phone',
          'email',
          'address',
          'remarks',
          'is_active',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF expected_column_count <> 14 THEN
        RAISE EXCEPTION
            'Migration 0014_growers.sql failed: growers has % of 14 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.growers'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0014_growers.sql failed: growers primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify province relationship
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.growers'::regclass
          AND conname = 'fk_growers_province'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0014_growers.sql failed: province foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify audit foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.growers'::regclass
          AND conname = 'fk_growers_created_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0014_growers.sql failed: created_by foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.growers'::regclass
          AND conname = 'fk_growers_updated_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0014_growers.sql failed: updated_by foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_growers_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0014_growers.sql failed: unique grower-code index is missing.';
    END IF;

    IF to_regclass('public.uq_growers_province_name_phone') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0014_growers.sql failed: duplicate-grower prevention index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify required triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.growers'::regclass
          AND tgname = 'trg_growers_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0014_growers.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.growers'::regclass
          AND tgname = 'trg_growers_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0014_growers.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.growers'::regclass
          AND tgname = 'trg_growers_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0014_growers.sql failed: updated_by trigger is missing.';
    END IF;
END;
$$;

COMMIT;
