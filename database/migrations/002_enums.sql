/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 002_enums.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates all system-level ENUM types used across AgriTrial Pro.
*
* Business master data (Crop Types, Trial Types, Fruit Colors, etc.)
* are intentionally NOT implemented as ENUMs because they are expected
* to evolve over time and should instead be managed as lookup tables.
*
* This migration is:
*   ✓ Idempotent
*   ✓ PostgreSQL 17 compatible
*   ✓ Supabase compatible
*   ✓ Production Ready
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
-- USER ROLE
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'user_role'
    ) THEN
        CREATE TYPE user_role AS ENUM (
            'super_admin',
            'admin',
            'manager',
            'researcher',
            'field_agent',
            'technician',
            'viewer'
        );
    END IF;
END;
$$;

COMMENT ON TYPE user_role IS
'Defines the application roles.';

--------------------------------------------------------------------------------
-- USER STATUS
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'user_status'
    ) THEN
        CREATE TYPE user_status AS ENUM (
            'active',
            'inactive',
            'pending',
            'suspended'
        );
    END IF;
END;
$$;

COMMENT ON TYPE user_status IS
'Represents the current status of a user account.';

--------------------------------------------------------------------------------
-- TRIAL STATUS
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'trial_status'
    ) THEN
        CREATE TYPE trial_status AS ENUM (
            'draft',
            'planned',
            'active',
            'completed',
            'cancelled',
            'archived'
        );
    END IF;
END;
$$;

COMMENT ON TYPE trial_status IS
'Represents the lifecycle state of a field trial.';

--------------------------------------------------------------------------------
-- EVALUATION STATUS
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'evaluation_status'
    ) THEN
        CREATE TYPE evaluation_status AS ENUM (
            'draft',
            'submitted',
            'validated',
            'rejected'
        );
    END IF;
END;
$$;

COMMENT ON TYPE evaluation_status IS
'Workflow status of an evaluation.';

--------------------------------------------------------------------------------
-- TASK STATUS
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'task_status'
    ) THEN
        CREATE TYPE task_status AS ENUM (
            'pending',
            'in_progress',
            'completed',
            'cancelled'
        );
    END IF;
END;
$$;

COMMENT ON TYPE task_status IS
'Represents the status of operational tasks.';

--------------------------------------------------------------------------------
-- TASK PRIORITY
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'task_priority'
    ) THEN
        CREATE TYPE task_priority AS ENUM (
            'low',
            'medium',
            'high',
            'critical'
        );
    END IF;
END;
$$;

COMMENT ON TYPE task_priority IS
'Priority assigned to a task.';

--------------------------------------------------------------------------------
-- REPORT STATUS
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'report_status'
    ) THEN
        CREATE TYPE report_status AS ENUM (
            'draft',
            'generated',
            'published',
            'archived'
        );
    END IF;
END;
$$;

COMMENT ON TYPE report_status IS
'Current lifecycle state of generated reports.';

--------------------------------------------------------------------------------
-- NOTIFICATION STATUS
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'notification_status'
    ) THEN
        CREATE TYPE notification_status AS ENUM (
            'unread',
            'read',
            'dismissed'
        );
    END IF;
END;
$$;

COMMENT ON TYPE notification_status IS
'Represents the read state of notifications.';

--------------------------------------------------------------------------------
-- AUDIT ACTION
--------------------------------------------------------------------------------

DO $$
BEGIN
    IF NOT EXISTS (
        SELECT 1 FROM pg_type WHERE typname = 'audit_action'
    ) THEN
        CREATE TYPE audit_action AS ENUM (
            'insert',
            'update',
            'delete',
            'login',
            'logout',
            'restore',
            'export'
        );
    END IF;
END;
$$;

COMMENT ON TYPE audit_action IS
'Actions recorded by the audit logging system.';

COMMIT;
