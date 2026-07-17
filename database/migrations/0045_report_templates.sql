/***************************************************************************************************
* Project      : AgriTrial Pro – Enterprise Field Trial Management Platform
* Client       : Agrimatco Morocco
* Database     : PostgreSQL 17 (Supabase)
* Migration    : 0045_report_templates.sql
* Version      : 1.0.0
*
* Description
* -----------------------------------------------------------------------------------------------
* Creates the report_templates table used to configure reusable report layouts,
* content sections, supported formats, branding, and generation behavior.
*
* Business rules:
*
*   • Every template has a unique active code.
*   • Templates are configured for one report scope.
*   • Templates may support PDF, CSV, XLSX, or several formats.
*   • Template configuration is stored as validated JSON objects.
*   • One active default template may exist per report scope and language.
*   • System templates cannot be physically deleted.
*   • Templates already used by generated reports remain historically immutable.
*   • Soft deletion is supported.
*   • RLS will be added later.
*
* Dependencies:
*
*   • 0001_extensions.sql
*   • 0004_functions.sql
*   • 0005_trigger_functions.sql
*   • 0044_generated_reports.sql
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
-- TABLE: report_templates
--------------------------------------------------------------------------------

CREATE TABLE public.report_templates
(
    --------------------------------------------------------------------------
    -- Primary Key
    --------------------------------------------------------------------------

    id                      uuid
                            PRIMARY KEY
                            DEFAULT gen_random_uuid(),

    --------------------------------------------------------------------------
    -- Template Identity
    --------------------------------------------------------------------------

    code                    varchar(100)
                            NOT NULL,

    name                    varchar(250)
                            NOT NULL,

    description             text,

    report_scope            varchar(30)
                            NOT NULL,

    language_code           varchar(10)
                            NOT NULL
                            DEFAULT 'en',

    --------------------------------------------------------------------------
    -- Supported Formats
    --------------------------------------------------------------------------

    supported_formats       text[]
                            NOT NULL
                            DEFAULT ARRAY['PDF']::text[],

    default_format          varchar(10)
                            NOT NULL
                            DEFAULT 'PDF',

    --------------------------------------------------------------------------
    -- Template Configuration
    --------------------------------------------------------------------------

    layout_config           jsonb
                            NOT NULL
                            DEFAULT '{}'::jsonb,

    section_config          jsonb
                            NOT NULL
                            DEFAULT '[]'::jsonb,

    branding_config         jsonb
                            NOT NULL
                            DEFAULT '{}'::jsonb,

    filter_config           jsonb
                            NOT NULL
                            DEFAULT '{}'::jsonb,

    --------------------------------------------------------------------------
    -- Generation Defaults
    --------------------------------------------------------------------------

    include_photos_default  boolean
                            NOT NULL
                            DEFAULT true,

    include_inactive_default boolean
                            NOT NULL
                            DEFAULT false,

    page_orientation        varchar(20)
                            NOT NULL
                            DEFAULT 'PORTRAIT',

    paper_size              varchar(20)
                            NOT NULL
                            DEFAULT 'A4',

    --------------------------------------------------------------------------
    -- Template Control
    --------------------------------------------------------------------------

    version_number          integer
                            NOT NULL
                            DEFAULT 1,

    is_default              boolean
                            NOT NULL
                            DEFAULT false,

    is_system               boolean
                            NOT NULL
                            DEFAULT false,

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

    CONSTRAINT fk_report_templates_created_by
        FOREIGN KEY (created_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    CONSTRAINT fk_report_templates_updated_by
        FOREIGN KEY (updated_by)
        REFERENCES auth.users(id)
        ON UPDATE CASCADE
        ON DELETE SET NULL,

    --------------------------------------------------------------------------
    -- Validation Constraints
    --------------------------------------------------------------------------

    CONSTRAINT chk_report_templates_code
        CHECK
        (
            char_length(btrim(code)) BETWEEN 2 AND 100
            AND code = upper(code)
            AND code ~ '^[A-Z0-9][A-Z0-9_]*$'
        ),

    CONSTRAINT chk_report_templates_name
        CHECK
        (
            char_length(btrim(name)) BETWEEN 1 AND 250
        ),

    CONSTRAINT chk_report_templates_description
        CHECK
        (
            description IS NULL
            OR char_length(btrim(description)) BETWEEN 1 AND 5000
        ),

    CONSTRAINT chk_report_templates_scope
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

    CONSTRAINT chk_report_templates_language
        CHECK
        (
            language_code ~ '^[a-z]{2}(-[A-Z]{2})?$'
        ),

    CONSTRAINT chk_report_templates_supported_formats
        CHECK
        (
            cardinality(supported_formats) > 0
            AND supported_formats <@ ARRAY['PDF', 'CSV', 'XLSX']::text[]
        ),

    CONSTRAINT chk_report_templates_default_format
        CHECK
        (
            default_format IN
            (
                'PDF',
                'CSV',
                'XLSX'
            )
            AND default_format = ANY(supported_formats)
        ),

    CONSTRAINT chk_report_templates_layout_object
        CHECK
        (
            jsonb_typeof(layout_config) = 'object'
        ),

    CONSTRAINT chk_report_templates_sections_array
        CHECK
        (
            jsonb_typeof(section_config) = 'array'
        ),

    CONSTRAINT chk_report_templates_branding_object
        CHECK
        (
            jsonb_typeof(branding_config) = 'object'
        ),

    CONSTRAINT chk_report_templates_filter_object
        CHECK
        (
            jsonb_typeof(filter_config) = 'object'
        ),

    CONSTRAINT chk_report_templates_orientation
        CHECK
        (
            page_orientation IN
            (
                'PORTRAIT',
                'LANDSCAPE'
            )
        ),

    CONSTRAINT chk_report_templates_paper_size
        CHECK
        (
            paper_size IN
            (
                'A4',
                'A3',
                'LETTER',
                'LEGAL'
            )
        ),

    CONSTRAINT chk_report_templates_version
        CHECK
        (
            version_number >= 1
        ),

    CONSTRAINT chk_report_templates_updated_at
        CHECK
        (
            updated_at >= created_at
        ),

    CONSTRAINT chk_report_templates_deleted_at
        CHECK
        (
            deleted_at IS NULL
            OR deleted_at >= created_at
        ),

    CONSTRAINT chk_report_templates_active_deleted
        CHECK
        (
            deleted_at IS NULL
            OR is_active = false
        ),

    CONSTRAINT chk_report_templates_default_state
        CHECK
        (
            is_default = false
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

COMMENT ON TABLE public.report_templates IS
'Reusable report definitions controlling report scope, layout, sections, branding, formats, and generation defaults.';

--------------------------------------------------------------------------------
-- COLUMN COMMENTS
--------------------------------------------------------------------------------

COMMENT ON COLUMN public.report_templates.id IS
'Internal UUID primary key of the report template.';

COMMENT ON COLUMN public.report_templates.code IS
'Stable uppercase business code identifying the report template.';

COMMENT ON COLUMN public.report_templates.name IS
'Human-readable report template name.';

COMMENT ON COLUMN public.report_templates.description IS
'Optional explanation of the report template purpose.';

COMMENT ON COLUMN public.report_templates.report_scope IS
'Report scope supported by the template.';

COMMENT ON COLUMN public.report_templates.language_code IS
'Default language of the report template.';

COMMENT ON COLUMN public.report_templates.supported_formats IS
'Report file formats supported by the template.';

COMMENT ON COLUMN public.report_templates.default_format IS
'Default generated file format for the template.';

COMMENT ON COLUMN public.report_templates.layout_config IS
'JSON object containing layout, margins, headers, footers, and pagination configuration.';

COMMENT ON COLUMN public.report_templates.section_config IS
'Ordered JSON array defining report sections, tables, charts, and visibility rules.';

COMMENT ON COLUMN public.report_templates.branding_config IS
'JSON object containing logos, organization labels, and branding configuration.';

COMMENT ON COLUMN public.report_templates.filter_config IS
'JSON object defining accepted filters and default filtering behavior.';

COMMENT ON COLUMN public.report_templates.include_photos_default IS
'Default value controlling whether trial and evaluation photos are included.';

COMMENT ON COLUMN public.report_templates.include_inactive_default IS
'Default value controlling whether inactive records are included.';

COMMENT ON COLUMN public.report_templates.page_orientation IS
'Default page orientation for printable formats.';

COMMENT ON COLUMN public.report_templates.paper_size IS
'Default paper size for printable formats.';

COMMENT ON COLUMN public.report_templates.version_number IS
'Template version number used for configuration history.';

COMMENT ON COLUMN public.report_templates.is_default IS
'Indicates the default active template for its report scope and language.';

COMMENT ON COLUMN public.report_templates.is_system IS
'Indicates a protected template seeded and maintained by the application.';

COMMENT ON COLUMN public.report_templates.is_active IS
'Indicates whether the template can be selected for new report requests.';

COMMENT ON COLUMN public.report_templates.created_at IS
'UTC timestamp when the template was created.';

COMMENT ON COLUMN public.report_templates.updated_at IS
'UTC timestamp when the template was most recently updated.';

COMMENT ON COLUMN public.report_templates.created_by IS
'Supabase Auth user who created the template.';

COMMENT ON COLUMN public.report_templates.updated_by IS
'Supabase Auth user who most recently updated the template.';

COMMENT ON COLUMN public.report_templates.deleted_at IS
'Soft-deletion timestamp. NULL indicates that the template has not been deleted.';

--------------------------------------------------------------------------------
-- UNIQUE INDEXES
--------------------------------------------------------------------------------

CREATE UNIQUE INDEX uq_report_templates_active_code
    ON public.report_templates (code)
    WHERE deleted_at IS NULL;

CREATE UNIQUE INDEX uq_report_templates_scope_language_default
    ON public.report_templates
    (
        report_scope,
        language_code
    )
    WHERE is_default = true
      AND is_active = true
      AND deleted_at IS NULL;

--------------------------------------------------------------------------------
-- APPLICATION INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_report_templates_scope
    ON public.report_templates
    (
        report_scope,
        language_code,
        name
    )
    WHERE is_active = true
      AND deleted_at IS NULL;

CREATE INDEX idx_report_templates_supported_formats
    ON public.report_templates
    USING gin (supported_formats);

CREATE INDEX idx_report_templates_system
    ON public.report_templates
    (
        is_system,
        report_scope,
        code
    )
    WHERE deleted_at IS NULL;

CREATE INDEX idx_report_templates_version
    ON public.report_templates
    (
        code,
        version_number DESC
    )
    WHERE deleted_at IS NULL;

CREATE INDEX idx_report_templates_deleted_at
    ON public.report_templates (deleted_at)
    WHERE deleted_at IS NOT NULL;

--------------------------------------------------------------------------------
-- AUDIT INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_report_templates_created_by
    ON public.report_templates (created_by)
    WHERE created_by IS NOT NULL;

CREATE INDEX idx_report_templates_updated_by
    ON public.report_templates (updated_by)
    WHERE updated_by IS NOT NULL;

--------------------------------------------------------------------------------
-- JSON AND SEARCH INDEXES
--------------------------------------------------------------------------------

CREATE INDEX idx_report_templates_layout_gin
    ON public.report_templates
    USING gin (layout_config);

CREATE INDEX idx_report_templates_sections_gin
    ON public.report_templates
    USING gin (section_config);

CREATE INDEX idx_report_templates_branding_gin
    ON public.report_templates
    USING gin (branding_config);

CREATE INDEX idx_report_templates_filters_gin
    ON public.report_templates
    USING gin (filter_config);

CREATE INDEX idx_report_templates_name_trgm
    ON public.report_templates
    USING gin
    (
        name gin_trgm_ops
    )
    WHERE deleted_at IS NULL;

CREATE INDEX idx_report_templates_description_trgm
    ON public.report_templates
    USING gin
    (
        description gin_trgm_ops
    )
    WHERE description IS NOT NULL
      AND deleted_at IS NULL;

--------------------------------------------------------------------------------
-- ADD TEMPLATE REFERENCE TO GENERATED REPORTS
--------------------------------------------------------------------------------

ALTER TABLE public.generated_reports
    ADD COLUMN report_template_id uuid;

ALTER TABLE public.generated_reports
    ADD COLUMN report_template_version integer;

ALTER TABLE public.generated_reports
    ADD CONSTRAINT fk_generated_reports_template
        FOREIGN KEY (report_template_id)
        REFERENCES public.report_templates(id)
        ON UPDATE CASCADE
        ON DELETE RESTRICT;

ALTER TABLE public.generated_reports
    ADD CONSTRAINT chk_generated_reports_template_version
        CHECK
        (
            report_template_version IS NULL
            OR report_template_version >= 1
        );

COMMENT ON COLUMN public.generated_reports.report_template_id IS
'Optional report template used to generate the report.';

COMMENT ON COLUMN public.generated_reports.report_template_version IS
'Snapshot of the report template version used during generation.';

CREATE INDEX idx_generated_reports_template_id
    ON public.generated_reports (report_template_id)
    WHERE report_template_id IS NOT NULL;

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION FUNCTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_report_template()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_format             text;
    v_clean_formats      text[] := ARRAY[]::text[];
BEGIN
    --------------------------------------------------------------------------
    -- Normalize identity and text
    --------------------------------------------------------------------------

    NEW.code :=
        upper(NULLIF(btrim(NEW.code), ''));

    NEW.name :=
        NULLIF(btrim(NEW.name), '');

    NEW.description :=
        CASE
            WHEN NEW.description IS NULL THEN NULL
            ELSE NULLIF(btrim(NEW.description), '')
        END;

    NEW.report_scope :=
        upper(NULLIF(btrim(NEW.report_scope), ''));

    NEW.default_format :=
        upper(NULLIF(btrim(NEW.default_format), ''));

    NEW.page_orientation :=
        upper(NULLIF(btrim(NEW.page_orientation), ''));

    NEW.paper_size :=
        upper(NULLIF(btrim(NEW.paper_size), ''));

    NEW.language_code :=
        CASE
            WHEN position('-' IN btrim(NEW.language_code)) > 0 THEN
                lower(split_part(btrim(NEW.language_code), '-', 1))
                || '-'
                || upper(split_part(btrim(NEW.language_code), '-', 2))
            ELSE lower(btrim(NEW.language_code))
        END;

    --------------------------------------------------------------------------
    -- Normalize supported formats
    --------------------------------------------------------------------------

    FOREACH v_format IN ARRAY COALESCE(NEW.supported_formats, ARRAY[]::text[])
    LOOP
        v_format := upper(NULLIF(btrim(v_format), ''));

        IF v_format IS NOT NULL
           AND NOT v_format = ANY(v_clean_formats) THEN
            v_clean_formats := array_append(v_clean_formats, v_format);
        END IF;
    END LOOP;

    NEW.supported_formats := v_clean_formats;

    --------------------------------------------------------------------------
    -- Normalize JSON configuration
    --------------------------------------------------------------------------

    NEW.layout_config :=
        COALESCE(NEW.layout_config, '{}'::jsonb);

    NEW.section_config :=
        COALESCE(NEW.section_config, '[]'::jsonb);

    NEW.branding_config :=
        COALESCE(NEW.branding_config, '{}'::jsonb);

    NEW.filter_config :=
        COALESCE(NEW.filter_config, '{}'::jsonb);

    --------------------------------------------------------------------------
    -- Prevent system-template identity changes
    --------------------------------------------------------------------------

    IF TG_OP = 'UPDATE'
       AND OLD.is_system = true
       AND
       (
           NEW.code IS DISTINCT FROM OLD.code
           OR NEW.report_scope IS DISTINCT FROM OLD.report_scope
           OR NEW.is_system IS DISTINCT FROM OLD.is_system
       ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Report template validation failed: system template identity cannot be changed.';
    END IF;

    --------------------------------------------------------------------------
    -- Protect used template configuration
    --------------------------------------------------------------------------

    IF TG_OP = 'UPDATE'
       AND EXISTS
       (
           SELECT 1
           FROM public.generated_reports gr
           WHERE gr.report_template_id = OLD.id
             AND gr.deleted_at IS NULL
       )
       AND
       (
           NEW.code IS DISTINCT FROM OLD.code
           OR NEW.report_scope IS DISTINCT FROM OLD.report_scope
           OR NEW.language_code IS DISTINCT FROM OLD.language_code
           OR NEW.supported_formats IS DISTINCT FROM OLD.supported_formats
           OR NEW.layout_config IS DISTINCT FROM OLD.layout_config
           OR NEW.section_config IS DISTINCT FROM OLD.section_config
           OR NEW.branding_config IS DISTINCT FROM OLD.branding_config
           OR NEW.filter_config IS DISTINCT FROM OLD.filter_config
           OR NEW.page_orientation IS DISTINCT FROM OLD.page_orientation
           OR NEW.paper_size IS DISTINCT FROM OLD.paper_size
       ) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Report template validation failed: templates already used by generated reports cannot have their generation configuration changed. Create a new version instead.';
    END IF;

    --------------------------------------------------------------------------
    -- Version progression
    --------------------------------------------------------------------------

    IF TG_OP = 'UPDATE'
       AND NEW.version_number < OLD.version_number THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Report template validation failed: version number cannot be decreased.';
    END IF;

    --------------------------------------------------------------------------
    -- Soft deletion state
    --------------------------------------------------------------------------

    IF NEW.deleted_at IS NOT NULL THEN
        IF NEW.is_system = true THEN
            RAISE EXCEPTION
                USING
                    ERRCODE = '23514',
                    MESSAGE =
                        'Report template validation failed: system templates cannot be soft-deleted.';
        END IF;

        NEW.is_active := false;
        NEW.is_default := false;
    END IF;

    IF NEW.is_active = false THEN
        NEW.is_default := false;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_report_template() IS
'Normalizes and validates report templates, protects system templates, and prevents changes to configurations already used by reports.';

--------------------------------------------------------------------------------
-- BUSINESS VALIDATION TRIGGER
--------------------------------------------------------------------------------

CREATE TRIGGER trg_report_templates_validate
    BEFORE INSERT OR UPDATE OF
        code,
        name,
        description,
        report_scope,
        language_code,
        supported_formats,
        default_format,
        layout_config,
        section_config,
        branding_config,
        filter_config,
        include_photos_default,
        include_inactive_default,
        page_orientation,
        paper_size,
        version_number,
        is_default,
        is_system,
        is_active,
        deleted_at
    ON public.report_templates
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_report_template();

--------------------------------------------------------------------------------
-- MAINTAIN ONE DEFAULT TEMPLATE
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_set_default_report_template()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
BEGIN
    IF NEW.is_default = true
       AND NEW.is_active = true
       AND NEW.deleted_at IS NULL THEN

        UPDATE public.report_templates
        SET
            is_default = false,
            updated_at = timezone('UTC', now()),
            updated_by = COALESCE(
                auth.uid(),
                NEW.updated_by,
                NEW.created_by
            )
        WHERE report_scope = NEW.report_scope
          AND language_code = NEW.language_code
          AND id <> NEW.id
          AND is_default = true
          AND deleted_at IS NULL;
    END IF;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_set_default_report_template() IS
'Ensures that only one active default report template exists per scope and language.';

CREATE TRIGGER trg_report_templates_set_default
    BEFORE INSERT OR UPDATE OF
        is_default,
        report_scope,
        language_code
    ON public.report_templates
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_default_report_template();

--------------------------------------------------------------------------------
-- GENERATED REPORT TEMPLATE VALIDATION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_validate_generated_report_template()
RETURNS trigger
LANGUAGE plpgsql
SECURITY INVOKER
SET search_path = public
AS
$$
DECLARE
    v_template_scope       text;
    v_template_language    text;
    v_template_formats     text[];
    v_template_version     integer;
    v_template_active      boolean;
    v_template_deleted_at  timestamptz;
BEGIN
    IF NEW.report_template_id IS NULL THEN
        NEW.report_template_version := NULL;
        RETURN NEW;
    END IF;

    SELECT
        rt.report_scope,
        rt.language_code,
        rt.supported_formats,
        rt.version_number,
        rt.is_active,
        rt.deleted_at
    INTO
        v_template_scope,
        v_template_language,
        v_template_formats,
        v_template_version,
        v_template_active,
        v_template_deleted_at
    FROM public.report_templates rt
    WHERE rt.id = NEW.report_template_id;

    IF NOT FOUND THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23503',
                MESSAGE =
                    'Generated report validation failed: selected report template does not exist.';
    END IF;

    IF v_template_active = false
       OR v_template_deleted_at IS NOT NULL THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Generated report validation failed: selected report template is unavailable.';
    END IF;

    IF v_template_scope IS DISTINCT FROM NEW.report_scope THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Generated report validation failed: report template scope does not match the report scope.';
    END IF;

    IF NOT NEW.report_format = ANY(v_template_formats) THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Generated report validation failed: selected report format is not supported by the template.';
    END IF;

    IF v_template_language IS DISTINCT FROM NEW.language_code THEN
        RAISE EXCEPTION
            USING
                ERRCODE = '23514',
                MESSAGE =
                    'Generated report validation failed: report language does not match the selected template language.';
    END IF;

    NEW.report_template_version := v_template_version;

    RETURN NEW;
END;
$$;

COMMENT ON FUNCTION public.trg_validate_generated_report_template() IS
'Validates selected report-template scope, language, supported format, availability, and version snapshot.';

CREATE TRIGGER trg_generated_reports_validate_template
    BEFORE INSERT OR UPDATE OF
        report_template_id,
        report_scope,
        report_format,
        language_code
    ON public.generated_reports
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_validate_generated_report_template();

--------------------------------------------------------------------------------
-- PHYSICAL DELETE PROTECTION
--------------------------------------------------------------------------------

CREATE OR REPLACE FUNCTION public.trg_prevent_report_template_delete()
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
                'Report template protection failed: templates cannot be physically deleted. Use soft deletion.';

    RETURN OLD;
END;
$$;

COMMENT ON FUNCTION public.trg_prevent_report_template_delete() IS
'Prevents physical deletion of report templates.';

CREATE TRIGGER trg_report_templates_prevent_delete
    BEFORE DELETE
    ON public.report_templates
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_prevent_report_template_delete();

--------------------------------------------------------------------------------
-- GENERIC AUDIT TRIGGERS
--------------------------------------------------------------------------------

CREATE TRIGGER trg_report_templates_timestamps
    BEFORE INSERT OR UPDATE
    ON public.report_templates
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_timestamps();

CREATE TRIGGER trg_report_templates_created_by
    BEFORE INSERT
    ON public.report_templates
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_created_by();

CREATE TRIGGER trg_report_templates_updated_by
    BEFORE UPDATE
    ON public.report_templates
    FOR EACH ROW
    EXECUTE FUNCTION public.trg_set_updated_by();

--------------------------------------------------------------------------------
-- SEED SYSTEM REPORT TEMPLATES
--------------------------------------------------------------------------------

INSERT INTO public.report_templates
(
    code,
    name,
    description,
    report_scope,
    language_code,
    supported_formats,
    default_format,
    layout_config,
    section_config,
    branding_config,
    filter_config,
    include_photos_default,
    include_inactive_default,
    page_orientation,
    paper_size,
    version_number,
    is_default,
    is_system,
    is_active
)
VALUES
(
    'TRIAL_STANDARD_EN',
    'Standard Trial Report',
    'Default English report template containing trial identity, location, varieties, evaluations, photos, and final decision.',
    'TRIAL',
    'en',
    ARRAY['PDF', 'XLSX']::text[],
    'PDF',
    jsonb_build_object(
        'show_header', true,
        'show_footer', true,
        'show_page_numbers', true
    ),
    jsonb_build_array(
        jsonb_build_object('code', 'TRIAL_IDENTITY', 'enabled', true, 'display_order', 10),
        jsonb_build_object('code', 'LOCATION', 'enabled', true, 'display_order', 20),
        jsonb_build_object('code', 'VARIETIES', 'enabled', true, 'display_order', 30),
        jsonb_build_object('code', 'EVALUATIONS', 'enabled', true, 'display_order', 40),
        jsonb_build_object('code', 'PHOTOS', 'enabled', true, 'display_order', 50),
        jsonb_build_object('code', 'DECISION', 'enabled', true, 'display_order', 60)
    ),
    jsonb_build_object(
        'organization_name', 'Agrimatco Morocco',
        'show_logo', true
    ),
    '{}'::jsonb,
    true,
    false,
    'PORTRAIT',
    'A4',
    1,
    true,
    true,
    true
),
(
    'EVALUATION_STANDARD_EN',
    'Standard Evaluation Report',
    'Default English report template containing evaluation metadata, criterion results, photos, recommendation, and decision.',
    'EVALUATION',
    'en',
    ARRAY['PDF', 'XLSX']::text[],
    'PDF',
    jsonb_build_object(
        'show_header', true,
        'show_footer', true,
        'show_page_numbers', true
    ),
    jsonb_build_array(
        jsonb_build_object('code', 'EVALUATION_IDENTITY', 'enabled', true, 'display_order', 10),
        jsonb_build_object('code', 'PLANT_CRITERIA', 'enabled', true, 'display_order', 20),
        jsonb_build_object('code', 'FRUIT_CRITERIA', 'enabled', true, 'display_order', 30),
        jsonb_build_object('code', 'PHOTOS', 'enabled', true, 'display_order', 40),
        jsonb_build_object('code', 'RECOMMENDATION', 'enabled', true, 'display_order', 50),
        jsonb_build_object('code', 'DECISION', 'enabled', true, 'display_order', 60)
    ),
    jsonb_build_object(
        'organization_name', 'Agrimatco Morocco',
        'show_logo', true
    ),
    '{}'::jsonb,
    true,
    false,
    'PORTRAIT',
    'A4',
    1,
    true,
    true,
    true
),
(
    'PORTFOLIO_STANDARD_EN',
    'Standard Portfolio Report',
    'Default English management report covering trial performance, crops, varieties, statuses, recommendations, and portfolio indicators.',
    'PORTFOLIO',
    'en',
    ARRAY['PDF', 'CSV', 'XLSX']::text[],
    'PDF',
    jsonb_build_object(
        'show_header', true,
        'show_footer', true,
        'show_page_numbers', true
    ),
    jsonb_build_array(
        jsonb_build_object('code', 'EXECUTIVE_SUMMARY', 'enabled', true, 'display_order', 10),
        jsonb_build_object('code', 'STATUS_OVERVIEW', 'enabled', true, 'display_order', 20),
        jsonb_build_object('code', 'CROP_ANALYTICS', 'enabled', true, 'display_order', 30),
        jsonb_build_object('code', 'TRIAL_PERFORMANCE', 'enabled', true, 'display_order', 40),
        jsonb_build_object('code', 'RECOMMENDATIONS', 'enabled', true, 'display_order', 50)
    ),
    jsonb_build_object(
        'organization_name', 'Agrimatco Morocco',
        'show_logo', true
    ),
    '{}'::jsonb,
    false,
    false,
    'LANDSCAPE',
    'A4',
    1,
    true,
    true,
    true
);

--------------------------------------------------------------------------------
-- MIGRATION VALIDATION
--------------------------------------------------------------------------------

DO
$$
DECLARE
    v_expected_column_count integer;
BEGIN
    IF to_regclass('public.report_templates') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0045_report_templates.sql failed: public.report_templates was not created.';
    END IF;

    SELECT count(*)
    INTO v_expected_column_count
    FROM information_schema.columns
    WHERE table_schema = 'public'
      AND table_name = 'report_templates'
      AND column_name IN
      (
          'id',
          'code',
          'name',
          'description',
          'report_scope',
          'language_code',
          'supported_formats',
          'default_format',
          'layout_config',
          'section_config',
          'branding_config',
          'filter_config',
          'include_photos_default',
          'include_inactive_default',
          'page_orientation',
          'paper_size',
          'version_number',
          'is_default',
          'is_system',
          'is_active',
          'created_at',
          'updated_at',
          'created_by',
          'updated_by',
          'deleted_at'
      );

    IF v_expected_column_count <> 25 THEN
        RAISE EXCEPTION
            'Migration 0045_report_templates.sql failed: report_templates has % of 25 required columns.',
            v_expected_column_count;
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.report_templates'::regclass
          AND contype = 'p'
    ) THEN
        RAISE EXCEPTION
            'Migration 0045_report_templates.sql failed: primary key is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM information_schema.columns
        WHERE table_schema = 'public'
          AND table_name = 'generated_reports'
          AND column_name = 'report_template_id'
    ) THEN
        RAISE EXCEPTION
            'Migration 0045_report_templates.sql failed: generated_reports.report_template_id is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_constraint
        WHERE conrelid = 'public.generated_reports'::regclass
          AND conname = 'fk_generated_reports_template'
          AND contype = 'f'
    ) THEN
        RAISE EXCEPTION
            'Migration 0045_report_templates.sql failed: generated report template foreign key is missing.';
    END IF;

    IF to_regclass('public.uq_report_templates_active_code') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0045_report_templates.sql failed: active-code unique index is missing.';
    END IF;

    IF to_regclass('public.uq_report_templates_scope_language_default') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0045_report_templates.sql failed: default-template unique index is missing.';
    END IF;

    IF to_regprocedure('public.trg_validate_report_template()') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0045_report_templates.sql failed: validation function is missing.';
    END IF;

    IF to_regprocedure('public.trg_set_default_report_template()') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0045_report_templates.sql failed: default-template function is missing.';
    END IF;

    IF to_regprocedure('public.trg_validate_generated_report_template()') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0045_report_templates.sql failed: generated-report template validation function is missing.';
    END IF;

    IF to_regprocedure('public.trg_prevent_report_template_delete()') IS NULL THEN
        RAISE EXCEPTION
            'Migration 0045_report_templates.sql failed: delete-protection function is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.report_templates'::regclass
          AND tgname = 'trg_report_templates_validate'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0045_report_templates.sql failed: validation trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.report_templates'::regclass
          AND tgname = 'trg_report_templates_set_default'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0045_report_templates.sql failed: default-template trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.generated_reports'::regclass
          AND tgname = 'trg_generated_reports_validate_template'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0045_report_templates.sql failed: generated-report template trigger is missing.';
    END IF;

    IF NOT EXISTS
    (
        SELECT 1
        FROM pg_trigger
        WHERE tgrelid = 'public.report_templates'::regclass
          AND tgname = 'trg_report_templates_prevent_delete'
          AND NOT tgisinternal
    ) THEN
        RAISE EXCEPTION
            'Migration 0045_report_templates.sql failed: delete-protection trigger is missing.';
    END IF;

    IF
    (
        SELECT count(*)
        FROM public.report_templates
        WHERE is_system = true
          AND deleted_at IS NULL
    ) < 3 THEN
        RAISE EXCEPTION
            'Migration 0045_report_templates.sql failed: required system report templates were not seeded.';
    END IF;
END;
$$;

COMMIT;
