# SoBeneficial Roadmap

[English](#english) | [Türkçe](#turkce)

## English
This roadmap mirrors the current repository reality: FastAPI and Flutter scaffolds exist, a reference Supabase schema lives in `benefisocial.sql`, but migrations/RLS policies and CI are still to be added. Milestones focus on making each screen “product-grade”, hardening security, and aligning Notion planning with GitHub issues.

### Milestones
- **MVP-0: Foundations (current state → short term)**
  - Stabilize local dev: documented env vars, working health check, Supabase connection verified.
  - Add minimal RLS policies for `profiles`, `rfh`, `offers`, `projects`, `events`, `comments`, `reports` with deny-by-default.
  - CI skeleton: lint + format for backend and Flutter, secret scanning enabled.
- **MVP-1: Core Communities & Trust**
  - Community membership model + role checks (owner/admin/mod/member/guest).
  - Content primitives: posts/comments/reactions with RLS that enforces membership and author/moderator update rules.
  - Reporting + moderator queue; audit log for role changes and bans.
  - Flutter: auth guard + community shell navigation and basic feed/Q&A readers.
- **MVP-2: Modular Community Space**
  - Community module settings table to toggle Q&A, resources, events, mentorship, jobs/collab.
  - Backend authorization per module; lightweight search (title/tag) and pagination.
  - Flutter UI for module toggles and list/detail for Q&A, events, resources.
- **MVP-3: Donated Sessions (safe & explicit)**
  - Offer slots, requests, approvals, and scheduling scaffolds with mandatory disclaimers.
  - Optional verification flows for sensitive categories; per-community safety presets.
  - Feedback loop with carefully scoped ratings; anti-harassment protections and cooldowns.
- **MVP-4: Reliability & Scale**
  - Background jobs for notifications/cleanup, caching for hot feeds, structured logging and metrics.
  - Postgres performance: indexes on membership/content tables, materialized views if needed, FTS for Q&A/resources.
  - Rate limiting across auth endpoints and content creation.

### Page-by-page professionalization (repeat per screen)
For each screen (auth, community list, community home, Q&A, resources, events, donated sessions, profile/settings):
- UX: happy path + edge cases, empty/error/loading states
- Permissions: copy and UI for role-based restrictions
- Accessibility: semantic labels, contrast, focus order, screen reader hints
- Content design: microcopy for safety/disclaimers, reporting affordances
- Observability: analytics events, error logging hooks
- Tests: widget tests (Flutter) and integration tests (backend + RLS)

### Database evolution plan
- Start from `benefisocial.sql` as reference; port into migrations with explicit `ENABLE ROW LEVEL SECURITY` per table.
- Tables to prioritize: `profiles`, `communities` (or equivalent membership tables), `rfh`, `offers`, `projects`, `events`, `comments`, `reports`, `notifications`.
- Indexing: `(community_id, created_at)` on content tables; `(user_id, community_id)` on membership; `(status, created_at)` on reports; trigram/FTS on Q&A/resources.
- Soft deletes for moderated content; audit tables for role changes and bans.

### Backend architecture plan
- API versioning remains at `/api/v1`; add consistent pagination and error envelope.
- Auth guards: dependency layer that checks `auth.uid()` against membership/role before handlers.
- Background jobs (post-MVP): notifications, cleanup, async verifications.
- Caching: simple per-community feed cache after RLS is proven; invalidate on write.

### Security milestones
- Deny-by-default RLS with membership + role checks; integration tests for IDOR/role escalation.
- Service role key only in backend; anon key in Flutter; secrets in GitHub Actions once CI is added.
- Rate limiting at auth and write-heavy endpoints; spam controls for reports/comments.
- Audit logs for moderation actions and role changes; periodic review.

### Notion → GitHub workflow
- Keep detailed tasks in Notion, but open GitHub issues for each deliverable.
- Use labels such as `backend`, `frontend`, `security`, `design-system`, `rls`, `docs`.
- Group issues under GitHub milestones that mirror MVP phases above.
- Update this roadmap as milestones close; summarize Notion decisions in PR descriptions.

## Türkçe
Bu roadmap mevcut depo durumunu yansıtır: FastAPI ve Flutter iskeletleri var, `benefisocial.sql` içinde referans Supabase şeması tutuluyor, ancak migration/RLS ve CI henüz eklenmedi. Odak, her ekranı “ürün kalitesine” taşımak, güvenliği sertleştirmek ve Notion planlarını GitHub issue’larıyla hizalamaktır.

### Milestone’lar
- **MVP-0: Temeller (mevcut durum → kısa vadeli)**
  - Lokal geliştirme stabil: dokümante env değişkenleri, çalışan health check, Supabase bağlantısı doğrulandı.
  - `profiles`, `rfh`, `offers`, `projects`, `events`, `comments`, `reports` tablolarında deny-by-default RLS politikaları.
  - CI iskeleti: backend ve Flutter için lint/format; secret scanning açık.
- **MVP-1: Çekirdek Topluluk & Güven**
  - Topluluk üyeliği modeli + rol kontrolleri (owner/admin/mod/member/guest).
  - İçerik temel nesneleri: post/comment/reaction RLS ile üyelik ve yazar/moderator güncelleme kuralları.
  - Raporlama + moderator kuyruğu; rol değişimi ve ban’ler için audit log.
  - Flutter: auth guard + topluluk kabuğu navigasyonu, temel feed/Soru-Cevap görüntüleyicileri.
- **MVP-2: Modüler Topluluk Alanı**
  - Topluluk modül ayar tablosu ile Soru-Cevap, kaynaklar, etkinlikler, mentorluk, işler/işbirlikleri aç/kapa.
  - Modül bazlı yetkilendirme; başlık/etiket araması ve pagination.
  - Flutter UI: modül ayarları ve Q&A/etkinlik/kaynak liste-detayları.
- **MVP-3: Bağış Seansları (güvenli ve açık sınırlar)**
  - Slot açma, talep, onay/red ve planlama iskeletleri; zorunlu uyarı metinleri.
  - Hassas kategoriler için opsiyonel doğrulama; topluluk bazlı güvenlik şablonları.
  - Sınırlı kapsamlı geri bildirim/derecelendirme; taciz karşıtı korumalar ve cooldown’lar.
- **MVP-4: Dayanıklılık ve Ölçek**
  - Bildirim/temizlik için background job’lar, sıcak feed’ler için caching, yapılandırılmış log ve metrikler.
  - Postgres performansı: üyelik/içerik tablolara indeks, gerekirse materialized view, Soru-Cevap/kaynaklar için FTS.
  - Auth ve yazma yoğun endpoint’lerde rate limiting.

### Sayfa bazlı profesyonelleştirme (her ekran için tekrar)
Auth, topluluk listesi, topluluk ana sayfası, Soru-Cevap, kaynaklar, etkinlikler, bağış seansları, profil/ayarlar ekranları için:
- UX: mutlu yol + edge case, empty/error/loading durumları
- Yetkiler: role göre kopya ve UI kısıtları
- Erişilebilirlik: semantik etiketler, kontrast, odak sırası, screen reader ipuçları
- İçerik tasarımı: güvenlik uyarıları, raporlama seçenekleri
- Gözlemlenebilirlik: analytics olayları, hata log’lama noktaları
- Testler: widget testleri (Flutter) ve entegrasyon testleri (backend + RLS)

### Veritabanı evrimi
- `benefisocial.sql` referans alınarak migration’lara taşının; her tabloda `ENABLE ROW LEVEL SECURITY` açık olsun.
- Öncelikli tablolar: `profiles`, `communities` (veya eşdeğer üyelik tabloları), `rfh`, `offers`, `projects`, `events`, `comments`, `reports`, `notifications`.
- İndeksleme: içerik tablolarında `(community_id, created_at)`; üyelikte `(user_id, community_id)`; raporlarda `(status, created_at)`; Soru-Cevap/kaynaklarda trigram/FTS.
- Moderasyon için soft delete; rol değişimi ve ban’ler için audit tabloları.

### Backend mimarisi
- API versiyonlaması `/api/v1` ile devam; tutarlı pagination ve hata formatı eklenir.
- Auth guard: handler öncesi `auth.uid()` + üyelik/rol kontrolü yapan dependency katmanı.
- Background job’lar (MVP sonrası): bildirim, temizlik, async doğrulamalar.
- Caching: RLS doğrulandıktan sonra topluluk feed’i için basit cache ve invalidation.

### Güvenlik hedefleri
- Deny-by-default RLS, üyelik + rol kontrolü; IDOR/rol yükseltme için entegrasyon testleri.
- Service role key sadece backend’de; anon key Flutter’da; CI için secret’lar GitHub Secrets’ta.
- Auth ve yazma yoğun endpoint’lerde rate limit; rapor/comment spam kontrolleri.
- Moderasyon aksiyonları ve rol değişimleri için audit log; periyodik inceleme.

### Notion → GitHub iş akışı
- Detaylı görevler Notion’da tutulsa da her teslimat için GitHub issue açın.
- `backend`, `frontend`, `security`, `design-system`, `rls`, `docs` gibi etiketler kullanın.
- Issue’ları yukarıdaki MVP aşamalarına denk gelen GitHub milestone’larında toplayın.
- Milestone’lar kapanırken bu roadmap’i güncelleyin; Notion kararlarını PR açıklamalarında özetleyin.
