enum AppLang { uz, ru, en }

extension AppLangX on AppLang {
  String get code => switch (this) {
        AppLang.uz => 'UZ',
        AppLang.ru => 'RU',
        AppLang.en => 'EN',
      };

  String get apiCode => switch (this) {
        AppLang.uz => 'uz',
        AppLang.ru => 'ru',
        AppLang.en => 'en',
      };
}

class AppStrings {
  const AppStrings._();

  static String t(AppLang lang, String key) {
    final map = switch (lang) {
      AppLang.uz => _uz,
      AppLang.ru => _ru,
      AppLang.en => _en,
    };
    return map[key] ?? _uz[key] ?? key;
  }

  static const Map<String, String> _uz = {
    'nav_home': 'Asosiy',
    'nav_docs': 'Hujjatlar',
    'nav_laws': 'Qonunlar',
    'nav_profile': 'Profil',
    'scan': 'Skan',
    'quick_services': 'Tezkor xizmatlar',
    'recent_checks': 'Oxirgi tekshiruvlar',
    'see_all': 'Barchasi',
    'trial_badge': 'Sinov rejimi · 14 kun',
    'remaining_analyses': 'ta tahlil qoldi',
    'today_limit': 'Bugun',
    'plans': 'Tariflar',
    'integrations': 'Integratsiya',
    'business_b2b': 'Yuridik (B2B)',
    'individual_b2c': 'Jismoniy',
    'svc_upload': 'Shartnoma\nDOCX / PDF',
    'svc_camera': 'Kamera\nSkan',
    'svc_notarial': 'Notarial\ntekshiruv (R6)',
    'svc_claim': 'Pretenziya\nxati',
    'svc_mediation': 'Mediatsiya\ntavsiyasi',
    'svc_lawyer': 'Hamkor\nadvokat',
    'red_label': 'Qizil',
    'yellow_label': 'Sariq',
    'gray_label': 'Kulrang',
    'green_label': 'Yashil',
    'green_disclaimer':
        'Tekshirilgan qoidalarda muammo topilmadi («xavfsiz» degani emas).',
    'orq_1115_banner':
        'O‘RQ-1115: Ushbu tahlil axborot-tahliliy xususiyatga ega bo‘lib, rasmiy yuridik xulosa yoki sud qarori o‘rnini bosmaydi.',
    'scan_title': 'Shartnoma yuklash va tekshirish',
    'pick_file': 'Fayl tanlash (DOCX, PDF, TXT, Rasm)',
    'camera_scan': 'Kamera bilan skanerlash',
    'demo_samples': '3 ta tayyor demo shartnoma (tez sinov)',
    'external_ai_consent': 'Tashqi AI tushuntirishiga rozilik (faqat PII maskalangan holda)',
    'top_3_issues': 'Eng muhim 3 ta muammo',
    'neutrality_title': 'Taraf balansi (Neytrallik)',
    'export_comments': 'Izohli takliflar\n+ Bayonnoma',
    'export_draft': 'To‘liq tahrir\n(LOYIHA)',
    'laws_title': 'Qonun bazasi va Holat',
    'docs_title': 'Shartnomalarim',
    'profile_title': 'Profil va Xavfsizlik',
  };

  static const Map<String, String> _ru = {
    'nav_home': 'Главная',
    'nav_docs': 'Документы',
    'nav_laws': 'Законы',
    'nav_profile': 'Профиль',
    'scan': 'Скан',
    'quick_services': 'Быстрые сервисы',
    'recent_checks': 'Последние проверки',
    'see_all': 'Все',
    'trial_badge': 'Пробный режим · 14 дней',
    'remaining_analyses': 'проверок осталось',
    'today_limit': 'Сегодня',
    'plans': 'Тарифы',
    'integrations': 'Интеграции',
    'business_b2b': 'Бизнес (B2B)',
    'individual_b2c': 'Физлицо',
    'svc_upload': 'Договор\nDOCX / PDF',
    'svc_camera': 'Камера\nСкан',
    'svc_notarial': 'Нотариат\nпроверка (R6)',
    'svc_claim': 'Претензия\n(проект)',
    'svc_mediation': 'Медиация\nи реестр',
    'svc_lawyer': 'Адвокат-\nпартнёр',
    'red_label': 'Красный',
    'yellow_label': 'Жёлтый',
    'gray_label': 'Серый',
    'green_label': 'Зелёный',
    'green_disclaimer':
        'В проверенных правилах проблем не найдено (не означает «полностью безопасно»).',
    'orq_1115_banner':
        'ЗРУ-1115: Результат носит информационно-аналитический характер и не заменяет юридическое заключение.',
    'scan_title': 'Загрузка и проверка договора',
    'pick_file': 'Выбрать файл (DOCX, PDF, TXT, Фото)',
    'camera_scan': 'Сканировать камерой',
    'demo_samples': '3 готовых демо-договора (быстрый тест)',
    'external_ai_consent': 'Согласие на внешний AI (только после маскировки ПДн)',
    'top_3_issues': 'Топ-3 ключевых риска',
    'neutrality_title': 'Баланс сторон (Нейтральность)',
    'export_comments': 'Предложения\n+ Протокол',
    'export_draft': 'Полный текст\n(ПРОЕКТ)',
    'laws_title': 'База норм и Статус',
    'docs_title': 'Мои договоры',
    'profile_title': 'Профиль и Безопасность',
  };

  static const Map<String, String> _en = {
    'nav_home': 'Home',
    'nav_docs': 'Documents',
    'nav_laws': 'Laws',
    'nav_profile': 'Profile',
    'scan': 'Scan',
    'quick_services': 'Quick Services',
    'recent_checks': 'Recent Checks',
    'see_all': 'View all',
    'trial_badge': 'Trial mode · 14 days',
    'remaining_analyses': 'checks left',
    'today_limit': 'Today',
    'plans': 'Plans',
    'integrations': 'Integrations',
    'business_b2b': 'Business (B2B)',
    'individual_b2c': 'Personal',
    'svc_upload': 'Contract\nDOCX / PDF',
    'svc_camera': 'Camera\nScan',
    'svc_notarial': 'Notarial\nCheck (R6)',
    'svc_claim': 'Claim\nLetter',
    'svc_mediation': 'Mediation\nClause',
    'svc_lawyer': 'Partner\nLawyer',
    'red_label': 'Red',
    'yellow_label': 'Yellow',
    'gray_label': 'Gray',
    'green_label': 'Green',
    'green_disclaimer':
        'No issues detected in checked rules (does not guarantee "100% safe").',
    'orq_1115_banner':
        'Law 1115: Informational analytical check only; not a binding legal opinion.',
    'scan_title': 'Upload & Check Contract',
    'pick_file': 'Choose File (DOCX, PDF, TXT, Image)',
    'camera_scan': 'Scan with Camera',
    'demo_samples': '3 Ready Demo Contracts (Quick Test)',
    'external_ai_consent': 'Consent to external AI (PII redacted locally first)',
    'top_3_issues': 'Top 3 Priority Issues',
    'neutrality_title': 'Party Balance (Neutrality)',
    'export_comments': 'Annotated\n+ Protocol',
    'export_draft': 'Clean Draft\n(LOYIHA)',
    'laws_title': 'Legal Corpus & Status',
    'docs_title': 'My Contracts',
    'profile_title': 'Profile & Security',
  };
}
