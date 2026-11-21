import React, { useState } from 'react';
import { useAuth } from '../../context/AuthContext';
import { EntityType } from '../../types/auth';
import { 
  X, 
  ShieldCheck, 
  Lock, 
  Mail, 
  Building, 
  User, 
  ArrowRight, 
  Zap, 
  CheckCircle2, 
  AlertCircle,
  FileBadge,
  CreditCard
} from 'lucide-react';

interface AuthModalProps {
  isOpen: boolean;
  onClose: () => void;
}

export const AuthModal: React.FC<AuthModalProps> = ({ isOpen, onClose }) => {
  const { login, demoLogin, register, isLoading } = useAuth();

  // Asosiy tanlov: Jismoniy shaxs yoki Yuridik shaxs
  const [selectedEntity, setSelectedEntity] = useState<EntityType>('LEGAL_ENTITY');
  const [mode, setMode] = useState<'login' | 'register'>('login');

  // Forma maydonlari
  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [jshshir, setJshshir] = useState('');
  const [tin, setTin] = useState('');
  const [orgName, setOrgName] = useState('');
  const [agreeConsent, setAgreeConsent] = useState(true);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  if (!isOpen) return null;

  const isIndividual = selectedEntity === 'INDIVIDUAL';

  // Tezkor demo ma'lumotlarini to'ldirish
  const handleQuickDemo = async (type: EntityType) => {
    setSelectedEntity(type);
    await demoLogin(type);
    onClose();
  };

  const handleSubmit = async (e: React.FormEvent) => {
    e.preventDefault();
    setErrorMsg(null);

    if (mode === 'login') {
      if (!email || !password) {
        setErrorMsg('Email va parolni kiriting');
        return;
      }
      try {
        await login(email, password, selectedEntity);
        onClose();
      } catch (err: any) {
        setErrorMsg(err.message || 'Kirishda xatolik yuz berdi');
      }
    } else {
      if (!fullName || !email || !password) {
        setErrorMsg('F.I.Sh., email va parolni kiriting');
        return;
      }
      if (isIndividual && jshshir.length !== 14) {
        setErrorMsg('JShShIR aniq 14 ta raqamdan iborat bo‘lishi lozim');
        return;
      }
      if (!isIndividual && (!orgName || tin.length !== 9)) {
        setErrorMsg('Tashkilot nomi va 9 xonali STIR (INN) kiritilishi shart');
        return;
      }
      if (!agreeConsent) {
        setErrorMsg('O‘RQ-547 bo‘yicha shaxsiy ma’lumotlarni qayta ishlashga rozilik shart');
        return;
      }

      try {
        await register({
          email,
          password,
          full_name: fullName,
          entity_type: selectedEntity,
          jshshir: isIndividual ? jshshir : undefined,
          tin: !isIndividual ? tin : undefined,
          org_name: !isIndividual ? orgName : undefined,
        });
        onClose();
      } catch (err: any) {
        setErrorMsg(err.message || 'Ro‘yxatdan o‘tishda xatolik');
      }
    }
  };

  return (
    <div className="fixed inset-0 z-50 flex items-center justify-center p-4 bg-slate-950/85 backdrop-blur-md animate-in fade-in duration-200">
      <div 
        className="relative w-full max-w-lg rounded-3xl bg-slate-900 border border-slate-800 shadow-2xl p-6 sm:p-8 overflow-hidden"
        onClick={(e) => e.stopPropagation()}
      >
        {/* Yopish tugmasi */}
        <button
          onClick={onClose}
          className="absolute top-5 right-5 p-2 rounded-xl bg-slate-800/60 hover:bg-slate-700 text-slate-400 hover:text-white transition-all cursor-pointer"
        >
          <X className="w-4 h-4" />
        </button>

        {/* Logo & Sarlavha */}
        <div className="flex items-center gap-3 mb-5">
          <div className="w-10 h-10 rounded-xl bg-gradient-to-tr from-sky-500 to-emerald-400 p-[2px] shadow-lg shadow-sky-500/20">
            <div className="w-full h-full bg-slate-900 rounded-[10px] flex items-center justify-center">
              <ShieldCheck className="w-6 h-6 text-sky-400" />
            </div>
          </div>
          <div>
            <h3 className="text-lg font-bold text-white tracking-tight">
              LexGuard AI — Kirish va Ro‘yxatdan O‘tish
            </h3>
            <p className="text-xs text-slate-400 font-mono">
              O‘zbekiston Respublikasi Qonunchilik Standartlari
            </p>
          </div>
        </div>

        {/* 🎯 JISMONIY SHAXS / YURIDIK SHAXS TANLOV TUGMALARI (Soliq.uz uslubi) */}
        <div className="mb-5">
          <label className="block text-[11px] font-mono uppercase tracking-wider text-slate-400 mb-2 font-bold">
            Shaxs turini tanlang:
          </label>
          <div className="grid grid-cols-2 gap-2 p-1 bg-slate-950 rounded-2xl border border-slate-800">
            {/* Jismoniy Shaxs Tugmasi */}
            <button
              type="button"
              onClick={() => { setSelectedEntity('INDIVIDUAL'); setErrorMsg(null); }}
              className={`py-3 px-3 rounded-xl flex flex-col items-center justify-center gap-1.5 transition-all cursor-pointer ${
                isIndividual
                  ? 'bg-gradient-to-b from-sky-500/20 to-sky-600/30 text-sky-300 border border-sky-500/50 shadow-md shadow-sky-500/10'
                  : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900/60'
              }`}
            >
              <div className="flex items-center gap-2">
                <User className={`w-4 h-4 ${isIndividual ? 'text-sky-400' : 'text-slate-500'}`} />
                <span className="text-xs font-bold">Jismoniy shaxs</span>
              </div>
              <span className="text-[10px] font-mono text-slate-400">
                Fuqaro · JShShIR (PINFL)
              </span>
            </button>

            {/* Yuridik Shaxs Tugmasi */}
            <button
              type="button"
              onClick={() => { setSelectedEntity('LEGAL_ENTITY'); setErrorMsg(null); }}
              className={`py-3 px-3 rounded-xl flex flex-col items-center justify-center gap-1.5 transition-all cursor-pointer ${
                !isIndividual
                  ? 'bg-gradient-to-b from-emerald-500/20 to-emerald-600/30 text-emerald-300 border border-emerald-500/50 shadow-md shadow-emerald-500/10'
                  : 'text-slate-400 hover:text-slate-200 hover:bg-slate-900/60'
              }`}
            >
              <div className="flex items-center gap-2">
                <Building className={`w-4 h-4 ${!isIndividual ? 'text-emerald-400' : 'text-slate-500'}`} />
                <span className="text-xs font-bold">Yuridik shaxs</span>
              </div>
              <span className="text-[10px] font-mono text-slate-400">
                Kompaniya · STIR (INN)
              </span>
            </button>
          </div>
        </div>

        {/* ⚡ 1-Bosishda Tezkor Kirish (Tanlangan shaxsga mos ravishda) */}
        <div className="mb-4">
          {isIndividual ? (
            <button
              onClick={() => handleQuickDemo('INDIVIDUAL')}
              className="w-full py-2.5 px-4 rounded-xl bg-gradient-to-r from-sky-600 to-brand-600 hover:from-sky-500 hover:to-brand-500 text-white text-xs font-bold shadow-lg shadow-sky-600/30 flex items-center justify-between transition-all cursor-pointer hover:scale-[1.01]"
            >
              <div className="flex items-center gap-2">
                <Zap className="w-4 h-4 fill-current text-sky-200" />
                <span>👤 Jismoniy shaxs sifatida tezkor kirish</span>
              </div>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-black/30 text-sky-200">
                Jasur Aliyev (JShShIR)
              </span>
            </button>
          ) : (
            <button
              onClick={() => handleQuickDemo('LEGAL_ENTITY')}
              className="w-full py-2.5 px-4 rounded-xl bg-gradient-to-r from-emerald-600 to-teal-700 hover:from-emerald-500 hover:to-teal-600 text-white text-xs font-bold shadow-lg shadow-emerald-600/30 flex items-center justify-between transition-all cursor-pointer hover:scale-[1.01]"
            >
              <div className="flex items-center gap-2">
                <Building className="w-4 h-4 text-emerald-200" />
                <span>🏢 Yuridik shaxs sifatida tezkor kirish</span>
              </div>
              <span className="text-[10px] font-mono px-2 py-0.5 rounded bg-black/30 text-emerald-200">
                Smart Legal MCHJ (STIR)
              </span>
            </button>
          )}
        </div>

        <div className="relative my-4">
          <div className="absolute inset-0 flex items-center">
            <div className="w-full border-t border-slate-800"></div>
          </div>
          <div className="relative flex justify-center text-[10px] uppercase font-mono tracking-widest">
            <span className="bg-slate-900 px-3 text-slate-500">yoki maxsus hisob bilan</span>
          </div>
        </div>

        {/* Xatolik xabari */}
        {errorMsg && (
          <div className="mb-4 p-3 rounded-xl bg-rose-500/10 border border-rose-500/30 text-rose-400 text-xs flex items-center gap-2">
            <AlertCircle className="w-4 h-4 shrink-0" />
            <span>{errorMsg}</span>
          </div>
        )}

        {/* FORMA (Jismoniy / Yuridik shaxsga moslashuvchan) */}
        <form onSubmit={handleSubmit} className="space-y-3">
          {mode === 'register' && (
            <>
              <div>
                <label className="block text-[11px] font-medium text-slate-400 mb-1">
                  {isIndividual ? 'F.I.Sh. (Fuqaro)' : 'Rahbar F.I.Sh.'}
                </label>
                <div className="relative">
                  <User className="w-4 h-4 text-slate-500 absolute left-3 top-3" />
                  <input
                    type="text"
                    value={fullName}
                    onChange={(e) => setFullName(e.target.value)}
                    placeholder={isIndividual ? "Masalan: Jasur Aliyev" : "Masalan: Alisher Qodirov"}
                    className="w-full pl-9 pr-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white focus:outline-none focus:border-sky-500 transition-colors"
                  />
                </div>
              </div>

              {/* Jismoniy shaxs uchun JShShIR */}
              {isIndividual ? (
                <div>
                  <label className="block text-[11px] font-medium text-slate-400 mb-1">
                    JShShIR (14 xonali PINFL)
                  </label>
                  <div className="relative">
                    <CreditCard className="w-4 h-4 text-slate-500 absolute left-3 top-3" />
                    <input
                      type="text"
                      maxLength={14}
                      value={jshshir}
                      onChange={(e) => setJshshir(e.target.value.replace(/\D/g, ''))}
                      placeholder="30101901234567"
                      className="w-full pl-9 pr-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white font-mono focus:outline-none focus:border-sky-500 transition-colors"
                    />
                  </div>
                </div>
              ) : (
                /* Yuridik shaxs uchun Tashkilot & STIR */
                <div className="grid grid-cols-1 sm:grid-cols-2 gap-2.5">
                  <div>
                    <label className="block text-[11px] font-medium text-slate-400 mb-1">
                      Tashkilot nomi
                    </label>
                    <div className="relative">
                      <Building className="w-4 h-4 text-slate-500 absolute left-3 top-3" />
                      <input
                        type="text"
                        value={orgName}
                        onChange={(e) => setOrgName(e.target.value)}
                        placeholder="Smart Solutions MCHJ"
                        className="w-full pl-9 pr-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white focus:outline-none focus:border-emerald-500 transition-colors"
                      />
                    </div>
                  </div>

                  <div>
                    <label className="block text-[11px] font-medium text-slate-400 mb-1">
                      STIR / INN (9 xonali)
                    </label>
                    <div className="relative">
                      <FileBadge className="w-4 h-4 text-slate-500 absolute left-3 top-3" />
                      <input
                        type="text"
                        maxLength={9}
                        value={tin}
                        onChange={(e) => setTin(e.target.value.replace(/\D/g, ''))}
                        placeholder="305123456"
                        className="w-full pl-9 pr-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white font-mono focus:outline-none focus:border-emerald-500 transition-colors"
                      />
                    </div>
                  </div>
                </div>
              )}
            </>
          )}

          <div>
            <label className="block text-[11px] font-medium text-slate-400 mb-1">Elektron pochta</label>
            <div className="relative">
              <Mail className="w-4 h-4 text-slate-500 absolute left-3 top-3" />
              <input
                type="email"
                value={email}
                onChange={(e) => setEmail(e.target.value)}
                placeholder={isIndividual ? "jasur@mail.uz" : "director@kompaniya.uz"}
                className="w-full pl-9 pr-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white focus:outline-none focus:border-sky-500 transition-colors"
              />
            </div>
          </div>

          <div>
            <label className="block text-[11px] font-medium text-slate-400 mb-1">Maxfiy parol</label>
            <div className="relative">
              <Lock className="w-4 h-4 text-slate-500 absolute left-3 top-3" />
              <input
                type="password"
                value={password}
                onChange={(e) => setPassword(e.target.value)}
                placeholder="••••••••"
                className="w-full pl-9 pr-3 py-2 bg-slate-950 border border-slate-800 rounded-xl text-xs text-white focus:outline-none focus:border-sky-500 transition-colors"
              />
            </div>
          </div>

          {mode === 'register' && (
            <label className="flex items-start gap-2 pt-1 text-[11px] text-slate-400 cursor-pointer">
              <input
                type="checkbox"
                checked={agreeConsent}
                onChange={(e) => setAgreeConsent(e.target.checked)}
                className="mt-0.5 rounded border-slate-800 bg-slate-950 text-sky-500"
              />
              <span>
                O‘RQ-547 qonuni bo‘yicha {isIndividual ? 'JShShIR va shaxsiy ma’lumotlarni' : 'korxona tijoriy ma’lumotlarini'} anonimlashtirib tekshirishga roziman.
              </span>
            </label>
          )}

          <button
            type="submit"
            disabled={isLoading}
            className={`w-full py-2.5 rounded-xl text-xs font-bold flex items-center justify-center gap-1.5 transition-all shadow-md cursor-pointer mt-2 ${
              isIndividual
                ? 'bg-sky-500 hover:bg-sky-400 text-white shadow-sky-500/20'
                : 'bg-emerald-500 hover:bg-emerald-400 text-white shadow-emerald-500/20'
            }`}
          >
            {isLoading ? (
              <span>Tekshirilmoqda...</span>
            ) : mode === 'login' ? (
              <>
                <span>{isIndividual ? 'Jismoniy Shaxs sifatida Kirish' : 'Yuridik Shaxs sifatida Kirish'}</span>
                <ArrowRight className="w-3.5 h-3.5" />
              </>
            ) : (
              <>
                <span>Ro‘yxatdan O‘tish</span>
                <CheckCircle2 className="w-3.5 h-3.5" />
              </>
            )}
          </button>
        </form>

        {/* Tab almashtirish */}
        <div className="mt-5 text-center text-xs text-slate-400">
          {mode === 'login' ? (
            <span>
              Hisobingiz yo‘qmi?{' '}
              <button 
                onClick={() => { setMode('register'); setErrorMsg(null); }}
                className={`${isIndividual ? 'text-sky-400' : 'text-emerald-400'} font-bold hover:underline`}
              >
                Yangi hisob ochish
              </button>
            </span>
          ) : (
            <span>
              Akkauntingiz bormi?{' '}
              <button 
                onClick={() => { setMode('login'); setErrorMsg(null); }}
                className={`${isIndividual ? 'text-sky-400' : 'text-emerald-400'} font-bold hover:underline`}
              >
                Kirish sahifasi
              </button>
            </span>
          )}
        </div>
      </div>
    </div>
  );
};
