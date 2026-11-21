import React, { useState } from 'react';
import { Card, CardHeader, CardTitle, CardDescription, CardContent } from '../ui/card';
import { Badge } from '../ui/badge';
import { Button } from '../ui/button';
import { Input } from '../ui/input';
import { 
  BookOpen, 
  Search, 
  ExternalLink, 
  Scale, 
  ShieldCheck, 
  Lock, 
  AlertCircle,
  FileCheck
} from 'lucide-react';

interface LegalNorm {
  id: string;
  code: string;
  article: string;
  title: string;
  category: 'FK' | 'ORQ-547' | 'IPK' | 'MK';
  nature: 'IMPERATIVE' | 'DISPOSITIVE';
  summary: string;
  contractImpact: string;
  lexUrl: string;
}

export const LawsView: React.FC = () => {
  const [searchQuery, setSearchQuery] = useState('');
  const [categoryFilter, setCategoryFilter] = useState<'all' | 'FK' | 'ORQ-547' | 'IPK' | 'MK'>('all');

  const norms: LegalNorm[] = [
    {
      id: 'fk-703',
      code: 'FK',
      article: '703-modda',
      title: 'Haq evaziga xizmat ko‘rsatish shartnomasi',
      category: 'FK',
      nature: 'IMPERATIVE',
      summary: 'Ijrochi Buyurtmachining topshirig‘i bo‘yicha ashyoviy shaklga ega bo‘lmagan xizmat ko‘rsatish, Buyurtmachi esa bu xizmatlar uchun haq to‘lash majburiyatini oladi.',
      contractImpact: 'Ijrochining xizmat natijasi bo‘yicha o‘z vaqtida haq olish huquqini kafolatlaydi, asossiz dalolatnoma kechiktirishni taqiqlaydi.',
      lexUrl: 'https://lex.uz/docs/111189#163777',
    },
    {
      id: 'fk-707',
      code: 'FK',
      article: '707-modda',
      title: 'Haq evaziga xizmat ko‘rsatish shartnomasini bajarishdan bir tomonlama bosh tortish',
      category: 'FK',
      nature: 'IMPERATIVE',
      summary: 'Buyurtmachi Ijrochiga amalda qilingan xarajatlarni to‘lagan taqdirdagina xizmat ko‘rsatish shartnomasini bajarishdan bosh tortishga haqli.',
      contractImpact: 'Buyurtmachi shartnomani xarajatlarni qoplamasdan bir tomonlama bekor qilish haqidagi bandlarni bekor (haqiqiy emas) qiladi.',
      lexUrl: 'https://lex.uz/docs/111189#163821',
    },
    {
      id: 'fk-324',
      code: 'FK',
      article: '324-modda',
      title: 'Zararni to‘lash majburiyati',
      category: 'FK',
      nature: 'DISPOSITIVE',
      summary: 'Qarzdor majburiyatni bajarmagan yoki lozim darajada bajarmagan taqdirda kreditorga yetkazilgan zararni to‘lashi shart.',
      contractImpact: 'Tomonlarga shartnomada javobgarlik chegarasini (Cap of Liability) belgilash va bilvosita zararlarni cheklash imkoniyatini beradi.',
      lexUrl: 'https://lex.uz/docs/111189#161205',
    },
    {
      id: 'fk-326',
      code: 'FK',
      article: '326-modda',
      title: 'Neustoykani (penya va jarimani) kamaytirish',
      category: 'FK',
      nature: 'DISPOSITIVE',
      summary: 'Agar to‘lanishi lozim bo‘lgan neustoyka kreditorning majburiyatni buzishi oqibatlariga nomutanosibligi aniq bo‘lsa, sud neustoykani kamaytirishga haqli.',
      contractImpact: 'Kunlik 1% yoki asossiz yuqori jarimalarni bozor standartiga (0.1%-0.2%) keltirish uchun asos bo‘ladi.',
      lexUrl: 'https://lex.uz/docs/111189#161220',
    },
    {
      id: 'fk-333',
      code: 'FK',
      article: '333-modda',
      title: 'Majburiyatni buzganlik uchun javobgarlik asoslari va fors-major',
      category: 'FK',
      nature: 'DISPOSITIVE',
      summary: 'Tadbirkorlik faoliyatini amalga oshirishda majburiyatni lozim darajada bajarmagan shaxs, agar bu yengib bo‘lmas kuch (fors-major) oqibatida yuz berganini isbotlay olmasa, javobgar bo‘ladi.',
      contractImpact: 'Fors-major holatlarida vakolatli organ (Savdo-sanoat palatasi) tasdiqnomasini talab etish majburiyatini mustahkamlaydi.',
      lexUrl: 'https://lex.uz/docs/111189#161270',
    },
    {
      id: 'orq-547',
      code: 'O‘RQ-547',
      article: '15-20 moddalar',
      title: 'Shaxsiy ma\'lumotlar to‘g‘risidagi Qonun',
      category: 'ORQ-547',
      nature: 'IMPERATIVE',
      summary: 'Jismoniy shaxslarning shaxsiy ma\'lumotlarini ularning roziligisiz yoki shartnoma maqsadlaridan tashqari qayta ishlash, tarqatish yoki uchinchi shaxslarga berish qat\'iyan man etiladi.',
      contractImpact: 'IT va xizmat ko‘rsatish shartnomalarida foydalanuvchilar ma\'lumotlarini himoyalash va shifrlash majburiyatini yuklaydi.',
      lexUrl: 'https://lex.uz/docs/4396419',
    },
    {
      id: 'ipk-148',
      code: 'IPK',
      article: '148-modda',
      title: 'Nizoni sudgacha hal qilish (talabnoma) tartibi',
      category: 'IPK',
      nature: 'DISPOSITIVE',
      summary: 'Tomonlar o‘rtasidagi iqtisodiy nizolar qonunda yoki shartnomada nazarda tutilgan hollarda sudgacha hal qilish (pretenziya) tartibida ko‘rib chiqiladi.',
      contractImpact: 'To‘g‘ridan-to‘g‘ri sudga da\'vo qo‘zg‘atishdan oldin 15-30 kunlik yozma muzokara majburiyatini joriy etadi.',
      lexUrl: 'https://lex.uz/docs/3516843#3520556',
    },
  ];

  const filteredNorms = norms.filter((norm) => {
    const matchesSearch =
      norm.article.toLowerCase().includes(searchQuery.toLowerCase()) ||
      norm.title.toLowerCase().includes(searchQuery.toLowerCase()) ||
      norm.summary.toLowerCase().includes(searchQuery.toLowerCase());
    const matchesCategory = categoryFilter === 'all' || norm.category === categoryFilter;
    return matchesSearch && matchesCategory;
  });

  return (
    <div className="max-w-6xl w-full mx-auto px-4 py-8 space-y-6">
      {/* Header */}
      <div className="flex flex-col sm:flex-row sm:items-center sm:justify-between gap-4">
        <div>
          <div className="flex items-center gap-2">
            <h1 className="text-3xl font-bold tracking-tight text-slate-900 dark:text-white">
              Qonunlar
            </h1>
            <Badge variant="outline" className="border-sky-500/30 text-sky-600 dark:text-sky-400 gap-1">
              <Scale className="w-3 h-3" />
              Lex.uz Sinxron
            </Badge>
          </div>
          <p className="text-sm text-slate-500 dark:text-slate-400 mt-1">
            O‘zbekiston Respublikasi Fuqarolik Kodeksi, O‘RQ-547 va protsessual qonuniy me’yorlar bazasi
          </p>
        </div>
      </div>

      {/* Search & Category Filter */}
      <div className="flex flex-col sm:flex-row items-stretch sm:items-center gap-3">
        <div className="relative flex-1">
          <Search className="absolute left-3 top-2.5 h-4 w-4 text-slate-400" />
          <Input
            placeholder="Modda raqami, kodeks yoki kalit so'z bo'yicha qidirish..."
            value={searchQuery}
            onChange={(e) => setSearchQuery(e.target.value)}
            className="pl-9"
          />
        </div>
        <div className="flex items-center gap-1.5 overflow-x-auto pb-1 sm:pb-0">
          <Button
            variant={categoryFilter === 'all' ? 'default' : 'outline'}
            size="sm"
            onClick={() => setCategoryFilter('all')}
          >
            Barchasi ({norms.length})
          </Button>
          <Button
            variant={categoryFilter === 'FK' ? 'default' : 'outline'}
            size="sm"
            onClick={() => setCategoryFilter('FK')}
          >
            Fuqarolik Kodeksi
          </Button>
          <Button
            variant={categoryFilter === 'ORQ-547' ? 'default' : 'outline'}
            size="sm"
            onClick={() => setCategoryFilter('ORQ-547')}
          >
            O‘RQ-547 (Maxfiylik)
          </Button>
          <Button
            variant={categoryFilter === 'IPK' ? 'default' : 'outline'}
            size="sm"
            onClick={() => setCategoryFilter('IPK')}
          >
            IPK (Sud/Pretenziya)
          </Button>
        </div>
      </div>

      {/* Norms Cards Grid */}
      <div className="grid grid-cols-1 md:grid-cols-2 gap-4">
        {filteredNorms.map((norm) => (
          <Card key={norm.id} className="hover:border-sky-500/40 transition-all duration-200">
            <CardHeader className="pb-3">
              <div className="flex items-start justify-between gap-3">
                <div className="flex items-center gap-2">
                  <div className="p-2 rounded-lg bg-sky-50 dark:bg-sky-950/60 text-sky-600 dark:text-sky-400">
                    <BookOpen className="w-5 h-5" />
                  </div>
                  <div>
                    <span className="text-xs font-bold text-sky-600 dark:text-sky-400">
                      {norm.code} {norm.article}
                    </span>
                    <CardTitle className="text-base line-clamp-1">
                      {norm.title}
                    </CardTitle>
                  </div>
                </div>
                {norm.nature === 'IMPERATIVE' ? (
                  <Badge variant="risk-red" className="shrink-0 text-[10px]">
                    IMPERATIV (Majburiy)
                  </Badge>
                ) : (
                  <Badge variant="secondary" className="shrink-0 text-[10px]">
                    DISPOZITIV
                  </Badge>
                )}
              </div>
            </CardHeader>

            <CardContent className="space-y-3 pt-0 text-sm">
              <div className="p-3 rounded-lg bg-slate-50 dark:bg-slate-800/50 border border-slate-100 dark:border-slate-800 text-xs text-slate-700 dark:text-slate-300 leading-relaxed">
                <strong>Qoida matni:</strong> {norm.summary}
              </div>

              <div className="flex items-start gap-2 text-xs text-slate-600 dark:text-slate-400">
                <ShieldCheck className="w-4 h-4 text-emerald-500 shrink-0 mt-0.5" />
                <span>
                  <strong>Shartnomadagi himoyasi:</strong> {norm.contractImpact}
                </span>
              </div>

              <div className="pt-2 flex justify-end">
                <a
                  href={norm.lexUrl}
                  target="_blank"
                  rel="noopener noreferrer"
                  className="inline-flex items-center gap-1.5 text-xs font-semibold text-sky-600 hover:text-sky-700 dark:text-sky-400 dark:hover:text-sky-300"
                >
                  <ExternalLink className="w-3.5 h-3.5" />
                  Lex.uz da to'liq moddani ko'rish
                </a>
              </div>
            </CardContent>
          </Card>
        ))}

        {filteredNorms.length === 0 && (
          <div className="col-span-full text-center py-12 border border-dashed rounded-xl border-slate-300 dark:border-slate-800">
            <p className="text-slate-500 dark:text-slate-400 text-sm">
              Qidiruv bo'yicha qonun normasi topilmadi
            </p>
          </div>
        )}
      </div>
    </div>
  );
};
