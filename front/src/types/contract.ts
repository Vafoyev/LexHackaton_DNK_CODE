export type RiskLevel = 'RED' | 'YELLOW' | 'GREEN' | 'GRAY';

export type ClauseCategory = 'LEGAL' | 'COMMERCIAL' | 'BALANCED' | 'UNKNOWN';

export type VerificationStatus = 'VERIFIED' | 'REVIEW_REQUIRED' | 'UNVERIFIED' | 'UNKNOWN' | 'REJECTED';

export type NormNature = 'IMPERATIVE' | 'DISPOSITIVE';

export interface LegalBasis {
  source_title: string;
  article: string;
  lex_uz_url: string;
  norm_nature: NormNature;
  effective_from?: string;
}

export interface Finding {
  id: string;
  clause_id: string;
  clause_number: string;
  original_quote: string;
  risk_level: RiskLevel;
  category: ClauseCategory;
  verification_status: VerificationStatus;
  rule_id: string;
  issue_title: string;
  issue_explanation: string;
  legal_basis: LegalBasis;
  suggested_redline: string;
  redline_reasoning: string;
}

export interface ContractClause {
  id: string;
  clause_number: string;
  title: string;
  original_text: string;
  finding?: Finding;
  risk_level: RiskLevel;
}

export interface SummaryStats {
  total_clauses: number;
  red_count: number;
  yellow_count: number;
  green_count: number;
  gray_count: number;
  balance_label: string;
  top_risks: string[];
  risk_score: number; // 0 (eng xavfsiz) dan 100 (juda xavfli) gacha
}

export interface DocumentMetadata {
  id: string;
  filename: string;
  sha256: string;
  contract_date: string;
  document_type: string;
  file_size?: number;
  parse_confidence?: number;
}

export interface AnalysisResult {
  id: string;
  document: DocumentMetadata;
  summary: SummaryStats;
  findings: Finding[];
  clauses: ContractClause[];
  disclaimer: string;
  created_at?: string;
}

export type AnalysisStage = 
  | 'INITIALIZING'
  | 'PARSING' 
  | 'PII_REDACTION' 
  | 'RULES_ENGINE' 
  | 'RAG_RETRIEVAL' 
  | 'VERIFICATION' 
  | 'COMPLETED';

export interface ProgressEvent {
  stage: AnalysisStage;
  progress_pct: number;
  message?: string;
  current_finding?: Partial<Finding>;
}
