/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0043_evaluation_photos.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the evaluation_photos table used to store Supabase Storage metadata
* for photos attached to Phase 2 agricultural evaluations.
*
* Business rules:
*
*   • Every photo belongs to exactly one evaluation.
*   • A photo may optionally belong to one evaluation detail.
*   • The selected evaluation detail must belong to the same evaluation.
*   • A photo may optionally target one trial variety.
*   • The selected trial variety must belong to the evaluation trial.
*   • When an evaluation detail targets a variety, the photo variety must match it.
*   • Only supported image MIME types are accepted.
*   • Storage bucket and object path are stored instead of binary image data.
*   • Each active storage object path must be unique within its bucket.
*   • One active photo may be marked as the cover photo per evaluation.
*   • Photos cannot be added to completed evaluations.
*   • Photos belonging to completed evaluations are immutable.
*   • Physical deletion is prohibited.
*   • Soft deletion remains available for auditability.
*   • Actual Supabase Storage policies will be added later.
*   • RLS will be added in a later migration.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
*   • 0037_trial_varieties.sql
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
-- TABLE: evaluation_photos
--------------------------------------------------------------------------------

CREATE TABLE public.evaluation_photos
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

    evaluation_detail_id    uuid,

    trial_variety_id        uuid,

    --------------------------------------------------------------------------
    -- Supabase Storage Information
    --------------------------------------------------------------------------

    storage_bucket          varchar(100)
                            NOT NULL
                            DEFAULT 'evaluation-photos',

    storage_path            text
                            NOT NULL,

    original_file_name      varchar(255),

    mime_type               varchar(100)
                            NOT NULL,

    file_size_bytes         bigint,

    file_checksum           varchar(128),

    --------------------------------------------------------------------------
    -- Image Metadata
    --------------------------------------------------------------------------

    width_pixels            integer,

    height_pixels           integer,

    captured_at             timestamptz,

    --------------------------------------------------------------------------
    -- Photo Information
    --------------------------------------------------------------------------

    title                   varchar(250),

    caption                 text,

    photo_category          varchar(50)
                            NOT NULL
                            DEFAULT 'GENERAL',

    display_order           integer
                            NOT NULL
                            DEFAULT 0,

    is_cover                boolean
                            NOT NULL
                            DEFAULT false,

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

    CONSTRAINT fk_evaluation_photos_evaluation
        FOREIGN KEY (evaluation_id)
        REFERENCES public.evaluations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_evaluation_photos_evaluation_detail
        FOREIGN KEY (evaluation_detail_id)
        REFERENCES public.evaluation_details(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_evaluation_photos_trial_variety
        FOREIGN KEY (trial_variety_id)
        REFERENCES public.trial_varieties(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_evaluation_photos_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_evaluation_photos_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_evaluation_photos_storage_bucket
        CHECK
        (
            char_length(btrim(storage_bucket)) BETWEEN 1 AND 100
            AND storage_bucket = lower(storage_bucket)
            AND storage_bucket ~ '^[a-z0-9][a-z0-9._-]*$'
        ),

    CONSTRAINT chk_evaluation_photos_storage_path
        CHECK
        (
            char_length(btrim(storage_path)) BETWEEN 1 AND 2000
            AND storage_path !~ '(^|/)\.\.(/|$)'
            AND storage_path !~ '^/'
            AND storage_path !~ '/$'
        ),

    CONSTRAINT chk_evaluation_photos_original_file_name
        CHECK
        (
            original_file_name IS NULL
            OR char_length(btrim(original_file_name)) BETWEEN 1 AND 255
        ),

    CONSTRAINT chk_evaluation_photos_mime_type
        CHECK
        (
            lower(btrim(mime_type)) IN
            (
                'image/jpeg',
                'image/png',
                'image/webp',
                'image/heic',
                'image/heif'
            )
        ),

    CONSTRAINT chk_evaluation_photos_file_size
        CHECK
        (
            file_size_bytes IS NULL
            OR file_size_bytes BETWEEN 1 AND 52428800
        ),

    CONSTRAINT chk_evaluation_photos_checksum
        CHECK
        (
            file_checksum IS NULL
            OR char_length(btrim(file_checksum)) BETWEEN 16 AND 128
        ),

    CONSTRAINT chk_evaluation_photos_dimensions
        CHECK
        (
            (
                width_pixels IS NULL
                AND height_pixels IS NULL
            )
            OR
            (
                width_pixels BETWEEN 1 AND 50000
                AND height_pixels BETWEEN 1 AND 50000
            )
        ),

    CONSTRAINT chk_evaluation_photos_captured_at
        CHECK
        (
            captured_at IS NULL
            OR captured_at <= timezone('UTC', now()) + interval '1 day'
        ),

    CONSTRAINT chk_evaluation_photos_title
        CHECK
        (
            title IS NULL
            OR char_length(btrim(title)) BETWEEN 1 AND 250
        ),

    CONSTRAINT chk_evaluation_photos_caption
        CHECK
        (
            caption IS NULL
            OR char_length(btrim(caption)) BETWEEN 1 AND 5000
        ),

    CONSTRAINT chk_evaluation_photos_category
        CHECK
        (
            photo_category IN
            (
                'GENERAL',
                'PLANT',
                'FRUIT',
                'DISEASE',
                'DEFECT',
                'MEASUREMENT',
                'COMPARISON',
                'PLOT',
                'OTHER'
            )
        ),

    CONSTRAINT chk_evaluation_photos_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_evaluation_photos_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_evaluation_photos_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        ),

    CONSTRAINT chk_evaluation_photos_active_deleted
        CHECK
        (
            deleted_at IS NULL
            OR is_active = false
        ),

    CONSTRAINT chk_evaluation_photos_cover_state
        CHECK
        (
            is_cover = false
            OR
            (
                is_active = true
                AND deleted_at IS NULL
            )
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.evaluation_photos IS
'Supabase Storage metadata for photos attached to agricultural trial evaluations and criterion results.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.evaluation_photos.id IS
'Internal UUID primary key of the evaluation photo metadata record.';

COMMENT ON COLUMN public.evaluation_photos.evaluation_id IS
'Parent agricultural evaluation to which the photo belongs.';

COMMENT ON COLUMN public.evaluation_photos.evaluation_detail_id IS
'Optional criterion-level result documented by the photo.';

COMMENT ON COLUMN public.evaluation_photos.trial_variety_id IS
'Optional candidate or witness variety shown in the photo.';

COMMENT ON COLUMN public.evaluation_photos.storage_bucket IS
'Supabase Storage bucket containing the image object.';

COMMENT ON COLUMN public.evaluation_photos.storage_path IS
'Relative Supabase Storage object path. Binary image data is not stored in PostgreSQL.';

COMMENT ON COLUMN public.evaluation_photos.original_file_name IS
'Original image filename supplied by the uploading device.';

COMMENT ON COLUMN public.evaluation_photos.mime_type IS
'Validated image MIME type.';

COMMENT ON COLUMN public.evaluation_photos.file_size_bytes IS
'Optional image file size in bytes. Maximum supported size is 50 MB.';

COMMENT ON COLUMN public.evaluation_photos.file_checksum IS
'Optional checksum used to identify duplicate or corrupted image objects.';

COMMENT ON COLUMN public.evaluation_photos.width_pixels IS
'Optional image width in pixels.';

COMMENT ON COLUMN public.evaluation_photos.height_pixels IS
'Optional image height in pixels.';

COMMENT ON COLUMN public.evaluation_photos.captured_at IS
'Optional UTC timestamp when the photo was captured by the device.';

COMMENT ON COLUMN public.evaluation_photos.title IS
'Optional human-readable title of the evaluation photo.';

COMMENT ON COLUMN public.evaluation_photos.caption IS
'Optional description explaining what the photo documents.';

COMMENT ON COLUMN public.evaluation_photos.photo_category IS
'Functional category used to organize evaluation photos.';

COMMENT ON COLUMN public.evaluation_photos.display_order IS
'Controls photo ordering in evaluation galleries and reports.';

COMMENT ON COLUMN public.evaluation_photos.is_cover IS
'Indicates the active cover photo displayed for the evaluation.';

COMMENT ON COLUMN public.evaluation_photos.is_active IS
'Indicates whether the photo is available in active evaluation galleries and reports.';

COMMENT ON COLUMN public.evaluation_photos.created_at IS
'UTC timestamp when the photo metadata record was created.';

COMMENT ON COLUMN public.evaluation_photos.updated_at IS
'UTC timestamp when the photo metadata record was most recently updated.';

COMMENT ON COLUMN public.evaluation_photos.created_by IS
'Supabase Auth user who created the photo metadata record.';

COMMENT ON COLUMN public.evaluation_photos.updated_by IS
'Supabase Auth user who most recently updated the photo metadata record.';

COMMENT ON COLUMN public.evaluation_photos.deleted_at IS
'Soft-deletion timestamp. The corresponding Storage object may be removed separately.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_evaluation_photos_storage_object
    ON public.evaluation_photos
    (
        storage_bucket,
        storage_path
    )
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX uq_evaluation_photos_one_cover
    ON public.evaluation_photos (evaluation_id)
    WHERE is_cover = true
      AND is_active = true
      AND deleted_at IS NULL;

--------------------------------------------------------------------------------
-- RELATIONSHIP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluation_photos_evaluation_id
    ON public.evaluation_photos (evaluation_id);

CREATE INDEX idx_evaluation_photos_evaluation_detail_id
    ON public.evaluation_photos (evaluation_detail_id)
    WHERE evaluation_detail_id IS NOT NULL;

CREATE INDEX idx_evaluation_photos_trial_variety_id
    ON public.evaluation_photos (trial_variety_id)
    WHERE trial_variety_id IS NOT NULL;

--------------------------------------------------------------------------------
-- APPLICATION QUERY INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluation_photos_gallery
    ON public.evaluation_photos
    (
        evaluation_id,
        is_cover DESC,
        display_order,
        created_at
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_photos_detail_gallery
    ON public.evaluation_photos
    (
        evaluation_detail_id,
        display_order,
        created_at
    )
    WHERE evaluation_detail_id IS NOT NULL
      AND is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_photos_variety_gallery
    ON public.evaluation_photos
    (
        trial_variety_id,
        evaluation_id,
        display_order
    )
    WHERE trial_variety_id IS NOT NULL
      AND is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_photos_category
    ON public.evaluation_photos
    (
        evaluation_id,
        photo_category,
        display_order
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_photos_captured_at
    ON public.evaluation_photos
    (
        captured_at DESC
    )
    WHERE captured_at IS NOT NULL
      AND is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_photos_deleted_at
    ON public.evaluation_photos (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- AUDIT INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluation_photos_created_by
    ON public.evaluation_photos (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_evaluation_photos_updated_by
    ON public.evaluation_photos (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_evaluation_photos_title_trgm
    ON public.evaluation_photos
    USING gin
    (
        title gin_trgm_ops
    )
    WHERE title IS NOT NULL
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_photos_caption_trgm
    ON public.evaluation_photos
    USING gin
    (
        caption gin_trgm_ops
    )
    WHERE caption IS NOT NULL
      AND deleted_at IS NULL;

CREATE INDEX idx_evaluation_photos_file_name_trgm
    ON public.evaluation_photos
    USING gin
    (
        original_file_name gin_trgm_ops
    )
    WHERE original_file_name IS NOT NULL
      AND deleted_at IS NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_evaluation_photo()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_evaluation_trial_id           uuid;
    v_evaluation_variety_id         uuid;
    v_evaluation_date               date;
    v_evaluation_status             text;
    v_evaluation_active             boolean;
    v_evaluation_deleted_at         timestamptz;

    v_detail_evaluation_id          uuid;
    v_detail_variety_id             uuid;
    v_detail_active                 boolean;
    v_detail_deleted_at             timestamptz;

    v_variety_trial_id              uuid;
    v_variety_active                boolean;
    v_variety_deleted_at            timestamptz;
BEGIN
    --------------------------------------------------------------------------
    -- Normalize storage metadata
    --------------------------------------------------------------------------

    NEW.storage_bucket :=
        lower(NULLIF(btrim(NEW.storage_bucket), ''));

    NEW.storage_path :=
        NULLIF(
            regexp_replace(
                btrim(NEW.storage_path),
                '/+',
                '/',
                'g'
            ),
            ''
        );

    NEW.original_file_name :=
        CASE
            WHEN NEW.original_file_name IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.original_file_name), '')
        END;

    NEW.mime_type :=
        lower(NULLIF(btrim(NEW.mime_type), ''));

    NEW.file_checksum :=
        CASE
            WHEN NEW.file_checksum IS NULL THEN NULL
            ELSE lower(NULLIF(btrim(NEW.file_checksum), ''))
        END;

    --------------------------------------------------------------------------
    -- Normalize descriptive fields
    --------------------------------------------------------------------------

    NEW.title :=
        CASE
            WHEN NEW.title IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.title), '')
        END;

    NEW.caption :=
        CASE
            WHEN NEW.caption IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.caption), '')
        END;

    NEW.photo_category :=
        upper(NULLIF(btrim(NEW.photo_category), ''));

    --------------------------------------------------------------------------
    -- Validate parent evaluation
    --------------------------------------------------------------------------

    SELECT
        e.trial_id,
        e.trial_variety_id,
        e.evaluation_date,
        upper(btrim(e.evaluation_status)),
        e.is_active,
        e.deleted_at
    INTO
        v_evaluation_trial_id,
        v_evaluation_variety_id,
        v_evaluation_date,
        v_evaluation_status,
        v_evaluation_active,
        v_evaluation_deleted_at
    FROM public.evaluations e
    WHERE e.id = NEW.evaluation_id
    FOR UPDATE;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Evaluation photo validation failed: evaluation %s does not exist.',
                    NEW.evaluation_id
                );
    END IF;

    IF v_evaluation_active = false
       OR v_evaluation_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation photo validation failed: the parent evaluation is unavailable.';
    END IF;

    IF TG_OP = 'INSERT'
       AND v_evaluation_status = 'COMPLETED' THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation photo validation failed: photos cannot be added to a completed evaluation.';
    END IF;

    --------------------------------------------------------------------------
    -- Default evaluation variety when one is selected on the evaluation
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
                    'Evaluation photo validation failed: photo variety must match the variety selected on the evaluation.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate optional evaluation detail
    --------------------------------------------------------------------------

    IF NEW.evaluation_detail_id IS NOT NULL THEN
        SELECT
            ed.evaluation_id,
            ed.trial_variety_id,
            ed.is_active,
            ed.deleted_at
        INTO
            v_detail_evaluation_id,
            v_detail_variety_id,
            v_detail_active,
            v_detail_deleted_at
        FROM public.evaluation_details ed
        WHERE ed.id = NEW.evaluation_detail_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE =
                        'Evaluation photo validation failed: selected evaluation detail does not exist.';
        END IF;

        IF v_detail_evaluation_id IS DISTINCT FROM NEW.evaluation_id THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation photo validation failed: selected detail belongs to another evaluation.';
        END IF;

        IF v_detail_active = false
           OR v_detail_deleted_at IS NOT NULL THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation photo validation failed: selected evaluation detail is unavailable.';
        END IF;

        IF NEW.trial_variety_id IS NULL
           AND v_detail_variety_id IS NOT NULL THEN
            NEW.trial_variety_id := v_detail_variety_id;
        END IF;

        IF v_detail_variety_id IS NOT NULL
           AND NEW.trial_variety_id IS DISTINCT FROM v_detail_variety_id THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation photo validation failed: photo variety must match the variety selected on the evaluation detail.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Validate optional trial variety
    --------------------------------------------------------------------------

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
                        'Evaluation photo validation failed: selected trial variety does not exist.';
        END IF;

        IF v_variety_trial_id IS DISTINCT FROM v_evaluation_trial_id THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation photo validation failed: selected trial variety belongs to another trial.';
        END IF;

        IF v_variety_active = false
           OR v_variety_deleted_at IS NOT NULL THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Evaluation photo validation failed: selected trial variety is unavailable.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Validate capture timestamp
    --------------------------------------------------------------------------

    IF NEW.captured_at IS NOT NULL
       AND NEW.captured_at::date < v_evaluation_date - 30 THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation photo validation failed: capture date cannot be more than 30 days before the evaluation date.';
    END IF;

    --------------------------------------------------------------------------
    -- Soft deletion state
    --------------------------------------------------------------------------

    IF NEW.deleted_at IS NOT NULL THEN
        NEW.is_active := false;
        NEW.is_cover := false;
    END IF;

    IF NEW.is_active = false THEN
        NEW.is_cover := false;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_evaluation_photo() IS
