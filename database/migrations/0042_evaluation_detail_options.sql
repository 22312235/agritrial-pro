/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0042_evaluation_detail_options.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the junction table used to store multiple selected options for
* MULTI_OPTION evaluation criteria.
*
* Business rules:
*
*   • Every record belongs to exactly one evaluation detail.
*   • Every record references exactly one configured criterion option.
*   • The parent evaluation detail must use a MULTI_OPTION criterion.
*   • The selected option must belong to the same criterion as the parent detail.
*   • The selected option must be active and not soft-deleted.
*   • The same option cannot be selected more than once for the same detail.
*   • A custom value is allowed only when the selected option is configured as
*     "Other" or explicitly allows a custom value.
*   • A custom value is required when the selected option is "Other" or requires
*     manual input.
*   • Options cannot be added to completed evaluations.
*   • Options belonging to completed evaluations are immutable.
*   • Physical deletion is prohibited.
*   • Soft deletion remains available for auditability.
*   • RLS will be added in a later migration.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
*   • 0032_criterion_data_types.sql
*   • 0033_evaluation_criteria.sql
*   • 0034_criterion_options.sql
*   • 0040_evaluations.sql
*   • 0041_evaluation_details.sql
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
-- TABLE: evaluation_detail_options
--------------------------------------------------------------------------------

