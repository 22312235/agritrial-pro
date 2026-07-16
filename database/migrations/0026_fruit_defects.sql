/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0026_fruit_defects.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the fruit_defects configuration table.
*
* Fruit defects represent crop-specific defects recorded during observations
* and technical evaluations.
*
* Confirmed examples:
*
*   • Mauvaise nouaison
*   • Creux
*   • Éclatement
*   • F. Bateaux
*   • Couleur
*   • Zippers
*   • Téton
*   • Fruit ouvert
*   • Nécrose apicale
*   • Micro cracking
*   • Collet vert
*
* Frozen architectural rules:
*
*   • Every fruit defect belongs to exactly one crop.
*   • Fruit defects are managed dynamically by the Manager.
*   • Flutter loads fruit defects dynamically from the database.
*   • Every crop must have exactly one "Other" defect option.
*   • Selecting "Other" requires a custom user-entered value.
*   • Multiple defects may be selected for one evaluation detail.
*   • Multiple selection will be stored through evaluation_detail_options.
*   • Custom-value validation will be enforced by the dynamic evaluation engine.
*   • Fruit defects support soft deletion and historical references.
*   • Row Level Security policies are intentionally deferred.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0003_domains.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
*   • 0018_crops.sql
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
-- TABLE: fruit_defects
--------------------------------------------------------------------------------

