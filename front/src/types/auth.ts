export type EntityType = 'INDIVIDUAL' | 'LEGAL_ENTITY';

export interface UserProfile {
  id: string;
  email: string;
  full_name: string;
  phone?: string;
  entity_type: EntityType; // 'INDIVIDUAL' (Jismoniy shaxs) yoki 'LEGAL_ENTITY' (Yuridik shaxs)
  jshshir?: string;        // Jismoniy shaxs uchun 14 xonali PINFL
  tin?: string;            // Yuridik shaxs uchun 9 xonali STIR/INN
  organization_id?: string;
  org_name?: string;       // Yuridik shaxs nomi (MCHJ, YaTT, XK)
  role: 'individual_user' | 'business_client' | 'lawyer_reviewer' | 'admin' | string;
  consents?: string[];
  quota?: {
    total: number;
    used: number;
    remaining: number;
  };
}

export interface AuthTokens {
  access_token: string;
  refresh_token: string;
  expires_at: string;
  token_type: string;
}

export interface AuthResponse {
  user: UserProfile;
  tokens: AuthTokens;
}