'Validates evaluation ownership, detail ownership, trial variety ownership, image metadata, capture time, cover state, and soft deletion.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_evaluation_photos_validate
    BEFORE INSERT OR UPDATE OF
        evaluation_id,
        evaluation_detail_id,
        trial_variety_id,
        storage_bucket,
        storage_path,
        original_file_name,
        mime_type,
        file_size_bytes,
        file_checksum,
        width_pixels,
        height_pixels,
        captured_at,
        title,
        caption,
        photo_category,
        display_order,
        is_cover,
        is_active,
        deleted_at
    ON public.evaluation_photos
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_evaluation_photo();

--------------------------------------------------------------------------------
-- FUNCTION: Maintain One Cover Photo per Evaluation
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_set_evaluation_cover_photo()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
BEGIN
    IF NEW.is_cover = true
       AND NEW.is_active = true
       AND NEW.deleted_at IS NULL THEN

        UPDATE public.evaluation_photos
        SET
            is_cover = false,
            updated_at = timezone('UTC', now()),
            updated_by = COALESCE(
                auth.uid(),
                NEW.updated_by,
                NEW.created_by
            )
        WHERE evaluation_id = NEW.evaluation_id
          AND id <> NEW.id
          AND is_cover = true
          AND deleted_at IS NULL;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_set_evaluation_cover_photo() IS
