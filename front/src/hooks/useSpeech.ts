import { useCallback, useEffect, useRef, useState } from 'react';

const getRecognitionCtor = (): any =>
  typeof window === 'undefined' ? null : (window as any).SpeechRecognition || (window as any).webkitSpeechRecognition || null;

const RECOGNITION_ERRORS: Record<string, string> = {
  'not-allowed': "Mikrofonga ruxsat berilmadi. Brauzer sozlamalaridan ruxsat bering.",
  'service-not-allowed': "Mikrofonga ruxsat berilmadi. Brauzer sozlamalaridan ruxsat bering.",
  'no-speech': "Ovoz eshitilmadi. Mikrofonga yaqinroq gapirib, qayta urinib ko'ring.",
  'audio-capture': "Mikrofon topilmadi.",
  'language-not-supported': "Brauzeringiz o'zbek tilidagi ovozni tanimaydi (Google Chrome tavsiya etiladi).",
  network: "Ovozni aniqlash uchun internet kerak.",
};

/** Mikrofon orqali nutqni matnga aylantirish (Web Speech API). */
export function useSpeechRecognition(lang = 'uz-UZ') {
  const [listening, setListening] = useState(false);
  const [interim, setInterim] = useState('');
  const [error, setError] = useState<string | null>(null);
  const recRef = useRef<any>(null);
  const supported = !!getRecognitionCtor();

  const stop = useCallback(() => {
    try {
      recRef.current?.stop();
    } catch {
      /* allaqachon to'xtagan */
    }
  }, []);

  const start = useCallback(
    (onFinal: (text: string) => void) => {
      const Ctor = getRecognitionCtor();
      if (!Ctor) {
        setError("Brauzeringiz ovozli kiritishni qo'llab-quvvatlamaydi (Google Chrome yoki Edge tavsiya etiladi).");
        return;
      }
      setError(null);
      setInterim('');
      const rec = new Ctor();
      let delivered = false;
      rec.lang = lang;
      rec.continuous = false;
      rec.interimResults = true;
      rec.onstart = () => setListening(true);
      rec.onresult = (event: any) => {
        let text = '';
        let isFinal = false;
        for (let i = event.resultIndex; i < event.results.length; i++) {
          text += event.results[i][0].transcript;
          if (event.results[i].isFinal) isFinal = true;
        }
        setInterim(text);
        if (isFinal && !delivered && text.trim()) {
          delivered = true;
          onFinal(text.trim());
        }
      };
      rec.onerror = (event: any) => {
        setError(RECOGNITION_ERRORS[event.error] || `Ovozni aniqlashda xatolik (${event.error}).`);
      };
      rec.onend = () => {
        setListening(false);
        setInterim('');
      };
      recRef.current = rec;
      try {
        rec.start();
      } catch {
        setError("Mikrofonni ishga tushirib bo'lmadi. Qayta urinib ko'ring.");
      }
    },
    [lang]
  );

  useEffect(() => () => {
    try {
      recRef.current?.abort();
    } catch {
      /* e'tiborsiz */
    }
  }, []);

  return { supported, listening, interim, error, clearError: () => setError(null), start, stop };
}

/** Matnni ovoz chiqarib o'qish (Web Speech API). O'zbekcha ovoz bo'lmasa, yaqin tillarga o'tadi. */
export function useSpeechSynthesis() {
  const [speaking, setSpeaking] = useState(false);
  const supported = typeof window !== 'undefined' && 'speechSynthesis' in window;

  const cancel = useCallback(() => {
    if (supported) window.speechSynthesis.cancel();
    setSpeaking(false);
  }, [supported]);

  const speak = useCallback(
    (text: string) => {
      if (!supported || !text.trim()) return;
      window.speechSynthesis.cancel();
      const utter = new SpeechSynthesisUtterance(text);
      const voices = window.speechSynthesis.getVoices();
      const voice =
        voices.find((v) => v.lang.toLowerCase().startsWith('uz')) ||
        voices.find((v) => v.lang.toLowerCase().startsWith('tr')) ||
        voices.find((v) => v.lang.toLowerCase().startsWith('ru')) ||
        voices[0];
      if (voice) {
        utter.voice = voice;
        utter.lang = voice.lang;
      }
      utter.rate = 1;
      utter.onstart = () => setSpeaking(true);
      utter.onend = () => setSpeaking(false);
      utter.onerror = () => setSpeaking(false);
      window.speechSynthesis.speak(utter);
    },
    [supported]
  );

  useEffect(() => {
    if (!supported) return;
    // Ba'zi brauzerlarda ovozlar kech yuklanadi
    const warm = () => window.speechSynthesis.getVoices();
    window.speechSynthesis.addEventListener?.('voiceschanged', warm);
    return () => {
      window.speechSynthesis.removeEventListener?.('voiceschanged', warm);
      window.speechSynthesis.cancel();
    };
  }, [supported]);

  return { supported, speaking, speak, cancel };
}
