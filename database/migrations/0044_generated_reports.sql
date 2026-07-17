/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0044_generated_reports.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the generated_reports table used to store metadata for reports generated
* from agricultural trial and evaluation data.
*
* Binary report files are stored in Supabase Storage. PostgreSQL stores only the
* report identity, generation parameters, storage metadata, workflow state, and
* audit information.
*
* Supported report scopes:
*
*   • TRIAL
*   • EVALUATION
*   • SEASON
*   • CROP
*   • PORTFOLIO
*
* Supported report formats:
*
*   • PDF
*   • CSV
*   • XLSX
*
* Supported generation states:
*
*   • PENDING
*   • PROCESSING
*   • COMPLETED
*   • FAILED
*   • CANCELLED
*
* Business rules:
*
*   • A TRIAL report must reference one trial.
*   • An EVALUATION report must reference one evaluation and its parent trial.
*   • A SEASON report must reference one season.
*   • A CROP report must reference one crop.
*   • A PORTFOLIO report does not require a specific entity.
*   • Completed reports must contain a storage object and completion timestamp.
*   • Failed reports must contain an error message.
*   • Pending and processing reports cannot contain completed report files.
*   • Storage object paths are unique while active.
*   • Completed reports are immutable except for soft deletion and audit metadata.
*   • Physical deletion is prohibited.
*   • RLS and Storage policies will be added later.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
*   • 0017_seasons.sql
*   • 0018_crops.sql
*   • 0036_trials.sql
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
-- TABLE: generated_reports
--------------------------------------------------------------------------------

