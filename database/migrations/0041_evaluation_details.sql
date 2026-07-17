/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0041_evaluation_details.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the evaluation_details table.
*
* This table stores criterion-level results collected during Phase 2 agricultural
* evaluations.
*
* Supported criterion value types are resolved from criterion_data_types:
*
*   • TEXT
*   • LONG_TEXT
*   • INTEGER
*   • DECIMAL
*   • BOOLEAN
*   • DATE
*   • OPTION
*   • MULTI_OPTION
*
* Business rules:
*
*   • Every detail belongs to exactly one evaluation.
*   • Every detail references exactly one configured evaluation criterion.
*   • A detail may optionally target one trial variety.
*   • The selected trial variety must belong to the evaluation trial.
*   • When the parent evaluation targets one variety, the detail variety must
*     match that evaluation variety.
*   • The criterion must be active and available.
*   • The criterion must be assigned to the evaluation type and trial crop when
*     an applicable criterion assignment exists.
*   • Exactly one value representation is used according to the criterion data
*     type.
*   • OPTION values use criterion_option_id.
*   • MULTI_OPTION values are stored through evaluation_detail_options, which
*     will be created in migration 0042.
*   • Manual values are allowed only when configured by the criterion or selected
*     option.
*   • Details belonging to completed evaluations are immutable.
*   • Physical deletion is prohibited.
*   • Historical records use soft deletion.
*   • RLS will be added later.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
*   • 0032_criterion_data_types.sql
*   • 0033_evaluation_criteria.sql
*   • 0034_criterion_options.sql
*   • 0035_criterion_assignments.sql
*   • 0037_trial_varieties.sql
*   • 0040_evaluations.sql
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
-- TABLE: evaluation_details
--------------------------------------------------------------------------------

