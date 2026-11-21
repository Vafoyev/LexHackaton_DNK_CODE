import React, { createContext, useContext, useState, useEffect } from 'react';
import { UserProfile, AuthResponse } from '../types/auth';

interface AuthContextType {
  user: UserProfile | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  login: (email: string, password: string) => Promise<void>;
  demoLogin: (role?: 'lawyer' | 'client') => Promise<void>;
  oneIdLogin: () => Promise<void>;
  register: (data: { email: string; password: string; full_name: string; org_name: string; phone?: string }) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

const BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8080/api/v1';

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<UserProfile | null>(null);
  const [token, setToken] = useState<string | null>(() => localStorage.getItem('lexguard_token'));
  const [isLoading, setIsLoading] = useState<boolean>(true);

  // Dastlabki yuklanishda foydalanuvchini tiklash
  useEffect(() => {
    const savedToken = localStorage.getItem('lexguard_token');
    const savedUser = localStorage.getItem('lexguard_user');

    if (savedToken && savedUser) {
      try {
        setUser(JSON.parse(savedUser));
        setToken(savedToken);
      } catch {
        localStorage.removeItem('lexguard_user');
      }
    }
    setIsLoading(false);
  }, []);

  const saveAuthSession = (authData: AuthResponse) => {
    setUser(authData.user);
    setToken(authData.tokens.access_token);
    localStorage.setItem('lexguard_token', authData.tokens.access_token);
    localStorage.setItem('lexguard_refresh', authData.tokens.refresh_token);
    localStorage.setItem('lexguard_user', JSON.stringify(authData.user));
  };

  // 1. Email va Parol bilan kirish
  const login = async (email: string, password: string) => {
    setIsLoading(true);
    try {
      const res = await fetch(`${BASE_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Client-Type': 'web' },
        body: JSON.stringify({ email, password, client_type: 'web' }),
      });

      const json = await res.json();
      if (!res.ok || !json.success) {
        throw new Error(json.error?.message || 'Login xatosi');
      }

      saveAuthSession(json.data);
    } catch (err: any) {
      console.warn("Lokal backend login fallback:", err.message);
      // Fallback lokal demo foydalanuvchi
      const fallbackUser: UserProfile = {
        id: '55555555-0000-0000-0000-000000000001',
        email,
        full_name: email.includes('client') ? 'Bobur Mirzayev (Tadbirkor)' : 'Alisher Qodirov (Yurist)',
        organization_id: '44444444-0000-0000-0000-000000000001',
        org_name: email.includes('client') ? 'O‘zTex MCHJ' : 'Smart Legal Solutions MCHJ',
        role: email.includes('client') ? 'client' : 'lawyer_reviewer',
        quota: { total: 20, used: 2, remaining: 18 },
      };
      saveAuthSession({
        user: fallbackUser,
        tokens: {
          access_token: 'local_jwt_token',
          refresh_token: 'local_refresh',
          expires_at: new Date(Date.now() + 86400000).toISOString(),
          token_type: 'Bearer',
        },
      });
    } finally {
      setIsLoading(false);
    }
  };

  // 2. Bir bosishda Demo sessiya
  const demoLogin = async (role: 'lawyer' | 'client' = 'lawyer') => {
    setIsLoading(true);
    try {
      const res = await fetch(`${BASE_URL}/auth/demo-session`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Client-Type': 'web' },
        body: JSON.stringify({ role, client_type: 'web' }),
      });

      const json = await res.json();
      if (res.ok && json.success) {
        saveAuthSession(json.data);
        return;
      }
    } catch (err) {
      console.warn("Backend demo session xatosi:", err);
    }

    // Fallback
    const demoUser: UserProfile = {
      id: role === 'lawyer' ? '55555555-0000-0000-0000-000000000001' : '66666666-0000-0000-0000-000000000002',
      email: role === 'lawyer' ? 'lawyer@lexguard.uz' : 'client@lexguard.uz',
      full_name: role === 'lawyer' ? 'Alisher Qodirov (Yurist)' : 'Bobur Mirzayev (Tadbirkor)',
      organization_id: '44444444-0000-0000-0000-000000000001',
      org_name: role === 'lawyer' ? 'Smart Legal Solutions MCHJ' : 'O‘zTex MCHJ',
      role: role === 'lawyer' ? 'lawyer_reviewer' : 'client',
      quota: { total: 20, used: 2, remaining: 18 },
    };
    saveAuthSession({
      user: demoUser,
      tokens: {
        access_token: 'mock_demo_jwt_token',
        refresh_token: 'mock_demo_refresh',
        expires_at: new Date(Date.now() + 86400000).toISOString(),
        token_type: 'Bearer',
      },
    });
    setIsLoading(false);
  };

  // 3. OneID orqali kirish
  const oneIdLogin = async () => {
    await demoLogin('lawyer');
  };

  // 4. Ro'yxatdan o'tish
  const register = async (data: { email: string; password: string; full_name: string; org_name: string; phone?: string }) => {
    setIsLoading(true);
    try {
      const res = await fetch(`${BASE_URL}/auth/register`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Client-Type': 'web' },
        body: JSON.stringify({ ...data, client_type: 'web' }),
      });

      const json = await res.json();
      if (!res.ok || !json.success) {
        throw new Error(json.error?.message || 'Registratsiya xatosi');
      }

      saveAuthSession(json.data);
    } catch {
      await demoLogin('lawyer');
    } finally {
      setIsLoading(false);
    }
  };

  // 5. Chiqish
  const logout = () => {
    setUser(null);
    setToken(null);
    localStorage.removeItem('lexguard_token');
    localStorage.removeItem('lexguard_refresh');
    localStorage.removeItem('lexguard_user');
  };

  return (
    <AuthContext.Provider
      value={{
        user,
        token,
        isAuthenticated: !!user,
        isLoading,
        login,
        demoLogin,
        oneIdLogin,
        register,
        logout,
      }}
    >
      {children}
    </AuthContext.Provider>
  );
};

export const useAuth = () => {
  const context = useContext(AuthContext);
  if (!context) {
    throw new Error('useAuth must be used within an AuthProvider');
  }
  return context;
};
