/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0035_criterion_assignments.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the criterion_assignments configuration table.
*
* Criterion assignments determine where and how each evaluation criterion appears
* inside the dynamic evaluation forms.
*
* An assignment connects:
*
*   • One evaluation criterion
*   • One evaluation type
*   • Optionally one crop
*
* Examples:
*
*   • Plant Vigor appears in Observation evaluations.
*   • BRIX appears in Technical Evaluations.
*   • Fruit Defects appears in both evaluation types.
*   • A criterion may be required in one evaluation type and optional in another.
*   • Crop-specific assignments may override global assignments.
*
* Frozen architectural rules:
*
*   • Flutter builds evaluation forms from active criterion assignments.
*   • Criteria are not hardcoded in the application.
*   • A criterion may be assigned to Observation, Technical Evaluation, or both.
*   • NULL crop_id represents a global assignment.
*   • A non-NULL crop_id limits the assignment to one crop.
*   • Crop-specific assignment configuration takes precedence over a global
*     assignment when both exist.
*   • Assignment-level required behavior may override the criterion default.
*   • Historical assignments use soft deletion.
*   • Row Level Security policies are intentionally deferred.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0003_domains.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
*   • 0018_crops.sql
*   • 0031_evaluation_types.sql
*   • 0033_evaluation_criteria.sql
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
-- TABLE: criterion_assignments
--------------------------------------------------------------------------------

