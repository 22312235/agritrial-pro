/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0016_experimental_stations.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the experimental_stations configuration table.
*
* Experimental stations are Agrimatco-approved agricultural locations where
* seed variety trials may be installed without using a grower and farm.
*
* Frozen architectural rules:
*
*   • Every experimental station belongs to exactly one province.
*   • Region is derived through the selected province.
*   • Geographic coordinates use PostGIS.
*   • A trial may reference either a farm or an experimental station,
*     never both.
*   • Experimental stations are configuration records managed by authorized users.
*   • Soft-deleted stations remain available for historical trial references.
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
-- TABLE: experimental_stations
--------------------------------------------------------------------------------

CREATE TABLE public.experimental_stations
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
    -- Station Information
    --------------------------------------------------------------------------

    code                long_code
                        NOT NULL,

    name                long_name
                        NOT NULL,

    contact_name        varchar(200),

    phone               phone_number,

    email               email_address,

    address             text,

    location            geometry(Point, 4326),

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

    CONSTRAINT fk_experimental_stations_province
        FOREIGN KEY (province_id)
        REFERENCES public.provinces(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_experimental_stations_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_experimental_stations_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_experimental_stations_code_not_blank
        CHECK (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_experimental_stations_name_not_blank
        CHECK (
            length(btrim(name::text)) > 0
        ),

    CONSTRAINT chk_experimental_stations_contact_name
        CHECK (
            contact_name IS NULL
            OR (
                length(btrim(contact_name)) > 0
                AND char_length(btrim(contact_name)) <= 200
            )
        ),

    CONSTRAINT chk_experimental_stations_address
        CHECK (
            address IS NULL
            OR (
                length(btrim(address)) > 0
                AND char_length(btrim(address)) <= 1000
            )
        ),

    CONSTRAINT chk_experimental_stations_display_order
        CHECK (
            display_order >= 0
        ),

    CONSTRAINT chk_experimental_stations_location_srid
        CHECK (
            location IS NULL
            OR ST_SRID(location) = 4326
        ),

    CONSTRAINT chk_experimental_stations_location_type
        CHECK (
            location IS NULL
            OR GeometryType(location) = 'POINT'
        ),

    CONSTRAINT chk_experimental_stations_longitude
        CHECK (
            location IS NULL
            OR ST_X(location) BETWEEN -180 AND 180
        ),

    CONSTRAINT chk_experimental_stations_latitude
        CHECK (
            location IS NULL
            OR ST_Y(location) BETWEEN -90 AND 90
        ),

    CONSTRAINT chk_experimental_stations_updated_at
        CHECK (
            updated_at >= created_at
        ),

    CONSTRAINT chk_experimental_stations_deleted_at
        CHECK (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.experimental_stations IS
'Agrimatco-approved experimental stations that may host seed variety trials independently from growers and farms.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.experimental_stations.id IS
'Internal UUID primary key of the experimental station.';

COMMENT ON COLUMN public.experimental_stations.province_id IS
'Province in which the experimental station is located. The region is derived through the province.';

COMMENT ON COLUMN public.experimental_stations.code IS
'Unique Agrimatco business code identifying the experimental station. Stored in uppercase by trigger.';

COMMENT ON COLUMN public.experimental_stations.name IS
'Official or operational name of the experimental station.';

COMMENT ON COLUMN public.experimental_stations.contact_name IS
'Optional primary contact person for the experimental station.';

COMMENT ON COLUMN public.experimental_stations.phone IS
'Optional contact phone number for the experimental station.';

COMMENT ON COLUMN public.experimental_stations.email IS
'Optional professional contact email address for the experimental station.';

COMMENT ON COLUMN public.experimental_stations.address IS
'Optional postal or descriptive address of the experimental station.';

COMMENT ON COLUMN public.experimental_stations.location IS
'Optional PostGIS point containing longitude and latitude using SRID 4326.';

COMMENT ON COLUMN public.experimental_stations.description IS
'Optional administrative or operational description of the experimental station.';

COMMENT ON COLUMN public.experimental_stations.is_active IS
'Indicates whether the experimental station is available for new trial installations.';

COMMENT ON COLUMN public.experimental_stations.display_order IS
'Controls station ordering in Flutter dropdowns and administrative interfaces.';

COMMENT ON COLUMN public.experimental_stations.created_at IS
'UTC timestamp when the experimental station record was created.';

COMMENT ON COLUMN public.experimental_stations.updated_at IS
'UTC timestamp when the experimental station record was most recently updated.';

COMMENT ON COLUMN public.experimental_stations.created_by IS
'Supabase Auth user who created the experimental station record.';

COMMENT ON COLUMN public.experimental_stations.updated_by IS
'Supabase Auth user who most recently updated the experimental station record.';

COMMENT ON COLUMN public.experimental_stations.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the station has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_experimental_stations_code_ci
    ON public.experimental_stations
    (
        lower(btrim(code::text))
    );

CREATE UNIQUE INDEX uq_experimental_stations_province_name
    ON public.experimental_stations
    (
        province_id,
        public.fn_normalize_text(name::text)
    );

--------------------------------------------------------------------------------
-- RELATIONSHIP AND FILTERING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_experimental_stations_province_id
    ON public.experimental_stations (province_id);

CREATE INDEX idx_experimental_stations_province_active_display
    ON public.experimental_stations
    (
        province_id,
        display_order,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_experimental_stations_is_active
    ON public.experimental_stations (is_active)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_experimental_stations_deleted_at
    ON public.experimental_stations (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- CONTACT INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_experimental_stations_phone
    ON public.experimental_stations
    (
        btrim(phone::text)
    )
    WHERE phone IS NOT NULL
      AND deleted_at IS NULL;

CREATE INDEX idx_experimental_stations_email
    ON public.experimental_stations
    (
        lower(btrim(email::text))
    )
    WHERE email IS NOT NULL
      AND deleted_at IS NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_experimental_stations_name_trgm
    ON public.experimental_stations
    USING gin
    (
        (name::text) gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- SPATIAL INDEX
--------------------------------------------------------------------------------

CREATE INDEX idx_experimental_stations_location_gist
    ON public.experimental_stations
    USING gist (location)
    WHERE location IS NOT NULL
      AND deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_experimental_stations_created_by
    ON public.experimental_stations (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_experimental_stations_updated_by
    ON public.experimental_stations (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_experimental_stations_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.experimental_stations
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

CREATE TRIGGER trg_experimental_stations_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.experimental_stations
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

CREATE TRIGGER trg_experimental_stations_timestamps
    BEFORE INSERT OR UPDATE
    ON public.experimental_stations
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_experimental_stations_created_by
    BEFORE INSERT
    ON public.experimental_stations
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_experimental_stations_updated_by
    BEFORE UPDATE
    ON public.experimental_stations
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

    IF to_regclass('public.experimental_stations') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0016_experimental_stations.sql failed: public.experimental_stations was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'experimental_stations'
      AND column_name IN
      (
          'id',
          'province_id',
          'code',
          'name',
          'contact_name',
          'phone',
          'email',
          'address',
          'location',
          'description',
          'is_active',
          'display_order',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF expected_column_count <> 17 THEN
        RAISE EXCEPTION
            'Migration 0016_experimental_stations.sql failed: experimental_stations has % of 17 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.experimental_stations'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0016_experimental_stations.sql failed: primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify province relationship
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.experimental_stations'::regclass
          AND conname = 'fk_experimental_stations_province'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0016_experimental_stations.sql failed: province foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify audit foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.experimental_stations'::regclass
          AND conname = 'fk_experimental_stations_created_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0016_experimental_stations.sql failed: created_by foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.experimental_stations'::regclass
          AND conname = 'fk_experimental_stations_updated_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0016_experimental_stations.sql failed: updated_by foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_experimental_stations_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0016_experimental_stations.sql failed: unique station-code index is missing.';
    END IF;

    IF to_regclass('public.uq_experimental_stations_province_name') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0016_experimental_stations.sql failed: unique province/station-name index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify spatial index
    --------------------------------------------------------------------------

    IF to_regclass('public.idx_experimental_stations_location_gist') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0016_experimental_stations.sql failed: spatial index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify required triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.experimental_stations'::regclass
          AND tgname = 'trg_experimental_stations_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0016_experimental_stations.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.experimental_stations'::regclass
          AND tgname = 'trg_experimental_stations_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0016_experimental_stations.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.experimental_stations'::regclass
          AND tgname = 'trg_experimental_stations_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0016_experimental_stations.sql failed: updated_by trigger is missing.';
    END IF;
END;
$$;

COMMIT;