CREATE TABLE public.fruit_defects
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                  uuid
                        PRIMARY KEY
                        DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Parent Crop
    --------------------------------------------------------------------------

    crop_id             uuid
                        NOT NULL,

    --------------------------------------------------------------------------
    -- Defect Information
    --------------------------------------------------------------------------

    code                long_code
                        NOT NULL,

    name                varchar(200)
                        NOT NULL,

    description         description_text,

    --------------------------------------------------------------------------
    -- Custom-Value Support
    --------------------------------------------------------------------------

    is_other            boolean
                        NOT NULL
                        DEFAULT false,

    allows_custom_value boolean
                        NOT NULL
                        DEFAULT false,

    --------------------------------------------------------------------------
    -- Configuration State
    --------------------------------------------------------------------------

    is_active           boolean
                        NOT NULL
                        DEFAULT true,

    display_order       integer
                        NOT NULL
                        DEFAULT 0,

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

    CONSTRAINT fk_fruit_defects_crop
        FOREIGN KEY (crop_id)
        REFERENCES public.crops(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_fruit_defects_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_fruit_defects_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_fruit_defects_code_not_blank
        CHECK
        (
            length(btrim(code::text)) > 0
        ),

    CONSTRAINT chk_fruit_defects_name
        CHECK
        (
            char_length(btrim(name)) BETWEEN 1 AND 200
        ),

    CONSTRAINT chk_fruit_defects_other_custom_value
        CHECK
        (
            is_other = false
            OR allows_custom_value = true
        ),

    CONSTRAINT chk_fruit_defects_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_fruit_defects_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_fruit_defects_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.fruit_defects IS
'Crop-specific fruit defects used in observations and technical evaluations. Every crop includes one Other option for custom user-entered values.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.fruit_defects.id IS
'Internal UUID primary key of the fruit defect.';

COMMENT ON COLUMN public.fruit_defects.crop_id IS
'Crop to which the fruit defect belongs.';

COMMENT ON COLUMN public.fruit_defects.code IS
'Unique business code identifying the fruit defect. Stored in uppercase by trigger.';

COMMENT ON COLUMN public.fruit_defects.name IS
'Fruit-defect display name shown in dynamic Flutter evaluation forms.';

COMMENT ON COLUMN public.fruit_defects.description IS
'Optional agronomic description of the fruit defect.';

COMMENT ON COLUMN public.fruit_defects.is_other IS
'Indicates that this record represents the Other fruit-defect option for its crop.';

COMMENT ON COLUMN public.fruit_defects.allows_custom_value IS
'Indicates that selecting this defect allows or requires a custom user-entered value.';

COMMENT ON COLUMN public.fruit_defects.is_active IS
'Indicates whether the fruit defect is available for new evaluations.';

COMMENT ON COLUMN public.fruit_defects.display_order IS
'Controls the ordering of fruit defects within a crop in Flutter forms.';

COMMENT ON COLUMN public.fruit_defects.created_at IS
'UTC timestamp when the fruit-defect record was created.';

COMMENT ON COLUMN public.fruit_defects.updated_at IS
'UTC timestamp when the fruit-defect record was most recently updated.';

COMMENT ON COLUMN public.fruit_defects.created_by IS
'Supabase Auth user who created the fruit-defect record.';

COMMENT ON COLUMN public.fruit_defects.updated_by IS
'Supabase Auth user who most recently updated the fruit-defect record.';

COMMENT ON COLUMN public.fruit_defects.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the fruit defect has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_fruit_defects_code_ci
    ON public.fruit_defects
    (
        lower(btrim(code::text))
    );

CREATE UNIQUE INDEX uq_fruit_defects_crop_name_normalized
    ON public.fruit_defects
    (
        crop_id,
        public.fn_normalize_text(name)
    );

CREATE UNIQUE INDEX uq_fruit_defects_one_other_per_crop
    ON public.fruit_defects (crop_id)
    WHERE is_other = true;

--------------------------------------------------------------------------------
-- RELATIONSHIP AND FILTERING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_fruit_defects_crop_id
    ON public.fruit_defects (crop_id);

CREATE INDEX idx_fruit_defects_crop_active_display
    ON public.fruit_defects
    (
        crop_id,
        display_order,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_fruit_defects_is_active
    ON public.fruit_defects (is_active)
    WHERE deleted_at IS NULL;

CREATE INDEX idx_fruit_defects_custom_values
    ON public.fruit_defects
    (
        crop_id,
        allows_custom_value
    )
    WHERE allows_custom_value = true
      AND deleted_at IS NULL;

CREATE INDEX idx_fruit_defects_deleted_at
    ON public.fruit_defects (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEX
--------------------------------------------------------------------------------

CREATE INDEX idx_fruit_defects_name_trgm
    ON public.fruit_defects
    USING gin
    (
        name gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- AUDIT LOOKUP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_fruit_defects_created_by
    ON public.fruit_defects (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_fruit_defects_updated_by
    ON public.fruit_defects (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_fruit_defect()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    parent_crop_active       boolean;
    parent_crop_deleted_at   timestamptz;
BEGIN
    --------------------------------------------------------------------------
    -- Resolve parent crop state
    --------------------------------------------------------------------------

    SELECT
        c.is_active,
        c.deleted_at
    INTO
        parent_crop_active,
        parent_crop_deleted_at
    FROM public.crops c
    WHERE c.id = NEW.crop_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Fruit defect validation failed: crop %s does not exist.',
                    NEW.crop_id
                );
    END IF;

    --------------------------------------------------------------------------
    -- Prevent references to soft-deleted crops
    --------------------------------------------------------------------------

    IF parent_crop_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = format(
                    'Fruit defect validation failed: crop %s is soft-deleted.',
                    NEW.crop_id
                );
    END IF;

    --------------------------------------------------------------------------
    -- Active fruit defect cannot belong to inactive crop
    --------------------------------------------------------------------------

    IF NEW.is_active = true
       AND parent_crop_active = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = format(
                    'Fruit defect validation failed: an active fruit defect cannot belong to inactive crop %s.',
                    NEW.crop_id
                );
    END IF;

    --------------------------------------------------------------------------
    -- Normalize the Other option
    --------------------------------------------------------------------------

    IF NEW.is_other = true THEN
        NEW.name := 'Other';
        NEW.allows_custom_value := true;
    END IF;

    --------------------------------------------------------------------------
    -- Reserve the name Other
    --------------------------------------------------------------------------

    IF public.fn_normalize_text(NEW.name) = 'other'
       AND NEW.is_other = false THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Fruit defect validation failed: the name "Other" requires is_other = true.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_fruit_defect() IS
'Validates crop ownership and configuration state and ensures that Other fruit defects support custom user-entered values.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_fruit_defects_validate
    BEFORE INSERT OR UPDATE OF
        crop_id,
        name,
        is_other,
        allows_custom_value,
        is_active
    ON public.fruit_defects
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_fruit_defect();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_fruit_defects_normalize_name
    BEFORE INSERT OR UPDATE OF name
    ON public.fruit_defects
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_normalize_name();

CREATE TRIGGER trg_fruit_defects_uppercase_code
    BEFORE INSERT OR UPDATE OF code
    ON public.fruit_defects
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_uppercase_code();

CREATE TRIGGER trg_fruit_defects_timestamps
    BEFORE INSERT OR UPDATE
    ON public.fruit_defects
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_fruit_defects_created_by
    BEFORE INSERT
    ON public.fruit_defects
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_fruit_defects_updated_by
    BEFORE UPDATE
    ON public.fruit_defects
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- SEED DATA
--------------------------------------------------------------------------------
-- Confirmed fruit defects are seeded for every existing crop.
--
-- The Manager may deactivate, reorder, rename, or add crop-specific defects.
--------------------------------------------------------------------------------

INSERT INTO public.fruit_defects
(
    crop_id,
    code,
    name,
    description,
    is_other,
    allows_custom_value,
    display_order
)
SELECT
    c.id,
    left(c.code::text || '_DEFECT_' || seed.code_suffix, 50),
    seed.name,
    seed.description,
    seed.is_other,
    seed.allows_custom_value,
    seed.display_order
FROM public.crops c
CROSS JOIN
(
    VALUES
        (
            'MAUVAISE_NOUAISON',
            'Mauvaise nouaison',
            'Poor fruit setting or unsuccessful flower-to-fruit development.',
            false,
            false,
            10
        ),
        (
            'CREUX',
            'Creux',
            'Internal or external hollow fruit condition.',
            false,
            false,
            20
        ),
        (
            'ECLATEMENT',
            'Éclatement',
            'Fruit cracking or splitting defect.',
            false,
            false,
            30
        ),
        (
            'F_BATEAUX',
            'F. Bateaux',
            'Boat-shaped or irregular fruit deformation.',
            false,
            false,
            40
        ),
        (
            'COULEUR',
            'Couleur',
            'Unsatisfactory, irregular, or non-uniform fruit color.',
            false,
            false,
            50
        ),
        (
            'ZIPPERS',
            'Zippers',
            'Zipper-like scar or longitudinal fruit marking.',
            false,
            false,
            60
        ),
        (
            'TETON',
            'Téton',
            'Nipple-like protrusion or pointed fruit-end defect.',
            false,
            false,
            70
        ),
        (
            'FRUIT_OUVERT',
            'Fruit ouvert',
            'Open or incompletely closed fruit defect.',
            false,
            false,
            80
        ),
        (
            'NECROSE_APICALE',
            'Nécrose apicale',
            'Blossom-end rot or necrosis at the fruit apex.',
            false,
            false,
            90
        ),
        (
            'MICRO_CRACKING',
            'Micro cracking',
            'Fine superficial cracking visible on the fruit surface.',
            false,
            false,
            100
        ),
        (
            'COLLET_VERT',
            'Collet vert',
            'Persistent green shoulder or collar near the fruit stem.',
            false,
            false,
            110
        ),
        (
            'OTHER',
            'Other',
            'Custom fruit defect entered by the user.',
            true,
            true,
            999
        )
) AS seed
(
    code_suffix,
    name,
    description,
    is_other,
    allows_custom_value,
    display_order
)
WHERE c.deleted_at IS NULL
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- ADD OTHER OPTION TO ANY CROP WITHOUT ONE
--------------------------------------------------------------------------------

INSERT INTO public.fruit_defects
(
    crop_id,
    code,
    name,
    description,
    is_other,
    allows_custom_value,
    display_order
)
SELECT
    c.id,
    left(c.code::text || '_DEFECT_OTHER', 50),
    'Other',
    'Custom fruit defect entered by the user.',
    true,
    true,
    999
FROM public.crops c
WHERE c.deleted_at IS NULL
  AND NOT EXISTS
  (
      SELECT 1
      FROM public.fruit_defects fd
      WHERE fd.crop_id = c.id
        AND fd.is_other = true
  )
ON CONFLICT DO NOTHING;

--------------------------------------------------------------------------------
-- MIGRATION VALIDATION
--------------------------------------------------------------------------------

DO
$$
DECLARE
    expected_column_count integer;
    existing_crop_count   integer;
    crops_with_other      integer;
    confirmed_defects     integer;
BEGIN
    --------------------------------------------------------------------------
    -- Verify table creation
    --------------------------------------------------------------------------

    IF to_regclass('public.fruit_defects') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0026_fruit_defects.sql failed: public.fruit_defects was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'fruit_defects'
      AND column_name IN
      (
          'id',
          'crop_id',
          'code',
          'name',
          'description',
          'is_other',
          'allows_custom_value',
          'is_active',
          'display_order',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF expected_column_count <> 14 THEN
        RAISE EXCEPTION
            'Migration 0026_fruit_defects.sql failed: fruit_defects has % of 14 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify crop foreign key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.fruit_defects'::regclass
          AND conname = 'fk_fruit_defects_crop'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0026_fruit_defects.sql failed: crop foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass('public.uq_fruit_defects_code_ci') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0026_fruit_defects.sql failed: unique fruit-defect code index is missing.';
    END IF;

    IF to_regclass('public.uq_fruit_defects_crop_name_normalized') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0026_fruit_defects.sql failed: unique crop/defect-name index is missing.';
    END IF;

    IF to_regclass('public.uq_fruit_defects_one_other_per_crop') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0026_fruit_defects.sql failed: one-Other-per-crop index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify validation function and trigger
    --------------------------------------------------------------------------

    IF to_regprocedure('public.trg_validate_fruit_defect()') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0026_fruit_defects.sql failed: validation function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.fruit_defects'::regclass
          AND tgname = 'trg_fruit_defects_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0026_fruit_defects.sql failed: validation trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify generic triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.fruit_defects'::regclass
          AND tgname = 'trg_fruit_defects_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0026_fruit_defects.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.fruit_defects'::regclass
          AND tgname = 'trg_fruit_defects_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0026_fruit_defects.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.fruit_defects'::regclass
          AND tgname = 'trg_fruit_defects_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0026_fruit_defects.sql failed: updated_by trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify confirmed defects exist for every current crop
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO confirmed_defects
    FROM public.fruit_defects
    WHERE is_other = false
      AND deleted_at IS NULL;

    IF confirmed_defects < 11 THEN
        RAISE EXCEPTION
            'Migration 0026_fruit_defects.sql failed: confirmed defect seed data is incomplete.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify every existing crop has exactly one valid Other option
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO existing_crop_count
    FROM public.crops
    WHERE deleted_at IS NULL;

    SELECT count(*)
    INTO crops_with_other
    FROM public.crops c
    WHERE c.deleted_at IS NULL
      AND
      (
          SELECT count(*)
          FROM public.fruit_defects fd
          WHERE fd.crop_id = c.id
            AND fd.is_other = true
            AND fd.allows_custom_value = true
      ) = 1;

    IF existing_crop_count <> crops_with_other THEN
        RAISE EXCEPTION
            'Migration 0026_fruit_defects.sql failed: only % of % crops have exactly one valid Other fruit defect.',
            crops_with_other,
            existing_crop_count;
    END IF;
END;
$$;

COMMIT;
