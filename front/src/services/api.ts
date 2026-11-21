import { AnalysisResult, ProgressEvent } from '../types/contract';
import { SAMPLE_IT_SERVICE_CONTRACT } from '../data/mockContract';
import { SAMPLE_CONTRACTS, SampleContract } from '../data/sampleContracts';
import { BackendAnalysis, BackendClause, mapAnalysis } from '../lib/analysisMapper';

const BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8080/api/v1';

export interface ChatSource {
  id: string;
  code: string;
  title: string;
  url: string;
}

export interface ChatFinding {
  risk_level: 'RED' | 'YELLOW' | string;
  issue_title: string;
  problematic_quote: string;
  suggested_redline: string;
  cited_article: string;
  lex_uz_url: string;
  balance_label: string;
}

export interface ChatReply {
  intent: string;
  answer: string;
  /** Ovozli o'qish uchun qisqa, URL/emojisiz matn */
  speech: string;
  sources: ChatSource[];
  findings: ChatFinding[];
  suggestions: string[];
  disclaimer: string;
}

export type ChatErrorKind = 'AUTH' | 'UNAVAILABLE' | 'TOO_LONG' | 'NETWORK';

export class ChatError extends Error {
  kind: ChatErrorKind;
  constructor(kind: ChatErrorKind, message: string) {
    super(message);
    this.name = 'ChatError';
    this.kind = kind;
  }
}

/** Demo (oflayn) rejimda berilgan soxta tokenlar haqiqiy backendga yaramaydi */
const isFakeToken = (t: string | null) => !t || t.startsWith('mock_') || t.startsWith('local_');

export type AnalysisErrorKind = 'AUTH' | 'NETWORK' | 'VALIDATION' | 'SERVER' | 'FAILED' | 'TIMEOUT';

export class AnalysisError extends Error {
  kind: AnalysisErrorKind;
  constructor(kind: AnalysisErrorKind, message: string) {
    super(message);
    this.name = 'AnalysisError';
    this.kind = kind;
  }
}

export interface RecentAnalysis {
  id: string;
  contract_id: string;
  filename: string;
  status: string;
  risk_level?: string;
  overall_risk_score?: number;
  summary?: { red_count?: number; total_clauses?: number };
  created_at: string;
}

const ANALYSIS_TIMEOUT_MS = 120_000;

/** Autentifikatsiyali so'rov: 401 bo'lsa tokenni yangilab, bir marta qayta uriniladi. */
async function authedFetch(path: string, init: RequestInit = {}): Promise<Response> {
  const call = () =>
    fetch(`${BASE_URL}${path}`, {
      ...init,
      headers: {
        'X-Client-Type': 'web',
        ...(init.headers as Record<string, string> | undefined),
        Authorization: `Bearer ${localStorage.getItem('lexguard_token') || ''}`,
      },
    });
  let res: Response;
  try {
    res = await call();
    if (res.status === 401 && (await refreshSession())) res = await call();
  } catch {
    throw new AnalysisError('NETWORK', "Serverga ulanib bo'lmadi. Internetni tekshirib, qayta urinib ko'ring.");
  }
  return res;
}

/** `{success, data}` konvertini ochadi; xatoliklarni AnalysisError ga aylantiradi. */
async function readData<T>(res: Response, failMessage: string): Promise<T> {
  if (res.status === 401) throw new AnalysisError('AUTH', 'Sessiya tugagan. Iltimos, qaytadan kiring.');
  if (res.status === 402) throw new AnalysisError('VALIDATION', "Tahlil kvotasi tugagan. Tarifni yangilang.");
  let json: any = null;
  try {
    json = await res.json();
  } catch {
    /* JSON bo'lmagan javob */
  }
  if (!res.ok || !json?.success) {
    const msg = res.status >= 500 ? failMessage : json?.error?.message || failMessage;
    throw new AnalysisError(res.status >= 500 ? 'SERVER' : 'VALIDATION', msg);
  }
  return json.data as T;
}

