/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0013_provinces.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the provinces configuration table.
*
* Provinces belong to Moroccan administrative regions and are used to organize:
*
*   • Growers
*   • Farms
*   • Experimental stations
*   • Trial installation locations
*   • Operational dashboards
*   • Regional and provincial reports
*
* Architectural rules:
*
*   • Every province belongs to exactly one region.
*   • Province codes are unique across the system.
*   • Province names are unique within the same region.
*   • Soft-deleted records remain available for historical references.
*   • Row Level Security policies are intentionally deferred.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0003_domains.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
*   • 0012_regions.sql
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
-- TABLE: provinces
--------------------------------------------------------------------------------

CREATE TABLE public.provinces
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                  uuid
                        PRIMARY KEY
                        DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Parent Region
    --------------------------------------------------------------------------

    region_id           uuid
                        NOT NULL,

    --------------------------------------------------------------------------
    -- Business Information
    --------------------------------------------------------------------------

    code                short_code
                        NOT NULL,

    name                short_name
                        NOT NULL,

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

    CONSTRAINT fk_provinces_region
        FOREIGN KEY (region_id)
        REFERENCES public.regions(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_provinces_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_provinces_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_provinces_code_not_blank
        CHECK (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_provinces_name_not_blank
        CHECK (
            length(btrim(name::text)) > 0
        ),

    CONSTRAINT chk_provinces_display_order
        CHECK (
            display_order >= 0
        ),

    CONSTRAINT chk_provinces_updated_at
        CHECK (
            updated_at >= created_at
        ),

    CONSTRAINT chk_provinces_deleted_at
        CHECK (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.provinces IS
'Moroccan provinces and prefectures linked to administrative regions. Used by growers, farms, experimental stations, trials, dashboards, and reports.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.provinces.id IS
'Internal UUID primary key of the province.';

COMMENT ON COLUMN public.provinces.region_id IS
'Administrative region to which the province belongs.';

COMMENT ON COLUMN public.provinces.code IS
'Unique business code identifying the province. Stored in uppercase by trigger.';

COMMENT ON COLUMN public.provinces.name IS
'Official display name of the Moroccan province or prefecture.';

COMMENT ON COLUMN public.provinces.description IS
'Optional administrative or operational description of the province.';

COMMENT ON COLUMN public.provinces.is_active IS
'Indicates whether the province is currently available in AgriTrial Pro dropdowns and configuration screens.';

COMMENT ON COLUMN public.provinces.display_order IS
'Controls the ordering of provinces within a region in Flutter dropdowns and administrative interfaces.';

COMMENT ON COLUMN public.provinces.created_at IS
'UTC timestamp when the province record was created.';

COMMENT ON COLUMN public.provinces.updated_at IS
'UTC timestamp when the province record was most recently updated.';

COMMENT ON COLUMN public.provinces.created_by IS
'Supabase Auth user who created the province record.';

COMMENT ON COLUMN public.provinces.updated_by IS
'Supabase Auth user who most recently updated the province record.';

COMMENT ON COLUMN public.provinces.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the province has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

-- Province codes are unique across Agrimatco Morocco regardless of casing
-- and surrounding whitespace.
CREATE UNIQUE INDEX uq_provinces_code_ci
    ON public.provinces
    (
        lower(btrim(code::text))
    );

-- Province names are unique within their assigned region, regardless of
-- casing, accents, and surrounding whitespace.
CREATE UNIQUE INDEX uq_provinces_region_name_normalized
    ON public.provinces
    (
        region_id,
        public.fn_normalize_text(name::text)
    );

--------------------------------------------------------------------------------
-- RELATIONSHIP AND FILTERING INDEXES
--------------------------------------------------------------------------------

-- Supports filtering provinces by region.
CREATE INDEX idx_provinces_region_id
    ON public.provinces (region_id);

-- Supports active province dropdowns filtered by region.
CREATE INDEX idx_provinces_region_active_display
    ON public.provinces
    (
        region_id,
        display_order,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

-- Supports administrative active-state filtering.
CREATE INDEX idx_provinces_is_active
    ON public.provinces (is_active)
    WHERE deleted_at IS NULL;

-- Supports soft-delete administration and restoration.
CREATE INDEX idx_provinces_deleted_at
    ON public.provinces (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEXES
--------------------------------------------------------------------------------

-- Supports fuzzy and partial searches by province name.
CREATE INDEX idx_provinces_name_trgm
    ON public.provinces
    USING gin
    (
        (name::text) gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_provinces_created_by
    ON public.provinces (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_provinces_updated_by
    ON public.provinces (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

-- Trims leading and trailing whitespace from province names.
CREATE TRIGGER trg_provinces_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.provinces
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

-- Trims and converts province codes to uppercase.
CREATE TRIGGER trg_provinces_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.provinces
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

-- Maintains created_at and updated_at timestamps.
CREATE TRIGGER trg_provinces_timestamps
    BEFORE INSERT OR UPDATE
    ON public.provinces
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

-- Stores the authenticated Supabase user who creates the record.
CREATE TRIGGER trg_provinces_created_by
    BEFORE INSERT
    ON public.provinces
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

-- Stores the authenticated Supabase user who updates the record.
CREATE TRIGGER trg_provinces_updated_by
    BEFORE UPDATE
    ON public.provinces
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

    IF to_regclass('public.provinces') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0013_provinces.sql failed: public.provinces was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'provinces'
      AND column_name IN
      (
          'id',
          'region_id',
          'code',
          'name',
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
            'Migration 0013_provinces.sql failed: provinces has % of 12 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.provinces'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0013_provinces.sql failed: provinces primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify region relationship
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.provinces'::regclass
          AND conname = 'fk_provinces_region'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0013_provinces.sql failed: region foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify audit foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.provinces'::regclass
          AND conname = 'fk_provinces_created_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0013_provinces.sql failed: created_by foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.provinces'::regclass
          AND conname = 'fk_provinces_updated_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0013_provinces.sql failed: updated_by foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_provinces_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0013_provinces.sql failed: unique province-code index is missing.';
    END IF;

    IF to_regclass('public.uq_provinces_region_name_normalized') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0013_provinces.sql failed: unique region/province-name index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify required triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.provinces'::regclass
          AND tgname = 'trg_provinces_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0013_provinces.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.provinces'::regclass
          AND tgname = 'trg_provinces_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0013_provinces.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.provinces'::regclass
          AND tgname = 'trg_provinces_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0013_provinces.sql failed: updated_by trigger is missing.';
    END IF;
END;
$$;

COMMIT;
