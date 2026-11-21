import React, { useState } from 'react';
import {
  AlertCircle,
  ArrowRight,
  Building,
  CheckCircle2,
  CreditCard,
  FileBadge,
  Lock,
  Mail,
  ShieldCheck,
  User,
  Zap,
} from 'lucide-react';
import { useAuth } from '../../context/AuthContext';
import { EntityType } from '../../types/auth';
import { Alert, AlertDescription } from '../ui/alert';
import { Button } from '../ui/button';
import { Checkbox } from '../ui/checkbox';
import { Dialog, DialogContent, DialogDescription, DialogHeader, DialogTitle } from '../ui/dialog';
import { Input } from '../ui/input';
import { Label } from '../ui/label';
import { Separator } from '../ui/separator';
import { Tabs, TabsList, TabsTrigger } from '../ui/tabs';

interface AuthModalProps {
  isOpen: boolean;
  onClose: () => void;
}

/** Ikonkali maydon: Label + Input (shadcn) */
const Field: React.FC<{
  id: string;
  label: string;
  icon: React.ElementType;
  mono?: boolean;
} & React.InputHTMLAttributes<HTMLInputElement>> = ({ id, label, icon: Icon, mono, className, ...props }) => (
  <div className="space-y-1.5">
    <Label htmlFor={id} className="text-xs text-muted-foreground">
      {label}
    </Label>
    <div className="relative">
      <Icon className="pointer-events-none absolute left-3 top-2.5 h-4 w-4 text-muted-foreground" aria-hidden="true" />
      <Input id={id} className={`pl-9 ${mono ? 'font-mono' : ''} ${className || ''}`} {...props} />
    </div>
  </div>
);

