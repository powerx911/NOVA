interface NotificationBadgeProps {
  count: number;
  className?: string;
  label?: string;
}

export function NotificationBadge({ count, className = '', label }: NotificationBadgeProps) {
  if (count <= 0) return null;
  return (
    <span
      className={`inline-flex min-w-4 h-4 px-1 rounded-full bg-red-600 text-[9px] font-bold text-white items-center justify-center leading-none ${className}`}
      aria-label={label ?? `${count} notifications`}
    >
      {count > 99 ? '99+' : count}
    </span>
  );
}
