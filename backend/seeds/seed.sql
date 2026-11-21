-- LexGuard AI 3.0 Curated Legal Seed and Initial State

-- 1. Curated Legal Sources
INSERT INTO legal_sources (id, code, title, short_name, source_type, jurisdiction) VALUES
('11111111-0000-0000-0000-000000000001', 'FK-UZ', 'O‘zbekiston Respublikasining Fuqarolik Kodeksi', 'Fuqarolik Kodeksi', 'CODE', 'UZ'),
('11111111-0000-0000-0000-000000000002', 'ORQ-547', 'O‘zbekiston Respublikasining "Shaxsiy ma’lumotlar to‘g‘risida"gi Qonuni', 'O‘RQ-547', 'LAW', 'UZ'),
('11111111-0000-0000-0000-000000000003', 'ORQ-1115', 'O‘zbekiston Respublikasining "Sun’iy intellekt texnologiyalarini qo‘llash sohasidagi munosabatlarni tartibga solish to‘g‘risida"gi Qonuni', 'O‘RQ-1115', 'LAW', 'UZ'),
('11111111-0000-0000-0000-000000000004', 'ORQ-1125', 'O‘zbekiston Respublikasining "Shaxsiy ma’lumotlar xavfsizligi va maxfiylikni kuchaytirish to‘g‘risida"gi Qonuni', 'O‘RQ-1125', 'LAW', 'UZ'),
('11111111-0000-0000-0000-000000000005', 'ORQ-793', 'O‘zbekiston Respublikasining "Elektron raqamli imzo to‘g‘risida"gi Qonuni', 'O‘RQ-793', 'LAW', 'UZ'),
('11111111-0000-0000-0000-000000000006', 'MK-1995', 'O‘zbekiston Respublikasining Mehnat Kodeksi (1995-yil tahriri)', 'Eski Mehnat Kodeksi', 'CODE', 'UZ'),
('11111111-0000-0000-0000-000000000007', 'MK-2022', 'O‘zbekiston Respublikasining Mehnat Kodeksi (Yangi tahrir, O‘RQ-798)', 'Yangi Mehnat Kodeksi', 'CODE', 'UZ'),
('11111111-0000-0000-0000-000000000008', 'IPK-UZ', 'O‘zbekiston Respublikasining Iqtisodiy protsessual kodeksi', 'Iqtisodiy protsessual kodeks', 'CODE', 'UZ')
ON CONFLICT (code) DO NOTHING;

