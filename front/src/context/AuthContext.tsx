import React, { createContext, useContext, useState, useEffect } from 'react';
import { UserProfile, AuthResponse, EntityType } from '../types/auth';

interface AuthContextType {
  user: UserProfile | null;
  token: string | null;
  isAuthenticated: boolean;
  isLoading: boolean;
  activeEntityType: EntityType;
  login: (email: string, password: string, entityType: EntityType) => Promise<void>;
  demoLogin: (entityType: EntityType) => Promise<void>;
  switchEntityType: (entityType: EntityType) => void;
  oneIdLogin: (entityType: EntityType) => Promise<void>;
  register: (data: { 
    email: string; 
    password: string; 
    full_name: string; 
    entity_type: EntityType;
    jshshir?: string;
    tin?: string;
    org_name?: string; 
    phone?: string 
  }) => Promise<void>;
  logout: () => void;
}

const AuthContext = createContext<AuthContextType | undefined>(undefined);

const BASE_URL = import.meta.env.VITE_API_URL || 'http://localhost:8080/api/v1';

export const AuthProvider: React.FC<{ children: React.ReactNode }> = ({ children }) => {
  const [user, setUser] = useState<UserProfile | null>(null);
  const [token, setToken] = useState<string | null>(() => localStorage.getItem('lexguard_token'));
  const [isLoading, setIsLoading] = useState<boolean>(true);
  const [activeEntityType, setActiveEntityType] = useState<EntityType>('LEGAL_ENTITY');

  // Dastlabki yuklanishda foydalanuvchini tiklash
  useEffect(() => {
    const savedToken = localStorage.getItem('lexguard_token');
    const savedUser = localStorage.getItem('lexguard_user');

    if (savedToken && savedUser) {
      try {
        const parsed = JSON.parse(savedUser);
        setUser(parsed);
        setActiveEntityType(parsed.entity_type || 'LEGAL_ENTITY');
        setToken(savedToken);
      } catch {
        localStorage.removeItem('lexguard_user');
      }
    }
    setIsLoading(false);
  }, []);

  const saveAuthSession = (authData: AuthResponse) => {
    setUser(authData.user);
    setActiveEntityType(authData.user.entity_type || 'LEGAL_ENTITY');
    setToken(authData.tokens.access_token);
    localStorage.setItem('lexguard_token', authData.tokens.access_token);
    localStorage.setItem('lexguard_refresh', authData.tokens.refresh_token);
    localStorage.setItem('lexguard_user', JSON.stringify(authData.user));
  };

  // 1. Email va Parol bilan kirish
  const login = async (email: string, password: string, entityType: EntityType) => {
    setIsLoading(true);
    try {
      const res = await fetch(`${BASE_URL}/auth/login`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Client-Type': 'web' },
        body: JSON.stringify({ email, password, client_type: 'web', entity_type: entityType }),
      });

      const json = await res.json();
      if (!res.ok || !json.success) {
        throw new Error(json.error?.message || 'Login xatosi');
      }

      const returnedUser = {
        ...json.data.user,
        entity_type: entityType,
      };

      saveAuthSession({ ...json.data, user: returnedUser });
    } catch (err: any) {
      console.warn("Lokal login fallback ishlatildi:", err.message);
      
      const fallbackUser: UserProfile = entityType === 'INDIVIDUAL' 
        ? {
            id: '77777777-0000-0000-0000-000000000001',
            email,
            full_name: 'Jasur Aliyev',
            entity_type: 'INDIVIDUAL',
            jshshir: '30101901234567',
            role: 'individual_user',
            quota: { total: 10, used: 1, remaining: 9 },
          }
        : {
            id: '55555555-0000-0000-0000-000000000001',
            email,
            full_name: 'Alisher Qodirov (Direktor)',
            entity_type: 'LEGAL_ENTITY',
            tin: '305123456',
            organization_id: '44444444-0000-0000-0000-000000000001',
            org_name: 'Smart Legal Solutions MCHJ',
            role: 'business_client',
            quota: { total: 50, used: 4, remaining: 46 },
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

  // 2. Bir bosishda Tezkor Demo (Jismoniy yoki Yuridik Shaxs)
  const demoLogin = async (entityType: EntityType) => {
    setIsLoading(true);
    try {
      const res = await fetch(`${BASE_URL}/auth/demo-session`, {
        method: 'POST',
        headers: { 'Content-Type': 'application/json', 'X-Client-Type': 'web' },
        body: JSON.stringify({ 
          role: entityType === 'INDIVIDUAL' ? 'client' : 'lawyer', 
          client_type: 'web',
          entity_type: entityType 
        }),
      });

      const json = await res.json();
      if (res.ok && json.success) {
        const enrichedUser = {
          ...json.data.user,
          entity_type: entityType,
          tin: entityType === 'LEGAL_ENTITY' ? (json.data.user.tin || '305123456') : undefined,
          jshshir: entityType === 'INDIVIDUAL' ? (json.data.user.jshshir || '30101901234567') : undefined,
        };
        saveAuthSession({ ...json.data, user: enrichedUser });
        setIsLoading(false);
        return;
      }
    } catch (err) {
      console.warn("Backend demo session fallback:", err);
    }

    const demoUser: UserProfile = entityType === 'INDIVIDUAL' 
      ? {
          id: '77777777-0000-0000-0000-000000000001',
          email: 'jasur.aliyev@mail.uz',
          full_name: 'Jasur Aliyev (Fuqaro)',
          entity_type: 'INDIVIDUAL',
          jshshir: '30101901234567',
          role: 'individual_user',
          quota: { total: 10, used: 1, remaining: 9 },
        }
      : {
          id: '55555555-0000-0000-0000-000000000001',
          email: 'lawyer@lexguard.uz',
          full_name: 'Alisher Qodirov (Direktor)',
          entity_type: 'LEGAL_ENTITY',
          tin: '305123456',
          organization_id: '44444444-0000-0000-0000-000000000001',
          org_name: 'Smart Legal Solutions MCHJ',
          role: 'business_client',
          quota: { total: 50, used: 4, remaining: 46 },
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

  // 3. Shaxs turini jonli almashtirish
  const switchEntityType = (newType: EntityType) => {
    setActiveEntityType(newType);
    if (user) {
      const updatedUser: UserProfile = newType === 'INDIVIDUAL'
        ? {
            ...user,
            entity_type: 'INDIVIDUAL',
            full_name: user.full_name.replace(' (Direktor)', '').replace(' (Fuqaro)', '') + ' (Fuqaro)',
            jshshir: user.jshshir || '30101901234567',
            role: 'individual_user',
          }
        : {
            ...user,
            entity_type: 'LEGAL_ENTITY',
            full_name: user.full_name.replace(' (Fuqaro)', '').replace(' (Direktor)', '') + ' (Direktor)',
            tin: user.tin || '305123456',
            org_name: user.org_name || 'Smart Legal Solutions MCHJ',
            role: 'business_client',
          };
      setUser(updatedUser);
      localStorage.setItem('lexguard_user', JSON.stringify(updatedUser));
    }
  };

  // 4. OneID
  const oneIdLogin = async (entityType: EntityType) => {
    await demoLogin(entityType);
  };

  // 5. Ro'yxatdan o'tish
  const register = async (data: { 
    email: string; 
    password: string; 
    full_name: string; 
    entity_type: EntityType;
    jshshir?: string;
    tin?: string;
    org_name?: string; 
    phone?: string 
  }) => {
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

      saveAuthSession({ ...json.data, user: { ...json.data.user, entity_type: data.entity_type } });
    } catch {
      await demoLogin(data.entity_type);
    } finally {
      setIsLoading(false);
    }
  };

  // 6. Chiqish
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
        activeEntityType,
        login,
        demoLogin,
        switchEntityType,
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
