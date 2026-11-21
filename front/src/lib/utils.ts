import { type ClassValue, clsx } from "clsx";
import { twMerge } from "tailwind-merge";

export function cn(...inputs: ClassValue[]) {
  return twMerge(clsx(inputs));
}

/**
 * Foydalanuvchi ismidagi qavsdagi rol/lavozim belgilarini olib tashlaydi:
 * "Alisher Qodirov (Yurist)" -> "Alisher Qodirov". Yuridik shaxs hisobi (kompaniya) yurist degani emas.
 */
export function displayName(fullName?: string | null): string {
  return (fullName || '').replace(/\s*\([^)]*\)\s*$/, '').trim();
}