/** Access token (15 daqiqa) eskirganda refresh token bilan yangilaydi. Muvaffaqiyatli bo'lsa true. */
async function refreshSession(): Promise<boolean> {
  try {
    const refresh = localStorage.getItem('lexguard_refresh');
    if (isFakeToken(refresh)) return false;
    const res = await fetch(`${BASE_URL}/auth/refresh`, {
      method: 'POST',
      headers: { 'Content-Type': 'application/json', 'X-Client-Type': 'web' },
      body: JSON.stringify({ refresh_token: refresh, client_type: 'web' }),
    });
    if (!res.ok) return false;
    const json = await res.json();
    const tokens = json?.data?.tokens;
    if (!tokens?.access_token) return false;
    localStorage.setItem('lexguard_token', tokens.access_token);
    if (tokens.refresh_token) localStorage.setItem('lexguard_refresh', tokens.refresh_token);
    return true;
  } catch {
    return false;
  }
}

/** Tokenli POST: soxta token / tarmoq xatosi / 401 (bir marta yangilab qayta urinadi) uchun yagona mantiq. */
async function postAuthed(path: string, payload: unknown, feature: string): Promise<Response> {
  const call = () =>
    fetch(`${BASE_URL}${path}`, {
      method: 'POST',
      headers: {
        'Content-Type': 'application/json',
        'X-Client-Type': 'web',
        Authorization: `Bearer ${localStorage.getItem('lexguard_token') || ''}`,
      },
      body: JSON.stringify(payload),
    });

  let res: Response;
  try {
    if (isFakeToken(localStorage.getItem('lexguard_token'))) {
      throw new ChatError('AUTH', `Demo (oflayn) rejimda ${feature} ishlamaydi. Tizimdan chiqib, qaytadan kiring.`);
    }
    res = await call();
    if (res.status === 401 && (await refreshSession())) {
      res = await call();
    }
  } catch (e) {
    if (e instanceof ChatError) throw e;
    throw new ChatError('NETWORK', "Serverga ulanib bo'lmadi. Internetni tekshirib, qayta urinib ko'ring.");
  }
  if (res.status === 401) {
    throw new ChatError('AUTH', 'Sessiya tugagan. Iltimos, qaytadan kiring.');
  }
  return res;
}

export interface BalanceTopic {
  topic: string;
  label: string;
  status: 'BALANCED' | 'ONE_SIDED' | 'UNEQUAL';
  burdened_side: 'PROVIDER' | 'RECIPIENT' | null;
  burdened_name: string | null;
  detail: string;
  clause_numbers: string[];
  quotes: string[];
  /** Ikki tomonga teng tahrir (muvozanatli topic uchun bo'sh) */
  fix: string;
}

export interface BalanceSide {
  name: string;
  burden: number;
  share: number;
  heavy: boolean;
}

export interface BalanceReport {
  verdict: 'BALANCED' | 'BALANCED_HEAVY' | 'ONE_SIDED_PROVIDER' | 'ONE_SIDED_RECIPIENT';
  verdict_label: string;
  summary: string;
  /** 0-100: tomonlar o'rtasidagi simmetriya (100 = to'liq teng) */
  score: number;
  sides: { provider: BalanceSide; recipient: BalanceSide };
  topics: BalanceTopic[];
  recommendations: { topic: string; label: string; text: string; clause_numbers: string[] }[];
  stats: { clauses: number; ledger_entries: number; symmetric_findings: number; unattributed: number };
  confidence: 'LOW' | 'MEDIUM';
  method: string;
  basis: { id: string; code: string; title: string; url: string }[];
  limitations: string[];
}

export interface LawChangeItem {
  id: string;
  code: string;
  source_code: string;
  law: string;
  title: string;
  changed_on: string; // ISO sana: o'zgartirgan qonun qabul qilingan kun
  amended_by: string; // masalan "OʻRQ-1189"
  amended_by_kind: string;
  effective_from: string | null;
  changed_parts: string[];
  changes_total: number;
  /** Bu modda LexGuard tahlil qoidalarida ishlatiladi */
  used_in_analysis: boolean;
  url: string;
  snippet: string;
}