CREATE TABLE public.generated_reports
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                      uuid
                            PRIMARY KEY
                            DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Report Identity
    --------------------------------------------------------------------------

    report_number           bigint
                            GENERATED ALWAYS AS IDENTITY,

    report_name             varchar(250)
                            NOT NULL,

    report_scope            varchar(30)
                            NOT NULL,

    report_format           varchar(10)
                            NOT NULL
                            DEFAULT 'PDF',

    report_status           varchar(30)
                            NOT NULL
                            DEFAULT 'PENDING',

    --------------------------------------------------------------------------
    -- Optional Report Scope References
    --------------------------------------------------------------------------

    trial_id                uuid,

    evaluation_id           uuid,

    season_id               uuid,

    crop_id                 uuid,

    --------------------------------------------------------------------------
    -- Generation Parameters
    --------------------------------------------------------------------------

    date_from               date,

    date_to                 date,

    language_code           varchar(10)
                            NOT NULL
                            DEFAULT 'en',

    include_photos          boolean
                            NOT NULL
                            DEFAULT true,

    include_inactive_data   boolean
                            NOT NULL
                            DEFAULT false,

    generation_parameters   jsonb
                            NOT NULL
                            DEFAULT '{}'::jsonb,

    --------------------------------------------------------------------------
    -- Supabase Storage Metadata
    --------------------------------------------------------------------------

    storage_bucket          varchar(100),

    storage_path            text,

    original_file_name      varchar(255),

    mime_type               varchar(100),

    file_size_bytes         bigint,

    file_checksum           varchar(128),

    --------------------------------------------------------------------------
    -- Processing Information
    --------------------------------------------------------------------------

    requested_at            timestamptz
                            NOT NULL
                            DEFAULT timezone('UTC', now()),

    processing_started_at   timestamptz,

    completed_at            timestamptz,

    expires_at              timestamptz,

    requested_by            uuid,

    processed_by            uuid,

    error_message           text,

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

    CONSTRAINT fk_generated_reports_trial
        FOREIGN KEY (trial_id)
        REFERENCES public.trials(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_generated_reports_evaluation
        FOREIGN KEY (evaluation_id)
        REFERENCES public.evaluations(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_generated_reports_season
        FOREIGN KEY (season_id)
        REFERENCES public.seasons(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_generated_reports_crop
        FOREIGN KEY (crop_id)
        REFERENCES public.crops(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT,

    CONSTRAINT fk_generated_reports_requested_by
        FOREIGN KEY (requested_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_generated_reports_processed_by
        FOREIGN KEY (processed_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_generated_reports_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_generated_reports_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT uq_generated_reports_report_number
        UNIQUE (report_number),

    CONSTRAINT chk_generated_reports_name
        CHECK
        (
            char_length(btrim(report_name)) BETWEEN 1 AND 250
        ),

    CONSTRAINT chk_generated_reports_scope
        CHECK
        (
            report_scope IN
            (
                'TRIAL',
                'EVALUATION',
                'SEASON',
                'CROP',
                'PORTFOLIO'
            )
        ),

    CONSTRAINT chk_generated_reports_format
        CHECK
        (
            report_format IN
            (
                'PDF',
                'CSV',
                'XLSX'
            )
        ),

    CONSTRAINT chk_generated_reports_status
        CHECK
        (
            report_status IN
            (
                'PENDING',
                'PROCESSING',
                'COMPLETED',
                'FAILED',
                'CANCELLED'
            )
        ),

    CONSTRAINT chk_generated_reports_language
        CHECK
        (
            language_code ~ '^[a-z]{2}(-[A-Z]{2})?$'
        ),

    CONSTRAINT chk_generated_reports_date_range
        CHECK
        (
            date_from IS NULL
            OR date_to IS NULL
            OR date_to >= date_from
        ),

    CONSTRAINT chk_generated_reports_parameters_object
        CHECK
        (
            jsonb_typeof(generation_parameters) = 'object'
        ),

    CONSTRAINT chk_generated_reports_storage_bucket
        CHECK
        (
            storage_bucket IS NULL
            OR
            (
                char_length(btrim(storage_bucket)) BETWEEN 1 AND 100
                AND storage_bucket = lower(storage_bucket)
                AND storage_bucket ~ '^[a-z0-9][a-z0-9._-]*$'
            )
        ),

    CONSTRAINT chk_generated_reports_storage_path
        CHECK
        (
            storage_path IS NULL
            OR
            (
                char_length(btrim(storage_path)) BETWEEN 1 AND 2000
                AND storage_path !~ '(^|/)\.\.(/|$)'
                AND storage_path !~ '^/'
                AND storage_path !~ '/$'
            )
        ),

    CONSTRAINT chk_generated_reports_original_file_name
        CHECK
        (
            original_file_name IS NULL
            OR char_length(btrim(original_file_name)) BETWEEN 1 AND 255
        ),

    CONSTRAINT chk_generated_reports_mime_type
        CHECK
        (
            mime_type IS NULL
            OR lower(btrim(mime_type)) IN
            (
                'application/pdf',
                'text/csv',
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
            )
        ),

    CONSTRAINT chk_generated_reports_file_size
        CHECK
        (
            file_size_bytes IS NULL
            OR file_size_bytes BETWEEN 1 AND 524288000
        ),

    CONSTRAINT chk_generated_reports_checksum
        CHECK
        (
            file_checksum IS NULL
            OR char_length(btrim(file_checksum)) BETWEEN 16 AND 128
        ),

    CONSTRAINT chk_generated_reports_error_message
        CHECK
        (
            error_message IS NULL
            OR char_length(btrim(error_message)) BETWEEN 1 AND 10000
        ),

    CONSTRAINT chk_generated_reports_processing_dates
        CHECK
        (
            processing_started_at IS NULL
            OR processing_started_at >= requested_at
        ),

    CONSTRAINT chk_generated_reports_completion_date
        CHECK
        (
            completed_at IS NULL
            OR
            (
                completed_at >= requested_at
                AND
                (
                    processing_started_at IS NULL
                    OR completed_at >= processing_started_at
                )
            )
        ),

    CONSTRAINT chk_generated_reports_expiry_date
        CHECK
        (
            expires_at IS NULL
            OR
            (
                completed_at IS NOT NULL
                AND expires_at > completed_at
            )
        ),

    CONSTRAINT chk_generated_reports_storage_pair
        CHECK
        (
            (
                storage_bucket IS NULL
                AND storage_path IS NULL
            )
            OR
            (
                storage_bucket IS NOT NULL
                AND storage_path IS NOT NULL
            )
        ),

    CONSTRAINT chk_generated_reports_status_state
        CHECK
        (
            (
                report_status = 'PENDING'
                AND processing_started_at IS NULL
                AND completed_at IS NULL
                AND storage_bucket IS NULL
                AND storage_path IS NULL
                AND error_message IS NULL
            )
            OR
            (
                report_status = 'PROCESSING'
                AND processing_started_at IS NOT NULL
                AND completed_at IS NULL
                AND storage_bucket IS NULL
                AND storage_path IS NULL
                AND error_message IS NULL
            )
            OR
            (
                report_status = 'COMPLETED'
                AND processing_started_at IS NOT NULL
                AND completed_at IS NOT NULL
                AND storage_bucket IS NOT NULL
                AND storage_path IS NOT NULL
                AND mime_type IS NOT NULL
                AND error_message IS NULL
            )
            OR
            (
                report_status = 'FAILED'
                AND processing_started_at IS NOT NULL
                AND completed_at IS NOT NULL
                AND storage_bucket IS NULL
                AND storage_path IS NULL
                AND error_message IS NOT NULL
            )
            OR
            (
                report_status = 'CANCELLED'
                AND completed_at IS NOT NULL
                AND storage_bucket IS NULL
                AND storage_path IS NULL
            )
        ),

    CONSTRAINT chk_generated_reports_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_generated_reports_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        ),

    CONSTRAINT chk_generated_reports_active_deleted
        CHECK
        (
            deleted_at IS NULL
            OR is_active = false
        )
);

--------------------------------------------------------------------------------
-- TABLE COMMENT
--------------------------------------------------------------------------------

COMMENT ON TABLE public.generated_reports IS
'Metadata and generation state for trial, evaluation, season, crop, and portfolio reports stored in Supabase Storage.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.generated_reports.id IS
'Internal UUID primary key of the generated report.';

COMMENT ON COLUMN public.generated_reports.report_number IS
'System-generated sequential report number.';

COMMENT ON COLUMN public.generated_reports.report_name IS
'Human-readable report title.';

COMMENT ON COLUMN public.generated_reports.report_scope IS
'Business scope of the report: TRIAL, EVALUATION, SEASON, CROP, or PORTFOLIO.';

COMMENT ON COLUMN public.generated_reports.report_format IS
'Generated file format: PDF, CSV, or XLSX.';

COMMENT ON COLUMN public.generated_reports.report_status IS
'Current report generation state.';

COMMENT ON COLUMN public.generated_reports.trial_id IS
'Optional trial included in the report scope.';

COMMENT ON COLUMN public.generated_reports.evaluation_id IS
'Optional evaluation included in the report scope.';

COMMENT ON COLUMN public.generated_reports.season_id IS
'Optional agricultural season included in the report scope.';

COMMENT ON COLUMN public.generated_reports.crop_id IS
'Optional crop included in the report scope.';

COMMENT ON COLUMN public.generated_reports.date_from IS
'Optional lower date boundary used to generate the report.';

COMMENT ON COLUMN public.generated_reports.date_to IS
'Optional upper date boundary used to generate the report.';

COMMENT ON COLUMN public.generated_reports.language_code IS
'Report language code, such as en, fr, or ar.';

COMMENT ON COLUMN public.generated_reports.include_photos IS
'Indicates whether trial and evaluation photos are included in the generated report.';

COMMENT ON COLUMN public.generated_reports.include_inactive_data IS
'Indicates whether inactive records are included in the report.';

COMMENT ON COLUMN public.generated_reports.generation_parameters IS
'Additional structured report-generation parameters stored as a JSON object.';

COMMENT ON COLUMN public.generated_reports.storage_bucket IS
'Supabase Storage bucket containing the generated report file.';

COMMENT ON COLUMN public.generated_reports.storage_path IS
'Relative Supabase Storage object path of the generated report file.';

COMMENT ON COLUMN public.generated_reports.original_file_name IS
'Filename presented when the report is downloaded.';

COMMENT ON COLUMN public.generated_reports.mime_type IS
'MIME type corresponding to the generated report format.';

COMMENT ON COLUMN public.generated_reports.file_size_bytes IS
'Generated report file size in bytes.';

COMMENT ON COLUMN public.generated_reports.file_checksum IS
'Optional checksum used to verify report-file integrity.';

COMMENT ON COLUMN public.generated_reports.requested_at IS
'UTC timestamp when report generation was requested.';

COMMENT ON COLUMN public.generated_reports.processing_started_at IS
'UTC timestamp when report generation processing started.';

COMMENT ON COLUMN public.generated_reports.completed_at IS
'UTC timestamp when generation completed, failed, or was cancelled.';

COMMENT ON COLUMN public.generated_reports.expires_at IS
'Optional UTC timestamp after which the report file should be considered expired.';

COMMENT ON COLUMN public.generated_reports.requested_by IS
'Supabase Auth user who requested the report.';

COMMENT ON COLUMN public.generated_reports.processed_by IS
'Supabase Auth user or service identity responsible for processing the report.';

COMMENT ON COLUMN public.generated_reports.error_message IS
'Generation error details when the report status is FAILED.';

COMMENT ON COLUMN public.generated_reports.is_active IS
'Indicates whether the report is available in active report history.';

COMMENT ON COLUMN public.generated_reports.created_at IS
'UTC timestamp when the report metadata record was created.';

COMMENT ON COLUMN public.generated_reports.updated_at IS
'UTC timestamp when the report metadata record was most recently updated.';

COMMENT ON COLUMN public.generated_reports.created_by IS
'Supabase Auth user who created the report metadata record.';

COMMENT ON COLUMN public.generated_reports.updated_by IS
'Supabase Auth user who most recently updated the report metadata record.';

COMMENT ON COLUMN public.generated_reports.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the report has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_generated_reports_storage_object
    ON public.generated_reports
    (
        storage_bucket,
        storage_path
    )
    WHERE storage_bucket IS NOT NULL
      AND storage_path IS NOT NULL
      AND deleted_at IS NULL;

--------------------------------------------------------------------------------
-- RELATIONSHIP INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_generated_reports_trial_id
    ON public.generated_reports (trial_id)
    WHERE trial_id IS NOT NULL;

CREATE INDEX idx_generated_reports_evaluation_id
    ON public.generated_reports (evaluation_id)
    WHERE evaluation_id IS NOT NULL;

CREATE INDEX idx_generated_reports_season_id
    ON public.generated_reports (season_id)
    WHERE season_id IS NOT NULL;

CREATE INDEX idx_generated_reports_crop_id
    ON public.generated_reports (crop_id)
    WHERE crop_id IS NOT NULL;

CREATE INDEX idx_generated_reports_requested_by
    ON public.generated_reports (requested_by)
    WHERE requested_by IS NOT NULL;

CREATE INDEX idx_generated_reports_processed_by
    ON public.generated_reports (processed_by)
    WHERE processed_by IS NOT NULL;

--------------------------------------------------------------------------------
-- APPLICATION QUERY INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_generated_reports_status_queue
    ON public.generated_reports
    (
        report_status,
        requested_at
    )
    WHERE report_status IN ('PENDING', 'PROCESSING')
      AND is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_generated_reports_history
    ON public.generated_reports
    (
        requested_at DESC,
        report_number DESC
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_generated_reports_scope_history
    ON public.generated_reports
    (
        report_scope,
        requested_at DESC
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_generated_reports_trial_history
    ON public.generated_reports
    (
        trial_id,
        requested_at DESC
    )
    WHERE trial_id IS NOT NULL
      AND is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_generated_reports_evaluation_history
    ON public.generated_reports
    (
        evaluation_id,
        requested_at DESC
    )
    WHERE evaluation_id IS NOT NULL
      AND is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_generated_reports_expiration
    ON public.generated_reports (expires_at)
    WHERE expires_at IS NOT NULL
      AND is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_generated_reports_failed
    ON public.generated_reports
    (
        completed_at DESC
    )
    WHERE report_status = 'FAILED'
      AND deleted_at IS NULL;

CREATE INDEX idx_generated_reports_deleted_at
    ON public.generated_reports (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- AUDIT INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_generated_reports_created_by
    ON public.generated_reports (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_generated_reports_updated_by
    ON public.generated_reports (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- JSON AND SEARCH INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_generated_reports_parameters_gin
    ON public.generated_reports
    USING gin (generation_parameters);

CREATE INDEX idx_generated_reports_name_trgm
    ON public.generated_reports
    USING gin
    (
        report_name gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

CREATE INDEX idx_generated_reports_file_name_trgm
    ON public.generated_reports
    USING gin
    (
        original_file_name gin_trgm_ops
    )
    WHERE original_file_name IS NOT NULL
      AND deleted_at IS NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_generated_report()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_evaluation_trial_id       uuid;

    v_trial_active              boolean;
    v_trial_deleted_at          timestamptz;

    v_evaluation_active         boolean;
    v_evaluation_deleted_at     timestamptz;

    v_season_active             boolean;
    v_season_deleted_at         timestamptz;

    v_crop_active               boolean;
    v_crop_deleted_at           timestamptz;
BEGIN
    --------------------------------------------------------------------------
    -- Normalize report metadata
    --------------------------------------------------------------------------

    NEW.report_name :=
        NULLIF(btrim(NEW.report_name), '');

    NEW.report_scope :=
        upper(NULLIF(btrim(NEW.report_scope), ''));

    NEW.report_format :=
        upper(NULLIF(btrim(NEW.report_format), ''));

    NEW.report_status :=
        upper(NULLIF(btrim(NEW.report_status), ''));

    NEW.language_code :=
        CASE
            WHEN position('-' IN btrim(NEW.language_code)) > 0 THEN
                lower(split_part(btrim(NEW.language_code), '-', 1))
                || '-'
                || upper(split_part(btrim(NEW.language_code), '-', 2))
            ELSE lower(btrim(NEW.language_code))
        END;

    NEW.storage_bucket :=
        CASE
            WHEN NEW.storage_bucket IS NULL THEN NULL
            ELSE lower(NULLIF(btrim(NEW.storage_bucket), ''))
        END;

    NEW.storage_path :=
        CASE
            WHEN NEW.storage_path IS NULL THEN NULL
            ELSE NULLIF
            (
                regexp_replace
                (
                    btrim(NEW.storage_path),
                    '/+',
                    '/',
                    'g'
                ),
                ''
            )
        END;

    NEW.original_file_name :=
        CASE
            WHEN NEW.original_file_name IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.original_file_name), '')
        END;

    NEW.mime_type :=
        CASE
            WHEN NEW.mime_type IS NULL THEN NULL
            ELSE lower(NULLIF(btrim(NEW.mime_type), ''))
        END;

    NEW.file_checksum :=
        CASE
            WHEN NEW.file_checksum IS NULL THEN NULL
            ELSE lower(NULLIF(btrim(NEW.file_checksum), ''))
        END;

    NEW.error_message :=
        CASE
            WHEN NEW.error_message IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.error_message), '')
        END;

    NEW.generation_parameters :=
        COALESCE(NEW.generation_parameters, '{}'::jsonb);

    --------------------------------------------------------------------------
    -- Default requesting actor
    --------------------------------------------------------------------------

    NEW.requested_by :=
        COALESCE
        (
            NEW.requested_by,
            auth.uid(),
            NEW.created_by
        );

    --------------------------------------------------------------------------
    -- Validate optional trial
    --------------------------------------------------------------------------

    IF NEW.trial_id IS NOT NULL THEN
        SELECT
            t.is_active,
            t.deleted_at
        INTO
            v_trial_active,
            v_trial_deleted_at
        FROM public.trials t
        WHERE t.id = NEW.trial_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE =
                        'Generated report validation failed: selected trial does not exist.';
        END IF;

        IF v_trial_active = false
           OR v_trial_deleted_at IS NOT NULL THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Generated report validation failed: selected trial is unavailable.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Validate optional evaluation
    --------------------------------------------------------------------------

    IF NEW.evaluation_id IS NOT NULL THEN
        SELECT
            e.trial_id,
            e.is_active,
            e.deleted_at
        INTO
            v_evaluation_trial_id,
            v_evaluation_active,
            v_evaluation_deleted_at
        FROM public.evaluations e
        WHERE e.id = NEW.evaluation_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE =
                        'Generated report validation failed: selected evaluation does not exist.';
        END IF;

        IF v_evaluation_active = false
           OR v_evaluation_deleted_at IS NOT NULL THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Generated report validation failed: selected evaluation is unavailable.';
        END IF;

        IF NEW.trial_id IS NULL THEN
            NEW.trial_id := v_evaluation_trial_id;
        ELSIF NEW.trial_id IS DISTINCT FROM v_evaluation_trial_id THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Generated report validation failed: selected evaluation belongs to another trial.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Validate optional season
    --------------------------------------------------------------------------

    IF NEW.season_id IS NOT NULL THEN
        SELECT
            s.is_active,
            s.deleted_at
        INTO
            v_season_active,
            v_season_deleted_at
        FROM public.seasons s
        WHERE s.id = NEW.season_id;

        IF NOT FOUND THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23503',
                    MESSAGE =
                        'Generated report validation failed: selected season does not exist.';
        END IF;

        IF v_season_active = false
           OR v_season_deleted_at IS NOT NULL THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Generated report validation failed: selected season is unavailable.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Validate optional crop
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
                    MESSAGE =
                        'Generated report validation failed: selected crop does not exist.';
        END IF;

        IF v_crop_active = false
           OR v_crop_deleted_at IS NOT NULL THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Generated report validation failed: selected crop is unavailable.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Validate report scope references
    --------------------------------------------------------------------------

    CASE NEW.report_scope
        WHEN 'TRIAL' THEN
            IF NEW.trial_id IS NULL
               OR NEW.evaluation_id IS NOT NULL
               OR NEW.season_id IS NOT NULL
               OR NEW.crop_id IS NOT NULL THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Generated report validation failed: TRIAL reports require only trial_id.';
            END IF;

        WHEN 'EVALUATION' THEN
            IF NEW.evaluation_id IS NULL
               OR NEW.trial_id IS NULL
               OR NEW.season_id IS NOT NULL
               OR NEW.crop_id IS NOT NULL THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Generated report validation failed: EVALUATION reports require evaluation_id and its trial_id.';
            END IF;

        WHEN 'SEASON' THEN
            IF NEW.season_id IS NULL
               OR NEW.trial_id IS NOT NULL
               OR NEW.evaluation_id IS NOT NULL
               OR NEW.crop_id IS NOT NULL THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Generated report validation failed: SEASON reports require only season_id.';
            END IF;

        WHEN 'CROP' THEN
            IF NEW.crop_id IS NULL
               OR NEW.trial_id IS NOT NULL
               OR NEW.evaluation_id IS NOT NULL
               OR NEW.season_id IS NOT NULL THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Generated report validation failed: CROP reports require only crop_id.';
            END IF;

        WHEN 'PORTFOLIO' THEN
            IF NEW.trial_id IS NOT NULL
               OR NEW.evaluation_id IS NOT NULL
               OR NEW.season_id IS NOT NULL
               OR NEW.crop_id IS NOT NULL THEN
                RAISE EXCEPTION
                    USING
                        ERRCODE = '23514',
                        MESSAGE =
                            'Generated report validation failed: PORTFOLIO reports cannot reference one specific entity.';
            END IF;
    END CASE;

    --------------------------------------------------------------------------
    -- Validate MIME type against report format
    --------------------------------------------------------------------------

    IF NEW.mime_type IS NOT NULL THEN
        IF
        (
            NEW.report_format = 'PDF'
            AND NEW.mime_type <> 'application/pdf'
        )
        OR
        (
            NEW.report_format = 'CSV'
            AND NEW.mime_type <> 'text/csv'
        )
        OR
        (
            NEW.report_format = 'XLSX'
            AND NEW.mime_type <>
                'application/vnd.openxmlformats-officedocument.spreadsheetml.sheet'
        ) THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Generated report validation failed: MIME type does not match the selected report format.';
        END IF;
    END IF;

    --------------------------------------------------------------------------
    -- Apply workflow timestamps and fields
    --------------------------------------------------------------------------

    CASE NEW.report_status
        WHEN 'PENDING' THEN
            NEW.processing_started_at := NULL;
            NEW.completed_at := NULL;
            NEW.processed_by := NULL;
            NEW.storage_bucket := NULL;
            NEW.storage_path := NULL;
            NEW.original_file_name := NULL;
            NEW.mime_type := NULL;
            NEW.file_size_bytes := NULL;
            NEW.file_checksum := NULL;
            NEW.error_message := NULL;
            NEW.expires_at := NULL;

        WHEN 'PROCESSING' THEN
            NEW.processing_started_at :=
                COALESCE
                (
                    NEW.processing_started_at,
                    timezone('UTC', now())
                );

            NEW.processed_by :=
                COALESCE
                (
                    NEW.processed_by,
                    auth.uid(),
                    NEW.updated_by
                );

            NEW.completed_at := NULL;
            NEW.storage_bucket := NULL;
            NEW.storage_path := NULL;
            NEW.original_file_name := NULL;
            NEW.mime_type := NULL;
            NEW.file_size_bytes := NULL;
            NEW.file_checksum := NULL;
            NEW.error_message := NULL;
            NEW.expires_at := NULL;

        WHEN 'COMPLETED' THEN
            NEW.processing_started_at :=
                COALESCE
                (
                    NEW.processing_started_at,
                    NEW.requested_at
                );

            NEW.completed_at :=
                COALESCE
                (
                    NEW.completed_at,
                    timezone('UTC', now())
                );

            NEW.processed_by :=
                COALESCE
                (
                    NEW.processed_by,
                    auth.uid(),
                    NEW.updated_by
                );

            NEW.error_message := NULL;

        WHEN 'FAILED' THEN
            NEW.processing_started_at :=
                COALESCE
                (
                    NEW.processing_started_at,
                    NEW.requested_at
                );

            NEW.completed_at :=
                COALESCE
                (
                    NEW.completed_at,
                    timezone('UTC', now())
                );

            NEW.processed_by :=
                COALESCE
                (
                    NEW.processed_by,
                    auth.uid(),
                    NEW.updated_by
                );

            NEW.storage_bucket := NULL;
            NEW.storage_path := NULL;
            NEW.original_file_name := NULL;
            NEW.mime_type := NULL;
            NEW.file_size_bytes := NULL;
            NEW.file_checksum := NULL;
            NEW.expires_at := NULL;

        WHEN 'CANCELLED' THEN
            NEW.completed_at :=
                COALESCE
                (
                    NEW.completed_at,
                    timezone('UTC', now())
                );

            NEW.storage_bucket := NULL;
            NEW.storage_path := NULL;
            NEW.original_file_name := NULL;
            NEW.mime_type := NULL;
            NEW.file_size_bytes := NULL;
            NEW.file_checksum := NULL;
            NEW.expires_at := NULL;
    END CASE;

    --------------------------------------------------------------------------
    -- Soft deletion state
    --------------------------------------------------------------------------

    IF NEW.deleted_at IS NOT NULL THEN
        NEW.is_active := false;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_generated_report() IS
'Validates report scope references, generation workflow, file metadata, MIME types, timestamps, and soft deletion.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_generated_reports_validate
    BEFORE INSERT OR UPDATE OF
        report_name,
        report_scope,
        report_format,
        report_status,
        trial_id,
        evaluation_id,
        season_id,
        crop_id,
        date_from,
        date_to,
        language_code,
        include_photos,
        include_inactive_data,
        generation_parameters,
        storage_bucket,
        storage_path,
        original_file_name,
        mime_type,
        file_size_bytes,
        file_checksum,
        requested_at,
        processing_started_at,
        completed_at,
        expires_at,
        requested_by,
        processed_by,
        error_message,
        is_active,
        deleted_at
    ON public.generated_reports
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_generated_report();

--------------------------------------------------------------------------------
-- WORKFLOW TRANSITION PROTECTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_generated_report_transition()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
BEGIN
    IF NEW.report_status IS NOT DISTINCT FROM OLD.report_status THEN
        RETURN NEW;
    END IF;

    IF NOT
    (
        (OLD.report_status = 'PENDING' AND NEW.report_status IN ('PROCESSING', 'CANCELLED'))
        OR
        (OLD.report_status = 'PROCESSING' AND NEW.report_status IN ('COMPLETED', 'FAILED', 'CANCELLED'))
        OR
        (OLD.report_status = 'FAILED' AND NEW.report_status = 'PENDING')
    ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE = format(
                    'Generated report workflow failed: transition from %s to %s is not allowed.',
                    OLD.report_status,
                    NEW.report_status
                );
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_generated_report_transition() IS
'Enforces valid report-generation workflow transitions.';

CREATE TRIGGER trg_generated_reports_validate_transition
    BEFORE UPDATE OF report_status
    ON public.generated_reports
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_generated_report_transition();

--------------------------------------------------------------------------------
-- COMPLETED REPORT PROTECTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_protect_completed_generated_report()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
BEGIN
    IF OLD.report_status = 'COMPLETED'
       AND
       (
           NEW.report_name IS DISTINCT FROM OLD.report_name
           OR NEW.report_scope IS DISTINCT FROM OLD.report_scope
           OR NEW.report_format IS DISTINCT FROM OLD.report_format
           OR NEW.report_status IS DISTINCT FROM OLD.report_status
           OR NEW.trial_id IS DISTINCT FROM OLD.trial_id
           OR NEW.evaluation_id IS DISTINCT FROM OLD.evaluation_id
           OR NEW.season_id IS DISTINCT FROM OLD.season_id
           OR NEW.crop_id IS DISTINCT FROM OLD.crop_id
           OR NEW.date_from IS DISTINCT FROM OLD.date_from
           OR NEW.date_to IS DISTINCT FROM OLD.date_to
           OR NEW.language_code IS DISTINCT FROM OLD.language_code
           OR NEW.include_photos IS DISTINCT FROM OLD.include_photos
           OR NEW.include_inactive_data IS DISTINCT FROM OLD.include_inactive_data
           OR NEW.generation_parameters IS DISTINCT FROM OLD.generation_parameters
           OR NEW.storage_bucket IS DISTINCT FROM OLD.storage_bucket
           OR NEW.storage_path IS DISTINCT FROM OLD.storage_path
           OR NEW.original_file_name IS DISTINCT FROM OLD.original_file_name
           OR NEW.mime_type IS DISTINCT FROM OLD.mime_type
           OR NEW.file_size_bytes IS DISTINCT FROM OLD.file_size_bytes
           OR NEW.file_checksum IS DISTINCT FROM OLD.file_checksum
           OR NEW.requested_at IS DISTINCT FROM OLD.requested_at
           OR NEW.processing_started_at IS DISTINCT FROM OLD.processing_started_at
           OR NEW.completed_at IS DISTINCT FROM OLD.completed_at
           OR NEW.expires_at IS DISTINCT FROM OLD.expires_at
           OR NEW.requested_by IS DISTINCT FROM OLD.requested_by
           OR NEW.processed_by IS DISTINCT FROM OLD.processed_by
           OR NEW.error_message IS DISTINCT FROM OLD.error_message
       ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Generated report protection failed: completed report metadata is immutable.';
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_protect_completed_generated_report() IS
'Prevents modification of completed report metadata while permitting audit updates and soft deletion.';

CREATE TRIGGER trg_generated_reports_protect_completed
    BEFORE UPDATE
    ON public.generated_reports
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_protect_completed_generated_report();

--------------------------------------------------------------------------------
-- PHYSICAL DELETE PROTECTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_prevent_generated_report_delete()
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
                'Generated report protection failed: reports cannot be physically deleted. Use soft deletion.';

    RETURN OLD;
END;
$$;

COMMENT ON FUNCTION public.trg_prevent_generated_report_delete() IS
'Prevents physical deletion of generated report metadata.';

CREATE TRIGGER trg_generated_reports_prevent_delete
    BEFORE DELETE
    ON public.generated_reports
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_prevent_generated_report_delete();

--------------------------------------------------------------------------------
-- GENERIC AUDIT TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_generated_reports_timestamps
    BEFORE INSERT OR UPDATE
    ON public.generated_reports
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_generated_reports_created_by
    BEFORE INSERT
    ON public.generated_reports
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_generated_reports_updated_by
    BEFORE UPDATE
    ON public.generated_reports
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
    IF to_regclass('public.generated_reports') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0044_generated_reports.sql failed: public.generated_reports was not created.';
    END IF;

    SELECT count(*)
    INTO v_expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'generated_reports'
      AND column_name IN
      (
          'id',
          'report_number',
          'report_name',
          'report_scope',
          'report_format',
          'report_status',
          'trial_id',
          'evaluation_id',
          'season_id',
          'crop_id',
          'date_from',
          'date_to',
          'language_code',
          'include_photos',
          'include_inactive_data',
          'generation_parameters',
          'storage_bucket',
          'storage_path',
          'original_file_name',
          'mime_type',
          'file_size_bytes',
          'file_checksum',
          'requested_at',
          'processing_started_at',
          'completed_at',
          'expires_at',
          'requested_by',
          'processed_by',
          'error_message',
          'is_active',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF v_expected_column_count <> 35 THEN
        RAISE EXCEPTION
            'Migration 0044_generated_reports.sql failed: generated_reports has % of 35 required columns.',
            v_expected_column_count;
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.generated_reports'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0044_generated_reports.sql failed: primary key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.generated_reports'::regclass
          AND conname = 'fk_generated_reports_trial'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0044_generated_reports.sql failed: trial foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.generated_reports'::regclass
          AND conname = 'fk_generated_reports_evaluation'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0044_generated_reports.sql failed: evaluation foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.generated_reports'::regclass
          AND conname = 'fk_generated_reports_season'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0044_generated_reports.sql failed: season foreign key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.generated_reports'::regclass
          AND conname = 'fk_generated_reports_crop'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0044_generated_reports.sql failed: crop foreign key is missing.';
    END IF;

    IF to_regclass(
        'public.uq_generated_reports_storage_object'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0044_generated_reports.sql failed: storage-object unique index is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_validate_generated_report()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0044_generated_reports.sql failed: validation function is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_validate_generated_report_transition()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0044_generated_reports.sql failed: transition-validation function is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_protect_completed_generated_report()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0044_generated_reports.sql failed: completed-report protection function is missing.';
    END IF;

    IF to_regprocedure(
        'public.trg_prevent_generated_report_delete()'
    ) IS NULL THEN
        RAISE EXCEPTION
            'Migration 0044_generated_reports.sql failed: delete-protection function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.generated_reports'::regclass
          AND tgname = 'trg_generated_reports_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0044_generated_reports.sql failed: validation trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.generated_reports'::regclass
          AND tgname = 'trg_generated_reports_validate_transition'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0044_generated_reports.sql failed: transition trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.generated_reports'::regclass
          AND tgname = 'trg_generated_reports_protect_completed'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0044_generated_reports.sql failed: completed-report protection trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.generated_reports'::regclass
          AND tgname = 'trg_generated_reports_prevent_delete'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0044_generated_reports.sql failed: physical-delete protection trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.generated_reports'::regclass
          AND tgname = 'trg_generated_reports_timestamps'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0044_generated_reports.sql failed: timestamp trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.generated_reports'::regclass
          AND tgname = 'trg_generated_reports_created_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0044_generated_reports.sql failed: created_by trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.generated_reports'::regclass
          AND tgname = 'trg_generated_reports_updated_by'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0044_generated_reports.sql failed: updated_by trigger is missing.';
    END IF;
END;
$$;

COMMIT;
