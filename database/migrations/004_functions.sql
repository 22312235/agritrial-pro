/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 004_functions.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates reusable utility functions used throughout AgriTrial Pro.
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
-- FUNCTION: fn_generate_uuid()
--------------------------------------------------------------------------------
-- Returns a random UUID.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_generate_uuid()
RETURNS uuid
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT gen_random_uuid();
$$;

COMMENT ON FUNCTION fn_generate_uuid IS
'Returns a randomly generated UUID.';

--------------------------------------------------------------------------------
-- FUNCTION: fn_current_timestamp_utc()
--------------------------------------------------------------------------------
-- Returns the current UTC timestamp.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_current_timestamp_utc()
RETURNS timestamptz
LANGUAGE sql
STABLE
AS $$
    SELECT timezone('UTC', now());
$$;

COMMENT ON FUNCTION fn_current_timestamp_utc IS
'Returns the current UTC timestamp.';

--------------------------------------------------------------------------------
-- FUNCTION: fn_normalize_text(text)
--------------------------------------------------------------------------------
-- Removes accents, trims spaces and converts text to lowercase.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_normalize_text(input_text text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
    SELECT lower(trim(unaccent(input_text)));
$$;

COMMENT ON FUNCTION fn_normalize_text IS
'Normalizes text by removing accents, trimming whitespace and converting to lowercase.';

--------------------------------------------------------------------------------
-- FUNCTION: fn_slugify(text)
--------------------------------------------------------------------------------
-- Generates URL-friendly slugs.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_slugify(input_text text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
SELECT trim(
       BOTH '-'
       FROM regexp_replace(
            lower(unaccent(input_text)),
            '[^a-z0-9]+',
            '-',
            'g'
       )
);
$$;

COMMENT ON FUNCTION fn_slugify IS
'Converts text into a URL-friendly slug.';

--------------------------------------------------------------------------------
-- FUNCTION: fn_is_valid_email(text)
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_is_valid_email(email text)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
SELECT email ~* '^[A-Za-z0-9._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$';
$$;

COMMENT ON FUNCTION fn_is_valid_email IS
'Checks whether an email address is valid.';

--------------------------------------------------------------------------------
-- FUNCTION: fn_calculate_age(date)
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_calculate_age(input_date date)
RETURNS integer
LANGUAGE sql
STABLE
AS $$
SELECT EXTRACT(YEAR FROM age(current_date, input_date))::integer;
$$;

COMMENT ON FUNCTION fn_calculate_age IS
'Calculates age in years from a date.';

--------------------------------------------------------------------------------
-- FUNCTION: fn_is_positive(numeric)
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_is_positive(value numeric)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
AS $$
SELECT value > 0;
$$;

COMMENT ON FUNCTION fn_is_positive IS
'Returns TRUE if the value is greater than zero.';

--------------------------------------------------------------------------------
-- FUNCTION: fn_round_decimal(numeric, integer)
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_round_decimal(
    value numeric,
    decimal_places integer DEFAULT 2
)
RETURNS numeric
LANGUAGE sql
IMMUTABLE
AS $$
SELECT round(value, decimal_places);
$$;

COMMENT ON FUNCTION fn_round_decimal IS
'Rounds a numeric value to the specified number of decimal places.';

--------------------------------------------------------------------------------
-- FUNCTION: fn_updated_at()
--------------------------------------------------------------------------------
-- Returns the current timestamp.
-- Used by update triggers.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_updated_at()
RETURNS timestamptz
LANGUAGE sql
STABLE
AS $$
SELECT now();
$$;

COMMENT ON FUNCTION fn_updated_at IS
'Returns the current timestamp for updated_at columns.';

--------------------------------------------------------------------------------
-- FUNCTION: fn_empty_to_null(text)
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_empty_to_null(value text)
RETURNS text
LANGUAGE sql
IMMUTABLE
AS $$
SELECT NULLIF(trim(value), '');
$$;

COMMENT ON FUNCTION fn_empty_to_null IS
'Converts empty or whitespace-only strings to NULL.';

--------------------------------------------------------------------------------
-- VALIDATION
--------------------------------------------------------------------------------

DO
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM pg_proc
        WHERE proname = 'fn_generate_uuid'
    ) THEN
        RAISE EXCEPTION 'Function fn_generate_uuid was not created.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_proc
        WHERE proname = 'fn_current_timestamp_utc'
    ) THEN
        RAISE EXCEPTION 'Function fn_current_timestamp_utc was not created.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_proc
        WHERE proname = 'fn_normalize_text'
    ) THEN
        RAISE EXCEPTION 'Function fn_normalize_text was not created.';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM pg_proc
        WHERE proname = 'fn_slugify'
    ) THEN
        RAISE EXCEPTION 'Function fn_slugify was not created.';
    END IF;
END;
$$;

COMMIT;
