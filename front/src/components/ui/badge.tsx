import * as React from "react";
import { cn } from "../../lib/utils";

export interface BadgeProps extends React.HTMLAttributes<HTMLDivElement> {
  variant?:
    | "default"
    | "secondary"
    | "destructive"
    | "outline"
    | "risk-red"
    | "risk-yellow"
    | "risk-green"
    | "risk-gray";
}

function Badge({ className, variant = "default", ...props }: BadgeProps) {
  const baseStyles =
    "inline-flex items-center rounded-md border px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-sky-500 focus:ring-offset-2";

  const variantStyles = {
    default:
      "border-transparent bg-sky-600 text-white shadow hover:bg-sky-700 dark:bg-sky-500",
    secondary:
      "border-transparent bg-slate-100 text-slate-900 hover:bg-slate-200 dark:bg-slate-800 dark:text-slate-100",
    destructive:
      "border-transparent bg-red-600 text-white shadow hover:bg-red-700 dark:bg-red-500",
    outline: "border-slate-300 text-slate-800 dark:border-slate-700 dark:text-slate-200",
    "risk-red":
      "border-red-500/30 bg-red-50 text-red-700 dark:border-red-500/20 dark:bg-red-950/50 dark:text-red-300",
    "risk-yellow":
      "border-amber-500/30 bg-amber-50 text-amber-700 dark:border-amber-500/20 dark:bg-amber-950/50 dark:text-amber-300",
    "risk-green":
      "border-emerald-500/30 bg-emerald-50 text-emerald-700 dark:border-emerald-500/20 dark:bg-emerald-950/50 dark:text-emerald-300",
    "risk-gray":
      "border-slate-400/30 bg-slate-100 text-slate-700 dark:border-slate-600/30 dark:bg-slate-800/50 dark:text-slate-300",
  }[variant];

  return <div className={cn(baseStyles, variantStyles, className)} {...props} />;
}

export { Badge };
