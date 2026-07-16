/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0015_farms.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the farms operational table.
*
* Farms represent agricultural locations owned or managed by growers where
* Agrimatco Morocco seed variety trials may be installed.
*
* Frozen architectural rules:
*
*   • Every farm belongs to exactly one grower.
*   • Every farm belongs to exactly one province.
*   • The farm province must match the grower's province.
*   • Region is derived through the selected province.
*   • Geographic coordinates use PostGIS.
*   • A trial may later reference either a farm or an experimental station,
*     never both.
*   • Soft-deleted farms remain available for historical trial references.
*   • Row Level Security policies are intentionally deferred.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0003_domains.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
*   • 0013_provinces.sql
*   • 0014_growers.sql
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
-- TABLE: farms
--------------------------------------------------------------------------------

CREATE TABLE public.farms
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                  uuid
                        PRIMARY KEY
                        DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Grower and Administrative Location
    --------------------------------------------------------------------------

    grower_id           uuid
                        NOT NULL,

    province_id         uuid
                        NOT NULL,

    --------------------------------------------------------------------------
    -- Farm Information
    --------------------------------------------------------------------------

    code                long_code
                        NOT NULL,

    name                long_name
                        NOT NULL,

    address             text,

    location            geometry(Point, 4326),

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

    CONSTRAINT fk_farms_grower
        FOREIGN KEY (grower_id)
        REFERENCES public.growers(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_farms_province
        FOREIGN KEY (province_id)
        REFERENCES public.provinces(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_farms_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_farms_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_farms_code_not_blank
        CHECK (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_farms_name_not_blank
        CHECK (
            length(btrim(name::text)) > 0
        ),

    CONSTRAINT chk_farms_address_not_blank
        CHECK (
            address IS NULL
            OR length(btrim(address)) > 0
        ),

    CONSTRAINT chk_farms_address_length
        CHECK (
            address IS NULL
            OR char_length(btrim(address)) <= 1000
        ),

    CONSTRAINT chk_farms_location_srid
        CHECK (
            location IS NULL
            OR ST_SRID(location) = 4326
        ),

    CONSTRAINT chk_farms_location_type
        CHECK (
            location IS NULL
            OR GeometryType(location) = 'POINT'
        ),

    CONSTRAINT chk_farms_longitude
        CHECK (
            location IS NULL
            OR ST_X(location) BETWEEN -180 AND 180
        ),

    CONSTRAINT chk_farms_latitude
        CHECK (
            location IS NULL
            OR ST_Y(location) BETWEEN -90 AND 90
        ),

    CONSTRAINT chk_farms_updated_at
        CHECK (
            updated_at >= created_at
        ),

    CONSTRAINT chk_farms_deleted_at
        CHECK (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.farms IS
'Agricultural farms belonging to growers and used as possible installation locations for Agrimatco Morocco seed variety trials.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.farms.id IS
'Internal UUID primary key of the farm.';

COMMENT ON COLUMN public.farms.grower_id IS
'Grower who owns, manages, or operates the farm.';

COMMENT ON COLUMN public.farms.province_id IS
'Province in which the farm is located. It must match the province assigned to the grower.';

COMMENT ON COLUMN public.farms.code IS
'Unique Agrimatco business code identifying the farm. Stored in uppercase by trigger.';

COMMENT ON COLUMN public.farms.name IS
'Operational or commonly used name of the farm.';

COMMENT ON COLUMN public.farms.address IS
'Optional postal or descriptive address of the farm.';

COMMENT ON COLUMN public.farms.location IS
'Optional PostGIS geographic point containing the farm longitude and latitude in SRID 4326.';

COMMENT ON COLUMN public.farms.remarks IS
'Optional operational remarks concerning the farm.';

COMMENT ON COLUMN public.farms.is_active IS
'Indicates whether the farm is currently available for new trial installations.';

COMMENT ON COLUMN public.farms.created_at IS
'UTC timestamp when the farm record was created.';

COMMENT ON COLUMN public.farms.updated_at IS
'UTC timestamp when the farm record was most recently updated.';

COMMENT ON COLUMN public.farms.created_by IS
'Supabase Auth user who created the farm record.';

COMMENT ON COLUMN public.farms.updated_by IS
'Supabase Auth user who most recently updated the farm record.';

COMMENT ON COLUMN public.farms.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the farm has not been deleted.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------
-- Ensures that the farm's selected province matches the province assigned
-- to the selected grower.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_farm_grower_province()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    grower_province_id uuid;
    grower_is_active   boolean;
    grower_deleted_at  timestamptz;
    province_deleted_at timestamptz;
BEGIN
    --------------------------------------------------------------------------
    -- Resolve grower province and state
    --------------------------------------------------------------------------

    SELECT
        g.province_id,
        g.is_active,
        g.deleted_at
    INTO
        grower_province_id,
        grower_is_active,
        grower_deleted_at
    FROM public.growers g
    WHERE g.id = NEW.grower_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Farm validation failed: grower %s does not exist.',
                    NEW.grower_id
                );
    END IF;

    --------------------------------------------------------------------------
    -- Prevent selection of a soft-deleted grower for a new or changed farm
    --------------------------------------------------------------------------

    IF grower_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = format(
                    'Farm validation failed: grower %s is soft-deleted.',
                    NEW.grower_id
                );
    END IF;

    --------------------------------------------------------------------------
    -- Prevent selection of an inactive grower for an active farm
    --------------------------------------------------------------------------

    IF NEW.is_active = true
       AND grower_is_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = format(
                    'Farm validation failed: an active farm cannot belong to inactive grower %s.',
                    NEW.grower_id
                );
    END IF;

    --------------------------------------------------------------------------
    -- Ensure farm province matches grower province
    --------------------------------------------------------------------------

    IF grower_province_id IS DISTINCT FROM NEW.province_id THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = format(
                    'Farm validation failed: farm province %s does not match grower province %s.',
                    NEW.province_id,
                    grower_province_id
                );
    END IF;

    --------------------------------------------------------------------------
    -- Prevent selection of a soft-deleted province
    --------------------------------------------------------------------------

    SELECT p.deleted_at
    INTO province_deleted_at
    FROM public.provinces p
    WHERE p.id = NEW.province_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Farm validation failed: province %s does not exist.',
                    NEW.province_id
                );
    END IF;

    IF province_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = format(
                    'Farm validation failed: province %s is soft-deleted.',
                    NEW.province_id
                );
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_farm_grower_province() IS
'Validates that a farm belongs to the same province as its grower and prevents active farms from referencing inactive or soft-deleted growers.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

-- Farm codes are unique across Agrimatco Morocco regardless of casing
-- and surrounding whitespace.
CREATE UNIQUE INDEX uq_farms_code_ci
    ON public.farms
    (
        lower(btrim(code::text))
    );

-- Prevents duplicate normalized farm names for the same grower.
CREATE UNIQUE INDEX uq_farms_grower_name_normalized
    ON public.farms
    (
        grower_id,
        public.fn_normalize_text(name::text)
    );

--------------------------------------------------------------------------------
-- RELATIONSHIP AND FILTERING INDEXES
--------------------------------------------------------------------------------

-- Supports filtering farms by grower.
CREATE INDEX idx_farms_grower_id
    ON public.farms (grower_id);

-- Supports filtering farms by province.
CREATE INDEX idx_farms_province_id
    ON public.farms (province_id);

-- Supports the cascading Flutter selection:
-- province → grower → farm.
CREATE INDEX idx_farms_province_grower
    ON public.farms
    (
        province_id,
        grower_id
    );

-- Supports active farm dropdowns for a selected grower.
CREATE INDEX idx_farms_grower_active_name
    ON public.farms
    (
        grower_id,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

-- Supports active farm dropdowns filtered by province and grower.
CREATE INDEX idx_farms_province_grower_active
    ON public.farms
    (
        province_id,
        grower_id,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

-- Supports administrative filtering by active state.
CREATE INDEX idx_farms_is_active
    ON public.farms (is_active)
    WHERE deleted_at IS NULL;

-- Supports soft-delete administration and restoration.
CREATE INDEX idx_farms_deleted_at
    ON public.farms (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SPATIAL INDEX
--------------------------------------------------------------------------------

-- Supports map views, distance searches, and spatial analysis.
CREATE INDEX idx_farms_location_gist
    ON public.farms
    USING gist (location)
    WHERE location IS NOT NULL
      AND deleted_at IS NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEXES
--------------------------------------------------------------------------------

-- Supports fuzzy and partial searches by farm name.
CREATE INDEX idx_farms_name_trgm
    ON public.farms
    USING gin
    (
        (name::text) gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_farms_created_by
    ON public.farms (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_farms_updated_by
    ON public.farms (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_farms_validate_grower_province
    BEFORE INSERT OR UPDATE OF grower_id, province_id, is_active
    ON public.farms
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_farm_grower_province();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

-- Trims leading and trailing whitespace from the farm name.
CREATE TRIGGER trg_farms_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.farms
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

-- Trims and converts farm codes to uppercase.
CREATE TRIGGER trg_farms_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.farms
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

-- Maintains created_at and updated_at timestamps.
CREATE TRIGGER trg_farms_timestamps
    BEFORE INSERT OR UPDATE
    ON public.farms
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

-- Stores the authenticated Supabase user who creates the record.
CREATE TRIGGER trg_farms_created_by
    BEFORE INSERT
    ON public.farms
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

-- Stores the authenticated Supabase user who updates the record.
CREATE TRIGGER trg_farms_updated_by
    BEFORE UPDATE
    ON public.farms
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

    IF to_regclass('public.farms') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0015_farms.sql failed: public.farms was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'farms'
      AND column_name IN
      (
          'id',
          'grower_id',
          'province_id',
          'code',
          'name',
          'address',
          'location',
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
            'Migration 0015_farms.sql failed: farms has % of 14 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.farms'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0015_farms.sql failed: farms primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify required foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.farms'::regclass
          AND conname = 'fk_farms_grower'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0015_farms.sql failed: grower foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.farms'::regclass
          AND conname = 'fk_farms_province'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0015_farms.sql failed: province foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_farms_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0015_farms.sql failed: unique farm-code index is missing.';
    END IF;

    IF to_regclass('public.uq_farms_grower_name_normalized') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0015_farms.sql failed: unique grower/farm-name index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify spatial index
    --------------------------------------------------------------------------

    IF to_regclass('public.idx_farms_location_gist') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0015_farms.sql failed: farm spatial index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify business validation function
    --------------------------------------------------------------------------

    IF to_regprocedure(
        'public.trg_validate_farm_grower_province()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0015_farms.sql failed: farm grower/province validation function is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify required triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.farms'::regclass
          AND tgname = 'trg_farms_validate_grower_province'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0015_farms.sql failed: grower/province validation trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.farms'::regclass
          AND tgname = 'trg_farms_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0015_farms.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.farms'::regclass
          AND tgname = 'trg_farms_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0015_farms.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.farms'::regclass
          AND tgname = 'trg_farms_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0015_farms.sql failed: updated_by trigger is missing.';
    END IF;
END;
$$;

COMMIT;