export interface LawChangesReport {
  snapshot_latest: string | null;
  total_changed_articles: number;
  affecting_analysis: number;
  items: LawChangeItem[];
  laws: { amended_by: string; kind: string; changed_on: string; effective_from: string | null; articles_count: number; sample: string[] }[];
  source_note: string;
}

export class ApiService {
  /**
   * O'zgargan normalar tasmasi (Lex.uz tahrir izohlari asosida). Ommaviy endpoint: token talab qilinmaydi.
   */
  static async getLawChanges(limit = 6, onlyUsed = false): Promise<LawChangesReport> {
    let res: Response;
    try {
      res = await fetch(`${BASE_URL}/laws/changes?limit=${limit}${onlyUsed ? '&only_used=true' : ''}`);
    } catch {
      throw new ChatError('NETWORK', "Serverga ulanib bo'lmadi. Internetni tekshirib, qayta urinib ko'ring.");
    }
    if (!res.ok) {
      throw new ChatError('UNAVAILABLE', "O'zgargan normalar vaqtincha mavjud emas. Birozdan so'ng urinib ko'ring.");
    }
    const json = await res.json();
    if (!json?.success || !json.data) {
      throw new ChatError('UNAVAILABLE', "O'zgargan normalar vaqtincha mavjud emas.");
    }
    return json.data as LawChangesReport;
  }

  /**
   * Shartnomadagi tomonlar balansi (band matnlari bo'yicha). Hujjat ID shart emas: mock/namuna hujjatlar uchun ham ishlaydi.
   */
  static async getBalance(
    clauses: { clause_number: string; text: string }[],
    documentType: string,
    partyRole = ''
  ): Promise<BalanceReport> {
    const res = await postAuthed(
      '/ai/balance',
      { document_type: documentType, party_role: partyRole, clauses },
      'balans tahlili'
    );
    if (res.status === 413) {
      throw new ChatError('TOO_LONG', 'Shartnoma balans tahlili uchun juda katta.');
    }
    if (!res.ok) {
      throw new ChatError('UNAVAILABLE', "Balans tahlili vaqtincha mavjud emas. Birozdan so'ng urinib ko'ring.");
    }
    const json = await res.json();
    if (!json?.success || !json.data) {
      throw new ChatError('UNAVAILABLE', "Balans tahlili javob bermadi. Birozdan so'ng urinib ko'ring.");
    }
    return json.data as BalanceReport;
  }

  /**
   * AI yordamchi bilan suhbat (matn yoki ovozdan aylantirilgan matn).
   * 401 bo'lsa sessiyani bir marta yangilab, qayta urinadi.
   */
  static async chat(message: string): Promise<ChatReply> {
    const res = await postAuthed('/ai/chat', { message }, "AI yordamchi");
    if (res.status === 413) {
      throw new ChatError('TOO_LONG', "Xabar juda uzun (ko'pi bilan 2000 belgi).");
    }
    if (!res.ok) {
      throw new ChatError('UNAVAILABLE', "AI yordamchi vaqtincha mavjud emas. Birozdan so'ng urinib ko'ring.");
    }
    const json = await res.json();
    if (!json?.success || !json.data) {
      throw new ChatError('UNAVAILABLE', "AI yordamchi javob bermadi. Birozdan so'ng urinib ko'ring.");
    }
    return json.data as ChatReply;
  }

  /**
   * Demo sessiya yaratish
   */
  static async createDemoSession(): Promise<{ token: string; remaining: number }> {
    try {
      const response = await fetch(`${BASE_URL}/auth/demo-session`, {
        method: 'POST',
        headers: {
          'Content-Type': 'application/json',
          'X-Client-Type': 'web',
        },
        body: JSON.stringify({ client_fingerprint: `fp_web_${Date.now()}` }),
      });
      if (response.ok) {
        const data = await response.json();
        return {
          token: data.access_token,
          remaining: data.user?.quota?.remaining ?? 3,
        };
      }
    } catch {
      // Backend mavjud bo'lmasa offline demo token
    }
    return { token: 'mock_demo_jwt_token_2026', remaining: 3 };
  }

