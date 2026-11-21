export interface UserProfile {
  id: string;
  email: string;
  full_name: string;
  phone?: string;
  jshshir?: string;
  organization_id: string;
  org_name: string;
  role: 'lawyer_reviewer' | 'client' | 'admin' | string;
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
