/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0011_profiles.sql
* Version      : 1.1.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the application profiles table.
*
* The profiles table extends Supabase Auth without duplicating authentication
* information. Every profile is linked to exactly one auth.users account and
* exactly one application role.
*
* Important architectural rules:
*
*   • Profiles are created explicitly by an authorized administrator.
*   • No profile is created automatically after signup.
*   • No default role is assigned automatically.
*   • Email remains managed by auth.users and is not duplicated here.
*   • Avatar files are stored in Supabase Storage; only the object path is saved.
*   • Row Level Security policies are intentionally deferred to later migrations.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0003_domains.sql
*   • 0005_trigger_functions.sql
*   • 0010_roles.sql
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
-- TABLE: profiles
--------------------------------------------------------------------------------

CREATE TABLE public.profiles
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                  uuid
                        PRIMARY KEY
                        DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Supabase Authentication Link
    --------------------------------------------------------------------------

    user_id             uuid
                        NOT NULL,

    --------------------------------------------------------------------------
    -- Application Role
    --------------------------------------------------------------------------

    role_id             uuid
                        NOT NULL,

    --------------------------------------------------------------------------
    -- Employee Information
    --------------------------------------------------------------------------

    first_name          varchar(100)
                        NOT NULL,

    last_name           varchar(100)
                        NOT NULL,

    employee_code       varchar(50)
                        NOT NULL,

    phone               phone_number,

    avatar_path         text,

    --------------------------------------------------------------------------
    -- Account State
    --------------------------------------------------------------------------

    is_active           boolean
                        NOT NULL
                        DEFAULT true,

    last_login_at       timestamptz,

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

    CONSTRAINT fk_profiles_user
        FOREIGN KEY (user_id)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_profiles_role
        FOREIGN KEY (role_id)
        REFERENCES public.roles(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_profiles_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_profiles_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Uniqueness Constraints
    --------------------------------------------------------------------------

    CONSTRAINT uq_profiles_user_id
        UNIQUE (user_id),

    --------------------------------------------------------------------------
    -- Data Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_profiles_first_name_not_blank
        CHECK (
            length(btrim(first_name)) > 0
        ),

    CONSTRAINT chk_profiles_last_name_not_blank
        CHECK (
            length(btrim(last_name)) > 0
        ),

    CONSTRAINT chk_profiles_employee_code_not_blank
        CHECK (
            length(btrim(employee_code)) > 0
        ),

    CONSTRAINT chk_profiles_first_name_length
        CHECK (
            char_length(btrim(first_name)) <= 100
        ),

    CONSTRAINT chk_profiles_last_name_length
        CHECK (
            char_length(btrim(last_name)) <= 100
        ),

    CONSTRAINT chk_profiles_employee_code_length
        CHECK (
            char_length(btrim(employee_code)) <= 50
        ),

    CONSTRAINT chk_profiles_avatar_path_not_blank
        CHECK (
            avatar_path IS NULL
            OR length(btrim(avatar_path)) > 0
        ),

    CONSTRAINT chk_profiles_avatar_path_length
        CHECK (
            avatar_path IS NULL
            OR char_length(btrim(avatar_path)) <= 1024
        ),

    CONSTRAINT chk_profiles_updated_at
        CHECK (
            updated_at >= created_at
        ),

    CONSTRAINT chk_profiles_deleted_at
        CHECK (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.profiles IS
'Application user profiles linked one-to-one with Supabase Auth users. Profiles and roles are assigned explicitly and are never created automatically during signup.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.profiles.id IS
'Internal UUID primary key of the application profile.';

COMMENT ON COLUMN public.profiles.user_id IS
'Unique Supabase Auth user associated with this profile. References auth.users.';

COMMENT ON COLUMN public.profiles.role_id IS
'Application role assigned to the profile. References public.roles.';

COMMENT ON COLUMN public.profiles.first_name IS
'Employee first name.';

COMMENT ON COLUMN public.profiles.last_name IS
'Employee last name.';

COMMENT ON COLUMN public.profiles.employee_code IS
'Unique Agrimatco Morocco employee code. Uniqueness is enforced case-insensitively.';

COMMENT ON COLUMN public.profiles.phone IS
'Optional employee telephone number validated by the phone_number domain.';

COMMENT ON COLUMN public.profiles.avatar_path IS
'Supabase Storage object path of the employee avatar. This column does not store binary image data or a permanent public URL.';

COMMENT ON COLUMN public.profiles.is_active IS
'Indicates whether the employee profile is currently active and authorized to use AgriTrial Pro.';

COMMENT ON COLUMN public.profiles.last_login_at IS
'Timestamp of the employee’s latest successful AgriTrial Pro login.';

COMMENT ON COLUMN public.profiles.created_at IS
'UTC timestamp when the profile record was created.';

COMMENT ON COLUMN public.profiles.updated_at IS
'UTC timestamp when the profile record was most recently updated.';

COMMENT ON COLUMN public.profiles.created_by IS
'Supabase Auth user who created the profile record.';

COMMENT ON COLUMN public.profiles.updated_by IS
'Supabase Auth user who most recently updated the profile record.';

COMMENT ON COLUMN public.profiles.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the profile has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

-- Employee codes must be unique regardless of casing or surrounding spaces.
CREATE UNIQUE INDEX uq_profiles_employee_code_ci
    ON public.profiles
    (
        lower(btrim(employee_code))
    );

--------------------------------------------------------------------------------
-- LOOKUP AND FILTERING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_profiles_role_id
    ON public.profiles (role_id);

CREATE INDEX idx_profiles_active_role
    ON public.profiles (role_id, is_active)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_profiles_active
    ON public.profiles (is_active)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_profiles_name
    ON public.profiles
    (
        lower(btrim(last_name)),
        lower(btrim(first_name))
    )
    WHERE deleted_at IS NULL;

CREATE INDEX idx_profiles_last_login
    ON public.profiles (last_login_at DESC)
    WHERE last_login_at IS NOT NULL
      AND deleted_at IS NULL;

CREATE INDEX idx_profiles_deleted_at
    ON public.profiles (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_profiles_created_by
    ON public.profiles (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_profiles_updated_by
    ON public.profiles (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

-- Maintains created_at and updated_at using the generic trigger function
-- created in 0005_trigger_functions.sql.
CREATE TRIGGER trg_profiles_timestamps
    BEFORE INSERT OR UPDATE
    ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

-- Records the authenticated Supabase user when a profile is created.
CREATE TRIGGER trg_profiles_created_by
    BEFORE INSERT
    ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

-- Records the authenticated Supabase user when a profile is updated.
CREATE TRIGGER trg_profiles_updated_by
    BEFORE UPDATE
    ON public.profiles
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- MIGRATION VALIDATION
--------------------------------------------------------------------------------

DO
$$
DECLARE
    profile_column_count integer;
BEGIN
    --------------------------------------------------------------------------
    -- Verify table creation
    --------------------------------------------------------------------------

    IF to_regclass('public.profiles') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0011_profiles.sql failed: public.profiles was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO profile_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'profiles'
      AND column_name IN
      (
          'id',
          'user_id',
          'role_id',
          'first_name',
          'last_name',
          'employee_code',
          'phone',
          'avatar_path',
          'is_active',
          'last_login_at',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF profile_column_count <> 15 THEN
        RAISE EXCEPTION
            'Migration 0011_profiles.sql failed: profiles has % of 15 required columns.',
            profile_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify one-to-one auth user constraint
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.profiles'::regclass
          AND conname = 'uq_profiles_user_id'
          AND contype = 'u'
    ) THEN
        RAISE EXCEPTION
            'Migration 0011_profiles.sql failed: unique user_id constraint is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify required triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.profiles'::regclass
          AND tgname = 'trg_profiles_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0011_profiles.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.profiles'::regclass
          AND tgname = 'trg_profiles_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0011_profiles.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.profiles'::regclass
          AND tgname = 'trg_profiles_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0011_profiles.sql failed: updated_by trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify that forbidden onboarding logic was not introduced
    --------------------------------------------------------------------------

    IF EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'auth.users'::regclass
          AND tgname = 'trg_auth_create_profile'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Frozen architecture violation: automatic Auth profile creation trigger exists.';
    END IF;
END;
$$;

COMMIT;