CREATE TABLE public.evaluation_detail_options
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                      uuid
                            PRIMARY KEY
                            DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Parent Evaluation Detail
    --------------------------------------------------------------------------

    evaluation_detail_id    uuid
                            NOT NULL,

    --------------------------------------------------------------------------
    -- Selected Criterion Option
    --------------------------------------------------------------------------

    criterion_option_id     uuid
                            NOT NULL,

    --------------------------------------------------------------------------
    -- Optional Manual Value
    --------------------------------------------------------------------------

    custom_value            text,

    notes                   text,

    --------------------------------------------------------------------------
    -- Display
    --------------------------------------------------------------------------

    display_order           integer
                            NOT NULL
                            DEFAULT 0,

    --------------------------------------------------------------------------
    -- State
    --------------------------------------------------------------------------

    is_active               boolean
                            NOT NULL
                            DEFAULT true,

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

    CONSTRAINT fk_evaluation_detail_options_detail
        FOREIGN KEY (evaluation_detail_id)
        REFERENCES public.evaluation_details(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_evaluation_detail_options_option
        FOREIGN KEY (criterion_option_id)
        REFERENCES public.criterion_options(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_evaluation_detail_options_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_evaluation_detail_options_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_evaluation_detail_options_custom_value
        CHECK
        (
            custom_value IS NULL
            OR char_length(btrim(custom_value)) BETWEEN 1 AND 1000
        ),

    CONSTRAINT chk_evaluation_detail_options_notes
        CHECK
        (
            notes IS NULL
            OR char_length(btrim(notes)) BETWEEN 1 AND 5000
        ),

    CONSTRAINT chk_evaluation_detail_options_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_evaluation_detail_options_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_evaluation_detail_options_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        ),

    CONSTRAINT chk_evaluation_detail_options_active_deleted
        CHECK
        (
            deleted_at IS NULL
            OR is_active = false
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.evaluation_detail_options IS
'Selected options for MULTI_OPTION evaluation criteria recorded in evaluation_details.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.evaluation_detail_options.id IS
'Internal UUID primary key of the selected multi-option result.';

COMMENT ON COLUMN public.evaluation_detail_options.evaluation_detail_id IS
'Parent evaluation detail representing a MULTI_OPTION criterion.';

COMMENT ON COLUMN public.evaluation_detail_options.criterion_option_id IS
'Configured criterion option selected for the parent evaluation detail.';

COMMENT ON COLUMN public.evaluation_detail_options.custom_value IS
'Manual value supplied when the selected option is Other or allows custom input.';

COMMENT ON COLUMN public.evaluation_detail_options.notes IS
'Optional supporting notes for the selected option.';

COMMENT ON COLUMN public.evaluation_detail_options.display_order IS
'Controls selected-option ordering in forms, dashboards, and reports.';

COMMENT ON COLUMN public.evaluation_detail_options.is_active IS
'Indicates whether the selected option is available in active evaluation results.';

COMMENT ON COLUMN public.evaluation_detail_options.created_at IS
'UTC timestamp when the selected option was created.';

COMMENT ON COLUMN public.evaluation_detail_options.updated_at IS
'UTC timestamp when the selected option was most recently updated.';

COMMENT ON COLUMN public.evaluation_detail_options.created_by IS
'Supabase Auth user who created the selected option record.';

COMMENT ON COLUMN public.evaluation_detail_options.updated_by IS
'Supabase Auth user who most recently updated the selected option record.';

COMMENT ON COLUMN public.evaluation_detail_options.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the selected option has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEX
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_evaluation_detail_options_detail_option
    ON public.evaluation_detail_options
    (
        evaluation_detail_id,
        criterion_option_id
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- RELATIONSHIP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluation_detail_options_detail_id
    ON public.evaluation_detail_options (evaluation_detail_id);

CREATE INDEX idx_evaluation_detail_options_option_id
    ON public.evaluation_detail_options (criterion_option_id);

--------------------------------------------------------------------------------
-- APPLICATION QUERY INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluation_detail_options_detail_order
    ON public.evaluation_detail_options
    (
        evaluation_detail_id,
        display_order,
        criterion_option_id
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_detail_options_option_results
    ON public.evaluation_detail_options
    (
        criterion_option_id,
        evaluation_detail_id
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_detail_options_deleted_at
    ON public.evaluation_detail_options (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- AUDIT INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluation_detail_options_created_by
    ON public.evaluation_detail_options (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_evaluation_detail_options_updated_by
    ON public.evaluation_detail_options (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluation_detail_options_custom_value_trgm
    ON public.evaluation_detail_options
    USING gin
    (
        custom_value gin_trgm_ops
    )
    WHERE custom_value IS NOT NULL
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_detail_options_notes_trgm
    ON public.evaluation_detail_options
    USING gin
    (
        notes gin_trgm_ops
    )
    WHERE notes IS NOT NULL
      AND deleted_at IS NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_evaluation_detail_option()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_detail_criterion_id            uuid;
    v_detail_not_applicable          boolean;
    v_detail_active                  boolean;
    v_detail_deleted_at              timestamptz;

    v_evaluation_status              text;
    v_evaluation_active              boolean;
    v_evaluation_deleted_at          timestamptz;

    v_data_type_code                 text;

    v_option_criterion_id            uuid;
    v_option_active                  boolean;
    v_option_deleted_at              timestamptz;
    v_option_is_other                boolean;
    v_option_allows_custom           boolean;
BEGIN
    --------------------------------------------------------------------------
    -- Normalize text
    --------------------------------------------------------------------------

    NEW.custom_value :=
        CASE
            WHEN NEW.custom_value IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.custom_value), '')
        END;

    NEW.notes :=
        CASE
            WHEN NEW.notes IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.notes), '')
        END;

    --------------------------------------------------------------------------
    -- Validate parent evaluation detail and parent evaluation
    --------------------------------------------------------------------------

    SELECT
        ed.criterion_id,
        ed.is_not_applicable,
        ed.is_active,
        ed.deleted_at,
        upper(btrim(e.evaluation_status)),
        e.is_active,
        e.deleted_at,
        upper(btrim(cdt.code))
    INTO
        v_detail_criterion_id,
        v_detail_not_applicable,
        v_detail_active,
        v_detail_deleted_at,
        v_evaluation_status,
        v_evaluation_active,
        v_evaluation_deleted_at,
        v_data_type_code
    FROM public.evaluation_details ed
    JOIN public.evaluations e
        ON e.id = ed.evaluation_id
    JOIN public.evaluation_criteria ec
        ON ec.id = ed.criterion_id
    JOIN public.criterion_data_types cdt
        ON cdt.id = ec.criterion_data_type_id
    WHERE ed.id = NEW.evaluation_detail_id
    FOR UPDATE OF ed, e;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Evaluation detail option validation failed: evaluation detail %s does not exist.',
                    NEW.evaluation_detail_id
                );
    END IF;

    IF v_detail_active = false
       OR v_detail_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation detail option validation failed: the parent evaluation detail is unavailable.';
    END IF;

    IF v_evaluation_active = false
       OR v_evaluation_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation detail option validation failed: the parent evaluation is unavailable.';
    END IF;

    IF TG_OP = 'INSERT'
       AND v_evaluation_status = 'COMPLETED' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation detail option validation failed: options cannot be added to a completed evaluation.';
    END IF;

    IF v_detail_not_applicable = true THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation detail option validation failed: options cannot be selected for a criterion marked as not applicable.';
    END IF;

    IF v_data_type_code <> 'MULTI_OPTION' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = format(
                    'Evaluation detail option validation failed: parent criterion must use MULTI_OPTION, but uses %s.',
                    v_data_type_code
                );
    END IF;

    --------------------------------------------------------------------------
    -- Validate selected criterion option
    --------------------------------------------------------------------------

    SELECT
        co.criterion_id,
        co.is_active,
        co.deleted_at,
        co.is_other,
        co.allows_custom_value
    INTO
        v_option_criterion_id,
        v_option_active,
        v_option_deleted_at,
        v_option_is_other,
        v_option_allows_custom
    FROM public.criterion_options co
    WHERE co.id = NEW.criterion_option_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE =
                    'Evaluation detail option validation failed: selected criterion option does not exist.';
    END IF;

    IF v_option_criterion_id IS DISTINCT FROM v_detail_criterion_id THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation detail option validation failed: selected option belongs to another criterion.';
    END IF;

    IF v_option_active = false
       OR v_option_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation detail option validation failed: selected criterion option is unavailable.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate custom value
    --------------------------------------------------------------------------

    IF NEW.custom_value IS NOT NULL
       AND NOT
       (
           COALESCE(v_option_is_other, false)
           OR COALESCE(v_option_allows_custom, false)
       ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation detail option validation failed: selected option does not allow a custom value.';
    END IF;

    IF
    (
        COALESCE(v_option_is_other, false)
        OR COALESCE(v_option_allows_custom, false)
    )
    AND NEW.custom_value IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation detail option validation failed: a custom value is required for the selected option.';
    END IF;

    --------------------------------------------------------------------------
    -- Soft deletion state
    --------------------------------------------------------------------------

    IF NEW.deleted_at IS NOT NULL THEN
        NEW.is_active := false;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_evaluation_detail_option() IS
'Validates MULTI_OPTION criterion ownership, option ownership, evaluation state, custom values, and soft deletion.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_evaluation_detail_options_validate
    BEFORE INSERT OR UPDATE OF
        evaluation_detail_id,
        criterion_option_id,
        custom_value,
        notes,
        display_order,
        is_active,
        deleted_at
    ON public.evaluation_detail_options
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_evaluation_detail_option();

--------------------------------------------------------------------------------
-- COMPLETED EVALUATION PROTECTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_protect_completed_evaluation_detail_option()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_evaluation_status text;
BEGIN
    SELECT upper(btrim(e.evaluation_status))
    INTO v_evaluation_status
    FROM public.evaluation_details ed
    JOIN public.evaluations e
        ON e.id = ed.evaluation_id
    WHERE ed.id = OLD.evaluation_detail_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE =
                    'Evaluation detail option protection failed: parent evaluation does not exist.';
    END IF;

    IF v_evaluation_status = 'COMPLETED'
       AND
       (
           NEW.evaluation_detail_id IS DISTINCT FROM OLD.evaluation_detail_id
           OR NEW.criterion_option_id IS DISTINCT FROM OLD.criterion_option_id
           OR NEW.custom_value IS DISTINCT FROM OLD.custom_value
           OR NEW.notes IS DISTINCT FROM OLD.notes
           OR NEW.display_order IS DISTINCT FROM OLD.display_order
           OR NEW.is_active IS DISTINCT FROM OLD.is_active
           OR NEW.deleted_at IS DISTINCT FROM OLD.deleted_at
       ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation detail option protection failed: options belonging to completed evaluations are immutable.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_protect_completed_evaluation_detail_option() IS
'Prevents modification or soft deletion of multi-option results belonging to completed evaluations.';

CREATE TRIGGER trg_evaluation_detail_options_protect_completed
    BEFORE UPDATE
    ON public.evaluation_detail_options
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_protect_completed_evaluation_detail_option();

--------------------------------------------------------------------------------
-- PHYSICAL DELETE PROTECTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_prevent_evaluation_detail_option_delete()
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
                'Evaluation detail option protection failed: selected options cannot be physically deleted. Use soft deletion.';

    RETURN OLD;
END;
$$;

COMMENT ON FUNCTION public.trg_prevent_evaluation_detail_option_delete() IS
'Prevents physical deletion of selected multi-option evaluation results.';

CREATE TRIGGER trg_evaluation_detail_options_prevent_delete
    BEFORE DELETE
    ON public.evaluation_detail_options
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_prevent_evaluation_detail_option_delete();

--------------------------------------------------------------------------------
-- VALIDATE MULTI-OPTION COMPLETION
--------------------------------------------------------------------------------
-- Ensures that every completed evaluation detail using MULTI_OPTION has at least
-- one active selected option.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_evaluation_multi_options_on_completion()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_missing_detail_count integer;
BEGIN
    IF NEW.evaluation_status = 'COMPLETED'
       AND OLD.evaluation_status IS DISTINCT FROM NEW.evaluation_status THEN

        SELECT count(*)
        INTO v_missing_detail_count
        FROM public.evaluation_details ed
        JOIN public.evaluation_criteria ec
            ON ec.id = ed.criterion_id
        JOIN public.criterion_data_types cdt
            ON cdt.id = ec.criterion_data_type_id
        WHERE ed.evaluation_id = NEW.id
          AND ed.is_active = true
          AND ed.deleted_at IS NULL
          AND ed.is_not_applicable = false
          AND upper(btrim(cdt.code)) = 'MULTI_OPTION'
          AND NOT EXISTS
          (
              SELECT 1
              FROM public.evaluation_detail_options edo
              WHERE edo.evaluation_detail_id = ed.id
                AND edo.is_active = true
                AND edo.deleted_at IS NULL
          );

        IF v_missing_detail_count > 0 THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE = format(
                        'Evaluation completion failed: % MULTI_OPTION criterion result(s) have no selected options.',
                        v_missing_detail_count
                    );
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_evaluation_multi_options_on_completion() IS
'Prevents evaluation completion when active MULTI_OPTION details do not contain at least one active selected option.';

CREATE TRIGGER trg_evaluations_validate_multi_options_completion
    BEFORE UPDATE OF evaluation_status
    ON public.evaluations
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_evaluation_multi_options_on_completion();

--------------------------------------------------------------------------------
-- PROTECT PARENT DETAIL TYPE WHILE OPTIONS EXIST
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_protect_multi_option_detail_definition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_new_data_type_code text;
BEGIN
    IF NEW.criterion_id IS DISTINCT FROM OLD.criterion_id
       OR NEW.is_not_applicable IS DISTINCT FROM OLD.is_not_applicable
       OR NEW.deleted_at IS DISTINCT FROM OLD.deleted_at
       OR NEW.is_active IS DISTINCT FROM OLD.is_active THEN

        IF EXISTS
        (
            SELECT 1
            FROM public.evaluation_detail_options edo
            WHERE edo.evaluation_detail_id = OLD.id
              AND edo.is_active = true
              AND edo.deleted_at IS NULL
        ) THEN
            IF NEW.is_not_applicable = true
               OR NEW.deleted_at IS NOT NULL
               OR NEW.is_active = false THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Evaluation detail protection failed: active selected options must be soft-deleted before disabling or deleting the parent detail.';
            END IF;

            SELECT upper(btrim(cdt.code))
            INTO v_new_data_type_code
            FROM public.evaluation_criteria ec
            JOIN public.criterion_data_types cdt
                ON cdt.id = ec.criterion_data_type_id
            WHERE ec.id = NEW.criterion_id;

            IF NOT FOUND
               OR v_new_data_type_code <> 'MULTI_OPTION' THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Evaluation detail protection failed: the criterion cannot be changed while active multi-option selections exist.';
            END IF;
        END IF;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_protect_multi_option_detail_definition() IS
'Protects parent evaluation details from becoming incompatible while active multi-option selections exist.';

CREATE TRIGGER trg_evaluation_details_protect_multi_option_definition
    BEFORE UPDATE OF
        criterion_id,
        is_not_applicable,
        is_active,
        deleted_at
    ON public.evaluation_details
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_protect_multi_option_detail_definition();

--------------------------------------------------------------------------------
-- GENERIC AUDIT TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_evaluation_detail_options_timestamps
    BEFORE INSERT OR UPDATE
    ON public.evaluation_detail_options
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_evaluation_detail_options_created_by
    BEFORE INSERT
    ON public.evaluation_detail_options
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_evaluation_detail_options_updated_by
    BEFORE UPDATE
    ON public.evaluation_detail_options
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- MIGRATION VALIDATION
--------------------------------------------------------------------------------

DO
$$
DECLARE
    v_expected_column_count integer;
BEGIN
    --------------------------------------------------------------------------
    -- Verify table
    --------------------------------------------------------------------------

    IF to_regclass('public.evaluation_detail_options') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0042_evaluation_detail_options.sql failed: public.evaluation_detail_options was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify required columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO v_expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'evaluation_detail_options'
      AND column_name IN
      (
          'id',
          'evaluation_detail_id',
          'criterion_option_id',
          'custom_value',
          'notes',
          'display_order',
          'is_active',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF v_expected_column_count <> 12 THEN
        RAISE EXCEPTION
            'Migration 0042_evaluation_detail_options.sql failed: evaluation_detail_options has % of 12 required columns.',
            v_expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluation_detail_options'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0042_evaluation_detail_options.sql failed: primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluation_detail_options'::regclass
          AND conname = 'fk_evaluation_detail_options_detail'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0042_evaluation_detail_options.sql failed: evaluation-detail foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluation_detail_options'::regclass
          AND conname = 'fk_evaluation_detail_options_option'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0042_evaluation_detail_options.sql failed: criterion-option foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique index
    --------------------------------------------------------------------------

    IF to_regclass(
        'public.uq_evaluation_detail_options_detail_option'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0042_evaluation_detail_options.sql failed: detail/option unique index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify functions
    --------------------------------------------------------------------------

    IF to_regprocedure(
        'public.trg_validate_evaluation_detail_option()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0042_evaluation_detail_options.sql failed: validation function is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_protect_completed_evaluation_detail_option()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0042_evaluation_detail_options.sql failed: completed-evaluation protection function is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_prevent_evaluation_detail_option_delete()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0042_evaluation_detail_options.sql failed: delete-protection function is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_validate_evaluation_multi_options_on_completion()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0042_evaluation_detail_options.sql failed: completion-validation function is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_protect_multi_option_detail_definition()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0042_evaluation_detail_options.sql failed: parent-detail protection function is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_detail_options'::regclass
          AND tgname = 'trg_evaluation_detail_options_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0042_evaluation_detail_options.sql failed: validation trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_detail_options'::regclass
          AND tgname = 'trg_evaluation_detail_options_protect_completed'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0042_evaluation_detail_options.sql failed: completed-evaluation protection trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_detail_options'::regclass
          AND tgname = 'trg_evaluation_detail_options_prevent_delete'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0042_evaluation_detail_options.sql failed: physical-delete protection trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluations'::regclass
          AND tgname = 'trg_evaluations_validate_multi_options_completion'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0042_evaluation_detail_options.sql failed: evaluation-completion validation trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_details'::regclass
          AND tgname = 'trg_evaluation_details_protect_multi_option_definition'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0042_evaluation_detail_options.sql failed: parent-detail protection trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_detail_options'::regclass
          AND tgname = 'trg_evaluation_detail_options_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0042_evaluation_detail_options.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_detail_options'::regclass
          AND tgname = 'trg_evaluation_detail_options_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0042_evaluation_detail_options.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_detail_options'::regclass
          AND tgname = 'trg_evaluation_detail_options_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0042_evaluation_detail_options.sql failed: updated_by trigger is missing.';
    END IF;
END;
$$;

COMMIT;
