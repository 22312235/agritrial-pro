/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0011_profiles.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the Profiles table.
*
* This table extends Supabase Auth (auth.users) and stores all application
* user information.
*
* Every authenticated user MUST have exactly one profile.
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
-- TABLE : profiles
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS profiles
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                  UUID PRIMARY KEY
                        REFERENCES auth.users(id)
                        ON DELETE CASCADE,

    --------------------------------------------------------------------------
    -- Role
    --------------------------------------------------------------------------

    role_id             UUID NOT NULL
                        REFERENCES roles(id)
                        ON DELETE RESTRICT,

    --------------------------------------------------------------------------
    -- Employee Information
    --------------------------------------------------------------------------

    employee_code       VARCHAR(20)
                        NOT NULL,

    first_name          VARCHAR(100)
                        NOT NULL,

    last_name           VARCHAR(100)
                        NOT NULL,

    email               email_address
                        NOT NULL,

    phone               phone_number,

    avatar_url          TEXT,

    --------------------------------------------------------------------------
    -- Status
    --------------------------------------------------------------------------

    is_active           BOOLEAN
                        NOT NULL
                        DEFAULT TRUE,

    last_login_at       TIMESTAMPTZ,

    --------------------------------------------------------------------------
    -- Audit Columns
    --------------------------------------------------------------------------

    created_at          TIMESTAMPTZ
                        NOT NULL
                        DEFAULT timezone('UTC', now()),

    updated_at          TIMESTAMPTZ
                        NOT NULL
                        DEFAULT timezone('UTC', now()),

    created_by          UUID
                        REFERENCES profiles(id)
                        ON DELETE SET NULL,

    updated_by          UUID
                        REFERENCES profiles(id)
                        ON DELETE SET NULL,

    deleted_at          TIMESTAMPTZ,

    --------------------------------------------------------------------------
    -- Constraints
    --------------------------------------------------------------------------

    CONSTRAINT uq_profiles_employee_code
        UNIQUE(employee_code),

    CONSTRAINT uq_profiles_email
        UNIQUE(email),

    CONSTRAINT chk_profiles_first_name
        CHECK(length(trim(first_name)) >= 2),

    CONSTRAINT chk_profiles_last_name
        CHECK(length(trim(last_name)) >= 2)

);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE profiles IS
'Stores application user information linked to Supabase authentication.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN profiles.id IS
'Same UUID as auth.users.id';

COMMENT ON COLUMN profiles.role_id IS
'Assigned role.';

COMMENT ON COLUMN profiles.employee_code IS
'Unique employee identifier.';

COMMENT ON COLUMN profiles.first_name IS
'User first name.';

COMMENT ON COLUMN profiles.last_name IS
'User last name.';

COMMENT ON COLUMN profiles.email IS
'Professional email address.';

COMMENT ON COLUMN profiles.phone IS
'Primary phone number.';

COMMENT ON COLUMN profiles.avatar_url IS
'Supabase Storage profile picture URL.';

COMMENT ON COLUMN profiles.is_active IS
'Indicates whether the profile is active.';

COMMENT ON COLUMN profiles.last_login_at IS
'Last successful login timestamp.';

COMMENT ON COLUMN profiles.created_at IS
'Record creation timestamp.';

COMMENT ON COLUMN profiles.updated_at IS
'Last update timestamp.';

COMMENT ON COLUMN profiles.created_by IS
'Profile that created this record.';

COMMENT ON COLUMN profiles.updated_by IS
'Last profile that updated this record.';

COMMENT ON COLUMN profiles.deleted_at IS
'Soft delete timestamp.';

--------------------------------------------------------------------------------
-- INDEXES
--------------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_profiles_role
ON profiles(role_id);

CREATE INDEX IF NOT EXISTS idx_profiles_employee_code
ON profiles(employee_code);

CREATE INDEX IF NOT EXISTS idx_profiles_email
ON profiles(email);

CREATE INDEX IF NOT EXISTS idx_profiles_active
ON profiles(is_active);

CREATE INDEX IF NOT EXISTS idx_profiles_deleted
ON profiles(deleted_at);

