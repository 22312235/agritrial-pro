/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 010_roles.sql
* Version      : 1.0.0
***************************************************************************************************/

BEGIN;

SET LOCAL search_path = public;

--------------------------------------------------------------------------------
-- TABLE: roles
--------------------------------------------------------------------------------

CREATE TABLE IF NOT EXISTS roles
(
    id                  uuid PRIMARY KEY DEFAULT gen_random_uuid(),

    code                short_code        NOT NULL,

    name                short_name        NOT NULL,

    description         description_text,

    is_active           boolean           NOT NULL DEFAULT TRUE,

    created_at          timestamptz       NOT NULL DEFAULT timezone('UTC', now()),

    updated_at          timestamptz       NOT NULL DEFAULT timezone('UTC', now()),

    created_by          uuid,

    updated_by          uuid,

    deleted_at          timestamptz,

    CONSTRAINT uq_roles_code
        UNIQUE(code),

    CONSTRAINT uq_roles_name
        UNIQUE(name)
);

--------------------------------------------------------------------------------
-- COMMENTS
--------------------------------------------------------------------------------

COMMENT ON TABLE roles IS
'System roles used for application authorization.';

COMMENT ON COLUMN roles.code IS 'Unique business role code.';
COMMENT ON COLUMN roles.name IS 'Display name.';
COMMENT ON COLUMN roles.description IS 'Role description.';
COMMENT ON COLUMN roles.is_active IS 'Whether the role is active.';

--------------------------------------------------------------------------------
-- INDEXES
--------------------------------------------------------------------------------

CREATE INDEX IF NOT EXISTS idx_roles_active
ON roles(is_active);

CREATE INDEX IF NOT EXISTS idx_roles_deleted
ON roles(deleted_at);

--------------------------------------------------------------------------------
-- TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_roles_timestamps
BEFORE INSERT OR UPDATE
ON roles
FOR EACH ROW
EXECUTE FUNCTION trg_set_timestamps();

--------------------------------------------------------------------------------
-- SEED DATA
--------------------------------------------------------------------------------

INSERT INTO roles
(code, name, description)
VALUES
(
'GENERAL_DIRECTOR',
'General Director',
'Full system access.'
),
(
'MANAGER',
'Manager',
'Manages field trials and users.'
),
(
'TRIAL_OFFICER',
'Trial Officer',
'Conducts field trials and evaluations.'
)
ON CONFLICT (code) DO NOTHING;

--------------------------------------------------------------------------------
-- VALIDATION
--------------------------------------------------------------------------------

DO
$$
BEGIN
    IF NOT EXISTS (
        SELECT 1
        FROM roles
        WHERE code = 'GENERAL_DIRECTOR'
    ) THEN
        RAISE EXCEPTION 'Seed data missing: GENERAL_DIRECTOR';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM roles
        WHERE code = 'MANAGER'
    ) THEN
        RAISE EXCEPTION 'Seed data missing: MANAGER';
    END IF;

    IF NOT EXISTS (
        SELECT 1
        FROM roles
        WHERE code = 'TRIAL_OFFICER'
    ) THEN
        RAISE EXCEPTION 'Seed data missing: TRIAL_OFFICER';
    END IF;
END;
$$;

COMMIT;
