import { AnalysisResult, ClauseCategory, ContractClause, Finding, RiskLevel, VerificationStatus } from '../types/contract';

/** Backend `GET /analyses/{id}` javobi (kerakli maydonlar) */
export interface BackendFinding {
  id: string;
  clause_number: string;
  rule_code?: string;
  rule_id?: string;
  severity?: string;
  risk_level?: string;
  verification_status?: string;
  original_quote?: string;
  problematic_quote?: string;
  suggested_redline?: string;
  suggested_revision?: string;
  issue_title?: string;
  issue_explanation?: string;
  explanation?: string;
  legal_basis?: { code?: string; article?: string; norm_nature?: string; official_url?: string; explanation?: string } | null;
  legal_source?: { code?: string; article?: string; norm_nature?: string; official_url?: string; explanation?: string } | null;
  temporal_note?: string;
}

export interface BackendAnalysis {
  id: string;
  document?: { id?: string; filename?: string; sha256?: string; contract_date?: string; document_type?: string };
  filename?: string;
  sha256?: string;
  contract_date?: string;
  doc_type?: string;
  disclaimer?: string;
  overall_risk_score?: number;
  total_clauses?: number;
  summary?: {
    total_clauses?: number;
    red_count?: number;
    yellow_count?: number;
    green_count?: number;
    gray_count?: number;
    balance_label?: string;
    top_risks?: string[];
  };
  findings?: BackendFinding[];
  created_at?: string;
}

export interface BackendClause {
  id: string;
  clause_number: string;
  title?: string;
  raw_text?: string;
}

const RISK_ORDER: Record<RiskLevel, number> = { RED: 3, YELLOW: 2, GRAY: 1, GREEN: 0 };

const asRisk = (v?: string): RiskLevel => (v === 'RED' || v === 'YELLOW' || v === 'GRAY' ? v : 'GREEN');

const asStatus = (v?: string): VerificationStatus => {
  switch (v) {
    case 'VERIFIED':
    case 'REVIEW_REQUIRED':
    case 'UNVERIFIED':
    case 'UNKNOWN':
    case 'REJECTED':
      return v;
    case 'FAILED':
      return 'REJECTED';
    default:
      return 'UNKNOWN';
  }
};

const categoryOf = (risk: RiskLevel): ClauseCategory => (risk === 'RED' ? 'LEGAL' : risk === 'YELLOW' ? 'COMMERCIAL' : 'BALANCED');

/** Backend tahlil natijasi va hujjat bandlarini frontend `AnalysisResult` modeliga aylantiradi. */
export function mapAnalysis(detail: BackendAnalysis, clauses: BackendClause[]): AnalysisResult {
  const byNumber = new Map<string, BackendClause>();
  clauses.forEach((c) => byNumber.set(c.clause_number, c));

  const findings: Finding[] = (detail.findings ?? []).map((f) => {
    const risk = asRisk(f.risk_level || f.severity);
    const basis = f.legal_basis || f.legal_source || {};
    const clause = byNumber.get(f.clause_number);
    return {
      id: f.id,
      clause_id: clause?.id ?? f.clause_number,
      clause_number: f.clause_number,
      original_quote: f.original_quote || f.problematic_quote || clause?.raw_text || '',
      risk_level: risk,
      category: categoryOf(risk),
      verification_status: asStatus(f.verification_status),
      rule_id: f.rule_id || f.rule_code || '',
      issue_title: f.issue_title || 'Xavfli band',
      issue_explanation: f.issue_explanation || f.explanation || '',
      legal_basis: {
        source_title: basis.code || '',
        article: basis.article || '',
        lex_uz_url: basis.official_url || '',
        norm_nature: basis.norm_nature === 'DISPOSITIVE' ? 'DISPOSITIVE' : 'IMPERATIVE',
      },
      suggested_redline: f.suggested_redline || f.suggested_revision || '',
      redline_reasoning: basis.explanation || f.temporal_note || '',
    };
  });

  // Har bir bandning xavf darajasi — uning eng og'ir topilmasi
  const worst = new Map<string, Finding>();
  findings.forEach((f) => {
    const prev = worst.get(f.clause_number);
    if (!prev || RISK_ORDER[f.risk_level] > RISK_ORDER[prev.risk_level]) worst.set(f.clause_number, f);
  });

  const mapped: ContractClause[] = clauses.map((c) => {
    const f = worst.get(c.clause_number);
    return {
      id: c.id,
      clause_number: c.clause_number,
      title: c.title || `${c.clause_number}-band`,
      original_text: c.raw_text || '',
      finding: f,
      risk_level: f ? f.risk_level : 'GREEN',
    };
  });

  const count = (lvl: RiskLevel) => mapped.filter((c) => c.risk_level === lvl).length;
  const s = detail.summary ?? {};
  const red = count('RED');
  const yellow = count('YELLOW');
  const doc = detail.document ?? {};

  return {
    id: detail.id,
    document: {
      id: doc.id || detail.id,
      filename: doc.filename || detail.filename || 'shartnoma',
      sha256: doc.sha256 || detail.sha256 || '',
      contract_date: doc.contract_date || detail.contract_date || '',
      document_type: doc.document_type || detail.doc_type || '',
    },
    summary: {
      total_clauses: mapped.length || s.total_clauses || detail.total_clauses || 0,
      red_count: red,
      yellow_count: yellow,
      green_count: count('GREEN'),
      gray_count: count('GRAY'),
      balance_label: s.balance_label || '',
      top_risks: s.top_risks ?? [],
      risk_score: detail.overall_risk_score ?? 0,
    },
    findings,
    clauses: mapped,
    disclaimer: detail.disclaimer || '',
    created_at: detail.created_at,
  };
}
