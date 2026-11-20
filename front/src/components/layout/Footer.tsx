import React from 'react';
import { Shield, ExternalLink, Scale, CheckCircle2 } from 'lucide-react';

export const Footer: React.FC = () => {
  return (
    <footer className="mt-auto border-t border-slate-800/80 bg-slate-950/90 text-slate-400 text-xs py-8">
      <div className="max-w-7xl mx-auto px-4 sm:px-6 lg:px-8">
        <div className="grid grid-cols-1 md:grid-cols-4 gap-8 mb-6">
          <div className="space-y-2">
            <div className="flex items-center gap-2 text-white font-bold text-sm">
              <Shield className="w-4 h-4 text-sky-400" />
              <span>LexGuard AI v3.2</span>
            </div>
            <p className="text-slate-400 text-[11px] leading-relaxed">
              O'zbekiston B2B shartnomalarini avtonom tahlil qilish, qonuniy ziddiyatlarni aniqlash va interaktiv 3D WebGL risk xaritasini qurish tizimi.
            </p>
          </div>

          <div>
            <h4 className="text-slate-200 font-semibold mb-2 text-xs uppercase tracking-wider">Qonuniy Asoslar</h4>
            <ul className="space-y-1.5 text-[11px]">
              <li>
                <a href="https://lex.uz/docs/111181" target="_blank" rel="noreferrer" className="hover:text-sky-400 flex items-center gap-1 transition-colors">
                  Fuqarolik Kodeksi (FK 364, 703, 707) <ExternalLink className="w-3 h-3" />
                </a>
              </li>
              <li>
                <a href="https://lex.uz/docs/4396428" target="_blank" rel="noreferrer" className="hover:text-sky-400 flex items-center gap-1 transition-colors">
                  O‘RQ-547 (Shaxsiy ma'lumotlar) <ExternalLink className="w-3 h-3" />
                </a>
              </li>
              <li>
                <a href="https://lex.uz/docs/3517337" target="_blank" rel="noreferrer" className="hover:text-sky-400 flex items-center gap-1 transition-colors">
                  Iqtisodiy protsessual kodeks (IPK) <ExternalLink className="w-3 h-3" />
                </a>
              </li>
            </ul>
          </div>

          <div>
            <h4 className="text-slate-200 font-semibold mb-2 text-xs uppercase tracking-wider">4-Rangli Standart</h4>
            <ul className="space-y-1.5 text-[11px]">
              <li className="flex items-center gap-2">
                <span className="w-2.5 h-2.5 rounded-full bg-red-500"></span>
                <span>Qizil — Qonunga to'g'ridan-to'g'ri zid</span>
              </li>
              <li className="flex items-center gap-2">
                <span className="w-2.5 h-2.5 rounded-full bg-amber-500"></span>
                <span>Sariq — Tijoriy asimmetriya / og'ir shart</span>
              </li>
              <li className="flex items-center gap-2">
                <span className="w-2.5 h-2.5 rounded-full bg-emerald-500"></span>
                <span>Yashil — Muvozanatli shartlar</span>
              </li>
              <li className="flex items-center gap-2">
                <span className="w-2.5 h-2.5 rounded-full bg-gray-500"></span>
                <span>Kulrang — Advokat ko'rigi talab etiladi</span>
              </li>
            </ul>
          </div>

          <div>
            <h4 className="text-slate-200 font-semibold mb-2 text-xs uppercase tracking-wider">Xavfsizlik & Maxfiylik</h4>
            <p className="text-[11px] leading-relaxed mb-2">
              Lokal PII sanitization — tashqi AI ga bormasdan oldin shaxsiy va bank ma'lumotlari shifrlanadi va maskalanadi.
            </p>
            <div className="flex items-center gap-1 text-[10px] text-emerald-400">
              <CheckCircle2 className="w-3.5 h-3.5" />
              <span>O‘RQ-547 va O‘RQ-1125 ga mos</span>
            </div>
          </div>
        </div>

        <div className="border-t border-slate-900 pt-4 flex flex-col sm:flex-row items-center justify-between text-[11px] text-slate-500">
          <p>© 2026 LexGuard AI. LexHackathon 2026 · 1-trek: Huquqiy xizmatlar.</p>
          <p className="mt-2 sm:mt-0 italic">
            O‘RQ-1115 yuridik ogohlantirish: AI tahlili rasmiy advokat xulosasi o'rnini bosmaydi.
          </p>
        </div>
      </div>
    </footer>
  );
};
