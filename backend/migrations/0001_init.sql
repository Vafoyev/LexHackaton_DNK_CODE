-- LexGuard AI 3.0 — Modular Monolith Database Schema
-- 19 Tables conforming to D-01..D-09 Architecture Decisions

CREATE EXTENSION IF NOT EXISTS "uuid-ossp";
CREATE EXTENSION IF NOT EXISTS "vector";

-- 1. Organizations (Multi-tenant isolation)
CREATE TABLE IF NOT EXISTS organizations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(255) NOT NULL,
    inn VARCHAR(32) NOT NULL,
    slug VARCHAR(64) UNIQUE NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 2. Users
CREATE TABLE IF NOT EXISTS users (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    email VARCHAR(255) UNIQUE NOT NULL,
    phone VARCHAR(32),
    password_hash VARCHAR(255) NOT NULL,
    full_name VARCHAR(255) NOT NULL,
    jshshir VARCHAR(14),
    is_active BOOLEAN NOT NULL DEFAULT TRUE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 3. Memberships (RBAC & Authority Verification)
CREATE TABLE IF NOT EXISTS memberships (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    role VARCHAR(32) NOT NULL DEFAULT 'member', -- owner, admin, lawyer_reviewer, member, viewer, platform_admin
    authority_verified BOOLEAN NOT NULL DEFAULT FALSE,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    UNIQUE(organization_id, user_id)
);

-- 4. Sessions (Rotating Refresh Tokens)
CREATE TABLE IF NOT EXISTS sessions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    refresh_token_hash VARCHAR(64) UNIQUE NOT NULL,
    client_type VARCHAR(16) NOT NULL DEFAULT 'web', -- web, mobile, admin
    user_agent VARCHAR(512),
    ip_address VARCHAR(45),
    expires_at TIMESTAMPTZ NOT NULL,
    revoked_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 5. Consents (O'RQ-547 & O'RQ-1125 Compliance)
CREATE TABLE IF NOT EXISTS consents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE CASCADE,
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    consent_type VARCHAR(64) NOT NULL, -- DATA_PROCESSING, EXTERNAL_AI, E_SIGNATURE
    version VARCHAR(16) NOT NULL DEFAULT '1.0',
    granted BOOLEAN NOT NULL DEFAULT TRUE,
    ip_address VARCHAR(45),
    granted_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 6. Documents (Sha256, Magic-Byte MIME, Data Classification)
CREATE TABLE IF NOT EXISTS documents (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    user_id UUID NOT NULL REFERENCES users(id) ON DELETE SET NULL,
    filename VARCHAR(255) NOT NULL,
    file_size BIGINT NOT NULL,
    mime_type VARCHAR(128) NOT NULL,
    sha256 VARCHAR(64) NOT NULL,
    storage_path VARCHAR(512) NOT NULL,
    data_classification VARCHAR(32) NOT NULL DEFAULT 'INTERNAL', -- PUBLIC, INTERNAL, CONFIDENTIAL, RESTRICTED
    parse_confidence NUMERIC(4,3) NOT NULL DEFAULT 1.0,
    deleted_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 7. Document Versions
CREATE TABLE IF NOT EXISTS document_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    version_number INT NOT NULL DEFAULT 1,
    sha256 VARCHAR(64) NOT NULL,
    storage_path VARCHAR(512) NOT NULL,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 8. Clauses (Granular chunking with PII redaction)
CREATE TABLE IF NOT EXISTS clauses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    clause_number VARCHAR(32) NOT NULL,
    title VARCHAR(255),
    raw_text TEXT NOT NULL,
    redacted_text TEXT NOT NULL,
    pii_entities_json JSONB NOT NULL DEFAULT '[]'::jsonb,
    start_offset INT NOT NULL DEFAULT 0,
    end_offset INT NOT NULL DEFAULT 0,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 9. Legal Sources (Normative baseline: FK, O'RQ-547, O'RQ-1115, etc.)
CREATE TABLE IF NOT EXISTS legal_sources (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    code VARCHAR(64) UNIQUE NOT NULL, -- FK-UZ, ORQ-547, ORQ-1115, ORQ-1125, ORQ-793
    title VARCHAR(512) NOT NULL,
    short_name VARCHAR(128) NOT NULL,
    source_type VARCHAR(64) NOT NULL DEFAULT 'LAW', -- CODE, LAW, RESOLUTION
    jurisdiction VARCHAR(8) NOT NULL DEFAULT 'UZ',
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 10. Legal Source Versions (Temporal RAG + pgvector + GIN tsvector)
CREATE TABLE IF NOT EXISTS legal_source_versions (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    source_id UUID NOT NULL REFERENCES legal_sources(id) ON DELETE CASCADE,
    article_number VARCHAR(32) NOT NULL, -- e.g. "707-modda"
    part_number VARCHAR(32),
    paragraph_number VARCHAR(32),
    title VARCHAR(512) NOT NULL,
    full_text TEXT NOT NULL,
    norm_nature VARCHAR(16) NOT NULL DEFAULT 'IMPERATIVE', -- IMPERATIVE, DISPOSITIVE
    applicable_doc_types TEXT[] NOT NULL DEFAULT ARRAY['SERVICE_AGREEMENT']::TEXT[],
    effective_from DATE NOT NULL,
    effective_to DATE,
    official_url VARCHAR(512) NOT NULL,
    text_sha256 VARCHAR(64) NOT NULL,
    embedding vector(768),
    tsv tsvector,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 11. Analyses (Central Analysis Entity)
CREATE TABLE IF NOT EXISTS analyses (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING', -- PENDING, IN_PROGRESS, COMPLETED, FAILED
    execution_mode VARCHAR(32) NOT NULL DEFAULT 'HYBRID_AI', -- RULE_ONLY, HYBRID_AI
    doc_type VARCHAR(64) NOT NULL DEFAULT 'SERVICE_AGREEMENT',
    contract_date DATE NOT NULL DEFAULT CURRENT_DATE,
    disclaimer TEXT NOT NULL DEFAULT 'Axborot-tahliliy xulosa. Rasmiy yuridik maslahat emas (O''RQ-1115).',
    overall_risk_score INT NOT NULL DEFAULT 0,
    risk_level VARCHAR(16) NOT NULL DEFAULT 'GREEN', -- GREEN, YELLOW, RED
    summary_json JSONB NOT NULL DEFAULT '{"red_legal":0,"yellow_commercial":0,"green_ok":0,"review_required":0,"pii_masked":0}'::jsonb,
    cost_metrics_json JSONB NOT NULL DEFAULT '{"tokens_used":0,"duration_ms":0}'::jsonb,
    completed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 12. Analysis Jobs (FOR UPDATE SKIP LOCKED queue)
CREATE TABLE IF NOT EXISTS analysis_jobs (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    analysis_id UUID NOT NULL REFERENCES analyses(id) ON DELETE CASCADE,
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING', -- PENDING, IN_PROGRESS, COMPLETED, FAILED, DEAD_LETTER
    attempts INT NOT NULL DEFAULT 0,
    max_attempts INT NOT NULL DEFAULT 3,
    worker_id VARCHAR(64),
    lease_until TIMESTAMPTZ,
    error_message TEXT,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 13. Findings (Anti-Hallucination verification results)
CREATE TABLE IF NOT EXISTS findings (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    analysis_id UUID NOT NULL REFERENCES analyses(id) ON DELETE CASCADE,
    clause_id UUID REFERENCES clauses(id) ON DELETE SET NULL,
    clause_number VARCHAR(32) NOT NULL,
    rule_code VARCHAR(64) NOT NULL,
    risk_category VARCHAR(32) NOT NULL DEFAULT 'LEGAL', -- LEGAL, COMMERCIAL, FORM
    severity VARCHAR(16) NOT NULL DEFAULT 'RED', -- RED, YELLOW, GREEN
    verification_status VARCHAR(32) NOT NULL DEFAULT 'VERIFIED', -- VERIFIED, REVIEW_REQUIRED, UNVERIFIED, UNKNOWN, FAILED
    original_quote TEXT NOT NULL,
    suggested_revision TEXT NOT NULL,
    legal_source_version_id UUID REFERENCES legal_source_versions(id) ON DELETE SET NULL,
    score NUMERIC(4,3) NOT NULL DEFAULT 1.0,
    explanation TEXT NOT NULL,
    client_decision VARCHAR(32) NOT NULL DEFAULT 'NONE', -- NONE, ACCEPTED, DISMISSED
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 14. Approvals (Human-in-the-loop Lawyer Review Queue)
CREATE TABLE IF NOT EXISTS approvals (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    analysis_id UUID NOT NULL REFERENCES analyses(id) ON DELETE CASCADE,
    finding_id UUID NOT NULL REFERENCES findings(id) ON DELETE CASCADE,
    reviewer_id UUID REFERENCES users(id) ON DELETE SET NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING', -- PENDING, APPROVED, REJECTED
    comments TEXT,
    reviewed_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 15. Integrations (Registry for Mock / Sandbox / Prod state)
CREATE TABLE IF NOT EXISTS integrations (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    name VARCHAR(64) UNIQUE NOT NULL, -- oneid, e-imzo, lex.uz, llm_provider
    mode VARCHAR(16) NOT NULL DEFAULT 'MOCK', -- MOCK, SANDBOX, PROD
    is_healthy BOOLEAN NOT NULL DEFAULT TRUE,
    last_checked_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    config_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 16. Signatures (O'RQ-793 E-IMZO / ERI challenge and verify records)
CREATE TABLE IF NOT EXISTS signatures (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    document_id UUID NOT NULL REFERENCES documents(id) ON DELETE CASCADE,
    user_id UUID REFERENCES users(id) ON DELETE SET NULL,
    doc_sha256 VARCHAR(64) NOT NULL,
    signature_hex TEXT NOT NULL,
    cert_serial VARCHAR(128) NOT NULL,
    signer_inn VARCHAR(32) NOT NULL,
    signer_name VARCHAR(255) NOT NULL,
    revocation_checked BOOLEAN NOT NULL DEFAULT TRUE,
    authority_verified BOOLEAN NOT NULL DEFAULT TRUE,
    verified_at TIMESTAMPTZ NOT NULL DEFAULT NOW(),
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 17. Quotas (B2B SaaS Atomic quota metering)
CREATE TABLE IF NOT EXISTS quotas (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID UNIQUE NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    plan_name VARCHAR(32) NOT NULL DEFAULT 'STARTER', -- FREE, STARTER, PRO, ENTERPRISE
    analyses_limit INT NOT NULL DEFAULT 50,
    analyses_used INT NOT NULL DEFAULT 0,
    tokens_limit INT NOT NULL DEFAULT 500000,
    tokens_used INT NOT NULL DEFAULT 0,
    period_start DATE NOT NULL DEFAULT CURRENT_DATE,
    period_end DATE NOT NULL DEFAULT (CURRENT_DATE + INTERVAL '30 days'),
    updated_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 18. Invoices
CREATE TABLE IF NOT EXISTS invoices (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID NOT NULL REFERENCES organizations(id) ON DELETE CASCADE,
    amount_uzs NUMERIC(14,2) NOT NULL,
    plan_name VARCHAR(32) NOT NULL,
    status VARCHAR(32) NOT NULL DEFAULT 'PENDING', -- PENDING, PAID, CANCELLED
    payment_provider VARCHAR(32) NOT NULL DEFAULT 'PAYME', -- PAYME, CLICK, UZUM, INVOICE
    transaction_id VARCHAR(128),
    paid_at TIMESTAMPTZ,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- 19. Audit Events (Append-Only Immutable Audit Log - PII free)
CREATE TABLE IF NOT EXISTS audit_events (
    id UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    organization_id UUID,
    user_id UUID,
    event_type VARCHAR(64) NOT NULL,
    resource_type VARCHAR(64) NOT NULL,
    resource_id UUID,
    ip_address VARCHAR(45),
    user_agent VARCHAR(512),
    metadata_json JSONB NOT NULL DEFAULT '{}'::jsonb,
    created_at TIMESTAMPTZ NOT NULL DEFAULT NOW()
);

-- Immutable Trigger for audit_events (Prevent UPDATE and DELETE)
CREATE OR REPLACE FUNCTION trg_audit_events_immutable()
RETURNS TRIGGER AS $$
BEGIN
    RAISE EXCEPTION 'Security Policy Violation: audit_events table is append-only. Modification and deletion prohibited.';
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS trg_audit_events_immutable_guard ON audit_events;
CREATE TRIGGER trg_audit_events_immutable_guard
BEFORE UPDATE OR DELETE ON audit_events
FOR EACH ROW EXECUTE FUNCTION trg_audit_events_immutable();

-- Indexes for High Performance & Tenant Guard
CREATE INDEX IF NOT EXISTS idx_users_email ON users(email);
CREATE INDEX IF NOT EXISTS idx_memberships_org_user ON memberships(organization_id, user_id);
CREATE INDEX IF NOT EXISTS idx_sessions_refresh_hash ON sessions(refresh_token_hash);
CREATE INDEX IF NOT EXISTS idx_documents_org_id ON documents(organization_id) WHERE deleted_at IS NULL;
CREATE INDEX IF NOT EXISTS idx_clauses_document_id ON clauses(document_id);
CREATE INDEX IF NOT EXISTS idx_analyses_org_status ON analyses(organization_id, status);
CREATE INDEX IF NOT EXISTS idx_analysis_jobs_queue ON analysis_jobs(status, lease_until) WHERE status IN ('PENDING', 'IN_PROGRESS');
CREATE INDEX IF NOT EXISTS idx_findings_analysis_id ON findings(analysis_id);
CREATE INDEX IF NOT EXISTS idx_audit_org_created ON audit_events(organization_id, created_at DESC);

-- Temporal RAG Indexes (Full Text Search GIN + Temporal dates)
CREATE INDEX IF NOT EXISTS idx_lsv_temporal ON legal_source_versions(effective_from, effective_to);
CREATE INDEX IF NOT EXISTS idx_lsv_tsv ON legal_source_versions USING gin(tsv);
-- Vector Cosine Similarity HNSW index
CREATE INDEX IF NOT EXISTS idx_lsv_embedding_hnsw ON legal_source_versions USING hnsw (embedding vector_cosine_ops);
