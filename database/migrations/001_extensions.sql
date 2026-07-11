/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 001_extensions.sql
* Version      : 1.1.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Installs all PostgreSQL extensions required by AgriTrial Pro.
*
* This migration is:
*   ✓ Idempotent
*   ✓ Transaction-safe
*   ✓ Supabase compatible
*   ✓ PostgreSQL 17 compatible
*   ✓ Production ready
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
-- pgcrypto
--------------------------------------------------------------------------------
-- Modern PostgreSQL cryptographic extension.
--
-- Preferred UUID generator:
--
--     gen_random_uuid()
--
-- Also provides:
--   • digest()
--   • crypt()
--   • hmac()
--   • secure random bytes
--------------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pgcrypto WITH SCHEMA public;

COMMENT ON EXTENSION pgcrypto IS
'Cryptographic functions including the preferred UUID generator (gen_random_uuid).';

--------------------------------------------------------------------------------
-- uuid-ossp
--------------------------------------------------------------------------------
-- Legacy UUID generation support.
--
-- Installed for compatibility with:
--   • Existing schemas
--   • External integrations
--   • Legacy SQL migrations
--------------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS "uuid-ossp" WITH SCHEMA public;

COMMENT ON EXTENSION "uuid-ossp" IS
'Legacy UUID generation functions maintained for compatibility.';

--------------------------------------------------------------------------------
-- PostGIS
--------------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS postgis WITH SCHEMA public;

COMMENT ON EXTENSION postgis IS
'Enterprise GIS and spatial analysis support.';

--------------------------------------------------------------------------------
-- btree_gist
--------------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS btree_gist WITH SCHEMA public;

COMMENT ON EXTENSION btree_gist IS
'GiST operator classes for B-tree data types.';

--------------------------------------------------------------------------------
-- citext
--------------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS citext WITH SCHEMA public;

COMMENT ON EXTENSION citext IS
'Case-insensitive text data type.';

--------------------------------------------------------------------------------
-- pg_trgm
--------------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS pg_trgm WITH SCHEMA public;

COMMENT ON EXTENSION pg_trgm IS
'Trigram similarity indexing and fuzzy searching.';

--------------------------------------------------------------------------------
-- unaccent
--------------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS unaccent WITH SCHEMA public;

COMMENT ON EXTENSION unaccent IS
'Accent-insensitive text normalization.';

--------------------------------------------------------------------------------
-- tablefunc
--------------------------------------------------------------------------------

CREATE EXTENSION IF NOT EXISTS tablefunc WITH SCHEMA public;

COMMENT ON EXTENSION tablefunc IS
'Pivot table and crosstab reporting functions.';

--------------------------------------------------------------------------------
-- Validation
--------------------------------------------------------------------------------

DO
$$
DECLARE
    required_extensions TEXT[] := ARRAY[
        'pgcrypto',
        'uuid-ossp',
        'postgis',
        'btree_gist',
        'citext',
        'pg_trgm',
        'unaccent',
        'tablefunc'
    ];

    ext TEXT;
BEGIN
    FOREACH ext IN ARRAY required_extensions
    LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM pg_extension
            WHERE extname = ext
        ) THEN
            RAISE EXCEPTION
                'Required extension "%" was not installed successfully.',
                ext;
        END IF;
    END LOOP;
END;
$$;

COMMIT;