CREATE TABLE public.criterion_assignments
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                      uuid
                            PRIMARY KEY
                            DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Assignment Relationships
    --------------------------------------------------------------------------

    evaluation_type_id      uuid
                            NOT NULL,

    criterion_id            uuid
                            NOT NULL,

    crop_id                 uuid,

    --------------------------------------------------------------------------
    -- Dynamic Form Behavior
    --------------------------------------------------------------------------

    is_required             boolean
                            NOT NULL
                            DEFAULT false,

    is_visible              boolean
                            NOT NULL
                            DEFAULT true,

    allows_not_applicable   boolean
                            NOT NULL
                            DEFAULT false,

    section_name            varchar(150),

    display_order           integer
                            NOT NULL
                            DEFAULT 0,

    --------------------------------------------------------------------------
    -- Configuration State
    --------------------------------------------------------------------------

    is_active               boolean
                            NOT NULL
                            DEFAULT true,

    --------------------------------------------------------------------------
    -- Audit and Soft-Delete Columns
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

    CONSTRAINT fk_criterion_assignments_evaluation_type
        FOREIGN KEY (evaluation_type_id)
        REFERENCES public.evaluation_types(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_criterion_assignments_criterion
        FOREIGN KEY (criterion_id)
        REFERENCES public.evaluation_criteria(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_criterion_assignments_crop
        FOREIGN KEY (crop_id)
        REFERENCES public.crops(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_criterion_assignments_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_criterion_assignments_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_criterion_assignments_section_name
        CHECK
        (
            section_name IS NULL
            OR
            (
                length(btrim(section_name)) > 0
                AND char_length(btrim(section_name)) <= 150
            )
        ),

    CONSTRAINT chk_criterion_assignments_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_criterion_assignments_required_visible
        CHECK
        (
            is_required = false
            OR is_visible = true
        ),

    CONSTRAINT chk_criterion_assignments_required_not_applicable
        CHECK
        (
            is_required = false
            OR allows_not_applicable = false
        ),

    CONSTRAINT chk_criterion_assignments_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_criterion_assignments_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.criterion_assignments IS
'Dynamic configuration connecting evaluation criteria to evaluation types and optional crop scopes.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.criterion_assignments.id IS
'Internal UUID primary key of the criterion assignment.';

COMMENT ON COLUMN public.criterion_assignments.evaluation_type_id IS
'Evaluation type in which the criterion is displayed.';

COMMENT ON COLUMN public.criterion_assignments.criterion_id IS
'Evaluation criterion displayed by this assignment.';

COMMENT ON COLUMN public.criterion_assignments.crop_id IS
'Optional crop-specific scope. NULL indicates a global assignment.';

COMMENT ON COLUMN public.criterion_assignments.is_required IS
'Indicates whether the evaluator must provide a value for the criterion.';

COMMENT ON COLUMN public.criterion_assignments.is_visible IS
'Indicates whether the criterion is displayed in the dynamic evaluation form.';

COMMENT ON COLUMN public.criterion_assignments.allows_not_applicable IS
'Indicates whether the evaluator may explicitly mark the criterion as not applicable.';

COMMENT ON COLUMN public.criterion_assignments.section_name IS
'Optional form section such as Plant Evaluation, Fruit Evaluation, Measurements, or Comments.';

COMMENT ON COLUMN public.criterion_assignments.display_order IS
'Controls criterion ordering inside the assigned evaluation form and section.';

COMMENT ON COLUMN public.criterion_assignments.is_active IS
'Indicates whether the assignment is available for new evaluations.';

COMMENT ON COLUMN public.criterion_assignments.created_at IS
'UTC timestamp when the assignment was created.';

COMMENT ON COLUMN public.criterion_assignments.updated_at IS
'UTC timestamp when the assignment was most recently updated.';

COMMENT ON COLUMN public.criterion_assignments.created_by IS
'Supabase Auth user who created the assignment.';

COMMENT ON COLUMN public.criterion_assignments.updated_by IS
'Supabase Auth user who most recently updated the assignment.';

COMMENT ON COLUMN public.criterion_assignments.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the assignment has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------
-- Prevents duplicate assignments within the same evaluation-type and crop scope.
-- NULL crop_id represents the global assignment scope.
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_criterion_assignments_scope
    ON public.criterion_assignments
    (
        evaluation_type_id,
        criterion_id,
        COALESCE(crop_id, '00000000-0000-0000-0000-000000000000'::uuid)
    );

--------------------------------------------------------------------------------
-- RELATIONSHIP AND FILTERING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_criterion_assignments_evaluation_type
    ON public.criterion_assignments (evaluation_type_id);

CREATE INDEX idx_criterion_assignments_criterion
    ON public.criterion_assignments (criterion_id);

CREATE INDEX idx_criterion_assignments_crop
    ON public.criterion_assignments (crop_id)
    WHERE crop_id IS NOT NULL;

CREATE INDEX idx_criterion_assignments_global_active
    ON public.criterion_assignments
    (
        evaluation_type_id,
        section_name,
        display_order
    )
    WHERE crop_id IS NULL
      AND is_active = true
      AND is_visible = true
      AND deleted_at IS NULL;

CREATE INDEX idx_criterion_assignments_crop_active
    ON public.criterion_assignments
    (
        evaluation_type_id,
        crop_id,
        section_name,
        display_order
    )
    WHERE crop_id IS NOT NULL
      AND is_active = true
      AND is_visible = true
      AND deleted_at IS NULL;

CREATE INDEX idx_criterion_assignments_required
    ON public.criterion_assignments
    (
        evaluation_type_id,
        is_required
    )
    WHERE is_required = true
      AND is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_criterion_assignments_deleted_at
    ON public.criterion_assignments (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_criterion_assignments_created_by
    ON public.criterion_assignments (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_criterion_assignments_updated_by
    ON public.criterion_assignments (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------
-- Validates:
--
--   • Evaluation type exists and is available.
--   • Criterion exists and is available.
--   • Optional crop exists and is available.
--   • Crop-specific criterion scopes remain compatible with assignments.
--   • Required criteria must be visible.
--   • Required criteria cannot permit Not Applicable.
--   • Optional text fields are normalized.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_criterion_assignment()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_evaluation_type_active       boolean;
    v_evaluation_type_deleted_at   timestamptz;

    v_criterion_active             boolean;
    v_criterion_deleted_at         timestamptz;
    v_criterion_crop_id            uuid;

    v_crop_active                  boolean;
    v_crop_deleted_at              timestamptz;
BEGIN
    --------------------------------------------------------------------------
    -- Normalize optional section name
    --------------------------------------------------------------------------

    NEW.section_name :=
        CASE
            WHEN NEW.section_name IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.section_name), '')
        END;

    --------------------------------------------------------------------------
    -- Validate evaluation type
    --------------------------------------------------------------------------

    SELECT
        et.is_active,
        et.deleted_at
    INTO
        v_evaluation_type_active,
        v_evaluation_type_deleted_at
    FROM public.evaluation_types et
    WHERE et.id = NEW.evaluation_type_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Criterion assignment validation failed: evaluation type %s does not exist.',
                    NEW.evaluation_type_id
                );
    END IF;

    IF v_evaluation_type_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Criterion assignment validation failed: the selected evaluation type is soft-deleted.';
    END IF;

    IF NEW.is_active = true
       AND v_evaluation_type_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Criterion assignment validation failed: an active assignment cannot use an inactive evaluation type.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate criterion
    --------------------------------------------------------------------------

    SELECT
        ec.is_active,
        ec.deleted_at,
        ec.crop_id
    INTO
        v_criterion_active,
        v_criterion_deleted_at,
        v_criterion_crop_id
    FROM public.evaluation_criteria ec
    WHERE ec.id = NEW.criterion_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Criterion assignment validation failed: evaluation criterion %s does not exist.',
                    NEW.criterion_id
                );
    END IF;

    IF v_criterion_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Criterion assignment validation failed: the selected evaluation criterion is soft-deleted.';
    END IF;

    IF NEW.is_active = true
       AND v_criterion_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Criterion assignment validation failed: an active assignment cannot use an inactive criterion.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate optional crop scope
    --------------------------------------------------------------------------

    IF NEW.crop_id IS NOT NULL THEN
        SELECT
            c.is_active,
            c.deleted_at
        INTO
            v_crop_active,
            v_crop_deleted_at
        FROM public.crops c
        WHERE c.id = NEW.crop_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE = format(
                        'Criterion assignment validation failed: crop %s does not exist.',
                        NEW.crop_id
                    );
        END IF;

        IF v_crop_deleted_at IS NOT NULL THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Criterion assignment validation failed: the selected crop is soft-deleted.';
        END IF;

        IF NEW.is_active = true
           AND v_crop_active = false THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Criterion assignment validation failed: an active assignment cannot use an inactive crop.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Enforce criterion crop compatibility
    --------------------------------------------------------------------------
    -- A crop-specific criterion cannot be globally assigned and cannot be
    -- assigned to a different crop.
    --------------------------------------------------------------------------

    IF v_criterion_crop_id IS NOT NULL
       AND NEW.crop_id IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Criterion assignment validation failed: a crop-specific criterion cannot use a global assignment.';
    END IF;

    IF v_criterion_crop_id IS NOT NULL
       AND NEW.crop_id IS DISTINCT FROM v_criterion_crop_id THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Criterion assignment validation failed: the assignment crop does not match the criterion crop.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate form behavior
    --------------------------------------------------------------------------

    IF NEW.is_required = true
       AND NEW.is_visible = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Criterion assignment validation failed: a required criterion must be visible.';
    END IF;

    IF NEW.is_required = true
       AND NEW.allows_not_applicable = true THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Criterion assignment validation failed: a required criterion cannot allow Not Applicable.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_criterion_assignment() IS
'Validates evaluation type, criterion, crop scope, assignment activity, visibility, requirement behavior, and crop compatibility.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_criterion_assignments_validate
    BEFORE INSERT OR UPDATE OF
        evaluation_type_id,
        criterion_id,
        crop_id,
        is_required,
        is_visible,
        allows_not_applicable,
        section_name,
        is_active
    ON public.criterion_assignments
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_criterion_assignment();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_criterion_assignments_timestamps
    BEFORE INSERT OR UPDATE
    ON public.criterion_assignments
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_criterion_assignments_created_by
    BEFORE INSERT
    ON public.criterion_assignments
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_criterion_assignments_updated_by
    BEFORE UPDATE
    ON public.criterion_assignments
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- SEED DATA: OBSERVATION ASSIGNMENTS
--------------------------------------------------------------------------------

INSERT INTO public.criterion_assignments
(
    evaluation_type_id,
    criterion_id,
    crop_id,
    is_required,
    is_visible,
    allows_not_applicable,
    section_name,
    display_order,
    is_active
)
SELECT
    et.id,
    ec.id,
    NULL,
    seed.is_required,
    true,
    seed.allows_not_applicable,
    seed.section_name,
    seed.display_order,
    true
FROM
(
    VALUES
        ('PLANT_VIGOR',                    true,  false, 'Plant Evaluation', 10),
        ('VEGETATIVE_GENERATIVE_BALANCE',  true,  false, 'Plant Evaluation', 20),
        ('PLANT_UNIFORMITY',               true,  false, 'Plant Evaluation', 30),
        ('INTERNODE_LENGTH',               false, true,  'Plant Evaluation', 40),
        ('LEAF_SIZE',                      false, true,  'Plant Evaluation', 50),
        ('DISEASE_TOLERANCE',              false, true,  'Plant Evaluation', 60),
        ('GROWTH_HABIT',                   false, true,  'Plant Evaluation', 70),
        ('FRUIT_SHAPE',                    false, true,  'Fruit Evaluation', 80),
        ('FRUIT_COLOR',                    false, true,  'Fruit Evaluation', 90),
        ('FRUIT_SETTING',                  true,  false, 'Fruit Evaluation', 100),
        ('FRUIT_DEFECTS',                  false, true,  'Fruit Evaluation', 110),
        ('GENERAL_COMMENTS',               false, true,  'Comments',         120)
) AS seed
(
    criterion_code,
    is_required,
    allows_not_applicable,
    section_name,
    display_order
)
JOIN public.evaluation_types et
    ON et.code::text = 'OBSERVATION'
JOIN public.evaluation_criteria ec
    ON ec.code::text = seed.criterion_code
WHERE et.deleted_at IS NULL
  AND ec.deleted_at IS NULL
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- SEED DATA: TECHNICAL EVALUATION ASSIGNMENTS
--------------------------------------------------------------------------------

INSERT INTO public.criterion_assignments
(
    evaluation_type_id,
    criterion_id,
    crop_id,
    is_required,
    is_visible,
    allows_not_applicable,
    section_name,
    display_order,
    is_active
)
SELECT
    et.id,
    ec.id,
    NULL,
    seed.is_required,
    true,
    seed.allows_not_applicable,
    seed.section_name,
    seed.display_order,
    true
FROM
(
    VALUES
        ('PLANT_VIGOR',                    true,  false, 'Plant Evaluation',    10),
        ('VEGETATIVE_GENERATIVE_BALANCE',  true,  false, 'Plant Evaluation',    20),
        ('PLANT_UNIFORMITY',               true,  false, 'Plant Evaluation',    30),
        ('INTERNODE_LENGTH',               false, true,  'Plant Measurements',  40),
        ('LEAF_SIZE',                      false, true,  'Plant Evaluation',    50),
        ('DISEASE_TOLERANCE',              true,  false, 'Plant Evaluation',    60),
        ('GROWTH_HABIT',                   false, true,  'Plant Evaluation',    70),
        ('FRUIT_SHAPE',                    true,  false, 'Fruit Evaluation',    80),
        ('FRUIT_COLOR',                    false, true,  'Fruit Evaluation',    90),
        ('SHELF_LIFE',                     false, true,  'Fruit Measurements', 100),
        ('FRUIT_SETTING',                  true,  false, 'Fruit Evaluation',   110),
        ('TASTE_QUALITY',                  false, true,  'Fruit Evaluation',   120),
        ('AVERAGE_WEIGHT',                 true,  false, 'Fruit Measurements', 130),
        ('FIRMNESS',                       false, true,  'Fruit Evaluation',   140),
        ('BRIX',                           false, true,  'Fruit Measurements', 150),
        ('FRUIT_DEFECTS',                  false, true,  'Fruit Evaluation',   160),
        ('GENERAL_COMMENTS',               false, true,  'Comments',           170)
) AS seed
(
    criterion_code,
    is_required,
    allows_not_applicable,
    section_name,
    display_order
)
JOIN public.evaluation_types et
    ON et.code::text = 'TECHNICAL_EVALUATION'
JOIN public.evaluation_criteria ec
    ON ec.code::text = seed.criterion_code
WHERE et.deleted_at IS NULL
  AND ec.deleted_at IS NULL
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- MIGRATION VALIDATION
--------------------------------------------------------------------------------

DO
$$
DECLARE
    expected_column_count          integer;
    observation_assignment_count  integer;
    technical_assignment_count    integer;
    invalid_parent_count           integer;
    invalid_crop_scope_count       integer;
    invalid_required_count         integer;
BEGIN
    --------------------------------------------------------------------------
    -- Verify table creation
    --------------------------------------------------------------------------

    IF to_regclass('public.criterion_assignments') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0035_criterion_assignments.sql failed: public.criterion_assignments was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'criterion_assignments'
      AND column_name IN
      (
          'id',
          'evaluation_type_id',
          'criterion_id',
          'crop_id',
          'is_required',
          'is_visible',
          'allows_not_applicable',
          'section_name',
          'display_order',
          'is_active',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF expected_column_count <> 15 THEN
        RAISE EXCEPTION
            'Migration 0035_criterion_assignments.sql failed: criterion_assignments has % of 15 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.criterion_assignments'::regclass
          AND conname = 'fk_criterion_assignments_evaluation_type'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0035_criterion_assignments.sql failed: evaluation-type foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.criterion_assignments'::regclass
          AND conname = 'fk_criterion_assignments_criterion'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0035_criterion_assignments.sql failed: criterion foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.criterion_assignments'::regclass
          AND conname = 'fk_criterion_assignments_crop'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0035_criterion_assignments.sql failed: crop foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique assignment index
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_criterion_assignments_scope') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0035_criterion_assignments.sql failed: unique assignment-scope index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify Observation assignments
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO observation_assignment_count
    FROM public.criterion_assignments ca
    JOIN public.evaluation_types et
        ON et.id = ca.evaluation_type_id
    WHERE et.code::text = 'OBSERVATION'
      AND ca.is_active = true
      AND ca.deleted_at IS NULL;

    IF observation_assignment_count <> 12 THEN
        RAISE EXCEPTION
            'Migration 0035_criterion_assignments.sql failed: only % of 12 Observation assignments were inserted.',
            observation_assignment_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify Technical Evaluation assignments
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO technical_assignment_count
    FROM public.criterion_assignments ca
    JOIN public.evaluation_types et
        ON et.id = ca.evaluation_type_id
    WHERE et.code::text = 'TECHNICAL_EVALUATION'
      AND ca.is_active = true
      AND ca.deleted_at IS NULL;

    IF technical_assignment_count <> 17 THEN
        RAISE EXCEPTION
            'Migration 0035_criterion_assignments.sql failed: only % of 17 Technical Evaluation assignments were inserted.',
            technical_assignment_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify valid parent relationships
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO invalid_parent_count
    FROM public.criterion_assignments ca
    LEFT JOIN public.evaluation_types et
        ON et.id = ca.evaluation_type_id
    LEFT JOIN public.evaluation_criteria ec
        ON ec.id = ca.criterion_id
    WHERE et.id IS NULL
       OR ec.id IS NULL;

    IF invalid_parent_count <> 0 THEN
        RAISE EXCEPTION
            'Migration 0035_criterion_assignments.sql failed: % assignments reference missing parents.',
            invalid_parent_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify crop-scope compatibility
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO invalid_crop_scope_count
    FROM public.criterion_assignments ca
    JOIN public.evaluation_criteria ec
        ON ec.id = ca.criterion_id
    WHERE ec.crop_id IS NOT NULL
      AND
      (
          ca.crop_id IS NULL
          OR ca.crop_id IS DISTINCT FROM ec.crop_id
      );

    IF invalid_crop_scope_count <> 0 THEN
        RAISE EXCEPTION
            'Migration 0035_criterion_assignments.sql failed: % assignments violate criterion crop scope.',
            invalid_crop_scope_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify required-form behavior
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO invalid_required_count
    FROM public.criterion_assignments
    WHERE is_required = true
      AND
      (
          is_visible = false
          OR allows_not_applicable = true
      );

    IF invalid_required_count <> 0 THEN
        RAISE EXCEPTION
            'Migration 0035_criterion_assignments.sql failed: % required assignments have invalid form behavior.',
            invalid_required_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify validation function and trigger
    --------------------------------------------------------------------------

    IF to_regprocedure(
        'public.trg_validate_criterion_assignment()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0035_criterion_assignments.sql failed: validation function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.criterion_assignments'::regclass
          AND tgname = 'trg_criterion_assignments_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0035_criterion_assignments.sql failed: validation trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify generic triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.criterion_assignments'::regclass
          AND tgname = 'trg_criterion_assignments_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0035_criterion_assignments.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.criterion_assignments'::regclass
          AND tgname = 'trg_criterion_assignments_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0035_criterion_assignments.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.criterion_assignments'::regclass
          AND tgname = 'trg_criterion_assignments_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0035_criterion_assignments.sql failed: updated_by trigger is missing.';
    END IF;
END;
$$;

COMMIT;
