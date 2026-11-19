export function getMissionPeriodKey(missionId: string, date = new Date()): string {
  if (missionId.startsWith('daily_') || missionId === 'daily_active_trader') {
    return date.toISOString().slice(0, 10);
  }
  if (missionId.startsWith('weekly_') || missionId === 'weekly_real_estate') {
    const utc = new Date(Date.UTC(date.getUTCFullYear(), date.getUTCMonth(), date.getUTCDate()));
    const day = utc.getUTCDay() || 7;
    utc.setUTCDate(utc.getUTCDate() + 4 - day);
    const yearStart = new Date(Date.UTC(utc.getUTCFullYear(), 0, 1));
    const week = Math.ceil((((utc.getTime() - yearStart.getTime()) / 86400000) + 1) / 7);
    return `${utc.getUTCFullYear()}-W${String(week).padStart(2, '0')}`;
  }
  if (missionId.startsWith('seasonal_') || missionId === 'seasonal_syndicate') {
    const quarter = Math.floor(date.getUTCMonth() / 3) + 1;
    return `${date.getUTCFullYear()}-Q${quarter}`;
  }
  return 'lifetime';
}
