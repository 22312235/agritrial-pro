/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0017_seasons.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the seasons configuration table.
*
* Seasons represent agricultural trial periods used to:
*
*   • Organize trials by campaign
*   • Compare variety performance between seasons
*   • Filter operational and executive dashboards
*   • Generate seasonal PDF reports
*   • Support historical analysis
*
* Frozen architectural rules:
*
*   • Every season has a defined start date and end date.
*   • The end date must be on or after the start date.
*   • Seasons are configuration records managed by authorized users.
*   • Season records support soft deletion.
*   • Row Level Security policies are intentionally deferred.
*   • No country or company relationship is introduced.
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
-- TABLE: seasons
--------------------------------------------------------------------------------

CREATE TABLE public.seasons
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                  uuid
                        PRIMARY KEY
                        DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Season Information
    --------------------------------------------------------------------------

    code                long_code
                        NOT NULL,

    name                long_name
                        NOT NULL,

    start_date          date
                        NOT NULL,

    end_date            date
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

    CONSTRAINT fk_seasons_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_seasons_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_seasons_code_not_blank
        CHECK (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_seasons_name_not_blank
        CHECK (
            length(btrim(name::text)) > 0
        ),

    CONSTRAINT chk_seasons_date_range
        CHECK (
            end_date >= start_date
        ),

    CONSTRAINT chk_seasons_display_order
        CHECK (
            display_order >= 0
        ),

    CONSTRAINT chk_seasons_updated_at
        CHECK (
            updated_at >= created_at
        ),

    CONSTRAINT chk_seasons_deleted_at
        CHECK (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.seasons IS
'Agricultural trial seasons used to organize trials, compare performance between campaigns, filter dashboards, and generate seasonal reports.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.seasons.id IS
'Internal UUID primary key of the agricultural season.';

COMMENT ON COLUMN public.seasons.code IS
'Unique Agrimatco business code identifying the season. Stored in uppercase by trigger.';

COMMENT ON COLUMN public.seasons.name IS
'Display name of the agricultural trial season.';

COMMENT ON COLUMN public.seasons.start_date IS
'First calendar date included in the agricultural season.';

COMMENT ON COLUMN public.seasons.end_date IS
'Final calendar date included in the agricultural season. Must not be before start_date.';

COMMENT ON COLUMN public.seasons.description IS
'Optional administrative or operational description of the season.';

COMMENT ON COLUMN public.seasons.is_active IS
'Indicates whether the season is available for selection in new trial installations.';

COMMENT ON COLUMN public.seasons.display_order IS
'Controls the order in which seasons appear in Flutter dropdowns and administrative interfaces.';

COMMENT ON COLUMN public.seasons.created_at IS
'UTC timestamp when the season record was created.';

COMMENT ON COLUMN public.seasons.updated_at IS
'UTC timestamp when the season record was most recently updated.';

COMMENT ON COLUMN public.seasons.created_by IS
'Supabase Auth user who created the season record.';

COMMENT ON COLUMN public.seasons.updated_by IS
'Supabase Auth user who most recently updated the season record.';

COMMENT ON COLUMN public.seasons.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the season has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

-- Season codes are unique across Agrimatco Morocco regardless of casing
-- and surrounding whitespace.
CREATE UNIQUE INDEX uq_seasons_code_ci
    ON public.seasons
    (
        lower(btrim(code::text))
    );

-- Season names are unique regardless of casing, accents, and whitespace.
CREATE UNIQUE INDEX uq_seasons_name_normalized
    ON public.seasons
    (
        public.fn_normalize_text(name::text)
    );

--------------------------------------------------------------------------------
-- DATE AND FILTERING INDEXES
--------------------------------------------------------------------------------

-- Supports chronological season listings.
CREATE INDEX idx_seasons_date_range
    ON public.seasons
    (
        start_date,
        end_date
    );

-- Supports finding the season containing a specific date.
CREATE INDEX idx_seasons_start_date
    ON public.seasons (start_date);

CREATE INDEX idx_seasons_end_date
    ON public.seasons (end_date);

-- Supports active season dropdowns ordered by date and display preference.
CREATE INDEX idx_seasons_active_display
    ON public.seasons
    (
        display_order,
        start_date DESC,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

-- Supports administrative filtering by active state.
CREATE INDEX idx_seasons_is_active
    ON public.seasons (is_active)
    WHERE deleted_at IS NULL;

-- Supports soft-delete administration and restoration.
CREATE INDEX idx_seasons_deleted_at
    ON public.seasons (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEXES
--------------------------------------------------------------------------------

-- Supports fuzzy and partial searches by season name.
CREATE INDEX idx_seasons_name_trgm
    ON public.seasons
    USING gin
    (
        (name::text) gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_seasons_created_by
    ON public.seasons (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_seasons_updated_by
    ON public.seasons (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

-- Trims leading and trailing whitespace from the season name.
CREATE TRIGGER trg_seasons_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.seasons
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

-- Trims and converts season codes to uppercase.
CREATE TRIGGER trg_seasons_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.seasons
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

-- Maintains created_at and updated_at timestamps.
CREATE TRIGGER trg_seasons_timestamps
    BEFORE INSERT OR UPDATE
    ON public.seasons
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

-- Stores the authenticated Supabase user who creates the record.
CREATE TRIGGER trg_seasons_created_by
    BEFORE INSERT
    ON public.seasons
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

-- Stores the authenticated Supabase user who updates the record.
CREATE TRIGGER trg_seasons_updated_by
    BEFORE UPDATE
    ON public.seasons
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

    IF to_regclass('public.seasons') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0017_seasons.sql failed: public.seasons was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'seasons'
      AND column_name IN
      (
          'id',
          'code',
          'name',
          'start_date',
          'end_date',
          'description',
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
            'Migration 0017_seasons.sql failed: seasons has % of 13 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.seasons'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0017_seasons.sql failed: seasons primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify audit foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.seasons'::regclass
          AND conname = 'fk_seasons_created_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0017_seasons.sql failed: created_by foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.seasons'::regclass
          AND conname = 'fk_seasons_updated_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0017_seasons.sql failed: updated_by foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify date-range constraint
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.seasons'::regclass
          AND conname = 'chk_seasons_date_range'
          AND contype = 'c'
    ) THEN
        RAISE EXCEPTION
            'Migration 0017_seasons.sql failed: season date-range constraint is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_seasons_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0017_seasons.sql failed: unique season-code index is missing.';
    END IF;

    IF to_regclass('public.uq_seasons_name_normalized') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0017_seasons.sql failed: unique season-name index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify required triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.seasons'::regclass
          AND tgname = 'trg_seasons_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0017_seasons.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.seasons'::regclass
          AND tgname = 'trg_seasons_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0017_seasons.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.seasons'::regclass
          AND tgname = 'trg_seasons_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0017_seasons.sql failed: updated_by trigger is missing.';
    END IF;
END;
$$;

COMMIT;
