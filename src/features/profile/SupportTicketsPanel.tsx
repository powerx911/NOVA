import { useCallback, useEffect, useState } from 'react';
import { nexoraApi } from '../../lib/nexoraApi';
import type { Language } from '../../types/game';

type TicketMessage = { id: string; sender_type: 'player' | 'admin'; message: string; created_at: string; attachments?: string[] };
type Ticket = { id: string; subject: string; status: 'open' | 'claimed' | 'closed'; claimed_at: string | null; created_at: string; messages: TicketMessage[] };

async function encodeImages(files: File[]): Promise<string[]> {
  return Promise.all(files.slice(0, 3).map((file) => new Promise<string>((resolve, reject) => {
    if (!['image/jpeg', 'image/png', 'image/webp'].includes(file.type) || file.size > 3 * 1024 * 1024) {
      reject(new Error('INVALID_ATTACHMENT'));
      return;
    }
    const reader = new FileReader();
    reader.onload = () => resolve(String(reader.result));
    reader.onerror = () => reject(new Error('ATTACHMENT_READ_FAILED'));
    reader.readAsDataURL(file);
  })));
}

export function SupportTicketsPanel({ language }: { language: Language }) {
  const ar = language === 'ar';
  const [tickets, setTickets] = useState<Ticket[]>([]);
  const [subject, setSubject] = useState('');
  const [message, setMessage] = useState('');
  const [images, setImages] = useState<File[]>([]);
  const [replyById, setReplyById] = useState<Record<string, string>>({});
  const [replyImages, setReplyImages] = useState<Record<string, File[]>>({});
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState('');
  const [ticketFormOpen, setTicketFormOpen] = useState(false);

  const refresh = useCallback(async () => {
    try { setTickets(await nexoraApi<Ticket[]>('list_my_support_tickets')); setError(''); }
    catch { setError(ar ? 'تعذر تحميل التذاكر.' : 'Could not load tickets.'); }
  }, [ar]);

  useEffect(() => {
    void refresh();
    const timer = window.setInterval(() => { void refresh(); }, 5000);
    return () => window.clearInterval(timer);
  }, [refresh]);

  async function createTicket() {
    if (subject.trim().length < 3 || message.trim().length < 1) return;
    setBusy(true);
    try {
      const encoded = await encodeImages(images);
      await nexoraApi('create_support_ticket', { subject: subject.trim(), message: message.trim(), images: encoded });
      setSubject(''); setMessage(''); setImages([]); setTicketFormOpen(false); await refresh();
    } catch (e) { setError(e instanceof Error && e.message === 'INVALID_ATTACHMENT' ? (ar ? 'الصورة غير مدعومة أو أكبر من 3 ميجابايت.' : 'Unsupported image or image exceeds 3 MB.') : (ar ? 'تعذر فتح التذكرة.' : 'Could not create ticket.')); }
    finally { setBusy(false); }
  }

  async function sendReply(ticket: Ticket) {
    const text = (replyById[ticket.id] || '').trim();
    if (!text || ticket.status === 'closed') return;
    setBusy(true);
    try {
      const encoded = await encodeImages(replyImages[ticket.id] || []);
      await nexoraApi('send_support_ticket_message', { ticketId: ticket.id, message: text, images: encoded });
      setReplyById((old) => ({ ...old, [ticket.id]: '' }));
      setReplyImages((old) => ({ ...old, [ticket.id]: [] }));
      await refresh();
    } catch { setError(ar ? 'تعذر إرسال الرسالة.' : 'Could not send message.'); }
    finally { setBusy(false); }
  }

  const statusLabel = (status: Ticket['status']) => status === 'closed' ? (ar ? 'مغلقة' : 'Closed') : status === 'claimed' ? (ar ? 'تم استلامها من الإدارة' : 'Claimed by admin') : (ar ? 'بانتظار الإدارة' : 'Waiting for admin');

  return <section className="space-y-4 border-b border-white/8 pb-5">
    <div className="flex items-center justify-between gap-2">
      <h3 className="text-sm font-semibold text-[#F4F5F7]">{ar ? 'التذاكر والدعم المباشر' : 'Support tickets'}</h3>
      <button type="button" onClick={() => void refresh()} className="text-xs text-[#AAB6D0]">{ar ? 'تحديث' : 'Refresh'}</button>
    </div>
    {!ticketFormOpen ? <button type="button" onClick={() => setTicketFormOpen(true)} className="w-full rounded-xl bg-[#B91C32] text-white py-3 text-sm font-semibold">{ar ? 'فتح تذكرة' : 'Open ticket'}</button> : <div className="rounded-xl border border-white/10 bg-[#0B0D12] p-3 space-y-2">
      <input value={subject} onChange={(e) => setSubject(e.target.value.slice(0,120))} maxLength={120} placeholder={ar ? 'عنوان التذكرة' : 'Ticket subject'} className="w-full rounded-lg bg-[#141821] border border-white/10 p-3 text-sm text-white" />
      <textarea value={message} onChange={(e) => setMessage(e.target.value.slice(0,3000))} maxLength={3000} rows={3} placeholder={ar ? 'اكتب رسالتك للإدارة…' : 'Write your message to the team…'} className="w-full rounded-lg bg-[#141821] border border-white/10 p-3 text-sm text-white" />
      <label className="inline-flex cursor-pointer items-center justify-center rounded-lg border border-white/15 bg-[#141821] px-4 py-2 text-xs text-white">{ar ? 'إرفاق صور' : 'Attach images'}<input type="file" accept="image/png,image/jpeg,image/webp" multiple onChange={(e) => setImages(Array.from(e.target.files || []).slice(0,3))} className="hidden" /></label>
      {images.length > 0 && <span className="ms-2 text-[11px] text-[#AAB1BE]">{ar ? `تم إرفاق ${images.length} صور` : `${images.length} images attached`}</span>}
      <div className="flex gap-2"><button type="button" disabled={busy || subject.trim().length < 3 || !message.trim()} onClick={() => void createTicket()} className="flex-1 rounded-xl bg-[#B91C32] text-white py-3 text-sm font-semibold disabled:opacity-40">{ar ? 'إرسال التذكرة' : 'Submit ticket'}</button><button type="button" onClick={() => {setTicketFormOpen(false);setSubject('');setMessage('');setImages([]);}} className="rounded-xl bg-[#252B36] px-4 text-sm text-white">{ar ? 'إلغاء' : 'Cancel'}</button></div>
    </div>}
    {error && <p className="text-xs text-rose-300">{error}</p>}
    {tickets.length === 0 ? <p className="text-xs text-[#9299A6]">{ar ? 'لا توجد لديك تذاكر بعد.' : 'You have no tickets yet.'}</p> : tickets.map((ticket) => <article key={ticket.id} className="rounded-xl border border-white/10 bg-[#0B0D12] p-3 space-y-3">
      <div className="flex items-center justify-between gap-2"><strong className="text-sm text-white">{ticket.subject}</strong><span className="text-[11px] text-[#AAB1BE]">{statusLabel(ticket.status)}</span></div>
      {ticket.status === 'claimed' && <p className="text-xs text-emerald-300">{ar ? 'تم استلام التذكرة من أحد الإداريين. يمكنك متابعة المحادثة هنا.' : 'An administrator has taken your ticket. Continue here.'}</p>}
      <div className="space-y-2">{(ticket.messages || []).map((item) => <div key={item.id} className="rounded-lg bg-[#141821] p-3">
        <p className="text-[11px] text-[#AAB1BE] mb-1">{item.sender_type === 'admin' ? (ar ? 'الإدارة' : 'Administration') : (ar ? 'أنت' : 'You')}</p>
        <p className="text-sm text-white whitespace-pre-wrap break-words">{item.message}</p>
        {(item.attachments || []).map((url) => <a key={url} href={url} target="_blank" rel="noreferrer"><img src={url} alt="" className="mt-2 max-h-36 rounded-lg" /></a>)}
      </div>)}</div>
      {ticket.status !== 'closed' && <div className="flex gap-2">
        <input value={replyById[ticket.id] || ''} onChange={(e) => setReplyById((old) => ({...old,[ticket.id]:e.target.value.slice(0,3000)}))} placeholder={ar ? 'اكتب ردك…' : 'Write a reply…'} className="min-w-0 flex-1 rounded-lg bg-[#141821] border border-white/10 px-3 text-sm text-white" />
        <label className="shrink-0 cursor-pointer rounded-lg border border-white/15 bg-[#141821] px-3 py-2 text-[10px] text-white">{ar ? 'إرفاق صور' : 'Attach images'}<input type="file" accept="image/png,image/jpeg,image/webp" multiple onChange={(e) => setReplyImages((old) => ({...old,[ticket.id]:Array.from(e.target.files || []).slice(0,3)}))} className="hidden" /></label>
        <button type="button" disabled={busy || !(replyById[ticket.id] || '').trim()} onClick={() => void sendReply(ticket)} className="rounded-lg bg-[#B91C32] px-4 text-white text-xs font-semibold disabled:opacity-40">{ar ? 'إرسال' : 'Send'}</button>
      </div>}
    </article>)}
  </section>;
}
