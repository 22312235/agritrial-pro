/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0038_trial_photos.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the trial_photos table.
*
* This table stores metadata for photos attached to Phase 1 trial installations.
* The physical image files are stored in Supabase Storage, while PostgreSQL
* stores the bucket, object path, file metadata, caption, ordering, and audit data.
*
* Supported photo purposes include:
*
*   • General installation photos
*   • Field overview photos
*   • Plot photos
*   • Plant photos
*   • Fruit photos
*   • Label or package photos
*   • Location evidence
*   • Other installation evidence
*
* Frozen architectural rules:
*
*   • One Installation = One Trial.
*   • Every photo belongs to exactly one trial.
*   • A photo may optionally reference one trial variety.
*   • The referenced trial variety must belong to the same trial.
*   • Supabase Storage object paths must be unique.
*   • File binaries are not stored inside PostgreSQL.
*   • Historical photo records use soft deletion.
*   • Physical Storage deletion is handled separately by application or
*     Storage-management functions.
*   • Row Level Security and Storage policies are intentionally deferred.
*
* General custom-value rule:
*
*   • photo_type supports a fixed common set of values.
*   • OTHER may be selected when no configured purpose applies.
*   • photo_type_custom is required when photo_type = OTHER.
*   • photo_type_custom must be NULL for all other photo types.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0003_domains.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
*   • 0036_trials.sql
*   • 0037_trial_varieties.sql
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
-- TABLE: trial_photos
--------------------------------------------------------------------------------

