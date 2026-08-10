# The colour vocabulary shared by components and views.
#
# Tailwind can only see class names it finds as literal text, so every variant is
# spelled out here rather than assembled from a colour name at runtime.
module AccentPalette
  ACCENTS = {
    'amber' => {
      bar: 'bg-amber-500',
      border: 'border-amber-200 dark:border-amber-900/60',
      chip: 'bg-amber-100 text-amber-900 dark:bg-amber-950 dark:text-amber-200',
      soft: 'bg-amber-50 dark:bg-amber-950/30',
      text: 'text-amber-700 dark:text-amber-300'
    },
    'emerald' => {
      bar: 'bg-emerald-500',
      border: 'border-emerald-200 dark:border-emerald-900/60',
      chip: 'bg-emerald-100 text-emerald-900 dark:bg-emerald-950 dark:text-emerald-200',
      soft: 'bg-emerald-50 dark:bg-emerald-950/30',
      text: 'text-emerald-700 dark:text-emerald-300'
    },
    'indigo' => {
      bar: 'bg-indigo-500',
      border: 'border-indigo-200 dark:border-indigo-900/60',
      chip: 'bg-indigo-100 text-indigo-900 dark:bg-indigo-950 dark:text-indigo-200',
      soft: 'bg-indigo-50 dark:bg-indigo-950/30',
      text: 'text-indigo-700 dark:text-indigo-300'
    },
    'rose' => {
      bar: 'bg-rose-500',
      border: 'border-rose-200 dark:border-rose-900/60',
      chip: 'bg-rose-100 text-rose-900 dark:bg-rose-950 dark:text-rose-200',
      soft: 'bg-rose-50 dark:bg-rose-950/30',
      text: 'text-rose-700 dark:text-rose-300'
    },
    'slate' => {
      bar: 'bg-slate-400',
      border: 'border-slate-200 dark:border-slate-700',
      chip: 'bg-slate-100 text-slate-700 dark:bg-slate-800 dark:text-slate-300',
      soft: 'bg-slate-50 dark:bg-slate-900/40',
      text: 'text-slate-600 dark:text-slate-400'
    }
  }.freeze

  def accent(name, part)
    ACCENTS.fetch(name.to_s, ACCENTS.fetch('slate')).fetch(part)
  end
end