  /**
   * Shartnomani tahlilga yuborish.
   * - Haqiqiy sessiya: yuklash -> tahlil -> natijani kutish (polling) -> modelga aylantirish. Xatolik yashirilmaydi (AnalysisError).
   * - Oflayn demo sessiya (soxta token): faqat namuna uchun lokal simulyatsiya.
   */
  static async analyzeDocument(
    file: File | null,
    onProgress: (event: ProgressEvent) => void,
    demoMode = false,
    sampleId?: SampleContract['id']
  ): Promise<AnalysisResult> {
    const sample = sampleId ? SAMPLE_CONTRACTS[sampleId] : undefined;
    const offline = isFakeToken(localStorage.getItem('lexguard_token'));

    if (offline) {
      if (file) {
        const hasToken = !!localStorage.getItem('lexguard_token');
        throw new AnalysisError(
          'AUTH',
          hasToken
            ? 'Demo (oflayn) rejimda fayl tahlil qilinmaydi. Tizimdan chiqib, haqiqiy hisob bilan kiring.'
            : 'Faylni tahlil qilish uchun avval tizimga kiring.'
        );
      }
      return this.simulateAnalysisProgress(onProgress, sample?.filename || 'B2B_IT_Xizmat_Korsatish_Shartnomasi.docx');
    }
    if (!file && !sample && !demoMode) {
      throw new AnalysisError('VALIDATION', 'Tahlil uchun fayl tanlang.');
    }
    const source = file ?? sample ?? SAMPLE_CONTRACTS.it;

    onProgress({ stage: 'INITIALIZING', progress_pct: 8, message: 'Hujjat yuklanmoqda…' });

    // 1. Yuklash (fayl: multipart; namuna: JSON matn)
    let uploadRes: Response;
    if (source instanceof File) {
      const form = new FormData();
      form.append('file', source);
      form.append('title', source.name);
      uploadRes = await authedFetch('/documents', { method: 'POST', body: form });
    } else {
      uploadRes = await authedFetch('/documents', {
        method: 'POST',
        headers: { 'Content-Type': 'application/json' },
        body: JSON.stringify({ filename: source.filename, text: source.text }),
      });
    }
    const uploaded = await readData<{ id: string }>(uploadRes, 'Faylni yuklab bo‘lmadi');

    // 2. Tahlilni boshlash
    onProgress({ stage: 'PARSING', progress_pct: 20, message: 'Bandlar ajratilmoqda…' });
    const createRes = await authedFetch('/analyses', {
      method: 'POST',
      headers: { 'Content-Type': 'application/json' },
      body: JSON.stringify({ document_id: uploaded.id, doc_type: 'SERVICE_AGREEMENT', execution_mode: 'HYBRID_AI' }),
    });
    const created = await readData<{ analysis_id: string }>(createRes, 'Tahlilni boshlab bo‘lmadi');

    // 3. Natijani kutish (SSE'ga Authorization sarlavhasi qo'yib bo'lmaydi, shuning uchun polling)
    const stages: ProgressEvent['stage'][] = ['RULES_ENGINE', 'RAG_RETRIEVAL', 'VERIFICATION'];
    const startedAt = Date.now();
    for (let attempt = 0; ; attempt++) {
      if (Date.now() - startedAt > ANALYSIS_TIMEOUT_MS) {
        throw new AnalysisError('TIMEOUT', 'Tahlil kutilganidan uzoq davom etdi. Keyinroq “Hujjatlar” bo‘limidan tekshiring.');
      }
      await new Promise((r) => setTimeout(r, attempt === 0 ? 700 : 1500));
      const detail = await readData<BackendAnalysis & { status?: string }>(
        await authedFetch(`/analyses/${created.analysis_id}`),
        'Tahlil natijasini olib bo‘lmadi'
      );
      if (detail.status === 'FAILED') {
        throw new AnalysisError('FAILED', 'Tahlil bajarilmadi. Fayl matnini tekshirib, qayta urinib ko‘ring.');
      }
      if (detail.status === 'COMPLETED') {
        const doc = await readData<{ clauses?: BackendClause[] }>(
          await authedFetch(`/documents/${uploaded.id}`),
          'Hujjat bandlarini olib bo‘lmadi'
        );
        onProgress({ stage: 'COMPLETED', progress_pct: 100, message: 'Tahlil yakunlandi' });
        return mapAnalysis(detail, doc.clauses ?? []);
      }
      const pct = Math.min(92, 30 + attempt * 8);
      onProgress({ stage: stages[Math.min(stages.length - 1, Math.floor(attempt / 2))], progress_pct: pct, message: 'Qoidalar va qonunlar bilan solishtirilmoqda…' });
    }
  }