CREATE TABLE public.trial_photos
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                      uuid
                            PRIMARY KEY
                            DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Parent Relationships
    --------------------------------------------------------------------------

    trial_id                uuid
                            NOT NULL,

    trial_variety_id        uuid,

    --------------------------------------------------------------------------
    -- Supabase Storage Information
    --------------------------------------------------------------------------

    storage_bucket          varchar(100)
                            NOT NULL
                            DEFAULT 'trial-photos',

    storage_path            text
                            NOT NULL,

    original_file_name      varchar(255)
                            NOT NULL,

    mime_type               varchar(100)
                            NOT NULL,

    file_size_bytes         bigint
                            NOT NULL,

    width_pixels            integer,

    height_pixels           integer,

    checksum_sha256         varchar(64),

    --------------------------------------------------------------------------
    -- Photo Classification
    --------------------------------------------------------------------------

    photo_type              varchar(50)
                            NOT NULL
                            DEFAULT 'GENERAL',

    photo_type_custom       varchar(150),

    --------------------------------------------------------------------------
    -- Photo Information
    --------------------------------------------------------------------------

    caption                 varchar(500),

    description             text,

    taken_at                timestamptz,

    latitude                numeric(9,6),

    longitude               numeric(9,6),

    --------------------------------------------------------------------------
    -- Display Configuration
    --------------------------------------------------------------------------

    is_primary              boolean
                            NOT NULL
                            DEFAULT false,

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

    CONSTRAINT fk_trial_photos_trial
        FOREIGN KEY (trial_id)
        REFERENCES public.trials(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trial_photos_trial_variety
        FOREIGN KEY (trial_variety_id)
        REFERENCES public.trial_varieties(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_trial_photos_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_trial_photos_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_trial_photos_storage_bucket
        CHECK
        (
            char_length(btrim(storage_bucket)) BETWEEN 1 AND 100
            AND storage_bucket = lower(storage_bucket)
            AND storage_bucket ~ '^[a-z0-9][a-z0-9._-]*$'
        ),

    CONSTRAINT chk_trial_photos_storage_path
        CHECK
        (
            length(btrim(storage_path)) > 0
            AND char_length(btrim(storage_path)) <= 2000
            AND storage_path !~ '(^/|/$|//)'
            AND storage_path !~ '(^|/)\.\.?(/|$)'
        ),

    CONSTRAINT chk_trial_photos_original_file_name
        CHECK
        (
            char_length(btrim(original_file_name)) BETWEEN 1 AND 255
            AND original_file_name !~ '[/\\]'
        ),

    CONSTRAINT chk_trial_photos_mime_type
        CHECK
        (
            mime_type IN
            (
                'image/jpeg',
                'image/png',
                'image/webp',
                'image/heic',
                'image/heif'
            )
        ),

    CONSTRAINT chk_trial_photos_file_size
        CHECK
        (
            file_size_bytes > 0
            AND file_size_bytes <= 52428800
        ),

    CONSTRAINT chk_trial_photos_width
        CHECK
        (
            width_pixels IS NULL
            OR width_pixels BETWEEN 1 AND 100000
        ),

    CONSTRAINT chk_trial_photos_height
        CHECK
        (
            height_pixels IS NULL
            OR height_pixels BETWEEN 1 AND 100000
        ),

    CONSTRAINT chk_trial_photos_dimensions
        CHECK
        (
            (
                width_pixels IS NULL
                AND height_pixels IS NULL
            )
            OR
            (
                width_pixels IS NOT NULL
                AND height_pixels IS NOT NULL
            )
        ),

    CONSTRAINT chk_trial_photos_checksum_sha256
        CHECK
        (
            checksum_sha256 IS NULL
            OR checksum_sha256 ~ '^[a-f0-9]{64}$'
        ),

    CONSTRAINT chk_trial_photos_type
        CHECK
        (
            photo_type IN
            (
                'GENERAL',
                'INSTALLATION',
                'FIELD_OVERVIEW',
                'PLOT',
                'PLANT',
                'FRUIT',
                'LABEL',
                'PACKAGE',
                'LOCATION',
                'OTHER'
            )
        ),

    CONSTRAINT chk_trial_photos_custom_type
        CHECK
        (
            (
                photo_type = 'OTHER'
                AND photo_type_custom IS NOT NULL
                AND char_length(btrim(photo_type_custom)) BETWEEN 1 AND 150
            )
            OR
            (
                photo_type <> 'OTHER'
                AND photo_type_custom IS NULL
            )
        ),

    CONSTRAINT chk_trial_photos_caption
        CHECK
        (
            caption IS NULL
            OR
            (
                length(btrim(caption)) > 0
                AND char_length(btrim(caption)) <= 500
            )
        ),

    CONSTRAINT chk_trial_photos_description
        CHECK
        (
            description IS NULL
            OR
            (
                length(btrim(description)) > 0
                AND char_length(btrim(description)) <= 5000
            )
        ),

    CONSTRAINT chk_trial_photos_latitude
        CHECK
        (
            latitude IS NULL
            OR latitude BETWEEN -90 AND 90
        ),

    CONSTRAINT chk_trial_photos_longitude
        CHECK
        (
            longitude IS NULL
            OR longitude BETWEEN -180 AND 180
        ),

    CONSTRAINT chk_trial_photos_coordinates
        CHECK
        (
            (
                latitude IS NULL
                AND longitude IS NULL
            )
            OR
            (
                latitude IS NOT NULL
                AND longitude IS NOT NULL
            )
        ),

    CONSTRAINT chk_trial_photos_display_order
        CHECK
        (
            display_order >= 0
        ),

    CONSTRAINT chk_trial_photos_taken_at
        CHECK
        (
            taken_at IS NULL
            OR taken_at <= timezone('UTC', now()) + interval '1 day'
        ),

    CONSTRAINT chk_trial_photos_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_trial_photos_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.trial_photos IS
'Supabase Storage metadata for photos attached to Phase 1 agricultural trial installations.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.trial_photos.id IS
'Internal UUID primary key of the trial-photo record.';

COMMENT ON COLUMN public.trial_photos.trial_id IS
'Parent trial installation to which the photo belongs.';

COMMENT ON COLUMN public.trial_photos.trial_variety_id IS
'Optional candidate or witness variety represented in the photo. It must belong to the same trial.';

COMMENT ON COLUMN public.trial_photos.storage_bucket IS
'Supabase Storage bucket containing the image object.';

COMMENT ON COLUMN public.trial_photos.storage_path IS
'Unique object path inside the Supabase Storage bucket.';

COMMENT ON COLUMN public.trial_photos.original_file_name IS
'Original client-side filename before upload.';

COMMENT ON COLUMN public.trial_photos.mime_type IS
'Validated image MIME type.';

COMMENT ON COLUMN public.trial_photos.file_size_bytes IS
'Uploaded image size in bytes. Maximum permitted size is 50 MB.';

COMMENT ON COLUMN public.trial_photos.width_pixels IS
'Optional image width in pixels. Width and height must be provided together.';

COMMENT ON COLUMN public.trial_photos.height_pixels IS
'Optional image height in pixels. Width and height must be provided together.';

COMMENT ON COLUMN public.trial_photos.checksum_sha256 IS
'Optional lowercase SHA-256 checksum used for integrity checks and duplicate detection.';

COMMENT ON COLUMN public.trial_photos.photo_type IS
'System photo-purpose classification used by Flutter and reports.';

COMMENT ON COLUMN public.trial_photos.photo_type_custom IS
'Custom photo-purpose text required only when photo_type is OTHER.';

COMMENT ON COLUMN public.trial_photos.caption IS
'Short photo caption shown in galleries, reports, and trial details.';

COMMENT ON COLUMN public.trial_photos.description IS
'Optional detailed explanation of the photo content.';

COMMENT ON COLUMN public.trial_photos.taken_at IS
'Optional UTC timestamp when the photo was captured.';

COMMENT ON COLUMN public.trial_photos.latitude IS
'Optional capture latitude in decimal degrees.';

COMMENT ON COLUMN public.trial_photos.longitude IS
'Optional capture longitude in decimal degrees.';

COMMENT ON COLUMN public.trial_photos.is_primary IS
'Indicates the principal installation photo shown as the trial cover image.';

COMMENT ON COLUMN public.trial_photos.display_order IS
'Controls photo ordering in Flutter galleries and generated reports.';

COMMENT ON COLUMN public.trial_photos.is_active IS
'Indicates whether the photo is available in active trial views and reports.';

COMMENT ON COLUMN public.trial_photos.created_at IS
'UTC timestamp when the photo metadata record was created.';

COMMENT ON COLUMN public.trial_photos.updated_at IS
'UTC timestamp when the photo metadata record was most recently updated.';

COMMENT ON COLUMN public.trial_photos.created_by IS
'Supabase Auth user who uploaded or registered the photo.';

COMMENT ON COLUMN public.trial_photos.updated_by IS
'Supabase Auth user who most recently updated the photo metadata.';

COMMENT ON COLUMN public.trial_photos.deleted_at IS
'Soft-deletion timestamp. Physical Storage deletion is handled separately.';

--------------------------------------------------------------------------------
-- UNIQUE STORAGE OBJECT INDEX
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_trial_photos_storage_object
    ON public.trial_photos
    (
        lower(btrim(storage_bucket)),
        btrim(storage_path)
    );

--------------------------------------------------------------------------------
-- ONE PRIMARY PHOTO PER TRIAL
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_trial_photos_one_primary_per_trial
    ON public.trial_photos (trial_id)
    WHERE is_primary = true
      AND is_active = true
      AND deleted_at IS NULL;

--------------------------------------------------------------------------------
-- OPTIONAL CHECKSUM DUPLICATE PREVENTION
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_trial_photos_trial_checksum
    ON public.trial_photos
    (
        trial_id,
        checksum_sha256
    )
    WHERE checksum_sha256 IS NOT NULL
      AND deleted_at IS NULL;

--------------------------------------------------------------------------------
-- RELATIONSHIP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_trial_photos_trial_id
    ON public.trial_photos (trial_id);

CREATE INDEX idx_trial_photos_trial_variety_id
    ON public.trial_photos (trial_variety_id)
    WHERE trial_variety_id IS NOT NULL;

CREATE INDEX idx_trial_photos_created_by
    ON public.trial_photos (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_trial_photos_updated_by
    ON public.trial_photos (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- GALLERY AND FILTERING INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_trial_photos_trial_gallery
    ON public.trial_photos
    (
        trial_id,
        is_primary DESC,
        display_order,
        created_at
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_trial_photos_trial_type
    ON public.trial_photos
    (
        trial_id,
        photo_type,
        display_order
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_trial_photos_variety_gallery
    ON public.trial_photos
    (
        trial_variety_id,
        display_order,
        created_at
    )
    WHERE trial_variety_id IS NOT NULL
      AND is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_trial_photos_taken_at
    ON public.trial_photos
    (
        trial_id,
        taken_at DESC
    )
    WHERE taken_at IS NOT NULL
      AND deleted_at IS NULL;

CREATE INDEX idx_trial_photos_deleted_at
    ON public.trial_photos (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- SEARCH INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_trial_photos_caption_trgm
    ON public.trial_photos
    USING gin
    (
        caption gin_trgm_ops
    )
    WHERE caption IS NOT NULL
      AND deleted_at IS NULL;

CREATE INDEX idx_trial_photos_original_file_name_trgm
    ON public.trial_photos
    USING gin
    (
        original_file_name gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------
-- Validates:
--
--   • Parent trial exists and is not soft-deleted.
--   • Optional trial variety exists and belongs to the same trial.
--   • Trial variety is active and not soft-deleted for active photos.
--   • Storage metadata is normalized.
--   • MIME type, checksum, photo type, and optional text are normalized.
--   • Primary photos must remain active and non-deleted.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_trial_photo()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_trial_deleted_at          timestamptz;

    v_variety_trial_id          uuid;
    v_variety_is_active         boolean;
    v_variety_deleted_at        timestamptz;
BEGIN
    --------------------------------------------------------------------------
    -- Normalize Storage metadata
    --------------------------------------------------------------------------

    NEW.storage_bucket :=
        lower(NULLIF(btrim(NEW.storage_bucket), ''));

    NEW.storage_path :=
        NULLIF(btrim(NEW.storage_path), '');

    NEW.original_file_name :=
        NULLIF(btrim(NEW.original_file_name), '');

    NEW.mime_type :=
        lower(NULLIF(btrim(NEW.mime_type), ''));

    NEW.checksum_sha256 :=
        CASE
            WHEN NEW.checksum_sha256 IS NULL THEN NULL
            ELSE lower(NULLIF(btrim(NEW.checksum_sha256), ''))
        END;

    --------------------------------------------------------------------------
    -- Normalize classification and optional text
    --------------------------------------------------------------------------

    NEW.photo_type :=
        upper(NULLIF(btrim(NEW.photo_type), ''));

    NEW.photo_type_custom :=
        CASE
            WHEN NEW.photo_type_custom IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.photo_type_custom), '')
        END;

    NEW.caption :=
        CASE
            WHEN NEW.caption IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.caption), '')
        END;

    NEW.description :=
        CASE
            WHEN NEW.description IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.description), '')
        END;

    --------------------------------------------------------------------------
    -- Validate mandatory normalized values
    --------------------------------------------------------------------------

    IF NEW.storage_bucket IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial photo validation failed: Storage bucket is required.';
    END IF;

    IF NEW.storage_path IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial photo validation failed: Storage object path is required.';
    END IF;

    IF NEW.original_file_name IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial photo validation failed: original file name is required.';
    END IF;

    IF NEW.mime_type IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial photo validation failed: MIME type is required.';
    END IF;

    IF NEW.photo_type IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial photo validation failed: photo type is required.';
    END IF;

    --------------------------------------------------------------------------
    -- Validate parent trial
    --------------------------------------------------------------------------

    SELECT
        t.deleted_at
    INTO
        v_trial_deleted_at
    FROM public.trials t
    WHERE t.id = NEW.trial_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE = format(
                    'Trial photo validation failed: trial %s does not exist.',
                    NEW.trial_id
                );
    END IF;

    IF v_trial_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial photo validation failed: photos cannot be attached to a soft-deleted trial.';
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
            v_variety_is_active,
            v_variety_deleted_at
        FROM public.trial_varieties tv
        WHERE tv.id = NEW.trial_variety_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE = format(
                        'Trial photo validation failed: trial variety %s does not exist.',
                        NEW.trial_variety_id
                    );
        END IF;

        IF v_variety_trial_id IS DISTINCT FROM NEW.trial_id THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Trial photo validation failed: the selected trial variety belongs to a different trial.';
        END IF;

        IF NEW.is_active = true
           AND
           (
               v_variety_is_active = false
               OR v_variety_deleted_at IS NOT NULL
           ) THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Trial photo validation failed: an active photo cannot reference an unavailable trial variety.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Validate custom photo type
    --------------------------------------------------------------------------

    IF NEW.photo_type = 'OTHER'
       AND NEW.photo_type_custom IS NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial photo validation failed: a custom photo type is required when photo type is OTHER.';
    END IF;

    IF NEW.photo_type <> 'OTHER'
       AND NEW.photo_type_custom IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial photo validation failed: custom photo type is only allowed when photo type is OTHER.';
    END IF;

    --------------------------------------------------------------------------
    -- Primary photo state
    --------------------------------------------------------------------------

    IF NEW.is_primary = true
       AND
       (
           NEW.is_active = false
           OR NEW.deleted_at IS NOT NULL
       ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial photo validation failed: the primary trial photo must remain active and non-deleted.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_trial_photo() IS
'Validates trial ownership, optional variety ownership, Storage metadata, image metadata, custom photo types, and primary-photo state.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trial_photos_validate
    BEFORE INSERT OR UPDATE OF
        trial_id,
        trial_variety_id,
        storage_bucket,
        storage_path,
        original_file_name,
        mime_type,
        file_size_bytes,
        width_pixels,
        height_pixels,
        checksum_sha256,
        photo_type,
        photo_type_custom,
        caption,
        description,
        taken_at,
        latitude,
        longitude,
        is_primary,
        is_active,
        deleted_at
    ON public.trial_photos
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_trial_photo();

--------------------------------------------------------------------------------
-- STORAGE IDENTITY PROTECTION FUNCTION
--------------------------------------------------------------------------------
-- Once a photo record has been created, its Storage bucket and object path
-- cannot be changed. Replacing a physical file must create a new photo record
-- so audit history remains reliable.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_protect_trial_photo_storage()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
BEGIN
    IF NEW.storage_bucket IS DISTINCT FROM OLD.storage_bucket
       OR NEW.storage_path IS DISTINCT FROM OLD.storage_path THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Trial photo protection failed: Storage bucket and object path are immutable after creation.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_protect_trial_photo_storage() IS
'Prevents modification of the Supabase Storage bucket and object path after photo creation.';

--------------------------------------------------------------------------------
-- STORAGE IDENTITY PROTECTION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trial_photos_protect_storage
    BEFORE UPDATE OF
        storage_bucket,
        storage_path
    ON public.trial_photos
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_protect_trial_photo_storage();

--------------------------------------------------------------------------------
-- PRIMARY PHOTO ASSIGNMENT FUNCTION
--------------------------------------------------------------------------------
-- When a photo is marked as primary, every other active, non-deleted photo for
-- the same trial is automatically demoted.
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_assign_primary_trial_photo()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
BEGIN
    IF NEW.is_primary = true
       AND NEW.is_active = true
       AND NEW.deleted_at IS NULL THEN

        UPDATE public.trial_photos
        SET
            is_primary = false,
            updated_at = timezone('UTC', now()),
            updated_by = COALESCE(auth.uid(), NEW.updated_by, NEW.created_by)
        WHERE trial_id = NEW.trial_id
          AND id <> NEW.id
          AND is_primary = true
          AND deleted_at IS NULL;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_assign_primary_trial_photo() IS
'Automatically demotes other primary photos when a new primary photo is assigned to a trial.';

--------------------------------------------------------------------------------
-- PRIMARY PHOTO ASSIGNMENT TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trial_photos_assign_primary
    BEFORE INSERT OR UPDATE OF
        trial_id,
        is_primary,
        is_active,
        deleted_at
    ON public.trial_photos
    FOR EACH ROW
    WHEN
    (
        NEW.is_primary = true
        AND NEW.is_active = true
        AND NEW.deleted_at IS NULL
    )
    EXECUTE FUNCTION public.trg_assign_primary_trial_photo();

--------------------------------------------------------------------------------
-- GENERIC TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_trial_photos_timestamps
    BEFORE INSERT OR UPDATE
    ON public.trial_photos
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_trial_photos_created_by
    BEFORE INSERT
    ON public.trial_photos
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_trial_photos_updated_by
    BEFORE UPDATE
    ON public.trial_photos
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- MIGRATION VALIDATION
--------------------------------------------------------------------------------

DO
$$
DECLARE
    expected_column_count integer;
BEGIN
    --------------------------------------------------------------------------
    -- Verify table creation
    --------------------------------------------------------------------------

    IF to_regclass('public.trial_photos') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0038_trial_photos.sql failed: public.trial_photos was not created.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify expected columns
    --------------------------------------------------------------------------

    SELECT count(*)
    INTO expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'trial_photos'
      AND column_name IN
      (
          'id',
          'trial_id',
          'trial_variety_id',
          'storage_bucket',
          'storage_path',
          'original_file_name',
          'mime_type',
          'file_size_bytes',
          'width_pixels',
          'height_pixels',
          'checksum_sha256',
          'photo_type',
          'photo_type_custom',
          'caption',
          'description',
          'taken_at',
          'latitude',
          'longitude',
          'is_primary',
          'display_order',
          'is_active',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF expected_column_count <> 26 THEN
        RAISE EXCEPTION
            'Migration 0038_trial_photos.sql failed: trial_photos has % of 26 required columns.',
            expected_column_count;
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary key
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trial_photos'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0038_trial_photos.sql failed: primary key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify foreign keys
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trial_photos'::regclass
          AND conname = 'fk_trial_photos_trial'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0038_trial_photos.sql failed: trial foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trial_photos'::regclass
          AND conname = 'fk_trial_photos_trial_variety'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0038_trial_photos.sql failed: trial-variety foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trial_photos'::regclass
          AND conname = 'fk_trial_photos_created_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0038_trial_photos.sql failed: created_by foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.trial_photos'::regclass
          AND conname = 'fk_trial_photos_updated_by'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0038_trial_photos.sql failed: updated_by foreign key is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify unique indexes
    --------------------------------------------------------------------------

    IF to_regclass(
        'public.uq_trial_photos_storage_object'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0038_trial_photos.sql failed: unique Storage-object index is missing.';
    END IF;

    IF to_regclass(
        'public.uq_trial_photos_one_primary_per_trial'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0038_trial_photos.sql failed: one-primary-photo index is missing.';
    END IF;

    IF to_regclass(
        'public.uq_trial_photos_trial_checksum'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0038_trial_photos.sql failed: trial/checksum unique index is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify validation function and trigger
    --------------------------------------------------------------------------

    IF to_regprocedure(
        'public.trg_validate_trial_photo()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0038_trial_photos.sql failed: validation function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trial_photos'::regclass
          AND tgname = 'trg_trial_photos_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0038_trial_photos.sql failed: validation trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify Storage protection function and trigger
    --------------------------------------------------------------------------

    IF to_regprocedure(
        'public.trg_protect_trial_photo_storage()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0038_trial_photos.sql failed: Storage protection function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trial_photos'::regclass
          AND tgname = 'trg_trial_photos_protect_storage'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0038_trial_photos.sql failed: Storage protection trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify primary-photo function and trigger
    --------------------------------------------------------------------------

    IF to_regprocedure(
        'public.trg_assign_primary_trial_photo()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0038_trial_photos.sql failed: primary-photo assignment function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trial_photos'::regclass
          AND tgname = 'trg_trial_photos_assign_primary'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0038_trial_photos.sql failed: primary-photo assignment trigger is missing.';
    END IF;

    --------------------------------------------------------------------------
    -- Verify generic triggers
    --------------------------------------------------------------------------

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trial_photos'::regclass
          AND tgname = 'trg_trial_photos_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0038_trial_photos.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trial_photos'::regclass
          AND tgname = 'trg_trial_photos_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0038_trial_photos.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.trial_photos'::regclass
          AND tgname = 'trg_trial_photos_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0038_trial_photos.sql failed: updated_by trigger is missing.';
    END IF;
END;
$$;

COMMIT;