CREATE INDEX IF NOT EXISTS idx_profiles_name
ON profiles(last_name, first_name);

--------------------------------------------------------------------------------
-- TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_profiles_set_timestamps
BEFORE INSERT OR UPDATE
ON profiles
FOR EACH ROW
EXECUTE FUNCTION trg_set_timestamps();

CREATE TRIGGER trg_profiles_created_by
BEFORE INSERT
ON profiles
FOR EACH ROW
EXECUTE FUNCTION trg_set_created_by();

CREATE TRIGGER trg_profiles_updated_by
BEFORE UPDATE
ON profiles
FOR EACH ROW
EXECUTE FUNCTION trg_set_updated_by();

--------------------------------------------------------------------------------
-- FUNCTION : fn_create_profile()
--------------------------------------------------------------------------------
-- Automatically creates a profile after a new user signs up.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_create_profile()
RETURNS trigger
LANGUAGE plpgsql
SECURITY DEFINER
SET search_path = public
AS
$$
DECLARE
    default_role UUID;
BEGIN

    --------------------------------------------------------------------------
    -- Default Role
    --------------------------------------------------------------------------

    SELECT id
    INTO default_role
    FROM roles
    WHERE code = 'TRIAL_OFFICER'
    LIMIT 1;

    --------------------------------------------------------------------------
    -- Create Profile
    --------------------------------------------------------------------------

    INSERT INTO profiles
    (
        id,
        role_id,
        employee_code,
        first_name,
        last_name,
        email,
        phone
    )
    VALUES
    (
        NEW.id,

        default_role,

        'EMP-' ||
        LPAD(
            FLOOR(EXTRACT(EPOCH FROM clock_timestamp()))::TEXT,
            6,
            '0'
        ),

        COALESCE(
            NEW.raw_user_meta_data->>'first_name',
            ''
        ),

        COALESCE(
            NEW.raw_user_meta_data->>'last_name',
            ''
        ),

        NEW.email,

        NEW.raw_user_meta_data->>'phone'
    );

    RETURN NEW;

END;
$$;

COMMENT ON FUNCTION fn_create_profile IS
'Automatically creates an application profile after a Supabase Auth signup.';

--------------------------------------------------------------------------------
-- AUTH TRIGGER
--------------------------------------------------------------------------------

DROP TRIGGER IF EXISTS trg_auth_create_profile
ON auth.users;

CREATE TRIGGER trg_auth_create_profile
AFTER INSERT
ON auth.users
FOR EACH ROW
EXECUTE FUNCTION fn_create_profile();

--------------------------------------------------------------------------------
-- HELPER FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_full_name(profile_uuid UUID)
RETURNS TEXT
LANGUAGE SQL
STABLE
AS
$$
SELECT
    CONCAT(first_name,' ',last_name)
FROM profiles
WHERE id = profile_uuid;
$$;

COMMENT ON FUNCTION fn_full_name IS
'Returns the full name of a profile.';