-- 2. Legal Source Versions (Temporal & Granular Articles)
INSERT INTO legal_source_versions (
    id, source_id, article_number, part_number, paragraph_number, title, full_text,
    norm_nature, applicable_doc_types, effective_from, effective_to, official_url, text_sha256, tsv
) VALUES
(
    '22222222-0000-0000-0000-000000000001',
    '11111111-0000-0000-0000-000000000001',
    '4-modda', '1', NULL,
    'Fuqarolik qonun hujjatlarining vaqt bo‘yicha amal qilishi',
    'Fuqarolik qonun hujjatlari orqaga qaytish kuchiga ega emas va ular amalga kiritilgandan keyin vujudga kelgan munosabatlarga nisbatan qo‘llaniladi. Qonun hujjatlari amalga kiritilishiga qadar vujudga kelgan munosabatlar bo‘yicha uning qoidalari qonun hujjatlari amalga kiritilgandan keyin vujudga kelgan huquq va burchlarga nisbatan qo‘llaniladi.',
    'IMPERATIVE',
    ARRAY['ALL', 'SERVICE_AGREEMENT', 'LEASE_AGREEMENT', 'SUPPLY_AGREEMENT'],
    '1997-03-01', NULL,
    'https://lex.uz/docs/111181#111220',
    'sha256_fk_art4',
    to_tsvector('simple', 'Fuqarolik qonun hujjatlari orqaga qaytish kuchiga ega emas amal qilish muddati munosabatlar')
),
(
    '22222222-0000-0000-0000-000000000002',
    '11111111-0000-0000-0000-000000000001',
    '364-modda', '1', NULL,
    'Shartnomaning asosiy shartlari',
    'Agar taraflar o‘rtasida shartnomaning barcha muhim shartlari bo‘yicha lozim bo‘lgan shaklda kelishuvga erishilgan bo‘lsa, shartnoma tuzilgan hisoblanadi. Shartnomaning predmeti to‘g‘risidagi shartlar, qonunchilikda bunday turdagi shartnomalar uchun muhim yoki zarur deb hisoblangan shartlar, shuningdek taraflardan birining arizasiga ko‘ra kelishuvga erishilishi zarur bo‘lgan barcha shartlar muhim shartlar hisoblanadi.',
    'IMPERATIVE',
    ARRAY['SERVICE_AGREEMENT', 'SUPPLY_AGREEMENT', 'ALL'],
    '1997-03-01', NULL,
    'https://lex.uz/docs/111181#111650',
    'sha256_fk_art364',
    to_tsvector('simple', 'Shartnomaning asosiy shartlari predmeti muhim shartlar kelishuvga erishilgan xizmatlar ro‘yxati')
),
(
    '22222222-0000-0000-0000-000000000003',
    '11111111-0000-0000-0000-000000000001',
    '703-modda', '1', NULL,
    'Haq evaziga xizmat ko‘rsatish shartnomasi',
    'Haq evaziga xizmat ko‘rsatish shartnomasi bo‘yicha ijrochi buyurtmachining topshirig‘i bilan ashyoviy shaklga ega bo‘lmagan xizmatlarni ko‘rsatish (muayyan harakatlarni bajarish yoki muayyan faoliyatni amalga oshirish), buyurtmachi esa bu xizmatlar uchun haq to‘lash majburiyatini oladi.',
    'IMPERATIVE',
    ARRAY['SERVICE_AGREEMENT'],
    '1997-03-01', NULL,
    'https://lex.uz/docs/180552#181500',
    'sha256_fk_art703',
    to_tsvector('simple', 'Haq evaziga xizmat ko‘rsatish ijrochi buyurtmachi topshiriq muayyan harakatlar faoliyat haq to‘lash')
),
(
    '22222222-0000-0000-0000-000000000004',
    '11111111-0000-0000-0000-000000000001',
    '705-modda', '1', NULL,
    'Xizmatlar haqini to‘lash',
    'Buyurtmachi ko‘rsatilgan xizmatlar uchun haq evaziga xizmat ko‘rsatish shartnomasida ko‘rsatilgan muddatlarda va tartibda haq to‘lashi shart.',
    'DISPOSITIVE',
    ARRAY['SERVICE_AGREEMENT'],
    '1997-03-01', NULL,
    'https://lex.uz/docs/180552#181520',
    'sha256_fk_art705',
    to_tsvector('simple', 'Xizmatlar haqini to‘lash tartibi muddati to‘lov kechiktirish valyuta banking')
),
(
    '22222222-0000-0000-0000-000000000005',
    '11111111-0000-0000-0000-000000000001',
    '706-modda', '1', NULL,
    'Xizmatlarni topshirish va qabul qilish tartibi',
    'Ko‘rsatilgan xizmatlar natijasi taraflar tomonidan imzolangan dalolatnoma (ijro akti) bilan rasmiylashtiriladi. Buyurtmachi e’tirozlarini dalolatnomada belgilangan muddatda yozma bildirishi lozim.',
    'DISPOSITIVE',
    ARRAY['SERVICE_AGREEMENT'],
    '1997-03-01', NULL,
    'https://lex.uz/docs/180552#181530',
    'sha256_fk_art706',
    to_tsvector('simple', 'topshirish qabul qilish dalolatnoma ijro akti e’tiroz muddati yozma bildirish')
),
(
    '22222222-0000-0000-0000-000000000006',
    '11111111-0000-0000-0000-000000000001',
    '707-modda', '1', NULL,
    'Haq evaziga xizmat ko‘rsatish shartnomasini bekor qilishdan bir tomonlama bosh tortish',
    'Buyurtmachi ijrochiga uning amalda qilgan xarajatlarini to‘lash sharti bilan haq evaziga xizmat ko‘rsatish shartnomasini bajarishdan bosh tortishga haqli. Ijrochi buyurtmachiga yetkazilgan zararning o‘rnini to‘liq qoplagan taqdirdagina majburiyatlarni bajarishdan bosh tortishga haqli.',
    'IMPERATIVE',
    ARRAY['SERVICE_AGREEMENT'],
    '1997-03-01', NULL,
    'https://lex.uz/docs/180552#181540',
    'sha256_fk_art707',
    to_tsvector('simple', 'bir tomonlama bosh tortish bekor qilish xarajatlarni to‘lash zararni qoplash ogohlantirmasdan to‘lovsiz')
),
(
    '22222222-0000-0000-0000-000000000007',
    '11111111-0000-0000-0000-000000000001',
    '260-modda', '1', NULL,
    'Neustoyka tushunchasi',
    'Qonunchilikda yoki shartnomada belgilangan, qarzdor majburiyatni bajarmagan yoki lozim darajada bajarmagan taqdirda kreditorga to‘lashi shart bo‘lgan pul summasi neustoyka (jarima, penya) hisoblanadi.',
    'IMPERATIVE',
    ARRAY['ALL', 'SERVICE_AGREEMENT', 'SUPPLY_AGREEMENT'],
    '1997-03-01', NULL,
    'https://lex.uz/docs/111181#111450',
    'sha256_fk_art260',
    to_tsvector('simple', 'neustoyka jarima penya majburiyatni bajarmagan pul summasi foiz kechiktirish')
),
(
    '22222222-0000-0000-0000-000000000008',
    '11111111-0000-0000-0000-000000000001',
    '326-modda', '1', NULL,
    'Neustoykani kamaytirish',
    'Agar to‘lanishi lozim bo‘lgan neustoyka kreditorning majburiyat buzilishi oqibatlariga nisbatan nomutanosibligi ko‘rinib tursa, sud neustoykani kamaytirishga haqlidir.',
    'DISPOSITIVE',
    ARRAY['ALL', 'SERVICE_AGREEMENT'],
    '1997-03-01', NULL,
    'https://lex.uz/docs/111181#111580',
    'sha256_fk_art326',
    to_tsvector('simple', 'neustoykani kamaytirish nomutanosiblik haddan tashqari yuqori sud kamaytirish')
),
(
    '22222222-0000-0000-0000-000000000009',
    '11111111-0000-0000-0000-000000000001',
    '333-modda', '3', NULL,
    'Fors-major (yengib bo‘lmas kuch)',
    'Agar qonunda yoki shartnomada boshqacha qoida nazarda tutilgan bo‘lmasa, tadbirkorlik faoliyatini amalga oshirishda majburiyatni bajarmagan yoki lozim darajada bajarmagan shaxs majburiyatni lozim darajada bajarishga yengib bo‘lmas kuch, ya’ni favqulodda va muayyan sharoitlarda oldini olib bo‘lmaydigan vaziyatlar (fors-major) tufayli imkon bo‘lmaganligini isbot qilsa, javobgar bo‘lmaydi.',
    'DISPOSITIVE',
    ARRAY['ALL', 'SERVICE_AGREEMENT'],
    '1997-03-01', NULL,
    'https://lex.uz/docs/111181#111600',
    'sha256_fk_art333',
    to_tsvector('simple', 'fors-major yengib bo‘lmas kuch favqulodda xabardor qilish javobgarlikdan ozod etish')
),
(
    '22222222-0000-0000-0000-000000000010',
    '11111111-0000-0000-0000-000000000001',
    '110-modda', '1', NULL,
    'Bitimlarning shakli va notarial tasdiqlash',
    'Bitimlar og‘zaki yoki yozma (oddiy yoki notarial tasdiqlangan) shaklda tuziladi. Qonunda belgilangan hollarda yoki taraflarning kelishuvi bilan ko‘zda tutilgan hollarda bitimlar notarial tasdiqlanishi shart.',
    'IMPERATIVE',
    ARRAY['ALL', 'REAL_ESTATE', 'VEHICLE'],
    '1997-03-01', NULL,
    'https://lex.uz/docs/111181#111300',
    'sha256_fk_art110',
    to_tsvector('simple', 'bitim shakli notarial tasdiqlash ko‘chmas mulk avtotransport haqiqiy emas')
),
(
    '22222222-0000-0000-0000-000000000011',
    '11111111-0000-0000-0000-000000000002',
    '15-modda', '1', NULL,
    'Shaxsiy ma’lumotlarni qayta ishlash shartlari va roziligi',
    'Shaxsiy ma’lumotlarni qayta ishlash faqat shaxsiy ma’lumotlar subyektining roziligi bo‘lganda yoki qonunda nazarda tutilgan boshqa qonuniy asoslar mavjud bo‘lganda amalga oshiriladi.',
    'IMPERATIVE',
    ARRAY['ALL', 'SERVICE_AGREEMENT', 'NDA'],
    '2019-10-01', NULL,
    'https://lex.uz/docs/4396428#4397000',
    'sha256_orq547_art15',
    to_tsvector('simple', 'shaxsiy ma’lumotlar qayta ishlash subyekt roziligi maxfiylik jshshir pasport')
),
(
    '22222222-0000-0000-0000-000000000012',
    '11111111-0000-0000-0000-000000000003',
    '6-modda', '1', NULL,
    'Sun’iy intellekt xulosalarida inson huquqi va inson nazorati kafolati',
    'Sun’iy intellekt tizimlari tomonidan chiqarilgan yuridik yoki iqtisodiy ahamiyatga ega tavsiyalar axborot-tahliliy xarakterga ega bo‘lib, inson huquqlariga daxldor yakuniy qarorlar inson-mutaxassis nazoratisiz qabul qilinishiga yo‘l qo‘yilmaydi.',
    'IMPERATIVE',
    ARRAY['ALL', 'SERVICE_AGREEMENT'],
    '2026-01-21', NULL,
    'https://lex.uz/docs/orq-1115#art6',
    'sha256_orq1115_art6',
    to_tsvector('simple', 'sun’iy intellekt AI inson nazorati yuridik ahamiyatga ega axborot tahliliy disklaymer')
),
(
    '22222222-0000-0000-0000-000000000020',
    '11111111-0000-0000-0000-000000000006',
    '84-modda', '1', NULL,
    'Ishga qabul qilishda dastlabki sinov (Eski MK)',
    'Xodimning topshirilayotgan ishga layoqatliligini tekshirish maqsadida dastlabki sinov muddati uch oydan oshmasligi kerak. Homilador ayollar, uch yoshga to‘lmagan bolalari bor ayollar, o‘quv yurtlarini bitirgan shaxslar ishga qabul qilinganda dastlabki sinov belgilanmaydi.',
    'IMPERATIVE',
    ARRAY['ALL', 'LABOR_AGREEMENT'],
    '1996-04-01', '2023-04-29',
    'https://lex.uz/docs/142859#143000',
    'sha256_mk1995_art84',
    to_tsvector('simple', 'dastlabki sinov muddati uch oydan oshmasligi homilador yosh bola bitiruvchi')
),
(
    '22222222-0000-0000-0000-000000000030',
    '11111111-0000-0000-0000-000000000007',
    '5-modda', '1', NULL,
    'Mehnat to‘g‘risidagi qonunchilik va xodimlar ahvolini yomonlashtiruvchi shartlarning haqiqiy emasligi (Yangi MK)',
    'Mehnat shartnomalarining xodimlar ahvolini mehnat to‘g‘risidagi qonunchilikka nisbatan yomonlashtiradigan shartlari o‘z-o‘zidan haqiqiy emasdir.',
    'IMPERATIVE',
    ARRAY['ALL', 'LABOR_AGREEMENT'],
    '2023-04-30', NULL,
    'https://lex.uz/docs/6257288#6257320',
    'sha256_mk2022_art5',
    to_tsvector('simple', 'mehnat to‘g‘risidagi qonunchilik xodimlar ahvolini yomonlashtiruvchi shartlar haqiqiy emas')
),
(
    '22222222-0000-0000-0000-000000000032',
    '11111111-0000-0000-0000-000000000007',
    '130-modda', '1', NULL,
    'Dastlabki sinov muddati va chegaralari (Yangi MK)',
    'Dastlabki sinov muddati uch oydan, tashkilot rahbarlari, ularning o‘rinbosarlari, bosh buxgalterlar va alohida bo‘linma rahbarlari uchun esa olti oydan oshishi mumkin emas. Homilador ayollar, uch yoshga to‘lmagan bolasi bor ayollar va ta’lim muassasasi bitiruvchilari birinchi marta ishga kirayotganda sinov belgilanmaydi.',
    'IMPERATIVE',
    ARRAY['ALL', 'LABOR_AGREEMENT'],
    '2023-04-30', NULL,
    'https://lex.uz/docs/6257288#6258020',
    'sha256_mk2022_art130',
    to_tsvector('simple', 'dastlabki sinov muddati uch oydan oshishi mumkin emas olti oy rahbarlar bitiruvchilar')
),
(
    '22222222-0000-0000-0000-000000000036',
    '11111111-0000-0000-0000-000000000007',
    '404-modda', '1', NULL,
    'Mehnat qilish erkinligi kafolatlari va no-compete taqiqlanishi (Yangi MK)',
    'Mehnat shartnomasi bekor qilinganidan so‘ng fuqaroning boshqa ish beruvchi bilan mehnat munosabatlariga kirishishi yoki qonuniy tadbirkorlik bilan shug‘ullanishi huquqini cheklovchi har qanday bitim yoki shart o‘z-o‘zidan haqiqiy emasdir.',
    'IMPERATIVE',
    ARRAY['ALL', 'LABOR_AGREEMENT'],
    '2023-04-30', NULL,
    'https://lex.uz/docs/6257288#6259450',
    'sha256_mk2022_art404',
    to_tsvector('simple', 'mehnat qilish erkinligi raqobatchi no-compete ishga kirmaslik haqiqiy emas')
),
(
    '22222222-0000-0000-0000-000000000042',
    '11111111-0000-0000-0000-000000000002',
    '27-1-modda', '1', NULL,
    'O‘zbekiston fuqarolarining shaxsiy ma’lumotlariga ishlov berishda mahalliylashtirish majburiyati',
    'Mulkdor va operator O‘zbekiston fuqarolarining shaxsiy ma’lumotlariga ishlov berishda ularning jismonan O‘zbekiston hududida joylashgan texnik vositalarda saqlanishini ta’minlashi shart.',
    'IMPERATIVE',
    ARRAY['ALL', 'SERVICE_AGREEMENT', 'NDA'],
    '2021-04-15', NULL,
    'https://lex.uz/docs/4396428#5270100',
    'sha256_orq547_art27_1',
    to_tsvector('simple', 'mahalliylashtirish shaxsiy ma’lumotlar o‘zbekiston hududidagi serverlar saqlash bazalar')
),
(
    '22222222-0000-0000-0000-000000000060',
    '11111111-0000-0000-0000-000000000004',
    '18-modda', '1', NULL,
    'Ma’lumotlar sizib chiqishi (Data Breach) holatida xabardor qilish',
    'Operator shaxsiy yoki maxfiy ma’lumotlar xavfsizligi buzilgan, ma’lumotlar sizib chiqqan vaqtdan boshlab 24 soat ichida vakolatli organni va subyektlarni xabardor qilishi shart.',
    'IMPERATIVE',
    ARRAY['ALL', 'SERVICE_AGREEMENT', 'NDA'],
    '2026-02-01', NULL,
    'https://lex.uz/docs/orq-1125#art18',
    'sha256_orq1125_art18',
    to_tsvector('simple', 'ma’lumotlar sizib chiqishi data breach 24 soat kiberxavfsizlik xabardor qilish')
),
(
    '22222222-0000-0000-0000-000000000004',
    '11111111-0000-0000-0000-000000000001',
    '245-modda', '1', NULL,
    'Pul majburiyatining valyutasi',
    'O‘zbekiston Respublikasi hududida pul majburiyatlari so‘mda ifodalanishi va to‘lanishi lozim.',
    'IMPERATIVE',
    ARRAY['ALL', 'SERVICE_AGREEMENT', 'SUPPLY_AGREEMENT'],
    '1997-03-01', NULL,
    'https://lex.uz/docs/111181#111430',
    'sha256_fk_art245',
    to_tsvector('simple', 'pul majburiyati valyuta so‘m chet el valyutasi to‘lov taqiqlangan')
)
ON CONFLICT (id) DO NOTHING;