'Clears the previous evaluation cover photo before another active photo is marked as cover.';

CREATE TRIGGER trg_evaluation_photos_set_cover
    BEFORE INSERT OR UPDATE OF is_cover
    ON public.evaluation_photos
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_evaluation_cover_photo();

--------------------------------------------------------------------------------
-- COMPLETED EVALUATION PHOTO PROTECTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_protect_completed_evaluation_photo()
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
                    'Evaluation photo protection failed: parent evaluation does not exist.';
    END IF;

    IF v_evaluation_status = 'COMPLETED'
       AND
       (
           NEW.evaluation_id IS DISTINCT FROM OLD.evaluation_id
           OR NEW.evaluation_detail_id IS DISTINCT FROM OLD.evaluation_detail_id
           OR NEW.trial_variety_id IS DISTINCT FROM OLD.trial_variety_id
           OR NEW.storage_bucket IS DISTINCT FROM OLD.storage_bucket
           OR NEW.storage_path IS DISTINCT FROM OLD.storage_path
           OR NEW.original_file_name IS DISTINCT FROM OLD.original_file_name
           OR NEW.mime_type IS DISTINCT FROM OLD.mime_type
           OR NEW.file_size_bytes IS DISTINCT FROM OLD.file_size_bytes
           OR NEW.file_checksum IS DISTINCT FROM OLD.file_checksum
           OR NEW.width_pixels IS DISTINCT FROM OLD.width_pixels
           OR NEW.height_pixels IS DISTINCT FROM OLD.height_pixels
           OR NEW.captured_at IS DISTINCT FROM OLD.captured_at
           OR NEW.title IS DISTINCT FROM OLD.title
           OR NEW.caption IS DISTINCT FROM OLD.caption
           OR NEW.photo_category IS DISTINCT FROM OLD.photo_category
           OR NEW.display_order IS DISTINCT FROM OLD.display_order
           OR NEW.is_cover IS DISTINCT FROM OLD.is_cover
           OR NEW.is_active IS DISTINCT FROM OLD.is_active
           OR NEW.deleted_at IS DISTINCT FROM OLD.deleted_at
       ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Evaluation photo protection failed: photos belonging to completed evaluations are immutable.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_protect_completed_evaluation_photo() IS
'Prevents modification or soft deletion of photos belonging to completed evaluations.';

CREATE TRIGGER trg_evaluation_photos_protect_completed
    BEFORE UPDATE
    ON public.evaluation_photos
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_protect_completed_evaluation_photo();

--------------------------------------------------------------------------------
-- PHYSICAL DELETE PROTECTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_prevent_evaluation_photo_delete()
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
                'Evaluation photo protection failed: photo metadata cannot be physically deleted. Use soft deletion.';

    RETURN OLD;
END;
$$;

COMMENT ON FUNCTION public.trg_prevent_evaluation_photo_delete() IS
'Prevents physical deletion of evaluation photo metadata records.';

CREATE TRIGGER trg_evaluation_photos_prevent_delete
    BEFORE DELETE
    ON public.evaluation_photos
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_prevent_evaluation_photo_delete();

--------------------------------------------------------------------------------
-- GENERIC AUDIT TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_evaluation_photos_timestamps
    BEFORE INSERT OR UPDATE
    ON public.evaluation_photos
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_evaluation_photos_created_by
    BEFORE INSERT
    ON public.evaluation_photos
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_evaluation_photos_updated_by
    BEFORE UPDATE
    ON public.evaluation_photos
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

    IF to_regclass('public.evaluation_photos') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: public.evaluation_photos was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify required columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO v_expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'evaluation_photos'
      AND column_name IN
      (
          'id',
          'evaluation_id',
          'evaluation_detail_id',
          'trial_variety_id',
          'storage_bucket',
          'storage_path',
          'original_file_name',
          'mime_type',
          'file_size_bytes',
          'file_checksum',
          'width_pixels',
          'height_pixels',
          'captured_at',
          'title',
          'caption',
          'photo_category',
          'display_order',
          'is_cover',
          'is_active',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF v_expected_column_count <> 24 THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: evaluation_photos has % of 24 required columns.',
            v_expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluation_photos'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluation_photos'::regclass
          AND conname = 'fk_evaluation_photos_evaluation'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: evaluation foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluation_photos'::regclass
          AND conname = 'fk_evaluation_photos_evaluation_detail'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: evaluation-detail foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.evaluation_photos'::regclass
          AND conname = 'fk_evaluation_photos_trial_variety'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: trial-variety foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass(
        'public.uq_evaluation_photos_storage_object'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: storage-object unique index is missing.';
    END IF;

    IF to_regclass(
        'public.uq_evaluation_photos_one_cover'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: cover-photo unique index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify functions
    --------------------------------------------------------------------------

    IF to_regprocedure(
        'public.trg_validate_evaluation_photo()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: validation function is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_set_evaluation_cover_photo()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: cover-photo function is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_protect_completed_evaluation_photo()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: completed-evaluation protection function is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_prevent_evaluation_photo_delete()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: delete-protection function is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_photos'::regclass
          AND tgname = 'trg_evaluation_photos_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: validation trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_photos'::regclass
          AND tgname = 'trg_evaluation_photos_set_cover'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: cover-photo trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_photos'::regclass
          AND tgname = 'trg_evaluation_photos_protect_completed'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: completed-evaluation protection trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_photos'::regclass
          AND tgname = 'trg_evaluation_photos_prevent_delete'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: physical-delete protection trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_photos'::regclass
          AND tgname = 'trg_evaluation_photos_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_photos'::regclass
          AND tgname = 'trg_evaluation_photos_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.evaluation_photos'::regclass
          AND tgname = 'trg_evaluation_photos_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: updated_by trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify one active cover photo maximum
    --------------------------------------------------------------------------

    IF EXISTS
    (
        SELECT ep.evaluation_id
        FROM public.evaluation_photos ep
        WHERE ep.is_cover = true
          AND ep.is_active = true
          AND ep.deleted_at IS NULL
        GROUP BY ep.evaluation_id
        HAVING count(*) > 1
    ) THEN
        RAISE EXCEPTION
            'Migration 0043_evaluation_photos.sql failed: one or more evaluations have multiple active cover photos.';
    END IF;
END;
$$;

COMMIT;