CREATE TABLE public.evaluation_details
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                      uuid
                            PRIMARY KEY
                            DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Parent Evaluation
    --------------------------------------------------------------------------

    evaluation_id           uuid
                            NOT NULL,

    --------------------------------------------------------------------------
    -- Optional Evaluated Variety
    --------------------------------------------------------------------------

    trial_variety_id        uuid,

    --------------------------------------------------------------------------
    -- Evaluation Criterion
    --------------------------------------------------------------------------

    criterion_id            uuid
                            NOT NULL,

    criterion_option_id     uuid,

    --------------------------------------------------------------------------
    -- Typed Criterion Values
    --------------------------------------------------------------------------

    text_value              text,

    integer_value           bigint,

    decimal_value           numeric(18,6),

    boolean_value           boolean,

    date_value              date,

    --------------------------------------------------------------------------
    -- Manual and Supporting Values
    --------------------------------------------------------------------------

    custom_value            text,

    unit_value              varchar(50),

    notes                   text,

    --------------------------------------------------------------------------
    -- Result Metadata
    --------------------------------------------------------------------------

    is_not_applicable       boolean
                            NOT NULL
                            DEFAULT false,

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

    CONSTRAINT fk_evaluation_details_evaluation
        FOREIGN KEY (evaluation_id)
        REFERENCES public.evaluations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_evaluation_details_trial_variety
        FOREIGN KEY (trial_variety_id)
        REFERENCES public.trial_varieties(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_evaluation_details_criterion
        FOREIGN KEY (criterion_id)
        REFERENCES public.evaluation_criteria(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_evaluation_details_criterion_option
        FOREIGN KEY (criterion_option_id)
        REFERENCES public.criterion_options(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_evaluation_details_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_evaluation_details_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_evaluation_details_text_value
        CHECK
        (
            text_value IS NULL
            OR char_length(btrim(text_value)) BETWEEN 1 AND 10000
        ),

    CONSTRAINT chk_evaluation_details_custom_value
        CHECK
        (
            custom_value IS NULL
            OR char_length(btrim(custom_value)) BETWEEN 1 AND 1000
        ),

    CONSTRAINT chk_evaluation_details_unit_value
        CHECK
        (
            unit_value IS NULL
            OR char_length(btrim(unit_value)) BETWEEN 1 AND 50
        ),

    CONSTRAINT chk_evaluation_details_notes
        CHECK
        (
            notes IS NULL
            OR char_length(btrim(notes)) BETWEEN 1 AND 5000
        ),

    CONSTRAINT chk_evaluation_details_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_evaluation_details_not_applicable_value
        CHECK
        (
            is_not_applicable = false
            OR
            (
                criterion_option_id IS NULL
                AND text_value IS NULL
                AND integer_value IS NULL
                AND decimal_value IS NULL
                AND boolean_value IS NULL
                AND date_value IS NULL
                AND custom_value IS NULL
            )
        ),

    CONSTRAINT chk_evaluation_details_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_evaluation_details_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        ),

    CONSTRAINT chk_evaluation_details_active_deleted
        CHECK
        (
            deleted_at IS NULL
            OR is_active = false
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.evaluation_details IS
'Criterion-level typed results recorded during agricultural trial evaluations.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.evaluation_details.id IS
'Internal UUID primary key of the criterion result.';

COMMENT ON COLUMN public.evaluation_details.evaluation_id IS
'Parent observation or technical evaluation containing the result.';

COMMENT ON COLUMN public.evaluation_details.trial_variety_id IS
'Optional candidate or witness variety evaluated by this criterion result.';

COMMENT ON COLUMN public.evaluation_details.criterion_id IS
'Configured evaluation criterion being measured or observed.';

COMMENT ON COLUMN public.evaluation_details.criterion_option_id IS
'Selected configured option for OPTION-type criteria.';

COMMENT ON COLUMN public.evaluation_details.text_value IS
'Text or long-text result according to the criterion data type.';

COMMENT ON COLUMN public.evaluation_details.integer_value IS
'Whole-number result according to the criterion data type.';

COMMENT ON COLUMN public.evaluation_details.decimal_value IS
'Decimal measurement or score according to the criterion data type.';

COMMENT ON COLUMN public.evaluation_details.boolean_value IS
'Boolean result according to the criterion data type.';

COMMENT ON COLUMN public.evaluation_details.date_value IS
'Date result according to the criterion data type.';

COMMENT ON COLUMN public.evaluation_details.custom_value IS
'Manual result entered when the criterion or selected option permits a custom value.';

COMMENT ON COLUMN public.evaluation_details.unit_value IS
'Optional measurement unit displayed with numeric results.';

COMMENT ON COLUMN public.evaluation_details.notes IS
'Optional explanation or supporting notes for the criterion result.';

COMMENT ON COLUMN public.evaluation_details.is_not_applicable IS
'Indicates that the criterion does not apply to the evaluated trial or variety.';

COMMENT ON COLUMN public.evaluation_details.display_order IS
'Controls criterion-result ordering in forms, reports, and dashboards.';

COMMENT ON COLUMN public.evaluation_details.is_active IS
'Indicates whether the criterion result is available in active evaluation views.';

COMMENT ON COLUMN public.evaluation_details.created_at IS
'UTC timestamp when the criterion result was created.';

COMMENT ON COLUMN public.evaluation_details.updated_at IS
'UTC timestamp when the criterion result was most recently updated.';

COMMENT ON COLUMN public.evaluation_details.created_by IS
'Supabase Auth user who created the criterion result.';

COMMENT ON COLUMN public.evaluation_details.updated_by IS
'Supabase Auth user who most recently updated the criterion result.';

COMMENT ON COLUMN public.evaluation_details.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the result has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------
-- A criterion can be recorded once for the general evaluation and once for each
-- evaluated variety.
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_evaluation_details_general_criterion
    ON public.evaluation_details
    (
        evaluation_id,
        criterion_id
    )
    WHERE trial_variety_id IS NULL
      AND deleted_at IS NULL;

CREATE UNIQUE INDEX uq_evaluation_details_variety_criterion
    ON public.evaluation_details
    (
        evaluation_id,
        trial_variety_id,
        criterion_id
    )
    WHERE trial_variety_id IS NOT NULL
      AND deleted_at IS NULL;

--------------------------------------------------------------------------------
-- RELATIONSHIP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluation_details_evaluation_id
    ON public.evaluation_details (evaluation_id);

CREATE INDEX idx_evaluation_details_trial_variety_id
    ON public.evaluation_details (trial_variety_id)
    WHERE trial_variety_id IS NOT NULL;

CREATE INDEX idx_evaluation_details_criterion_id
    ON public.evaluation_details (criterion_id);

CREATE INDEX idx_evaluation_details_criterion_option_id
    ON public.evaluation_details (criterion_option_id)
    WHERE criterion_option_id IS NOT NULL;

--------------------------------------------------------------------------------
-- APPLICATION QUERY INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluation_details_evaluation_order
    ON public.evaluation_details
    (
        evaluation_id,
        display_order,
        criterion_id
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_details_variety_order
    ON public.evaluation_details
    (
        evaluation_id,
        trial_variety_id,
        display_order
    )
    WHERE trial_variety_id IS NOT NULL
      AND is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_details_criterion_results
    ON public.evaluation_details
    (
        criterion_id,
        evaluation_id
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_details_not_applicable
    ON public.evaluation_details
    (
        evaluation_id,
        criterion_id
    )
    WHERE is_not_applicable = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_details_deleted_at
    ON public.evaluation_details (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- AUDIT INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluation_details_created_by
    ON public.evaluation_details (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_evaluation_details_updated_by
    ON public.evaluation_details (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluation_details_text_value_trgm
    ON public.evaluation_details
    USING gin
    (
        text_value gin_trgm_ops
    )
    WHERE text_value IS NOT NULL
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_details_custom_value_trgm
    ON public.evaluation_details
    USING gin
    (
        custom_value gin_trgm_ops
    )
    WHERE custom_value IS NOT NULL
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_details_notes_trgm
    ON public.evaluation_details
    USING gin
    (
        notes gin_trgm_ops
    )
    WHERE notes IS NOT NULL
      AND deleted_at IS NULL;

--------------------------------------------------------------------------------
-- FUNCTION: Count Populated Scalar Values
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.fn_evaluation_detail_scalar_value_count(
    p_criterion_option_id uuid,
    p_text_value          text,
    p_integer_value       bigint,
    p_decimal_value       numeric,
    p_boolean_value       boolean,
    p_date_value          date,
    p_custom_value        text
)
RETURNS integer
LANGUAGE sql
IMMUTABLE
SECURITY INVOKER
SET search_path = public
AS
$$
    SELECT
        (p_criterion_option_id IS NOT NULL)::integer
        + (p_text_value IS NOT NULL)::integer
        + (p_integer_value IS NOT NULL)::integer
        + (p_decimal_value IS NOT NULL)::integer
        + (p_boolean_value IS NOT NULL)::integer
        + (p_date_value IS NOT NULL)::integer
        + (p_custom_value IS NOT NULL)::integer;
$$;

COMMENT ON FUNCTION public.fn_evaluation_detail_scalar_value_count(
    uuid,
    text,
    bigint,
    numeric,
    boolean,
    date,
    text
) IS
'Returns the number of populated scalar result fields in an evaluation detail.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_evaluation_detail()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_evaluation_trial_id             uuid;
    v_evaluation_variety_id           uuid;
    v_evaluation_type_id              uuid;
    v_evaluation_status               text;
    v_evaluation_active               boolean;
    v_evaluation_deleted_at           timestamptz;

    v_trial_crop_id                   uuid;

    v_variety_trial_id                uuid;
    v_variety_active                  boolean;
    v_variety_deleted_at              timestamptz;

    v_criterion_data_type_id          uuid;
    v_criterion_active                boolean;
    v_criterion_deleted_at            timestamptz;
    v_criterion_allows_custom         boolean;

    v_data_type_code                  text;

    v_option_criterion_id             uuid;
    v_option_active                   boolean;
    v_option_deleted_at               timestamptz;
    v_option_is_other                 boolean;
    v_option_allows_custom            boolean;

    v_scalar_value_count              integer;
    v_assignment_exists               boolean;
    v_assignment_matches              boolean;
BEGIN
    --------------------------------------------------------------------------
    -- Normalize optional text values
    --------------------------------------------------------------------------

    NEW.text_value :=
        CASE
            WHEN NEW.text_value IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.text_value), '')
        END;

    NEW.custom_value :=
        CASE
            WHEN NEW.custom_value IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.custom_value), '')
        END;

    NEW.unit_value :=
        CASE
            WHEN NEW.unit_value IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.unit_value), '')
        END;

    NEW.notes :=
        CASE
            WHEN NEW.notes IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.notes), '')
        END;

    --------------------------------------------------------------------------
    -- Validate parent evaluation
    --------------------------------------------------------------------------

    SELECT
        e.trial_id,
        e.trial_variety_id,
        e.evaluation_type_id,
        upper(btrim(e.evaluation_status)),
        e.is_active,
        e.deleted_at,
        t.crop_id
    INTO
        v_evaluation_trial_id,
        v_evaluation_variety_id,
        v_evaluation_type_id,
        v_evaluation_status,
        v_evaluation_active,
        v_evaluation_deleted_at,
        v_trial_crop_id
    FROM public.evaluations e
    JOIN public.trials t
        ON t.id = e.trial_id
    WHERE e.id = NEW.evaluation_id
    FOR UPDATE OF e;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Evaluation detail validation failed: evaluation %s does not exist.',
                    NEW.evaluation_id
                );
    END IF;

    IF v_evaluation_active = false
       OR v_evaluation_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation detail validation failed: the parent evaluation is unavailable.';
    END IF;

    IF TG_OP = 'INSERT'
       AND v_evaluation_status = 'COMPLETED' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation detail validation failed: details cannot be added to a completed evaluation.';
    END IF;

    --------------------------------------------------------------------------
    -- Default and validate trial variety
    --------------------------------------------------------------------------

    IF NEW.trial_variety_id IS NULL
       AND v_evaluation_variety_id IS NOT NULL THEN
        NEW.trial_variety_id := v_evaluation_variety_id;
    END IF;

    IF v_evaluation_variety_id IS NOT NULL
       AND NEW.trial_variety_id IS DISTINCT FROM v_evaluation_variety_id THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation detail validation failed: the detail variety must match the variety selected on the parent evaluation.';
    END IF;

    IF NEW.trial_variety_id IS NOT NULL THEN
        SELECT
            tv.trial_id,
            tv.is_active,
            tv.deleted_at
        INTO
            v_variety_trial_id,
            v_variety_active,
            v_variety_deleted_at
        FROM public.trial_varieties tv
        WHERE tv.id = NEW.trial_variety_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE =
                        'Evaluation detail validation failed: selected trial variety does not exist.';
        END IF;

        IF v_variety_trial_id IS DISTINCT FROM v_evaluation_trial_id THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation detail validation failed: selected variety belongs to another trial.';
        END IF;

        IF v_variety_active = false
           OR v_variety_deleted_at IS NOT NULL THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation detail validation failed: selected trial variety is unavailable.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Validate criterion and resolve data type
    --------------------------------------------------------------------------

    SELECT
        ec.criterion_data_type_id,
        ec.is_active,
        ec.deleted_at,
        ec.allows_custom_value
    INTO
        v_criterion_data_type_id,
        v_criterion_active,
        v_criterion_deleted_at,
        v_criterion_allows_custom
    FROM public.evaluation_criteria ec
    WHERE ec.id = NEW.criterion_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE =
                    'Evaluation detail validation failed: selected criterion does not exist.';
    END IF;

    IF v_criterion_active = false
       OR v_criterion_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation detail validation failed: selected criterion is unavailable.';
    END IF;

    SELECT
        upper(btrim(cdt.code))
    INTO
        v_data_type_code
    FROM public.criterion_data_types cdt
    WHERE cdt.id = v_criterion_data_type_id
      AND cdt.is_active = true
      AND cdt.deleted_at IS NULL;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation detail validation failed: criterion data type is unavailable.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate criterion assignment when assignments exist
    --------------------------------------------------------------------------

    SELECT EXISTS
    (
        SELECT 1
        FROM public.criterion_assignments ca
        WHERE ca.criterion_id = NEW.criterion_id
          AND ca.is_active = true
          AND ca.deleted_at IS NULL
    )
    INTO v_assignment_exists;

    IF v_assignment_exists THEN
        SELECT EXISTS
        (
            SELECT 1
            FROM public.criterion_assignments ca
            WHERE ca.criterion_id = NEW.criterion_id
              AND ca.is_active = true
              AND ca.deleted_at IS NULL
              AND
              (
                  ca.evaluation_type_id IS NULL
                  OR ca.evaluation_type_id = v_evaluation_type_id
              )
              AND
              (
                  ca.crop_id IS NULL
                  OR ca.crop_id = v_trial_crop_id
              )
        )
        INTO v_assignment_matches;

        IF NOT v_assignment_matches THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation detail validation failed: criterion is not assigned to this evaluation type or crop.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Validate selected option
    --------------------------------------------------------------------------

    IF NEW.criterion_option_id IS NOT NULL THEN
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
                        'Evaluation detail validation failed: selected criterion option does not exist.';
        END IF;

        IF v_option_criterion_id IS DISTINCT FROM NEW.criterion_id THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation detail validation failed: selected option belongs to another criterion.';
        END IF;

        IF v_option_active = false
           OR v_option_deleted_at IS NOT NULL THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation detail validation failed: selected criterion option is unavailable.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Not-applicable result
    --------------------------------------------------------------------------

    IF NEW.is_not_applicable = true THEN
        NEW.criterion_option_id := NULL;
        NEW.text_value := NULL;
        NEW.integer_value := NULL;
        NEW.decimal_value := NULL;
        NEW.boolean_value := NULL;
        NEW.date_value := NULL;
        NEW.custom_value := NULL;

        IF NEW.deleted_at IS NOT NULL THEN
            NEW.is_active := false;
        END IF;

        RETURN NEW;
    END IF;

    --------------------------------------------------------------------------
    -- Count populated scalar fields
    --------------------------------------------------------------------------

    v_scalar_value_count :=
        public.fn_evaluation_detail_scalar_value_count
        (
            NEW.criterion_option_id,
            NEW.text_value,
            NEW.integer_value,
            NEW.decimal_value,
            NEW.boolean_value,
            NEW.date_value,
            NEW.custom_value
        );

    --------------------------------------------------------------------------
    -- Validate data-type-specific values
    --------------------------------------------------------------------------

    CASE v_data_type_code

        WHEN 'TEXT', 'LONG_TEXT' THEN
            IF NEW.text_value IS NULL THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Evaluation detail validation failed: a text value is required for this criterion.';
            END IF;

            IF NEW.criterion_option_id IS NOT NULL
               OR NEW.integer_value IS NOT NULL
               OR NEW.decimal_value IS NOT NULL
               OR NEW.boolean_value IS NOT NULL
               OR NEW.date_value IS NOT NULL THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Evaluation detail validation failed: invalid value field for a text criterion.';
            END IF;

        WHEN 'INTEGER' THEN
            IF NEW.integer_value IS NULL THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Evaluation detail validation failed: an integer value is required for this criterion.';
            END IF;

            IF NEW.criterion_option_id IS NOT NULL
               OR NEW.text_value IS NOT NULL
               OR NEW.decimal_value IS NOT NULL
               OR NEW.boolean_value IS NOT NULL
               OR NEW.date_value IS NOT NULL THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Evaluation detail validation failed: invalid value field for an integer criterion.';
            END IF;

        WHEN 'DECIMAL' THEN
            IF NEW.decimal_value IS NULL THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Evaluation detail validation failed: a decimal value is required for this criterion.';
            END IF;

            IF NEW.criterion_option_id IS NOT NULL
               OR NEW.text_value IS NOT NULL
               OR NEW.integer_value IS NOT NULL
               OR NEW.boolean_value IS NOT NULL
               OR NEW.date_value IS NOT NULL THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Evaluation detail validation failed: invalid value field for a decimal criterion.';
            END IF;

        WHEN 'BOOLEAN' THEN
            IF NEW.boolean_value IS NULL THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Evaluation detail validation failed: a boolean value is required for this criterion.';
            END IF;

            IF NEW.criterion_option_id IS NOT NULL
               OR NEW.text_value IS NOT NULL
               OR NEW.integer_value IS NOT NULL
               OR NEW.decimal_value IS NOT NULL
               OR NEW.date_value IS NOT NULL THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Evaluation detail validation failed: invalid value field for a boolean criterion.';
            END IF;

        WHEN 'DATE' THEN
            IF NEW.date_value IS NULL THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Evaluation detail validation failed: a date value is required for this criterion.';
            END IF;

            IF NEW.criterion_option_id IS NOT NULL
               OR NEW.text_value IS NOT NULL
               OR NEW.integer_value IS NOT NULL
               OR NEW.decimal_value IS NOT NULL
               OR NEW.boolean_value IS NOT NULL THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Evaluation detail validation failed: invalid value field for a date criterion.';
            END IF;

        WHEN 'OPTION' THEN
            IF NEW.criterion_option_id IS NULL THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Evaluation detail validation failed: a configured option is required for this criterion.';
            END IF;

            IF NEW.text_value IS NOT NULL
               OR NEW.integer_value IS NOT NULL
               OR NEW.decimal_value IS NOT NULL
               OR NEW.boolean_value IS NOT NULL
               OR NEW.date_value IS NOT NULL THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Evaluation detail validation failed: invalid value field for an option criterion.';
            END IF;

        WHEN 'MULTI_OPTION' THEN
            IF NEW.criterion_option_id IS NOT NULL
               OR NEW.text_value IS NOT NULL
               OR NEW.integer_value IS NOT NULL
               OR NEW.decimal_value IS NOT NULL
               OR NEW.boolean_value IS NOT NULL
               OR NEW.date_value IS NOT NULL THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Evaluation detail validation failed: MULTI_OPTION selections must be stored in evaluation_detail_options.';
            END IF;

        ELSE
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE = format(
                        'Evaluation detail validation failed: unsupported criterion data type %s.',
                        v_data_type_code
                    );
    END CASE;

    --------------------------------------------------------------------------
    -- Validate manual custom value
    --------------------------------------------------------------------------

    IF NEW.custom_value IS NOT NULL THEN
        IF v_data_type_code = 'OPTION' THEN
            IF NOT
            (
                COALESCE(v_criterion_allows_custom, false)
                OR COALESCE(v_option_allows_custom, false)
                OR COALESCE(v_option_is_other, false)
            ) THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Evaluation detail validation failed: the selected criterion option does not allow a custom value.';
            END IF;
        ELSIF NOT COALESCE(v_criterion_allows_custom, false) THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation detail validation failed: this criterion does not allow a custom value.';
        END IF;
    END IF;

    IF v_data_type_code = 'OPTION'
       AND
       (
           COALESCE(v_option_is_other, false)
           OR COALESCE(v_option_allows_custom, false)
       )
       AND NEW.custom_value IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation detail validation failed: a custom value is required for the selected option.';
    END IF;

    --------------------------------------------------------------------------
    -- General scalar value validation
    --------------------------------------------------------------------------

    IF v_data_type_code <> 'MULTI_OPTION'
       AND v_scalar_value_count = 0 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation detail validation failed: a criterion result value is required.';
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