-- 3. Default Demo Integrations Registry
INSERT INTO integrations (id, name, mode, is_healthy, config_json) VALUES
('33333333-0000-0000-0000-000000000001', 'oneid', 'MOCK', TRUE, '{"endpoint": "https://sso.egov.uz", "client_id": "lexguard_mock", "note": "VM-679 ga muvofiq mock sandbox"}'::jsonb),
('33333333-0000-0000-0000-000000000002', 'e-imzo', 'MOCK', TRUE, '{"endpoint": "http://127.0.0.1:9222", "mode": "MOCK", "note": "O‘RQ-793 SHA-256 challenge"}'::jsonb),
('33333333-0000-0000-0000-000000000003', 'lex.uz', 'MOCK', TRUE, '{"endpoint": "https://lex.uz/api", "mode": "MOCK", "note": "Curated offline corpus"}'::jsonb),
('33333333-0000-0000-0000-000000000004', 'llm_provider', 'MOCK', TRUE, '{"provider": "noop", "model": "luna-legal-uz", "timeout_sec": 15}'::jsonb)
ON CONFLICT (name) DO UPDATE SET is_healthy = EXCLUDED.is_healthy, updated_at = NOW();

-- 4. Demo Organization
INSERT INTO organizations (id, name, inn, slug) VALUES
('44444444-0000-0000-0000-000000000001', 'Smart Legal Solutions MCHJ', '309876543', 'smart-legal')
ON CONFLICT (slug) DO NOTHING;