--------------------------------------------------------------------------------
-- HELPER FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_is_manager(profile_uuid UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
AS
$$
SELECT EXISTS
(
    SELECT 1
    FROM profiles p
    JOIN roles r
        ON r.id = p.role_id
    WHERE
        p.id = profile_uuid
        AND r.code = 'MANAGER'
);
$$;

COMMENT ON FUNCTION fn_is_manager IS
'Returns TRUE if the profile belongs to a Manager.';

--------------------------------------------------------------------------------
-- HELPER FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_is_general_director(profile_uuid UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
AS
$$
SELECT EXISTS
(
    SELECT 1
    FROM profiles p
    JOIN roles r
        ON r.id = p.role_id
    WHERE
        p.id = profile_uuid
        AND r.code = 'GENERAL_DIRECTOR'
);
$$;

COMMENT ON FUNCTION fn_is_general_director IS
'Returns TRUE if the profile belongs to the General Director.';

--------------------------------------------------------------------------------
-- HELPER FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION fn_is_trial_officer(profile_uuid UUID)
RETURNS BOOLEAN
LANGUAGE SQL
STABLE
AS
$$
SELECT EXISTS
(
    SELECT 1
    FROM profiles p
    JOIN roles r
        ON r.id = p.role_id
    WHERE
        p.id = profile_uuid
        AND r.code = 'TRIAL_OFFICER'
);
$$;

COMMENT ON FUNCTION fn_is_trial_officer IS
'Returns TRUE if the profile belongs to a Trial Officer.';
--------------------------------------------------------------------------------
-- ROW LEVEL SECURITY
--------------------------------------------------------------------------------

ALTER TABLE profiles ENABLE ROW LEVEL SECURITY;

--------------------------------------------------------------------------------
-- POLICY : Users can view their own profile
--------------------------------------------------------------------------------

DROP POLICY IF EXISTS profiles_select_own
ON profiles;

CREATE POLICY profiles_select_own
ON profiles
FOR SELECT
TO authenticated
USING (
    id = auth.uid()
);

--------------------------------------------------------------------------------
-- POLICY : Users can update their own profile
--------------------------------------------------------------------------------

DROP POLICY IF EXISTS profiles_update_own
ON profiles;

CREATE POLICY profiles_update_own
ON profiles
FOR UPDATE
TO authenticated
USING (
    id = auth.uid()
)
WITH CHECK (
    id = auth.uid()
);

--------------------------------------------------------------------------------
-- POLICY : Managers and General Directors can view all profiles
--------------------------------------------------------------------------------

DROP POLICY IF EXISTS profiles_select_management
ON profiles;

CREATE POLICY profiles_select_management
ON profiles
FOR SELECT
TO authenticated
USING
(
    EXISTS
    (
        SELECT 1
        FROM profiles p
        JOIN roles r
            ON r.id = p.role_id
        WHERE
            p.id = auth.uid()
            AND r.code IN
            (
                'MANAGER',
                'GENERAL_DIRECTOR'
            )
    )
);

--------------------------------------------------------------------------------
-- POLICY : Only General Director can delete profiles
--------------------------------------------------------------------------------

DROP POLICY IF EXISTS profiles_delete_gd
ON profiles;

CREATE POLICY profiles_delete_gd
ON profiles
FOR DELETE
TO authenticated
USING
(
    EXISTS
    (
        SELECT 1
        FROM profiles p
        JOIN roles r
            ON r.id = p.role_id
        WHERE
            p.id = auth.uid()
            AND r.code = 'GENERAL_DIRECTOR'
    )
);

--------------------------------------------------------------------------------
-- VALIDATION
--------------------------------------------------------------------------------

DO
$$
BEGIN

    IF NOT EXISTS
    (
        SELECT 1
        FROM information_schema.tables
        WHERE table_schema = 'public'
        AND table_name = 'profiles'
    )
    THEN
        RAISE EXCEPTION
        'Table profiles was not created successfully.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_proc
        WHERE proname = 'fn_create_profile'
    )
    THEN
        RAISE EXCEPTION
        'Function fn_create_profile is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgname = 'trg_auth_create_profile'
    )
    THEN
        RAISE EXCEPTION
        'Trigger trg_auth_create_profile is missing.';
    END IF;

END;
$$;

--------------------------------------------------------------------------------
-- FINAL COMMENTS
--------------------------------------------------------------------------------

COMMENT ON TABLE profiles IS
'Application user profiles linked to Supabase Auth.';

COMMENT ON FUNCTION fn_create_profile IS
'Automatically creates a profile when a new user registers.';

COMMENT ON FUNCTION fn_full_name IS
'Returns the full name of a profile.';

COMMENT ON FUNCTION fn_is_manager IS
'Checks whether a profile belongs to a Manager.';

COMMENT ON FUNCTION fn_is_general_director IS
'Checks whether a profile belongs to the General Director.';

COMMENT ON FUNCTION fn_is_trial_officer IS
'Checks whether a profile belongs to a Trial Officer.';

--------------------------------------------------------------------------------
-- COMMIT
--------------------------------------------------------------------------------

COMMIT;
