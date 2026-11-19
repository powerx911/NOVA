import { Clock, Gavel } from 'lucide-react';
import type { Dispatch, SetStateAction } from 'react';
import type { Company, CompanyAuction, Factory, Language } from '../../types/game';

interface BusinessAuctionsPanelProps {
  language: Language;
  profileUid: string;
  visibleCompanies: Company[];
  factories: Factory[];
  activeAuctions: CompanyAuction[];
  occupiedCompanySlots: number;
  hasFactorySlot: boolean;
  hasCompanySlot: boolean;
  startingPrices: Record<string, string>;
  setStartingPrices: Dispatch<SetStateAction<Record<string, string>>>;
  bidDrafts: Record<string, string>;
  setBidDrafts: Dispatch<SetStateAction<Record<string, string>>>;
  busyKey: string | null;
  onListCompany: (companyId: string) => void;
  onListFactory: (factoryId: string) => void;
  onPlaceBid: (auction: CompanyAuction) => void;
  formatAuctionRemaining: (endsAt: number) => string;
}

export function BusinessAuctionsPanel({
  language, profileUid, visibleCompanies, factories, activeAuctions,
  occupiedCompanySlots, hasFactorySlot, hasCompanySlot,
  startingPrices, setStartingPrices, bidDrafts, setBidDrafts, busyKey,
  onListCompany, onListFactory, onPlaceBid, formatAuctionRemaining,
}: BusinessAuctionsPanelProps) {
  return (
    <div className="space-y-4">
      <section className="rounded-xl border border-amber-400/20 bg-amber-400/5 px-4 py-3 space-y-1">
        <p className="text-xs font-bold text-amber-200">{language === 'ar' ? 'عمولة البيع في المزادات: 4%' : 'Auction seller fee: 4%'}</p>
        <p className="text-xs text-[#C2C8D2]">{language === 'ar' ? 'تُخصم العمولة من البائع عند إتمام البيع، ويستلم البائع صافي 96% من سعر البيع النهائي. لا تُفرض هذه العمولة على المزايد.' : 'The fee is deducted from the seller when the auction closes. The seller receives 96% of the final sale price; bidders do not pay this fee.'}</p>
      </section>
      <section className="rounded-2xl border border-amber-400/20 bg-[#141821] p-4 space-y-2">
        <div className="flex items-center gap-2 text-sm font-bold text-amber-200"><Gavel className="w-4 h-4" />{language === 'ar' ? 'مزاد الأعمال' : 'Business Auction'}</div>
        <p className="text-xs text-[#AAB1BD]">{language === 'ar' ? 'الشركات والمصانع من المستوى 50 فأعلى. مدة المزاد 24 ساعة، ويُحجز مبلغ العرض في الضمان حتى الفوز أو تجاوزه.' : 'Level 50+ companies and factories. Auctions last 24 hours; bids are held in escrow until settlement or being outbid.'}</p>
        <p className="text-xs text-[#9299A6]">{language === 'ar' ? 'المساحات المستخدمة: ' + occupiedCompanySlots + '/3 (الشركات المملوكة والعروض الأعلى)' : 'Company slots used: ' + occupiedCompanySlots + '/3 (owned companies and leading bids)'}</p>
      </section>
      <section className="rounded-2xl border border-white/8 bg-[#141821] p-4 space-y-3">
        <h3 className="text-sm font-bold text-[#F4F5F7]">{language === 'ar' ? 'إدراج شركة في المزاد' : 'List a company'}</h3>
        {visibleCompanies.filter((company) => company.level >= 50 && !company.auctionId).length === 0 ? <p className="text-xs text-[#9299A6]">{language === 'ar' ? 'لا توجد شركة مؤهلة حالياً. تحتاج الشركة إلى المستوى 50 على الأقل.' : 'No eligible company yet. A company must be level 50 or higher.'}</p> : visibleCompanies.filter((company) => company.level >= 50 && !company.auctionId).map((company) => (
          <div key={company.id} className="rounded-xl bg-[#0B0D12] border border-white/8 p-3 space-y-2">
            <div className="flex items-center justify-between gap-2"><span className="text-sm font-semibold text-[#F4F5F7]">{company.name}</span><span className="text-xs text-amber-200">Lv.{company.level}</span></div>
            <div className="flex gap-2"><input type="number" min="1" step="1" value={startingPrices[company.id] ?? '10000'} onChange={(e) => setStartingPrices((previous) => ({ ...previous, [company.id]: e.target.value }))} placeholder={language === 'ar' ? 'سعر البداية' : 'Starting price'} className="min-w-0 flex-1 min-h-[42px] rounded-xl bg-[#141821] border border-white/10 px-3 text-sm text-[#F4F5F7]" />
              <button type="button" disabled={busyKey === 'auction_list_' + company.id} onClick={() => onListCompany(company.id)} className="min-h-[42px] px-4 rounded-xl bg-[#B91C32] text-white text-xs font-semibold disabled:opacity-50">{language === 'ar' ? 'إدراج' : 'List'}</button></div>
          </div>
        ))}
      </section>
      <section className="rounded-2xl border border-white/8 bg-[#141821] p-4 space-y-3">
        <h3 className="text-sm font-bold text-[#F4F5F7]">{language === 'ar' ? 'إدراج مصنع في المزاد' : 'List a factory'}</h3>
        {factories.filter((factory) => factory.level >= 50 && !factory.auctionId).length === 0 ? <p className="text-xs text-[#9299A6]">{language === 'ar' ? 'لا يوجد مصنع مؤهل حالياً. يحتاج المصنع إلى المستوى 50 على الأقل.' : 'No eligible factory. Factories must be level 50 or higher.'}</p> : factories.filter((factory) => factory.level >= 50 && !factory.auctionId).map((factory) => (
          <div key={factory.id} className="rounded-xl bg-[#0B0D12] border border-white/8 p-3 space-y-2">
            <div className="flex items-center justify-between gap-2"><span className="text-sm font-semibold text-[#F4F5F7]">{factory.name}</span><span className="text-xs text-amber-200">Lv.{factory.level}</span></div>
            <div className="flex gap-2"><input type="number" min="1" step="1" value={startingPrices[factory.id] ?? '10000'} onChange={(e) => setStartingPrices((previous) => ({ ...previous, [factory.id]: e.target.value }))} placeholder={language === 'ar' ? 'سعر البداية' : 'Starting price'} className="min-w-0 flex-1 min-h-[42px] rounded-xl bg-[#141821] border border-white/10 px-3 text-sm text-[#F4F5F7]" />
              <button type="button" disabled={busyKey === 'auction_list_' + factory.id} onClick={() => onListFactory(factory.id)} className="min-h-[42px] px-4 rounded-xl bg-[#B91C32] text-white text-xs font-semibold disabled:opacity-50">{language === 'ar' ? 'إدراج' : 'List'}</button></div>
          </div>
        ))}
      </section>
      <section className="space-y-3">
        <h3 className="text-sm font-bold text-[#F4F5F7]">{language === 'ar' ? 'المزادات المتاحة' : 'Available auctions'}</h3>
        {activeAuctions.length === 0 ? <div className="rounded-2xl border border-white/8 bg-[#141821] p-8 text-center text-sm text-[#9299A6]">{language === 'ar' ? 'لا توجد مزادات نشطة حالياً.' : 'There are no active auctions right now.'}</div> : activeAuctions.map((auction) => {
          const isLeading = auction.highestBidderUid === profileUid;
          const isSeller = auction.sellerUid === profileUid;
          const minBid = auction.highestBidderUid ? auction.currentPrice + 1 : auction.startingPrice;
          const canBid = !isSeller && (isLeading || (auction.assetType === 'factory' ? hasFactorySlot : hasCompanySlot));
          return (
            <article key={auction.id} className="rounded-2xl border border-white/8 bg-[#141821] p-4 space-y-3">
              <div className="flex items-start justify-between gap-3"><div><h4 className="text-sm font-bold text-[#F4F5F7]">{auction.companyName}</h4><p className="mt-1 text-xs text-[#9299A6]">{auction.assetType === 'factory' ? (language === 'ar' ? 'مصنع' : 'Factory') : (language === 'ar' ? 'شركة' : 'Company')} · {language === 'ar' ? 'البائع' : 'Seller'}: {auction.sellerName} · Lv.{auction.companyLevel}</p></div>{isLeading && <span className="rounded-lg bg-emerald-500/10 px-2 py-1 text-[10px] text-emerald-300">{language === 'ar' ? 'أنت الأعلى' : 'You lead'}</span>}</div>
              <div className="grid grid-cols-2 gap-2 rounded-xl bg-[#0B0D12] p-3">
                <div><p className="text-[10px] text-[#9299A6]">{language === 'ar' ? 'سعر البداية' : 'Starting price'}</p><p className="text-sm font-mono-num font-semibold text-[#F4F5F7]">{'$'}{auction.startingPrice.toLocaleString()}</p></div>
                <div><p className="text-[10px] text-[#9299A6]">{language === 'ar' ? 'أعلى عرض' : 'Highest bid'}</p><p className="text-sm font-mono-num font-semibold text-amber-200">{'$'}{auction.currentPrice.toLocaleString()}</p></div>
              </div>
              <div className="flex items-center gap-2 text-xs text-[#9299A6]"><Clock className="w-3.5 h-3.5" />{language === 'ar' ? 'ينتهي خلال' : 'Ends in'} {formatAuctionRemaining(auction.endsAt)}</div>
              {auction.highestBidderName && <p className="text-[11px] text-[#9299A6]">{language === 'ar' ? 'صاحب أعلى عرض:' : 'Leading bidder:'} {auction.highestBidderName}</p>}
              {!isSeller && <div className="space-y-2">
                <input type="number" min={minBid} step="1" value={bidDrafts[auction.id] ?? String(minBid)} onChange={(e) => setBidDrafts((previous) => ({ ...previous, [auction.id]: e.target.value }))} disabled={!canBid || busyKey === 'auction_bid_' + auction.id} className="w-full min-h-[42px] rounded-xl bg-[#0B0D12] border border-white/10 px-3 text-sm text-[#F4F5F7] disabled:opacity-50" />
                <button type="button" disabled={!canBid || busyKey === 'auction_bid_' + auction.id} onClick={() => onPlaceBid(auction)} className="w-full min-h-[42px] rounded-xl bg-[#B91C32] text-white text-xs font-semibold disabled:opacity-40">{busyKey === 'auction_bid_' + auction.id ? '...' : isLeading ? (language === 'ar' ? 'ارفع عرضك' : 'Raise your bid') : (language === 'ar' ? 'تقديم عرض شراء' : 'Place bid')}</button>
                {!canBid && <p className="text-[11px] text-rose-300">{language === 'ar' ? 'لا توجد مساحة متاحة ضمن حد 3 شركات.' : 'No free company slot under the three-company limit.'}</p>}
              </div>}
              <p className="text-[10px] text-[#77808F]">{language === 'ar' ? 'يُحجز كامل عرضك في الضمان. عند تجاوزك أو إلغاء البيع يُعاد المبلغ تلقائياً.' : 'Your full bid is held in escrow and automatically refunded if outbid or the sale is cancelled.'}</p>
            </article>
          );
        })}
      </section>
    </div>
  );
}
