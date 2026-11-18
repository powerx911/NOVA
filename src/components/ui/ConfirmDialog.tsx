import { X } from 'lucide-react';

interface ConfirmDialogProps {
  open: boolean;
  title: string;
  description: string;
  confirmLabel: string;
  cancelLabel: string;
  onConfirm: () => void;
  onCancel: () => void;
  busy?: boolean;
  destructive?: boolean;
}

export function ConfirmDialog({
  open,
  title,
  description,
  confirmLabel,
  cancelLabel,
  onConfirm,
  onCancel,
  busy = false,
  destructive = false,
}: ConfirmDialogProps) {
  if (!open) return null;

  return (
    <div
      className="fixed inset-0 z-50 flex items-end sm:items-center justify-center bg-black/70 backdrop-blur-sm p-0 sm:p-4"
      role="dialog"
      aria-modal="true"
    >
      <div className="w-full sm:max-w-md bg-[#141821] border border-white/10 rounded-t-3xl sm:rounded-2xl p-6 pb-8 sm:pb-6 shadow-2xl">
        <div className="w-10 h-1 bg-white/15 rounded-full mx-auto mb-4 sm:hidden" />
        <div className="flex items-start justify-between gap-4 mb-3">
          <h3 className="text-lg font-semibold text-[#F4F5F7]">{title}</h3>
          <button
            type="button"
            onClick={onCancel}
            disabled={busy}
            className="min-h-[40px] min-w-[40px] flex items-center justify-center rounded-lg text-[#9299A6] hover:text-[#F4F5F7] hover:bg-white/5"
          >
            <X className="w-5 h-5" />
          </button>
        </div>
        <p className="text-sm text-[#9299A6] leading-relaxed mb-6">{description}</p>
        <div className="flex items-center gap-3">
          <button
            type="button"
            onClick={onCancel}
            disabled={busy}
            className="flex-1 min-h-[44px] px-4 py-2.5 rounded-xl bg-[#1B2230] text-[#F4F5F7] text-sm font-medium hover:bg-[#232C3E] transition-colors whitespace-nowrap"
          >
            {cancelLabel}
          </button>
          <button
            type="button"
            onClick={onConfirm}
            disabled={busy}
            className={`flex-1 min-h-[44px] px-4 py-2.5 rounded-xl text-white text-sm font-medium transition-colors whitespace-nowrap ${
              destructive
                ? 'bg-[#B91C32] hover:bg-[#E04455]'
                : 'bg-[#B91C32] hover:bg-[#E04455]'
            } disabled:opacity-50`}
          >
            {busy ? '...' : confirmLabel}
          </button>
        </div>
      </div>
    </div>
  );
}
