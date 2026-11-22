import { useCallback, useEffect, useState } from 'react';
import { ArrowLeft, MessageSquare, Plus, RefreshCw, Send } from 'lucide-react';
import { nexoraApi } from '../../lib/nexoraApi';
import type { Language } from '../../types/game';

type TicketMessage = { id: string; sender_type: 'player' | 'admin'; message: string; created_at: string; attachments?: string[] };
type Ticket = { id: string; subject: string; status: 'open' | 'claimed' | 'closed'; claimed_at: string | null; closed_at: string | null; created_at: string; messages: TicketMessage[] };

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
  const [selectedTicketId, setSelectedTicketId] = useState<string | null>(null);

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
  const selectedTicket = tickets.find((ticket) => ticket.id === selectedTicketId) || null;

  return <section className="space-y-4 border-b border-white/8 pb-5">
    <div className="flex items-center justify-between gap-2">
      <h3 className="text-sm font-semibold text-[#F4F5F7]">{ar ? 'التذاكر والدعم المباشر' : 'Support tickets'}</h3>
      <button type="button" onClick={() => void refresh()} className="inline-flex items-center gap-1 text-xs text-[#AAB6D0]"><RefreshCw className="h-3.5 w-3.5" />{ar ? 'تحديث' : 'Refresh'}</button>
    </div>
    {!ticketFormOpen ? <button type="button" onClick={() => setTicketFormOpen(true)} className="w-full rounded-xl bg-[#B91C32] text-white py-3 text-sm font-semibold"><Plus className="inline h-4 w-4 me-1" />{ar ? 'فتح تذكرة' : 'Open ticket'}</button> : <div className="rounded-xl border border-white/10 bg-[#0B0D12] p-3 space-y-2">
      <input value={subject} onChange={(e) => setSubject(e.target.value.slice(0,120))} maxLength={120} placeholder={ar ? 'عنوان التذكرة' : 'Ticket subject'} className="w-full rounded-lg bg-[#141821] border border-white/10 p-3 text-sm text-white" />
      <textarea value={message} onChange={(e) => setMessage(e.target.value.slice(0,3000))} maxLength={3000} rows={3} placeholder={ar ? 'اكتب رسالتك للإدارة…' : 'Write your message to the team…'} className="w-full rounded-lg bg-[#141821] border border-white/10 p-3 text-sm text-white" />
      <label className="inline-flex cursor-pointer items-center justify-center rounded-lg border border-white/15 bg-[#141821] px-4 py-2 text-xs text-white">{ar ? 'إرفاق صور' : 'Attach images'}<input type="file" accept="image/png,image/jpeg,image/webp" multiple onChange={(e) => setImages(Array.from(e.target.files || []).slice(0,3))} className="hidden" /></label>
      {images.length > 0 && <span className="ms-2 text-[11px] text-[#AAB1BE]">{ar ? `تم إرفاق ${images.length} صور` : `${images.length} images attached`}</span>}
      <div className="flex gap-2"><button type="button" disabled={busy || subject.trim().length < 3 || !message.trim()} onClick={() => void createTicket()} className="flex-1 rounded-xl bg-[#B91C32] text-white py-3 text-sm font-semibold disabled:opacity-40">{ar ? 'إرسال التذكرة' : 'Submit ticket'}</button><button type="button" onClick={() => {setTicketFormOpen(false);setSubject('');setMessage('');setImages([]);}} className="rounded-xl bg-[#252B36] px-4 text-sm text-white">{ar ? 'إلغاء' : 'Cancel'}</button></div>
    </div>}
    {error && <p className="text-xs text-rose-300">{error}</p>}
    {tickets.length === 0 ? <p className="text-xs text-[#9299A6]">{ar ? 'لا توجد لديك تذاكر بعد.' : 'You have no tickets yet.'}</p> : <div className="space-y-2">{tickets.map((ticket) => <button key={ticket.id} type="button" onClick={() => setSelectedTicketId(ticket.id)} className="w-full rounded-xl border border-white/10 bg-[#0B0D12] p-4 text-start transition-colors hover:border-white/20">
      <span className="flex items-center justify-between gap-3"><strong className="text-sm text-white">{ticket.subject}</strong><span className={`shrink-0 rounded-full px-2.5 py-1 text-[11px] ${ticket.status === 'closed' ? 'bg-white/10 text-[#AAB1BE]' : ticket.status === 'claimed' ? 'bg-emerald-500/10 text-emerald-300' : 'bg-amber-500/10 text-amber-200'}`}>{statusLabel(ticket.status)}</span></span>
      <span className="mt-2 flex items-center gap-1.5 text-[11px] text-[#9299A6]"><MessageSquare className="h-3.5 w-3.5" />{ar ? `${ticket.messages?.length || 0} رسائل` : `${ticket.messages?.length || 0} messages`}</span>
    </button>)}</div>}

    {selectedTicket && <div className="fixed inset-0 z-[100] overflow-y-auto bg-[#090B10] text-[#F4F5F7]">
      <div className="mx-auto flex min-h-full w-full max-w-3xl flex-col p-4 sm:p-6">
        <header className="sticky top-0 z-10 -mx-4 mb-4 flex items-center gap-3 border-b border-white/10 bg-[#090B10]/95 px-4 py-3 backdrop-blur sm:-mx-6 sm:px-6">
          <button type="button" onClick={() => setSelectedTicketId(null)} className="inline-flex h-10 w-10 shrink-0 items-center justify-center rounded-xl bg-[#1B202B] text-white" aria-label={ar ? 'رجوع إلى التذاكر' : 'Back to tickets'}><ArrowLeft className="h-5 w-5" /></button>
          <div className="min-w-0 flex-1"><h2 className="truncate text-base font-bold">{selectedTicket.subject}</h2><p className="mt-1 text-xs text-[#AAB1BE]">{statusLabel(selectedTicket.status)}</p></div>
        </header>
        {selectedTicket.status === 'claimed' && <p className="mb-3 rounded-xl border border-emerald-400/20 bg-emerald-400/5 p-3 text-xs text-emerald-300">{ar ? 'تم استلام التذكرة من أحد الإداريين. يمكنك متابعة المحادثة هنا.' : 'An administrator has taken your ticket. Continue the conversation here.'}</p>}
        {selectedTicket.status === 'closed' && <p className="mb-3 rounded-xl border border-amber-400/20 bg-amber-400/5 p-3 text-xs text-amber-200">{ar ? 'تم إغلاق هذه التذكرة. ستختفي من قائمة تذاكرك تلقائيًا بعد 5 دقائق من وقت الإغلاق.' : 'This ticket is closed. It will automatically disappear from your ticket list 5 minutes after it was closed.'}</p>}
        <div className="flex-1 space-y-3 pb-4">{(selectedTicket.messages || []).map((item) => <article key={item.id} className={`max-w-[92%] rounded-2xl p-3 ${item.sender_type === 'admin' ? 'me-auto bg-[#1B2633]' : 'ms-auto bg-[#27202A]'}`}>
          <p className="mb-1 text-[11px] text-[#AAB1BE]">{item.sender_type === 'admin' ? (ar ? 'الإدارة' : 'Administration') : (ar ? 'أنت' : 'You')}</p>
          <p className="whitespace-pre-wrap break-words text-sm">{item.message}</p>
          {(item.attachments || []).map((url) => <a key={url} href={url} target="_blank" rel="noreferrer"><img src={url} alt="" className="mt-2 max-h-56 rounded-lg" /></a>)}
          <p className="mt-2 text-end text-[10px] text-[#7F8998]">{new Date(item.created_at).toLocaleString(ar ? 'ar' : 'en', { dateStyle: 'short', timeStyle: 'short' })}</p>
        </article>)}</div>
        {selectedTicket.status !== 'closed' ? <div className="sticky bottom-0 -mx-4 border-t border-white/10 bg-[#090B10] p-3 sm:-mx-6 sm:p-4">
          <textarea value={replyById[selectedTicket.id] || ''} onChange={(e) => setReplyById((old) => ({...old,[selectedTicket.id]:e.target.value.slice(0,3000)}))} placeholder={ar ? 'اكتب ردك للإدارة…' : 'Write your reply…'} rows={3} className="w-full rounded-xl border border-white/10 bg-[#141821] p-3 text-sm text-white" />
          <div className="mt-2 flex items-center gap-2">
            <label className="inline-flex shrink-0 cursor-pointer items-center justify-center rounded-lg border border-white/15 bg-[#141821] px-3 py-2 text-xs text-white">{ar ? 'إرفاق صور' : 'Attach images'}<input type="file" accept="image/png,image/jpeg,image/webp" multiple onChange={(e) => setReplyImages((old) => ({...old,[selectedTicket.id]:Array.from(e.target.files || []).slice(0,3)}))} className="hidden" /></label>
            {(replyImages[selectedTicket.id] || []).length > 0 && <span className="text-[11px] text-[#AAB1BE]">{ar ? `مرفق ${replyImages[selectedTicket.id].length} صور` : `${replyImages[selectedTicket.id].length} attached`}</span>}
            <button type="button" disabled={busy || !(replyById[selectedTicket.id] || '').trim()} onClick={() => void sendReply(selectedTicket)} className="ms-auto inline-flex items-center gap-2 rounded-xl bg-[#B91C32] px-4 py-2.5 text-sm font-semibold text-white disabled:opacity-40"><Send className="h-4 w-4" />{ar ? 'إرسال' : 'Send'}</button>
          </div>
        </div> : <p className="sticky bottom-0 rounded-xl border border-white/10 bg-[#141821] p-3 text-center text-xs text-[#AAB1BE]">{ar ? 'هذه التذكرة مغلقة ولا يمكن إرسال ردود جديدة.' : 'This ticket is closed and no longer accepts replies.'}</p>}
      </div>
    </div>}
  </section>;
}
