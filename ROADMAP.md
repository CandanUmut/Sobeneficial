# ROADMAP.md

# SoBeneficial Roadmap (SoBeneficial / BeneFiSocial)

Bu roadmap, Notion’da tuttuğumuz daha detaylı planın “repo içi” yaşayan özeti gibi düşünülmeli.
Hedef: Zehirli sosyal medya yerine, toplulukları büyüten ve insanlara gerçek fayda sağlayan bir community-network.

## Ürün Vizyonu (Özet)
- Topluluk-önce (community-first) mimari
- Her topluluğun kendi mini sosyal alanı (modüllerle)
- Güvenlik, mahremiyet, moderasyon ve şeffaf kurallar temel öncelik
- “Donated Sessions” ile güvenli ve etik destek mekanizması
- Nonprofit/mission-first yaklaşım: engagement bait yok, rage algoritması yok

---

## 0) Netleştirme: Ürün Çerçevesi ve Bilgi Mimarisi (Hemen)
**Amaç:** Her sayfanın/ekranın profesyonel hale gelmesi için ortak bir tasarım dili + modüler yapı.

### Teslimatlar
- **Information Architecture**: Ana navigasyon ve sayfa hiyerarşisi
  - Home (Discovery)
  - Communities
  - Community Space (modüler)
  - Q&A
  - Mentorship
  - Donated Sessions
  - Resources
  - Events
  - Moderation / Reports
  - Profile / Settings
- **Design System v1 (Flutter)**:
  - Typography scale, spacing, color tokens
  - Component library (Button, Card, Input, Tag, ListTile, Sheet, Dialog, Empty states)
  - Accessibility: kontrast, font scaling, screen reader etiketleri
- **API Contract Draft** (FastAPI):
  - Versiyonlama, pagination standardı, error formatı
  - Auth/roles modeli
  - Rate limiting yaklaşımı (MVP seviyesinde bile)

---

## 1) MVP-1: Topluluk Çekirdeği (Core Community)
**Hedef:** Kullanıcılar topluluk oluşturabilsin, katılabilsin, içerik üretebilsin ve basic moderasyon çalışsın.

### Özellikler
- Auth (Supabase Auth) + profile
- Community:
  - create / join / leave
  - public / private / hybrid
  - roles: owner, admin, moderator, member, guest
  - community rules + onboarding
- Community Feed (basit):
  - post oluşturma (text + link)
  - comment
  - basic reactions (like vb.)
- Moderasyon v1:
  - report content/user
  - moderator review queue
  - ban/mute (community scope)

### Teknik Çıktılar
- **DB Schema v1** (Postgres):
  - users/profile
  - communities
  - community_members
  - posts, comments, reactions
  - reports, moderation_actions
- **RLS v1** (minimum güvenlik standardı)
- Flutter’da “community shell” (community içi sayfalar arası geçiş)

---

## 2) MVP-2: Modüler Community Space (Her topluluk kendi araçlarını seçsin)
**Hedef:** Topluluğun ihtiyacına göre modüller aç/kapa.

### Modüller
- Q&A Board
- Resources / Library
- Events
- Mentorship Directory
- Jobs/Collaboration Board (basit)

### Teknik
- Community module settings table (hangi modüller açık)
- Modül bazlı yetki kontrolü (backend + RLS)
- Arama (MVP düzeyi): başlık/etiket üzerinden

---

## 3) MVP-3: Donated Sessions (Etik + güvenli yardım sistemi)
**Hedef:** “Yardım” mekanizmasını suistimal edilmez ve güvenli hale getirerek sisteme koymak.

### Özellikler (MVP)
- Session offering: slot oluşturma (konu, süre, dil, uygunluk)
- Request flow: talep + onay/red + planlama
- Basit eşleşme: kategori + uygunluk + topluluk bağlamı
- Review/feedback (çok kontrollü)
- Safety: boundary & disclaimer ekranları

### Güvenlik / Uyum
- Profesyoneller için doğrulama opsiyonu (ileride)
- Hassas kategoriler için ek kural/uyarı (hukuk, mental health vb.)
- “Platform yerine profesyonel hizmet” olmadığını net belirtme

---

## 4) Trust & Safety: MVP’den Önce/İçinde Sürekli (Non-negotiable)
**Hedef:** “Faydalı” hedefinin kilidi güvenlik.

- Reporting + moderator tools (queue, filters, bulk actions)
- Abuse prevention:
  - rate limiting (API)
  - spam detection (basit heuristic)
  - shadow-ban / cooldown gibi güvenli mekanizmalar
- Privacy:
  - private community content izolasyonu
  - profile visibility ayarları
- Audit logs:
  - moderation_actions kayıtları
  - critical actions log (role change vb.)

---

## 5) Scaling & Performance (Gerçekçi büyüme planı)
**Amaç:** İlk günden dev ölçek değil, ama “yol doğru” olsun.

### DB / Postgres
- Index planı:
  - posts (community_id, created_at)
  - comments (post_id, created_at)
  - membership (community_id, user_id)
  - reports (status, created_at)
- Pagination standardı: cursor-based (created_at + id)
- Soft delete stratejisi (moderasyon için)
- Read-optimized views / materialized views (gerekirse)
- Search:
  - Basit LIKE ile başla
  - Sonra Postgres full-text search (tsvector)
  - Çok büyürse ayrı arama servisi

### Backend
- Background jobs (ileride): bildirim, email, cleanup, analytics
- Caching (MVP sonrası): community feed caching
- Observability:
  - structured logs
  - error tracking (Sentry vb. opsiyon)
  - performance metrics

### Flutter
- State management standardı (ör. Riverpod/Bloc seçimi ve convention)
- Offline cache (read-only) + optimistic UI (kısıtlı)
- Image handling / CDN (ileride)

---

## 6) Profesyonelleştirme: Her Sayfanın Tek Tek “Product-grade” Yapılması
**Hedef:** Notion’daki “sayfa bazlı iyileştirme” işini repo roadmap’e bağlamak.

Her ekran için checklist:
- UX akışları (happy path + edge cases)
- Empty state / error state
- Loading skeleton
- Permission state (kullanıcı rolü)
- Copywriting / mikro metinler
- Analytics events (minimum)
- A11y kontrolleri
- Test senaryoları

---

## 7) Test & CI/CD
- Backend:
  - unit tests (services)
  - integration tests (DB + RLS kritik senaryolar)
- Flutter:
  - widget tests (core components)
  - golden tests (design system kritik ekranlar)
- CI:
  - lint + format
  - test pipeline
  - secret scanning (GitHub)
  - dependency alerts

---

## 8) Açık Sorular / Kararlar (Karar Defteri)
- Multi-tenant model: community-level isolation ne kadar “hard” olmalı?
- Auth & roles: global admin var mı? nonprofit moderation nasıl olacak?
- Donated sessions: doğrulama seviyesi MVP’de ne kadar?
- Ücret / bağış / sürdürülebilirlik modeli (ileride): platformu zehirlemeyecek şekilde nasıl?

---

## Notion ↔ Repo Senkronu
- Notion: detay, task’ler, sprint planları
- Repo: bu dosya “kuzey yıldızı”, ana milestone’lar ve teknik prensipler

> Bu roadmap “living document”tir. PR ile güncellenebilir.