COMMENT ON FUNCTION public.trg_validate_evaluation_detail() IS
'Validates evaluation ownership, trial variety ownership, criterion assignment, criterion data type, selected option, manual values, and soft deletion.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_evaluation_details_validate
    BEFORE INSERT OR UPDATE OF
        evaluation_id,
        trial_variety_id,
        criterion_id,
        criterion_option_id,
        text_value,
        integer_value,
        decimal_value,
        boolean_value,
        date_value,
        custom_value,
        unit_value,
        notes,
        is_not_applicable,
        display_order,
        is_active,
        deleted_at
    ON public.evaluation_details
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_evaluation_detail();

--------------------------------------------------------------------------------
-- COMPLETED EVALUATION DETAIL PROTECTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_protect_completed_evaluation_detail()
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
    FROM public.evaluations e
    WHERE e.id = OLD.evaluation_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE =
                    'Evaluation detail protection failed: parent evaluation does not exist.';
    END IF;

    IF v_evaluation_status = 'COMPLETED'
       AND
       (
           NEW.evaluation_id IS DISTINCT FROM OLD.evaluation_id
           OR NEW.trial_variety_id IS DISTINCT FROM OLD.trial_variety_id
           OR NEW.criterion_id IS DISTINCT FROM OLD.criterion_id
           OR NEW.criterion_option_id IS DISTINCT FROM OLD.criterion_option_id
           OR NEW.text_value IS DISTINCT FROM OLD.text_value
           OR NEW.integer_value IS DISTINCT FROM OLD.integer_value
           OR NEW.decimal_value IS DISTINCT FROM OLD.decimal_value
           OR NEW.boolean_value IS DISTINCT FROM OLD.boolean_value
           OR NEW.date_value IS DISTINCT FROM OLD.date_value
           OR NEW.custom_value IS DISTINCT FROM OLD.custom_value
           OR NEW.unit_value IS DISTINCT FROM OLD.unit_value
           OR NEW.notes IS DISTINCT FROM OLD.notes
           OR NEW.is_not_applicable IS DISTINCT FROM OLD.is_not_applicable
           OR NEW.display_order IS DISTINCT FROM OLD.display_order
       ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation detail protection failed: results belonging to a completed evaluation are immutable.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_protect_completed_evaluation_detail() IS
'Prevents modification of criterion results belonging to completed evaluations.';

CREATE TRIGGER trg_evaluation_details_protect_completed
    BEFORE UPDATE
    ON public.evaluation_details
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_protect_completed_evaluation_detail();

--------------------------------------------------------------------------------
-- PHYSICAL DELETE PROTECTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_prevent_evaluation_detail_delete()
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
                'Evaluation detail protection failed: criterion results cannot be physically deleted. Use soft deletion.';

    RETURN OLD;
END;
$$;

COMMENT ON FUNCTION public.trg_prevent_evaluation_detail_delete() IS
'Prevents physical deletion of evaluation criterion results.';

CREATE TRIGGER trg_evaluation_details_prevent_delete
    BEFORE DELETE
    ON public.evaluation_details
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_prevent_evaluation_detail_delete();

--------------------------------------------------------------------------------
-- GENERIC AUDIT TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_evaluation_details_timestamps
    BEFORE INSERT OR UPDATE
    ON public.evaluation_details
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_evaluation_details_created_by
    BEFORE INSERT
    ON public.evaluation_details
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_evaluation_details_updated_by
    BEFORE UPDATE
    ON public.evaluation_details
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

    IF to_regclass('public.evaluation_details') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0041_evaluation_details.sql failed: public.evaluation_details was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify required columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO v_expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'evaluation_details'
      AND column_name IN
      (
          'id',
          'evaluation_id',
          'trial_variety_id',
          'criterion_id',
          'criterion_option_id',
          'text_value',
          'integer_value',
          'decimal_value',
          'boolean_value',
          'date_value',
          'custom_value',
          'unit_value',
          'notes',
          'is_not_applicable',
          'display_order',
          'is_active',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF v_expected_column_count <> 21 THEN
        RAISE EXCEPTION
            'Migration 0041_evaluation_details.sql failed: evaluation_details has % of 21 required columns.',
            v_expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluation_details'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0041_evaluation_details.sql failed: primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluation_details'::regclass
          AND conname = 'fk_evaluation_details_evaluation'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0041_evaluation_details.sql failed: evaluation foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluation_details'::regclass
          AND conname = 'fk_evaluation_details_trial_variety'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0041_evaluation_details.sql failed: trial-variety foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluation_details'::regclass
          AND conname = 'fk_evaluation_details_criterion'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0041_evaluation_details.sql failed: criterion foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluation_details'::regclass
          AND conname = 'fk_evaluation_details_criterion_option'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0041_evaluation_details.sql failed: criterion-option foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass(
        'public.uq_evaluation_details_general_criterion'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0041_evaluation_details.sql failed: general criterion unique index is missing.';
    END IF;

    IF to_regclass(
        'public.uq_evaluation_details_variety_criterion'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0041_evaluation_details.sql failed: variety criterion unique index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify functions
    --------------------------------------------------------------------------

    IF to_regprocedure(
        'public.fn_evaluation_detail_scalar_value_count(uuid,text,bigint,numeric,boolean,date,text)'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0041_evaluation_details.sql failed: scalar-value count function is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_validate_evaluation_detail()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0041_evaluation_details.sql failed: validation function is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_protect_completed_evaluation_detail()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0041_evaluation_details.sql failed: completed-evaluation protection function is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_prevent_evaluation_detail_delete()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0041_evaluation_details.sql failed: delete-protection function is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_details'::regclass
          AND tgname = 'trg_evaluation_details_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0041_evaluation_details.sql failed: validation trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_details'::regclass
          AND tgname = 'trg_evaluation_details_protect_completed'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0041_evaluation_details.sql failed: completed-evaluation protection trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_details'::regclass
          AND tgname = 'trg_evaluation_details_prevent_delete'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0041_evaluation_details.sql failed: physical-delete protection trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_details'::regclass
          AND tgname = 'trg_evaluation_details_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0041_evaluation_details.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_details'::regclass
          AND tgname = 'trg_evaluation_details_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0041_evaluation_details.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_details'::regclass
          AND tgname = 'trg_evaluation_details_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0041_evaluation_details.sql failed: updated_by trigger is missing.';
    END IF;
END;
$$;

COMMIT;