export const AuthModal: React.FC<AuthModalProps> = ({ isOpen, onClose }) => {
  const { login, demoLogin, register, isLoading } = useAuth();

  const [selectedEntity, setSelectedEntity] = useState<EntityType>('LEGAL_ENTITY');
  const [mode, setMode] = useState<'login' | 'register'>('login');

  const [email, setEmail] = useState('');
  const [password, setPassword] = useState('');
  const [fullName, setFullName] = useState('');
  const [jshshir, setJshshir] = useState('');
  const [tin, setTin] = useState('');
  const [orgName, setOrgName] = useState('');
  const [agreeConsent, setAgreeConsent] = useState(true);
  const [errorMsg, setErrorMsg] = useState<string | null>(null);

  const isIndividual = selectedEntity === 'INDIVIDUAL';

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
      return;
    }

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
  };

  return (
    <Dialog open={isOpen} onOpenChange={(open) => !open && onClose()}>
      <DialogContent className="max-h-[92vh] max-w-lg overflow-y-auto sm:rounded-2xl">
        <DialogHeader>
          <div className="mb-1 flex items-center gap-3">
            <div className="flex h-10 w-10 items-center justify-center rounded-xl bg-primary/10 text-primary">
              <ShieldCheck className="h-6 w-6" aria-hidden="true" />
            </div>
            <div className="text-left">
              <DialogTitle>LexGuard AI: kirish va ro‘yxatdan o‘tish</DialogTitle>
              <DialogDescription>O‘zbekiston Respublikasi qonunchilik standartlari</DialogDescription>
            </div>
          </div>
        </DialogHeader>

        {/* Shaxs turi */}
        <div className="space-y-2">
          <Label className="text-xs text-muted-foreground">Shaxs turini tanlang</Label>
          <Tabs
            value={selectedEntity}
            onValueChange={(v) => {
              setSelectedEntity(v as EntityType);
              setErrorMsg(null);
            }}
          >
            <TabsList className="grid h-auto w-full grid-cols-2 p-1">
              <TabsTrigger value="INDIVIDUAL" className="flex-col gap-0.5 py-2">
                <span className="flex items-center gap-2 text-xs font-semibold">
                  <User className="h-4 w-4" aria-hidden="true" /> Jismoniy shaxs
                </span>
                <span className="text-[10px] font-normal text-muted-foreground">Fuqaro, JShShIR (PINFL)</span>
              </TabsTrigger>
              <TabsTrigger value="LEGAL_ENTITY" className="flex-col gap-0.5 py-2">
                <span className="flex items-center gap-2 text-xs font-semibold">
                  <Building className="h-4 w-4" aria-hidden="true" /> Yuridik shaxs
                </span>
                <span className="text-[10px] font-normal text-muted-foreground">Kompaniya, STIR (INN)</span>
              </TabsTrigger>
            </TabsList>
          </Tabs>
        </div>

        {/* 1 bosishda tezkor kirish */}
        <Button
          type="button"
          onClick={() => handleQuickDemo(selectedEntity)}
          disabled={isLoading}
          className="w-full justify-between"
        >
          <span className="flex items-center gap-2">
            {isIndividual ? <Zap className="h-4 w-4" aria-hidden="true" /> : <Building className="h-4 w-4" aria-hidden="true" />}
            {isIndividual ? 'Jismoniy shaxs sifatida tezkor kirish' : 'Yuridik shaxs sifatida tezkor kirish'}
          </span>
          <span className="rounded bg-primary-foreground/15 px-2 py-0.5 font-mono text-[10px]">
            {isIndividual ? 'Jasur Aliyev (JShShIR)' : 'Smart Legal MCHJ (STIR)'}
          </span>
        </Button>

        <div className="relative">
          <Separator />
          <span className="absolute left-1/2 top-1/2 -translate-x-1/2 -translate-y-1/2 bg-background px-3 text-[11px] text-muted-foreground">
            yoki maxsus hisob bilan
          </span>
        </div>

        {errorMsg && (
          <Alert variant="destructive" role="alert">
            <AlertCircle className="h-4 w-4" aria-hidden="true" />
            <AlertDescription>{errorMsg}</AlertDescription>
          </Alert>
        )}

        <form onSubmit={handleSubmit} className="space-y-3">
          {mode === 'register' && (
            <>
              <Field
                id="auth-fullname"
                label={isIndividual ? 'F.I.Sh. (fuqaro)' : 'Rahbar F.I.Sh.'}
                icon={User}
                type="text"
                value={fullName}
                onChange={(e) => setFullName(e.target.value)}
                placeholder={isIndividual ? 'Masalan: Jasur Aliyev' : 'Masalan: Alisher Qodirov'}
                autoComplete="name"
              />

              {isIndividual ? (
                <Field
                  id="auth-jshshir"
                  label="JShShIR (14 xonali PINFL)"
                  icon={CreditCard}
                  mono
                  type="text"
                  inputMode="numeric"
                  maxLength={14}
                  value={jshshir}
                  onChange={(e) => setJshshir(e.target.value.replace(/\D/g, ''))}
                  placeholder="30101901234567"
                />
              ) : (
                <div className="grid grid-cols-1 gap-3 sm:grid-cols-2">
                  <Field
                    id="auth-org"
                    label="Tashkilot nomi"
                    icon={Building}
                    type="text"
                    value={orgName}
                    onChange={(e) => setOrgName(e.target.value)}
                    placeholder="Smart Solutions MCHJ"
                    autoComplete="organization"
                  />
                  <Field
                    id="auth-tin"
                    label="STIR / INN (9 xonali)"
                    icon={FileBadge}
                    mono
                    type="text"
                    inputMode="numeric"
                    maxLength={9}
                    value={tin}
                    onChange={(e) => setTin(e.target.value.replace(/\D/g, ''))}
                    placeholder="305123456"
                  />
                </div>
              )}
            </>
          )}

          <Field
            id="auth-email"
            label="Elektron pochta"
            icon={Mail}
            type="email"
            value={email}
            onChange={(e) => setEmail(e.target.value)}
            placeholder={isIndividual ? 'jasur@mail.uz' : 'director@kompaniya.uz'}
            autoComplete="email"
          />
          <Field
            id="auth-password"
            label="Parol"
            icon={Lock}
            type="password"
            value={password}
            onChange={(e) => setPassword(e.target.value)}
            placeholder="••••••••"
            autoComplete={mode === 'login' ? 'current-password' : 'new-password'}
          />

          {mode === 'register' && (
            <div className="flex items-start gap-2 pt-1">
              <Checkbox
                id="auth-consent"
                checked={agreeConsent}
                onCheckedChange={(v) => setAgreeConsent(v === true)}
                className="mt-0.5"
              />
              <Label htmlFor="auth-consent" className="text-xs font-normal leading-snug text-muted-foreground">
                O‘RQ-547 qonuni bo‘yicha {isIndividual ? 'JShShIR va shaxsiy ma’lumotlarni' : 'korxona tijoriy ma’lumotlarini'} anonimlashtirib
                tekshirishga roziman.
              </Label>
            </div>
          )}

          <Button type="submit" disabled={isLoading} className="mt-1 w-full gap-1.5">
            {isLoading ? (
              'Tekshirilmoqda…'
            ) : mode === 'login' ? (
              <>
                {isIndividual ? 'Jismoniy shaxs sifatida kirish' : 'Yuridik shaxs sifatida kirish'}
                <ArrowRight className="h-4 w-4" aria-hidden="true" />
              </>
            ) : (
              <>
                Ro‘yxatdan o‘tish
                <CheckCircle2 className="h-4 w-4" aria-hidden="true" />
              </>
            )}
          </Button>
        </form>

        <p className="text-center text-sm text-muted-foreground">
          {mode === 'login' ? 'Hisobingiz yo‘qmi?' : 'Hisobingiz bormi?'}{' '}
          <Button
            type="button"
            variant="link"
            className="h-auto p-0 font-semibold"
            onClick={() => {
              setMode(mode === 'login' ? 'register' : 'login');
              setErrorMsg(null);
            }}
          >
            {mode === 'login' ? 'Yangi hisob ochish' : 'Kirish sahifasi'}
          </Button>
        </p>

        <div className="flex items-center justify-center gap-2 border-t pt-3 text-[11px] text-muted-foreground">
          <span>Qonuniy asos:</span>
          <img src="/lex_uz.svg" alt="Lex.uz" className="h-3.5 w-auto object-contain opacity-80" />
          <span>· Soliq.uz · OneID standartlariga mos</span>
        </div>
      </DialogContent>
    </Dialog>
  );
};