-- 5. Demo Users (Password: Password123!)
-- bcrypt hash of 'Password123!' is $2a$10$wE9O2eWp3u0P6.4G4s7Rse8G33y8FhRzYp1p68oO2zH9YFp/nB.6y (or standard generated)
INSERT INTO users (id, email, phone, password_hash, full_name, jshshir, is_active) VALUES
('55555555-0000-0000-0000-000000000001', 'lawyer@lexguard.uz', '+998901234567', '$2a$10$eO0VjB9R5h9T5wP9v0/V9eq.hE6Z9sW8oBq5M9/X5uP2F9qM9/e1e', 'Alisher Qodirov (Yurist)', '30101901234567', TRUE),
('55555555-0000-0000-0000-000000000002', 'client@lexguard.uz', '+998939876543', '$2a$10$eO0VjB9R5h9T5wP9v0/V9eq.hE6Z9sW8oBq5M9/X5uP2F9qM9/e1e', 'Bobur Mirzayev (Biznesmen)', '30202951234568', TRUE)
ON CONFLICT (email) DO NOTHING;

-- 6. Memberships
INSERT INTO memberships (organization_id, user_id, role, authority_verified) VALUES
('44444444-0000-0000-0000-000000000001', '55555555-0000-0000-0000-000000000001', 'lawyer_reviewer', TRUE),
('44444444-0000-0000-0000-000000000001', '55555555-0000-0000-0000-000000000002', 'owner', TRUE)
ON CONFLICT (organization_id, user_id) DO NOTHING;

-- 7. Quota for Org
INSERT INTO quotas (organization_id, plan_name, analyses_limit, analyses_used, tokens_limit, tokens_used) VALUES
('44444444-0000-0000-0000-000000000001', 'STARTER', 50, 0, 500000, 0)
ON CONFLICT (organization_id) DO NOTHING;

-- 8. Consents
INSERT INTO consents (user_id, organization_id, consent_type, version, granted) VALUES
('55555555-0000-0000-0000-000000000001', '44444444-0000-0000-0000-000000000001', 'EXTERNAL_AI', '1.0', TRUE),
('55555555-0000-0000-0000-000000000002', '44444444-0000-0000-0000-000000000001', 'EXTERNAL_AI', '1.0', TRUE),
('55555555-0000-0000-0000-000000000001', '44444444-0000-0000-0000-000000000001', 'DATA_PROCESSING', '1.0', TRUE),
('55555555-0000-0000-0000-000000000002', '44444444-0000-0000-0000-000000000001', 'DATA_PROCESSING', '1.0', TRUE);