  /** Foydalanuvchining oxirgi tahlillari (bosh sahifa uchun). */
  static async listAnalyses(): Promise<RecentAnalysis[]> {
    if (isFakeToken(localStorage.getItem('lexguard_token'))) return [];
    const res = await authedFetch('/analyses');
    return readData<RecentAnalysis[]>(res, 'Tahlillar ro‘yxatini olib bo‘lmadi');
  }

  /** Mavjud tahlilni to'liq yuklash. */
  static async loadAnalysis(analysisId: string, documentId: string): Promise<AnalysisResult> {
    const detail = await readData<BackendAnalysis>(await authedFetch(`/analyses/${analysisId}`), 'Tahlilni olib bo‘lmadi');
    const doc = await readData<{ clauses?: BackendClause[] }>(await authedFetch(`/documents/${documentId}`), 'Hujjatni olib bo‘lmadi');
    return mapAnalysis(detail, doc.clauses ?? []);
  }

  /**
   * Zero-blocker Mock SSE simulyatori (Kelishuv 3.2 bo'yicha 100% ishlaydi)
   */
  private static async simulateAnalysisProgress(
    onProgress: (event: ProgressEvent) => void,
    fileName: string
  ): Promise<AnalysisResult> {
    const stages: Array<{ stage: ProgressEvent['stage']; pct: number; msg: string; delay: number }> = [
      { stage: 'INITIALIZING', pct: 10, msg: "Hujjat tekshirilmoqda va xavfsizlik nazoratidan o'tmoqda...", delay: 400 },
      { stage: 'PARSING', pct: 25, msg: "DOCX/PDF tuzilmasi va bandlar bo'laklarga ajratilmoqda...", delay: 500 },
      { stage: 'PII_REDACTION', pct: 40, msg: "O'RQ-547 bo'yicha shaxsiy ma'lumotlar lokal maskalanmoqda...", delay: 600 },
      { stage: 'RULES_ENGINE', pct: 60, msg: "10 ta Go Deterministik B2B qoidalar dvigateli tekshirmoqda...", delay: 700 },
      { stage: 'RAG_RETRIEVAL', pct: 80, msg: "Lex.uz FK 364, 703, 707, 324-moddalar bilan qiyoslanmoqda...", delay: 700 },
      { stage: 'VERIFICATION', pct: 95, msg: "Anti-gallyutsinatsiya filtri va temporal tahlil yakunlanmoqda...", delay: 500 },
      { stage: 'COMPLETED', pct: 100, msg: "Tahlil muvaffaqiyatli yakunlandi!", delay: 300 },
    ];

    for (const step of stages) {
      await new Promise(r => setTimeout(r, step.delay));
      onProgress({
        stage: step.stage,
        progress_pct: step.pct,
        message: step.msg,
      });
    }

    // Natijani qaytarish
    return {
      ...SAMPLE_IT_SERVICE_CONTRACT,
      document: {
        ...SAMPLE_IT_SERVICE_CONTRACT.document,
        filename: fileName,
      }
    };
  }
}
