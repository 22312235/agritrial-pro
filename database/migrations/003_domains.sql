/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 003_domains.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates reusable DOMAIN types used throughout the AgriTrial Pro database.
*
* Domains centralize validation rules, reduce duplication, and improve
* consistency across all database tables.
*
* PostgreSQL : 17
* Compatible : Supabase
*
***************************************************************************************************/

BEGIN;

--------------------------------------------------------------------------------
-- Session Configuration
--------------------------------------------------------------------------------

SET LOCAL search_path = public;

SET LOCAL statement_timeout = '5min';

SET LOCAL lock_timeout = '30s';

--------------------------------------------------------------------------------
-- EMAIL ADDRESS
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'email_address'
    ) THEN
        CREATE DOMAIN email_address AS citext
        CHECK (
            VALUE ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$'
        );
    END IF;
END;
$$;

COMMENT ON DOMAIN email_address IS
'Validated email address.';

--------------------------------------------------------------------------------
-- PHONE NUMBER
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'phone_number'
    ) THEN
        CREATE DOMAIN phone_number AS varchar(25)
        CHECK (
            VALUE ~ '^\+?[0-9 ()-]{7,25}$'
        );
    END IF;
END;
$$;

COMMENT ON DOMAIN phone_number IS
'International phone number.';

--------------------------------------------------------------------------------
-- WEBSITE URL
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'website_url'
    ) THEN
        CREATE DOMAIN website_url AS text
        CHECK (
            VALUE IS NULL
            OR VALUE ~* '^https?://'
        );
    END IF;
END;
$$;

COMMENT ON DOMAIN website_url IS
'HTTP or HTTPS website URL.';

--------------------------------------------------------------------------------
-- SHORT CODE
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'short_code'
    ) THEN
        CREATE DOMAIN short_code AS varchar(20)
        CHECK (
            length(trim(VALUE)) BETWEEN 2 AND 20
        );
    END IF;
END;
$$;

COMMENT ON DOMAIN short_code IS
'Short business code (2-20 characters).';

--------------------------------------------------------------------------------
-- LONG CODE
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'long_code'
    ) THEN
        CREATE DOMAIN long_code AS varchar(50)
        CHECK (
            length(trim(VALUE)) BETWEEN 2 AND 50
        );
    END IF;
END;
$$;

COMMENT ON DOMAIN long_code IS
'Long business code (2-50 characters).';

--------------------------------------------------------------------------------
-- SHORT NAME
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'short_name'
    ) THEN
        CREATE DOMAIN short_name AS varchar(100)
        CHECK (
            length(trim(VALUE)) BETWEEN 2 AND 100
        );
    END IF;
END;
$$;

COMMENT ON DOMAIN short_name IS
'Short descriptive name.';

--------------------------------------------------------------------------------
-- LONG NAME
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'long_name'
    ) THEN
        CREATE DOMAIN long_name AS varchar(255)
        CHECK (
            length(trim(VALUE)) BETWEEN 2 AND 255
        );
    END IF;
END;
$$;

COMMENT ON DOMAIN long_name IS
'Long descriptive name.';

--------------------------------------------------------------------------------
-- DESCRIPTION
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'description_text'
    ) THEN
        CREATE DOMAIN description_text AS text
        CHECK (
            length(trim(VALUE)) <= 5000
        );
    END IF;
END;
$$;

COMMENT ON DOMAIN description_text IS
'General purpose description.';

--------------------------------------------------------------------------------
-- POSITIVE INTEGER
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'positive_integer'
    ) THEN
        CREATE DOMAIN positive_integer AS integer
        CHECK (
            VALUE > 0
        );
    END IF;
END;
$$;

COMMENT ON DOMAIN positive_integer IS
'Integer greater than zero.';

--------------------------------------------------------------------------------
-- POSITIVE DECIMAL
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'positive_decimal'
    ) THEN
        CREATE DOMAIN positive_decimal AS numeric(18,4)
        CHECK (
            VALUE > 0
        );
    END IF;
END;
$$;

COMMENT ON DOMAIN positive_decimal IS
'Positive decimal value.';

--------------------------------------------------------------------------------
-- PERCENTAGE
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'percentage'
    ) THEN
        CREATE DOMAIN percentage AS numeric(5,2)
        CHECK (
            VALUE BETWEEN 0 AND 100
        );
    END IF;
END;
$$;

COMMENT ON DOMAIN percentage IS
'Percentage value between 0 and 100.';

--------------------------------------------------------------------------------
-- LATITUDE
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'latitude'
    ) THEN
        CREATE DOMAIN latitude AS numeric(9,6)
        CHECK (
            VALUE BETWEEN -90 AND 90
        );
    END IF;
END;
$$;

COMMENT ON DOMAIN latitude IS
'Latitude in decimal degrees.';

--------------------------------------------------------------------------------
-- LONGITUDE
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'longitude'
    ) THEN
        CREATE DOMAIN longitude AS numeric(9,6)
        CHECK (
            VALUE BETWEEN -180 AND 180
        );
    END IF;
END;
$$;

COMMENT ON DOMAIN longitude IS
'Longitude in decimal degrees.';

--------------------------------------------------------------------------------
-- CROP YEAR
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'crop_year'
    ) THEN
        CREATE DOMAIN crop_year AS integer
        CHECK (
            VALUE BETWEEN 2000 AND 2100
        );
    END IF;
END;
$$;

COMMENT ON DOMAIN crop_year IS
'Agricultural campaign year.';

--------------------------------------------------------------------------------
-- PLOT AREA
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'plot_area'
    ) THEN
        CREATE DOMAIN plot_area AS numeric(12,2)
        CHECK (
            VALUE > 0
        );
    END IF;
END;
$$;

COMMENT ON DOMAIN plot_area IS
'Area measurement in square meters.';

--------------------------------------------------------------------------------
-- UUID IDENTIFIER
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_type
        WHERE typname = 'entity_uuid'
    ) THEN
        CREATE DOMAIN entity_uuid AS uuid;
    END IF;
END;
$$;

COMMENT ON DOMAIN entity_uuid IS
'Standard UUID identifier used across the application.';

--------------------------------------------------------------------------------
-- VALIDATION
--------------------------------------------------------------------------------

DO $$
DECLARE
    expected_domains text[] := ARRAY[
        'email_address',
        'phone_number',
        'website_url',
        'short_code',
        'long_code',
        'short_name',
        'long_name',
        'description_text',
        'positive_integer',
        'positive_decimal',
        'percentage',
        'latitude',
        'longitude',
        'crop_year',
        'plot_area',
        'entity_uuid'
    ];

    d text;
BEGIN
    FOREACH d IN ARRAY expected_domains
    LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM pg_type
            WHERE typname = d
        ) THEN
            RAISE EXCEPTION 'Domain "%" was not created successfully.', d;
        END IF;
    END LOOP;
END;
$$;

COMMIT;
