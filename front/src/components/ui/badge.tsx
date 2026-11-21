import * as React from "react"
import { cva, type VariantProps } from "class-variance-authority"

import { cn } from "@/lib/utils"

const badgeVariants = cva(
  "inline-flex items-center rounded-md border px-2.5 py-0.5 text-xs font-semibold transition-colors focus:outline-none focus:ring-2 focus:ring-ring focus:ring-offset-2",
  {
    variants: {
      variant: {
        default:
          "border-transparent bg-primary text-primary-foreground shadow hover:bg-primary/80",
        secondary:
          "border-transparent bg-secondary text-secondary-foreground hover:bg-secondary/80",
        destructive:
          "border-transparent bg-destructive text-destructive-foreground shadow hover:bg-destructive/80",
        outline: "text-foreground",
        // Loyiha semantikasi: xavf darajalari (LegalTech 4-rang standarti)
        danger:
          "border-red-500/30 bg-red-50 text-red-700 dark:border-red-500/20 dark:bg-red-950/50 dark:text-red-300",
        warning:
          "border-amber-500/30 bg-amber-50 text-amber-800 dark:border-amber-500/20 dark:bg-amber-950/50 dark:text-amber-300",
        success:
          "border-emerald-500/30 bg-emerald-50 text-emerald-700 dark:border-emerald-500/20 dark:bg-emerald-950/50 dark:text-emerald-300",
        neutral:
          "border-slate-400/30 bg-slate-100 text-slate-700 dark:border-slate-600/30 dark:bg-slate-800/50 dark:text-slate-300",
      },
    },
    defaultVariants: {
      variant: "default",
    },
  }
)

export interface BadgeProps
  extends React.HTMLAttributes<HTMLDivElement>,
    VariantProps<typeof badgeVariants> {}

function Badge({ className, variant, ...props }: BadgeProps) {
  return (
    <div className={cn(badgeVariants({ variant }), className)} {...props} />
  )
}

export { Badge, badgeVariants }
