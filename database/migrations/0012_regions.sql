/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0012_regions.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the regions configuration table.
*
* Regions represent the administrative regions of Morocco used to organize:
*
*   • Provinces
*   • Growers
*   • Farms
*   • Experimental stations
*   • Agricultural trials
*   • Operational dashboards
*   • Regional reports
*
* Region records are configuration data managed by authorized users.
*
* This migration intentionally does not:
*
*   • Create countries
*   • Create companies
*   • Add Row Level Security policies
*   • Insert unconfirmed business seed data
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0003_domains.sql
*   • 0005_trigger_functions.sql
*   • 0011_profiles.sql
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
-- TABLE: regions
--------------------------------------------------------------------------------

CREATE TABLE public.regions
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                  uuid
                        PRIMARY KEY
                        DEFAULT gen_random_uuid(),

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

    CONSTRAINT fk_regions_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_regions_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_regions_code_not_blank
        CHECK (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_regions_name_not_blank
        CHECK (
            length(btrim(name::text)) > 0
        ),

    CONSTRAINT chk_regions_display_order
        CHECK (
            display_order >= 0
        ),

    CONSTRAINT chk_regions_updated_at
        CHECK (
            updated_at >= created_at
        ),

    CONSTRAINT chk_regions_deleted_at
        CHECK (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.regions IS
'Moroccan administrative regions used for provinces, growers, farms, experimental stations, trials, dashboards, and reports.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.regions.id IS
'Internal UUID primary key of the region.';

COMMENT ON COLUMN public.regions.code IS
'Unique business code identifying the region. Stored in uppercase by trigger.';

COMMENT ON COLUMN public.regions.name IS
'Official display name of the Moroccan administrative region.';

COMMENT ON COLUMN public.regions.description IS
'Optional administrative or operational description of the region.';

COMMENT ON COLUMN public.regions.is_active IS
'Indicates whether the region is available for selection in AgriTrial Pro.';

COMMENT ON COLUMN public.regions.display_order IS
'Controls the order in which regions appear in Flutter dropdowns and administrative interfaces.';

COMMENT ON COLUMN public.regions.created_at IS
'UTC timestamp when the region record was created.';

COMMENT ON COLUMN public.regions.updated_at IS
'UTC timestamp when the region record was most recently updated.';

COMMENT ON COLUMN public.regions.created_by IS
'Supabase Auth user who created the region record.';

COMMENT ON COLUMN public.regions.updated_by IS
'Supabase Auth user who most recently updated the region record.';

COMMENT ON COLUMN public.regions.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the region has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

-- Region codes are unique regardless of casing and surrounding whitespace.
CREATE UNIQUE INDEX uq_regions_code_ci
    ON public.regions
    (
        lower(btrim(code::text))
    );

-- Active and historical region names are unique regardless of casing,
-- accents, and surrounding whitespace.
CREATE UNIQUE INDEX uq_regions_name_normalized
    ON public.regions
    (
        public.fn_normalize_text(name::text)
    );

--------------------------------------------------------------------------------
-- FILTERING AND SORTING INDEXES
--------------------------------------------------------------------------------

-- Supports active dropdown lists ordered for Flutter forms.
CREATE INDEX idx_regions_active_display_order
    ON public.regions
    (
        display_order,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

-- Supports administrative filtering by active state.
CREATE INDEX idx_regions_is_active
    ON public.regions (is_active)
    WHERE deleted_at IS NULL;

-- Supports soft-deleted record administration and restoration.
CREATE INDEX idx_regions_deleted_at
    ON public.regions (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEXES
--------------------------------------------------------------------------------

-- Supports case-insensitive and fuzzy region-name searches.
CREATE INDEX idx_regions_name_trgm
    ON public.regions
    USING gin
    (
        (name::text) gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_regions_created_by
    ON public.regions (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_regions_updated_by
    ON public.regions (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

-- Trims whitespace from the region name.
CREATE TRIGGER trg_regions_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.regions
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

-- Trims and converts region codes to uppercase.
CREATE TRIGGER trg_regions_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.regions
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

-- Maintains created_at and updated_at timestamps.
CREATE TRIGGER trg_regions_timestamps
    BEFORE INSERT OR UPDATE
    ON public.regions
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

-- Stores the authenticated Supabase user who creates the record.
CREATE TRIGGER trg_regions_created_by
    BEFORE INSERT
    ON public.regions
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

-- Stores the authenticated Supabase user who updates the record.
CREATE TRIGGER trg_regions_updated_by
    BEFORE UPDATE
    ON public.regions
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

    IF to_regclass('public.regions') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0012_regions.sql failed: public.regions was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'regions'
      AND column_name IN
      (
          'id',
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

    IF expected_column_count <> 11 THEN
        RAISE EXCEPTION
            'Migration 0012_regions.sql failed: regions has % of 11 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.regions'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0012_regions.sql failed: regions primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify required foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.regions'::regclass
          AND conname = 'fk_regions_created_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0012_regions.sql failed: created_by foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.regions'::regclass
          AND conname = 'fk_regions_updated_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0012_regions.sql failed: updated_by foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify required indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_regions_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0012_regions.sql failed: unique region-code index is missing.';
    END IF;

    IF to_regclass('public.uq_regions_name_normalized') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0012_regions.sql failed: unique region-name index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify required triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.regions'::regclass
          AND tgname = 'trg_regions_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0012_regions.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.regions'::regclass
          AND tgname = 'trg_regions_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0012_regions.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.regions'::regclass
          AND tgname = 'trg_regions_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0012_regions.sql failed: updated_by trigger is missing.';
    END IF;
END;
$$;

COMMIT;
