/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 005_trigger_functions.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates reusable trigger functions used throughout AgriTrial Pro.
*
* These trigger functions are generic and will be attached to tables
* in later migrations.
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
-- trg_set_timestamps()
--------------------------------------------------------------------------------
-- Automatically sets created_at and updated_at.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION trg_set_timestamps()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

    IF TG_OP = 'INSERT' THEN

        NEW.created_at :=
            COALESCE(NEW.created_at, timezone('UTC', now()));

        NEW.updated_at :=
            COALESCE(NEW.updated_at, timezone('UTC', now()));

    ELSIF TG_OP = 'UPDATE' THEN

        NEW.created_at := OLD.created_at;

        NEW.updated_at := timezone('UTC', now());

    END IF;

    RETURN NEW;

END;
$$;

COMMENT ON FUNCTION trg_set_timestamps IS
'Automatically manages created_at and updated_at columns.';

--------------------------------------------------------------------------------
-- trg_generate_uuid()
--------------------------------------------------------------------------------
-- Automatically generates UUID primary keys.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION trg_generate_uuid()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

    IF NEW.id IS NULL THEN
        NEW.id := gen_random_uuid();
    END IF;

    RETURN NEW;

END;
$$;

COMMENT ON FUNCTION trg_generate_uuid IS
'Automatically generates UUID values for primary keys.';

--------------------------------------------------------------------------------
-- trg_soft_delete()
--------------------------------------------------------------------------------
-- Performs soft delete by setting deleted_at.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION trg_soft_delete()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

    NEW.deleted_at := timezone('UTC', now());

    RETURN NEW;

END;
$$;

COMMENT ON FUNCTION trg_soft_delete IS
'Marks a record as deleted using deleted_at timestamp.';

--------------------------------------------------------------------------------
-- trg_normalize_name()
--------------------------------------------------------------------------------
-- Trims leading/trailing spaces.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION trg_normalize_name()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

    IF NEW.name IS NOT NULL THEN
        NEW.name := trim(NEW.name);
    END IF;

    RETURN NEW;

END;
$$;

COMMENT ON FUNCTION trg_normalize_name IS
'Automatically trims whitespace from the name column.';

--------------------------------------------------------------------------------
-- trg_uppercase_code()
--------------------------------------------------------------------------------
-- Converts business codes to uppercase.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION trg_uppercase_code()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

    IF NEW.code IS NOT NULL THEN
        NEW.code := upper(trim(NEW.code));
    END IF;

    RETURN NEW;

END;
$$;

COMMENT ON FUNCTION trg_uppercase_code IS
'Converts code values to uppercase before saving.';

--------------------------------------------------------------------------------
-- trg_slugify_name()
--------------------------------------------------------------------------------
-- Automatically creates a slug from name.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION trg_slugify_name()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

    IF NEW.name IS NOT NULL THEN
        NEW.slug := fn_slugify(NEW.name);
    END IF;

    RETURN NEW;

END;
$$;

COMMENT ON FUNCTION trg_slugify_name IS
'Automatically generates slug values from the name column.';

--------------------------------------------------------------------------------
-- trg_prevent_created_at_update()
--------------------------------------------------------------------------------
-- Prevents modification of created_at.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION trg_prevent_created_at_update()
RETURNS trigger
LANGUAGE plpgsql
AS $$
BEGIN

    NEW.created_at := OLD.created_at;

    RETURN NEW;

END;
$$;

COMMENT ON FUNCTION trg_prevent_created_at_update IS
'Prevents changes to created_at after insertion.';

--------------------------------------------------------------------------------
-- trg_set_created_by()
--------------------------------------------------------------------------------
-- Sets created_by from authenticated Supabase user.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION trg_set_created_by()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN

    IF NEW.created_by IS NULL THEN
        NEW.created_by := auth.uid();
    END IF;

    RETURN NEW;

END;
$$;

COMMENT ON FUNCTION trg_set_created_by IS
'Automatically stores the authenticated user ID in created_by.';

--------------------------------------------------------------------------------
-- trg_set_updated_by()
--------------------------------------------------------------------------------
-- Sets updated_by from authenticated Supabase user.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION trg_set_updated_by()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS $$
BEGIN

    NEW.updated_by := auth.uid();

    RETURN NEW;

END;
$$;

COMMENT ON FUNCTION trg_set_updated_by IS
'Automatically stores the authenticated user ID in updated_by.';

--------------------------------------------------------------------------------
-- VALIDATION
--------------------------------------------------------------------------------

DO
$$
DECLARE
    expected_functions text[] := ARRAY[
        'trg_set_timestamps',
        'trg_generate_uuid',
        'trg_soft_delete',
        'trg_normalize_name',
        'trg_uppercase_code',
        'trg_slugify_name',
        'trg_prevent_created_at_update',
        'trg_set_created_by',
        'trg_set_updated_by'
    ];

    fn text;
BEGIN
    FOREACH fn IN ARRAY expected_functions
    LOOP
        IF NOT EXISTS (
            SELECT 1
            FROM pg_proc
            WHERE proname = fn
        ) THEN
            RAISE EXCEPTION 'Trigger function "%" was not created successfully.', fn;
        END IF;
    END LOOP;
END;
$$;

COMMIT;
