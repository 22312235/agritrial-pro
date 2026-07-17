
/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0039_trial_status_history.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the permanent workflow history for agricultural trials.
*
* Supported workflow:
*
*   PENDING_APPROVAL
*       ├── APPROVED
*       ├── REJECTED
*       └── CORRECTIONS_REQUESTED
*
*   CORRECTIONS_REQUESTED
*       └── PENDING_APPROVAL
*
* Rules:
*
*   • Every trial status transition is recorded permanently.
*   • A trial has exactly one current active history record.
*   • The first transition has no previous status.
*   • The first status must be PENDING_APPROVAL.
*   • Consecutive duplicate statuses are prohibited.
*   • The previous current history record is closed automatically.
*   • trials.status_id is synchronized automatically.
*   • Direct modifications of trials.status_id are prohibited.
*   • Workflow history transition fields are immutable after insertion.
*   • Existing trials are backfilled automatically.
*   • RLS will be added in a later migration.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
*   • 0028_decision_types.sql
*   • 0030_trial_statuses.sql
*   • 0036_trials.sql
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
-- TABLE: trial_status_history
--------------------------------------------------------------------------------

CREATE TABLE public.trial_status_history
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                      uuid
                            PRIMARY KEY
                            DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Parent Trial
    --------------------------------------------------------------------------

    trial_id                uuid
                            NOT NULL,

    --------------------------------------------------------------------------
    -- Workflow Transition
    --------------------------------------------------------------------------

    from_status_id          uuid,

    to_status_id            uuid
                            NOT NULL,

    decision_type_id        uuid,

    --------------------------------------------------------------------------
    -- Transition Information
    --------------------------------------------------------------------------

    transition_comment      text,

    manager_comment         text,

    director_comment        text,

    correction_request      text,

    rejection_reason        text,

    --------------------------------------------------------------------------
    -- Current State
    --------------------------------------------------------------------------

    is_current              boolean
                            NOT NULL
                            DEFAULT true,

    --------------------------------------------------------------------------
    -- Workflow Actor and Time
    --------------------------------------------------------------------------

    changed_by              uuid,

    changed_at              timestamptz
                            NOT NULL
                            DEFAULT timezone('UTC', now()),

    --------------------------------------------------------------------------
    -- Audit and Soft Delete
    --------------------------------------------------------------------------

    created_at              timestamptz
                            NOT NULL
                            DEFAULT timezone('UTC', now()),

    updated_at              timestamptz
                            NOT NULL
                            DEFAULT timezone('UTC', now()),

    created_by              uuid,

    updated_by              uuid,

    deleted_at              timestamptz,

    --------------------------------------------------------------------------
    -- Foreign Keys
    --------------------------------------------------------------------------

    CONSTRAINT fk_trial_status_history_trial
        FOREIGN KEY (trial_id)
        REFERENCES public.trials(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trial_status_history_from_status
        FOREIGN KEY (from_status_id)
        REFERENCES public.trial_statuses(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trial_status_history_to_status
        FOREIGN KEY (to_status_id)
        REFERENCES public.trial_statuses(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trial_status_history_decision_type
        FOREIGN KEY (decision_type_id)
        REFERENCES public.decision_types(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trial_status_history_changed_by
        FOREIGN KEY (changed_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_trial_status_history_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_trial_status_history_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_trial_status_history_different_statuses
        CHECK
        (
            from_status_id IS NULL
            OR from_status_id <> to_status_id
        ),

    CONSTRAINT chk_trial_status_history_transition_comment
        CHECK
        (
            transition_comment IS NULL
            OR
            (
                length(btrim(transition_comment)) > 0
                AND char_length(btrim(transition_comment)) <= 5000
            )
        ),

    CONSTRAINT chk_trial_status_history_manager_comment
        CHECK
        (
            manager_comment IS NULL
            OR
            (
                length(btrim(manager_comment)) > 0
                AND char_length(btrim(manager_comment)) <= 5000
            )
        ),

    CONSTRAINT chk_trial_status_history_director_comment
        CHECK
        (
            director_comment IS NULL
            OR
            (
                length(btrim(director_comment)) > 0
                AND char_length(btrim(director_comment)) <= 5000
            )
        ),

    CONSTRAINT chk_trial_status_history_correction_request
        CHECK
        (
            correction_request IS NULL
            OR
            (
                length(btrim(correction_request)) > 0
                AND char_length(btrim(correction_request)) <= 5000
            )
        ),

    CONSTRAINT chk_trial_status_history_rejection_reason
        CHECK
        (
            rejection_reason IS NULL
            OR
            (
                length(btrim(rejection_reason)) > 0
                AND char_length(btrim(rejection_reason)) <= 5000
            )
        ),

    CONSTRAINT chk_trial_status_history_changed_at
        CHECK
        (
            changed_at <= timezone('UTC', now()) + interval '1 day'
        ),

    CONSTRAINT chk_trial_status_history_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_trial_status_history_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        ),

    CONSTRAINT chk_trial_status_history_current_record
        CHECK
        (
            is_current = false
            OR deleted_at IS NULL
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.trial_status_history IS
'Permanent audit trail of all workflow status transitions performed on agricultural trials.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.trial_status_history.id IS
'Internal UUID primary key of the workflow-history record.';

COMMENT ON COLUMN public.trial_status_history.trial_id IS
'Trial whose workflow status changed.';

COMMENT ON COLUMN public.trial_status_history.from_status_id IS
'Previous trial status. NULL only for the first workflow-history record.';

COMMENT ON COLUMN public.trial_status_history.to_status_id IS
'New trial status produced by the workflow transition.';

COMMENT ON COLUMN public.trial_status_history.decision_type_id IS
'Optional configured decision associated with the workflow transition.';

COMMENT ON COLUMN public.trial_status_history.transition_comment IS
'General comment explaining the workflow transition.';

COMMENT ON COLUMN public.trial_status_history.manager_comment IS
'Optional comment entered by a Manager.';

COMMENT ON COLUMN public.trial_status_history.director_comment IS
'Optional comment entered by the General Director.';

COMMENT ON COLUMN public.trial_status_history.correction_request IS
'Correction instructions supplied when the new status is CORRECTIONS_REQUESTED.';

COMMENT ON COLUMN public.trial_status_history.rejection_reason IS
'Reason supplied when the new status is REJECTED.';

COMMENT ON COLUMN public.trial_status_history.is_current IS
'Indicates the active workflow-history record representing the current trial status.';

COMMENT ON COLUMN public.trial_status_history.changed_by IS
'Supabase Auth user who performed the workflow transition.';

COMMENT ON COLUMN public.trial_status_history.changed_at IS
'UTC timestamp when the workflow transition occurred.';

COMMENT ON COLUMN public.trial_status_history.created_at IS
'UTC timestamp when the history record was created.';

COMMENT ON COLUMN public.trial_status_history.updated_at IS
'UTC timestamp when editable history metadata was most recently updated.';

COMMENT ON COLUMN public.trial_status_history.created_by IS
'Supabase Auth user who created the history record.';

COMMENT ON COLUMN public.trial_status_history.updated_by IS
'Supabase Auth user who most recently updated editable history metadata.';

COMMENT ON COLUMN public.trial_status_history.deleted_at IS
'Soft-deletion timestamp. Workflow records should normally remain permanently available.';

--------------------------------------------------------------------------------
-- UNIQUE INDEX: ONE CURRENT STATUS PER TRIAL
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_trial_status_history_one_current
    ON public.trial_status_history (trial_id)
    WHERE is_current = true
      AND deleted_at IS NULL;

--------------------------------------------------------------------------------
-- RELATIONSHIP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_trial_status_history_trial_id
    ON public.trial_status_history (trial_id);

CREATE INDEX idx_trial_status_history_from_status_id
    ON public.trial_status_history (from_status_id)
    WHERE from_status_id IS NOT NULL;

CREATE INDEX idx_trial_status_history_to_status_id
    ON public.trial_status_history (to_status_id);

CREATE INDEX idx_trial_status_history_decision_type_id
    ON public.trial_status_history (decision_type_id)
    WHERE decision_type_id IS NOT NULL;

CREATE INDEX idx_trial_status_history_changed_by
    ON public.trial_status_history (changed_by)
    WHERE changed_by IS NOT NULL;

--------------------------------------------------------------------------------
-- WORKFLOW QUERY INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_trial_status_history_trial_timeline
    ON public.trial_status_history
    (
        trial_id,
        changed_at DESC,
        created_at DESC
    )
    WHERE deleted_at IS NULL;

CREATE INDEX idx_trial_status_history_current
    ON public.trial_status_history
    (
        trial_id,
        to_status_id
    )
    WHERE is_current = true
      AND deleted_at IS NULL;

CREATE INDEX idx_trial_status_history_status_date
    ON public.trial_status_history
    (
        to_status_id,
        changed_at DESC
    )
    WHERE deleted_at IS NULL;

CREATE INDEX idx_trial_status_history_pending_actions
    ON public.trial_status_history
    (
        to_status_id,
        changed_at
    )
    WHERE is_current = true
      AND deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_trial_status_history_created_by
    ON public.trial_status_history (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_trial_status_history_updated_by
    ON public.trial_status_history (updated_by)
    WHERE updated_by IS NOT NULL;

CREATE INDEX idx_trial_status_history_deleted_at
    ON public.trial_status_history (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- FUNCTION: Resolve Trial Status Code
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_get_trial_status_code(
    p_status_id uuid
)
RETURNS text
LANGUAGE plpgsql
STABLE
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_status_code text;
BEGIN
    IF p_status_id IS NULL THEN
        RETURN NULL;
    END IF;

    SELECT upper(btrim(ts.code))
    INTO v_status_code
    FROM public.trial_statuses ts
    WHERE ts.id = p_status_id
      AND ts.deleted_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Trial workflow validation failed: status %s does not exist or is unavailable.',
                    p_status_id
                );
    END IF;

    RETURN v_status_code;
END;
$$;

COMMENT ON FUNCTION public.fn_get_trial_status_code(uuid) IS
'Returns the normalized system code of an active, non-deleted trial status.';

--------------------------------------------------------------------------------
-- FUNCTION: Validate Legal Workflow Transition
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_is_valid_trial_status_transition(
    p_from_status_code text,
    p_to_status_code   text
)
RETURNS boolean
LANGUAGE sql
IMMUTABLE
SECURITY INVOKER
SET search_path = public
AS
$$
    SELECT
        CASE
            WHEN p_from_status_code IS NULL
                 AND p_to_status_code = 'PENDING_APPROVAL'
                THEN true

            WHEN p_from_status_code = 'PENDING_APPROVAL'
                 AND p_to_status_code IN
                 (
                     'APPROVED',
                     'REJECTED',
                     'CORRECTIONS_REQUESTED'
                 )
                THEN true

            WHEN p_from_status_code = 'CORRECTIONS_REQUESTED'
                 AND p_to_status_code = 'PENDING_APPROVAL'
                THEN true

            ELSE false
        END;
$$;

COMMENT ON FUNCTION public.fn_is_valid_trial_status_transition(text, text) IS
'Returns true only when the supplied trial workflow transition is allowed by the frozen workflow.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_trial_status_history()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_trial_status_id             uuid;
    v_trial_deleted_at            timestamptz;

    v_current_history_id          uuid;
    v_current_status_id           uuid;

    v_from_status_code            text;
    v_to_status_code              text;

    v_decision_is_active          boolean;
    v_decision_deleted_at         timestamptz;
BEGIN
    --------------------------------------------------------------------------
    -- Normalize optional text
    --------------------------------------------------------------------------

    NEW.transition_comment :=
        CASE
            WHEN NEW.transition_comment IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.transition_comment), '')
        END;

    NEW.manager_comment :=
        CASE
            WHEN NEW.manager_comment IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.manager_comment), '')
        END;

    NEW.director_comment :=
        CASE
            WHEN NEW.director_comment IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.director_comment), '')
        END;

    NEW.correction_request :=
        CASE
            WHEN NEW.correction_request IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.correction_request), '')
        END;

    NEW.rejection_reason :=
        CASE
            WHEN NEW.rejection_reason IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.rejection_reason), '')
        END;

    NEW.changed_at :=
        COALESCE(
            NEW.changed_at,
            timezone('UTC', now())
        );

    NEW.changed_by :=
        COALESCE(
            NEW.changed_by,
            auth.uid(),
            NEW.created_by
        );

    --------------------------------------------------------------------------
    -- Validate parent trial
    --------------------------------------------------------------------------

    SELECT
        t.status_id,
        t.deleted_at
    INTO
        v_trial_status_id,
        v_trial_deleted_at
    FROM public.trials t
    WHERE t.id = NEW.trial_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Trial workflow validation failed: trial %s does not exist.',
                    NEW.trial_id
                );
    END IF;

    IF v_trial_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial workflow validation failed: status transitions cannot be added to a soft-deleted trial.';
    END IF;

    --------------------------------------------------------------------------
    -- Find current workflow-history record
    --------------------------------------------------------------------------

    SELECT
        tsh.id,
        tsh.to_status_id
    INTO
        v_current_history_id,
        v_current_status_id
    FROM public.trial_status_history tsh
    WHERE tsh.trial_id = NEW.trial_id
      AND tsh.is_current = true
      AND tsh.deleted_at IS NULL
      AND
      (
          TG_OP <> 'UPDATE'
          OR tsh.id <> NEW.id
      )
    ORDER BY
        tsh.changed_at DESC,
        tsh.created_at DESC
    LIMIT 1
    FOR UPDATE;

    --------------------------------------------------------------------------
    -- Determine expected previous status
    --------------------------------------------------------------------------

    IF v_current_history_id IS NULL THEN
        IF NEW.from_status_id IS NOT NULL THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Trial workflow validation failed: the first history record must have a NULL previous status.';
        END IF;
    ELSE
        IF NEW.from_status_id IS NULL THEN
            NEW.from_status_id := v_current_status_id;
        END IF;

        IF NEW.from_status_id IS DISTINCT FROM v_current_status_id THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Trial workflow validation failed: from_status_id must match the current trial status.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Resolve status codes
    --------------------------------------------------------------------------

    v_from_status_code :=
        public.fn_get_trial_status_code(NEW.from_status_id);

    v_to_status_code :=
        public.fn_get_trial_status_code(NEW.to_status_id);

    --------------------------------------------------------------------------
    -- Prevent duplicate consecutive status
    --------------------------------------------------------------------------

    IF NEW.from_status_id IS NOT NULL
       AND NEW.from_status_id = NEW.to_status_id THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial workflow validation failed: duplicate consecutive statuses are not allowed.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate legal workflow transition
    --------------------------------------------------------------------------

    IF NOT public.fn_is_valid_trial_status_transition(
        v_from_status_code,
        v_to_status_code
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = format(
                    'Trial workflow validation failed: transition from %s to %s is not allowed.',
                    COALESCE(v_from_status_code, 'INITIAL'),
                    v_to_status_code
                );
    END IF;

    --------------------------------------------------------------------------
    -- Validate decision type
    --------------------------------------------------------------------------

    IF NEW.decision_type_id IS NOT NULL THEN
        SELECT
            dt.is_active,
            dt.deleted_at
        INTO
            v_decision_is_active,
            v_decision_deleted_at
        FROM public.decision_types dt
        WHERE dt.id = NEW.decision_type_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE =
                        'Trial workflow validation failed: the selected decision type does not exist.';
        END IF;

        IF v_decision_is_active = false
           OR v_decision_deleted_at IS NOT NULL THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Trial workflow validation failed: the selected decision type is unavailable.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Status-specific requirements
    --------------------------------------------------------------------------

    IF v_to_status_code = 'CORRECTIONS_REQUESTED'
       AND NEW.correction_request IS NULL
       AND NEW.transition_comment IS NULL
       AND NEW.manager_comment IS NULL
       AND NEW.director_comment IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial workflow validation failed: correction instructions are required when requesting corrections.';
    END IF;

    IF v_to_status_code = 'REJECTED'
       AND NEW.rejection_reason IS NULL
       AND NEW.transition_comment IS NULL
       AND NEW.manager_comment IS NULL
       AND NEW.director_comment IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial workflow validation failed: a rejection reason is required when rejecting a trial.';
    END IF;

    IF v_to_status_code <> 'CORRECTIONS_REQUESTED'
       AND NEW.correction_request IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial workflow validation failed: correction_request is only allowed for CORRECTIONS_REQUESTED.';
    END IF;

    IF v_to_status_code <> 'REJECTED'
       AND NEW.rejection_reason IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial workflow validation failed: rejection_reason is only allowed for REJECTED.';
    END IF;

    --------------------------------------------------------------------------
    -- New transitions are always current
    --------------------------------------------------------------------------

    IF TG_OP = 'INSERT' THEN
        NEW.is_current := true;
    END IF;

    IF NEW.is_current = true
       AND NEW.deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial workflow validation failed: the current status-history record cannot be soft-deleted.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_trial_status_history() IS
'Validates trial workflow ownership, previous status, legal transitions, decision availability, required comments, and current-record state.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trial_status_history_validate
    BEFORE INSERT OR UPDATE OF
        trial_id,
        from_status_id,
        to_status_id,
        decision_type_id,
        transition_comment,
        manager_comment,
        director_comment,
        correction_request,
        rejection_reason,
        is_current,
        changed_by,
        changed_at,
        deleted_at
    ON public.trial_status_history
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_trial_status_history();

--------------------------------------------------------------------------------
-- FUNCTION: Close Previous Current History Record
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_close_previous_trial_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
BEGIN
    UPDATE public.trial_status_history
    SET
        is_current = false,
        updated_at = timezone('UTC', now()),
        updated_by = COALESCE(
            auth.uid(),
            NEW.changed_by,
            NEW.updated_by,
            NEW.created_by
        )
    WHERE trial_id = NEW.trial_id
      AND id <> NEW.id
      AND is_current = true
      AND deleted_at IS NULL;

    NEW.is_current := true;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_close_previous_trial_status() IS
'Closes the previous current history record before inserting a new trial status transition.';

--------------------------------------------------------------------------------
-- CLOSE PREVIOUS CURRENT RECORD TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trial_status_history_close_previous
    BEFORE INSERT
    ON public.trial_status_history
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_close_previous_trial_status();

--------------------------------------------------------------------------------
-- FUNCTION: Synchronize Trial Current Status
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_sync_trial_current_status()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_status_code text;
BEGIN
    v_status_code :=
        public.fn_get_trial_status_code(NEW.to_status_id);

    UPDATE public.trials
    SET
        status_id = NEW.to_status_id,

        submitted_at =
            CASE
                WHEN v_status_code = 'PENDING_APPROVAL'
                     AND submitted_at IS NULL
                    THEN NEW.changed_at
                ELSE submitted_at
            END,

        approved_at =
            CASE
                WHEN v_status_code = 'APPROVED'
                    THEN NEW.changed_at
                ELSE NULL
            END,

        rejected_at =
            CASE
                WHEN v_status_code = 'REJECTED'
                    THEN NEW.changed_at
                ELSE NULL
            END,

        corrections_requested_at =
            CASE
                WHEN v_status_code = 'CORRECTIONS_REQUESTED'
                    THEN NEW.changed_at
                ELSE NULL
            END,

        updated_at = timezone('UTC', now()),

        updated_by = COALESCE(
            NEW.changed_by,
            auth.uid(),
            NEW.updated_by,
            NEW.created_by
        )

    WHERE id = NEW.trial_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE =
                    'Trial workflow synchronization failed: parent trial was not found.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_sync_trial_current_status() IS
'Synchronizes trials.status_id and workflow timestamps after a new current history record is inserted.';

--------------------------------------------------------------------------------
-- SYNCHRONIZE TRIAL STATUS TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trial_status_history_sync_trial
    AFTER INSERT
    ON public.trial_status_history
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_sync_trial_current_status();

--------------------------------------------------------------------------------
-- FUNCTION: Protect Workflow Transition Fields
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_protect_trial_status_history()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
BEGIN
    IF NEW.trial_id IS DISTINCT FROM OLD.trial_id
       OR NEW.from_status_id IS DISTINCT FROM OLD.from_status_id
       OR NEW.to_status_id IS DISTINCT FROM OLD.to_status_id
       OR NEW.changed_by IS DISTINCT FROM OLD.changed_by
       OR NEW.changed_at IS DISTINCT FROM OLD.changed_at THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial workflow protection failed: transition identity fields are immutable after insertion.';
    END IF;

    IF OLD.is_current = false
       AND NEW.is_current = true THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial workflow protection failed: a historical record cannot be manually restored as current.';
    END IF;

    IF OLD.is_current = true
       AND NEW.deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial workflow protection failed: the current workflow record cannot be soft-deleted.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_protect_trial_status_history() IS
'Protects immutable transition identity fields and prevents invalid current-record restoration or deletion.';

--------------------------------------------------------------------------------
-- PROTECTION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trial_status_history_protect
    BEFORE UPDATE
    ON public.trial_status_history
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_protect_trial_status_history();

--------------------------------------------------------------------------------
-- FUNCTION: Prevent Physical Deletion
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_prevent_trial_status_history_delete()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
BEGIN
    RAISE EXCEPTION
        USING
            ERRCODE = '23514',
            MESSAGE =
                'Trial workflow protection failed: workflow-history records cannot be physically deleted.';

    RETURN OLD;
END;
$$;

COMMENT ON FUNCTION public.trg_prevent_trial_status_history_delete() IS
'Prevents physical deletion of permanent trial workflow-history records.';

--------------------------------------------------------------------------------
-- PHYSICAL DELETE PROTECTION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trial_status_history_prevent_delete
    BEFORE DELETE
    ON public.trial_status_history
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_prevent_trial_status_history_delete();

--------------------------------------------------------------------------------
-- FUNCTION: Prevent Direct Trial Status Changes
--------------------------------------------------------------------------------
-- Status changes must be performed by inserting a trial_status_history record.
-- Updates made internally by trg_sync_trial_current_status are permitted through
-- PostgreSQL trigger depth.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_prevent_direct_trial_status_change()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
BEGIN
    IF NEW.status_id IS DISTINCT FROM OLD.status_id
       AND pg_trigger_depth() <= 1 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Direct trial status changes are prohibited. Insert a trial_status_history record instead.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_prevent_direct_trial_status_change() IS
'Prevents direct modification of trials.status_id outside the controlled workflow-history synchronization process.';

--------------------------------------------------------------------------------
-- DIRECT STATUS CHANGE PROTECTION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trials_prevent_direct_status_change
    BEFORE UPDATE OF status_id
    ON public.trials
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_prevent_direct_trial_status_change();

--------------------------------------------------------------------------------
-- GENERIC AUDIT TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trial_status_history_timestamps
    BEFORE INSERT OR UPDATE
    ON public.trial_status_history
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_trial_status_history_created_by
    BEFORE INSERT
    ON public.trial_status_history
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_trial_status_history_updated_by
    BEFORE UPDATE
    ON public.trial_status_history
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- BACKFILL EXISTING TRIALS
--------------------------------------------------------------------------------
-- Creates the first current workflow-history record for trials that existed
-- before this migration.
--------------------------------------------------------------------------------

INSERT INTO public.trial_status_history
(
    trial_id,
    from_status_id,
    to_status_id,
    decision_type_id,
    transition_comment,
    is_current,
    changed_by,
    changed_at,
    created_by,
    updated_by
)
SELECT
    t.id,
    NULL,
    t.status_id,
    t.initial_decision_type_id,
    'Initial workflow status backfilled during migration 0039.',
    true,
    COALESCE(t.created_by, t.updated_by),
    COALESCE(t.submitted_at, t.created_at, timezone('UTC', now())),
    COALESCE(t.created_by, t.updated_by),
    COALESCE(t.updated_by, t.created_by)
FROM public.trials t
JOIN public.trial_statuses ts
    ON ts.id = t.status_id
WHERE t.deleted_at IS NULL
  AND upper(btrim(ts.code)) = 'PENDING_APPROVAL'
  AND NOT EXISTS
  (
      SELECT 1
      FROM public.trial_status_history tsh
      WHERE tsh.trial_id = t.id
        AND tsh.deleted_at IS NULL
  );

--------------------------------------------------------------------------------
-- MIGRATION VALIDATION
--------------------------------------------------------------------------------

DO
$$
DECLARE
    v_expected_column_count integer;
    v_missing_trial_count    integer;
BEGIN
    --------------------------------------------------------------------------
    -- Verify table
    --------------------------------------------------------------------------

    IF to_regclass('public.trial_status_history') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0039_trial_status_history.sql failed: table was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify required columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO v_expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'trial_status_history'
      AND column_name IN
      (
          'id',
          'trial_id',
          'from_status_id',
          'to_status_id',
          'decision_type_id',
          'transition_comment',
          'manager_comment',
          'director_comment',
          'correction_request',
          'rejection_reason',
          'is_current',
          'changed_by',
          'changed_at',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF v_expected_column_count <> 18 THEN
        RAISE EXCEPTION
            'Migration 0039_trial_status_history.sql failed: table has % of 18 required columns.',
            v_expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trial_status_history'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0039_trial_status_history.sql failed: primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trial_status_history'::regclass
          AND conname = 'fk_trial_status_history_trial'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0039_trial_status_history.sql failed: trial foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trial_status_history'::regclass
          AND conname = 'fk_trial_status_history_from_status'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0039_trial_status_history.sql failed: from-status foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trial_status_history'::regclass
          AND conname = 'fk_trial_status_history_to_status'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0039_trial_status_history.sql failed: to-status foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique current-record index
    --------------------------------------------------------------------------

    IF to_regclass(
        'public.uq_trial_status_history_one_current'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0039_trial_status_history.sql failed: one-current-status index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify workflow functions
    --------------------------------------------------------------------------

    IF to_regprocedure(
        'public.fn_get_trial_status_code(uuid)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0039_trial_status_history.sql failed: status-code function is missing.';
    END IF;

    IF to_regprocedure(
        'public.fn_is_valid_trial_status_transition(text,text)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0039_trial_status_history.sql failed: transition-validation function is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_validate_trial_status_history()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0039_trial_status_history.sql failed: history-validation function is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_sync_trial_current_status()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0039_trial_status_history.sql failed: trial synchronization function is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_prevent_direct_trial_status_change()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0039_trial_status_history.sql failed: direct-change protection function is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trial_status_history'::regclass
          AND tgname = 'trg_trial_status_history_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0039_trial_status_history.sql failed: validation trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trial_status_history'::regclass
          AND tgname = 'trg_trial_status_history_close_previous'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0039_trial_status_history.sql failed: previous-status closing trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trial_status_history'::regclass
          AND tgname = 'trg_trial_status_history_sync_trial'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0039_trial_status_history.sql failed: trial synchronization trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trials'::regclass
          AND tgname = 'trg_trials_prevent_direct_status_change'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0039_trial_status_history.sql failed: direct trial-status protection trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify one current status maximum
    --------------------------------------------------------------------------

    IF EXISTS
    (
        SELECT tsh.trial_id
        FROM public.trial_status_history tsh
        WHERE tsh.is_current = true
          AND tsh.deleted_at IS NULL
        GROUP BY tsh.trial_id
        HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION
            'Migration 0039_trial_status_history.sql failed: one or more trials have multiple current status records.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify current history matches trials.status_id
    --------------------------------------------------------------------------

    IF EXISTS
    (
        SELECT 1
        FROM public.trials t
        JOIN public.trial_status_history tsh
            ON tsh.trial_id = t.id
           AND tsh.is_current = true
           AND tsh.deleted_at IS NULL
        WHERE t.status_id IS DISTINCT FROM tsh.to_status_id
    ) THEN
        RAISE EXCEPTION
            'Migration 0039_trial_status_history.sql failed: current history does not match trials.status_id.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify existing pending trials were backfilled
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO v_missing_trial_count
    FROM public.trials t
    JOIN public.trial_statuses ts
        ON ts.id = t.status_id
    WHERE t.deleted_at IS NULL
      AND upper(btrim(ts.code)) = 'PENDING_APPROVAL'
      AND NOT EXISTS
      (
          SELECT 1
          FROM public.trial_status_history tsh
          WHERE tsh.trial_id = t.id
            AND tsh.is_current = true
            AND tsh.deleted_at IS NULL
      );

    IF v_missing_trial_count > 0 THEN
        RAISE EXCEPTION
            'Migration 0039_trial_status_history.sql failed: % pending trials were not backfilled.',
            v_missing_trial_count;
    END IF;
END;
$$;

COMMIT;
