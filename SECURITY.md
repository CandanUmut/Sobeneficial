# Security Policy | Güvenlik Politikası

[English](#english) | [Türkçe](#turkce)

## English
SoBeneficial uses FastAPI with Supabase Postgres/Auth. The repo currently contains a reference schema (`benefisocial.sql`) and environment examples but no migrations or RLS policies; treat production hardening as a priority.

### Reporting a vulnerability
- **Do not** open public issues for security concerns or risks of harm.
- Use GitHub Security Advisories (Security → Advisories → “New draft advisory”).
- If that is not possible, contact maintainers privately at `security@sobeneficial.org` (placeholder—replace when available).
- Include: impact, reproducible steps, affected endpoint/table/policy, and suggested mitigations.

### Threat model (focus areas)
- Private community data leakage (missing RLS/membership checks)
- Role escalation (member → moderator/admin) and IDOR
- Abuse/spam of reporting or posting endpoints
- Secret leakage (Supabase service role key, database URL)
- Donated Sessions misuse (impersonation, unsafe advice) if/when implemented

### Supabase RLS principles
- **Deny-by-default**: `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` and no permissive default policy.
- **Auth binding**: use `auth.uid()`; never trust client-provided user IDs.
- **Membership & role checks**: join membership/role tables to gate read/write (owner/admin/mod/member/guest).
- **Visibility tiers**: public communities/tables should still restrict writes; reads should filter to allowed rows.

### Policy patterns for key tables (adapt to your schema)
- `profiles`: users can `SELECT/UPDATE` only their own row; moderators may read limited fields for enforcement.
- `rfh`, `offers`, `projects`, `events`, `comments`: `SELECT/INSERT` only if the user is a member of the related community; `UPDATE/DELETE` only by author or moderator/admin.
- `reports`: any member can `INSERT`; `SELECT` only by moderators/admins and optionally the reporter.
- `notifications`: `SELECT` only for the recipient user; inserts via backend service role.
- `views`/analytics tables: write via backend only; restrict `SELECT` to aggregated views if exposed.
- Future `donated_sessions` tables: enforce community membership, require explicit safety acknowledgment flags, and log all status transitions.

### Service role & keys
- Keep the **service role key** only in backend/secret storage. Do not embed it in Flutter or the repo.
- The Flutter app should use only the Supabase anon key and call backend endpoints for privileged actions.
- Rotate keys promptly after leaks or environment resets.

### Backend authorization patterns
- Centralize authorization in FastAPI dependencies that:
  - Validate JWT via Supabase JWKS (`SUPABASE_JWKS_URL`) and audience.
  - Load membership/role from the database before entering handlers.
  - Enforce object-level checks (resource belongs to the same community and user has permission).
- Avoid trusting IDs passed from the client without cross-checking ownership/membership.

### Rate limiting and abuse controls
- Apply rate limits to auth, post/comment creation, report submission, and session offering/request endpoints.
- Combine IP + user-based limits; add spam heuristics (duplicate content, rapid repeats).
- Implement cooldowns for sensitive actions (e.g., repeated reports or session requests).

### Audit logging
- Log moderation actions, role changes, bans/mutes, and donated session status changes.
- Avoid logging PII; include request IDs/user IDs (masked) for traceability.

### Recommended tests
- Integration tests for RLS:
  - Non-member cannot read or write private community content.
  - Member cannot edit another member’s post/comment unless moderator.
  - Role change endpoints reject non-admins.
- API tests for IDOR and pagination-based data leaks.
- Dependency and secret scanning in CI.

### Next steps for this repo
- Translate `benefisocial.sql` into migrations and enable RLS on each table with the patterns above.
- Add automated RLS integration tests for `profiles`, `rfh`, `offers`, `projects`, `events`, `comments`, and `reports`.
- Wire GitHub Actions for lint/format/tests and enable secret scanning and Dependabot.
- Document safety disclaimers and verification paths for Donated Sessions before launch.

---

## Türkçe
SoBeneficial, Supabase Postgres/Auth üzerinde çalışan bir FastAPI projesidir. Repoda referans şema (`benefisocial.sql`) ve ortam örnekleri bulunuyor; migration ve RLS politikaları henüz eklenmedi, bu yüzden üretim ortamında sert güvenlik şarttır.

### Güvenlik açığı bildirimi
- Güvenlik veya zarar riski durumlarını **public issue** olarak açmayın.
- GitHub Security Advisories kullanın (Security → Advisories → “New draft advisory”).
- Bu mümkün değilse `security@sobeneficial.org` (yerine gerçek iletişim eklenecek) adresine özelden ulaşın.
- Etki, tekrarlanabilir adımlar, etkilenen endpoint/tablo/policy ve önerilen düzeltmeleri ekleyin.

### Tehdit modeli (odak noktaları)
- Özel topluluk verilerinin sızması (eksik RLS/üyelik kontrolü)
- Rol yükseltme (member → moderator/admin) ve IDOR
- Raporlama veya içerik üretimi endpoint’lerinin spam/abuse kullanımı
- Gizli anahtar sızıntısı (Supabase service role key, database URL)
- Bağış Seansları kötüye kullanımı (kimlik taklidi, güvensiz yönlendirme) uygulanırsa

### Supabase RLS ilkeleri
- **Varsayılan red**: `ALTER TABLE ... ENABLE ROW LEVEL SECURITY` ve izin verici varsayılan policy olmamalı.
- **Kimlik bağlama**: `auth.uid()` kullanın; istemcinin gönderdiği user ID’ye güvenmeyin.
- **Üyelik ve rol kontrolü**: üyelik/rol tablolarıyla join ederek okuma/yazma yetkisi verin (owner/admin/mod/member/guest).
- **Görünürlük katmanları**: public içerik bile yazmalarda kısıtlanmalı; okumalar izin verilen satırlarla sınırlandırılmalı.

### Kritik tablolar için policy örüntüleri (şemanıza uyarlayın)
- `profiles`: kullanıcı yalnızca kendi satırını `SELECT/UPDATE` edebilir; moderator’ler denetim için sınırlı alanları okuyabilir.
- `rfh`, `offers`, `projects`, `events`, `comments`: ilgili topluluk üyesi olanlar `SELECT/INSERT`; `UPDATE/DELETE` sadece yazar veya moderator/admin.
- `reports`: her üye `INSERT` yapabilir; `SELECT` sadece moderator/admin ve opsiyonel olarak raporu açan kişi.
- `notifications`: yalnızca alıcı kullanıcı `SELECT` edebilir; ekleme backend service role ile yapılır.
- `views`/analitik tabloları: yazma sadece backend’den; açılacaksa agregalar üzerinden sınırlı `SELECT`.
- Gelecek `donated_sessions` tabloları: topluluk üyeliği şartı, güvenlik uyarısı onayı ve tüm durum değişimlerinin loglanması.

### Service role ve anahtarlar
- **Service role key** sadece backend/secret storage ortamlarında tutulmalı. Flutter veya repoya eklemeyin.
- Flutter uygulaması yalnızca Supabase anon key’i kullanmalı; ayrıcalıklı işlemler backend API üzerinden yapılmalı.
- Anahtar sızıntısı veya ortam sıfırlamasında hızlıca rotasyon yapın.

### Backend yetkilendirme desenleri
- FastAPI dependency katmanında merkezi kontroller:
  - JWT’yi Supabase JWKS (`SUPABASE_JWKS_URL`) ve audience ile doğrulama.
  - Handler öncesi veritabanından üyelik/rol yükleme.
  - Nesne seviyesinde kontrol (kaynak aynı topluluğa ait mi, kullanıcı yetkili mi?).
- İstemciden gelen ID’lere körü körüne güvenmeyin; sahiplik/üyelikle çapraz kontrol yapın.

### Rate limiting ve abuse önlemleri
- Auth, post/comment oluşturma, rapor gönderme ve seans açma/talep etme endpoint’lerinde rate limit uygulayın.
- IP + kullanıcı bazlı limitleri birleştirin; spam için içerik tekrarı gibi basit heuristikler ekleyin.
- Hassas aksiyonlar için cooldown (ör. arka arkaya rapor/seans talebi) ekleyin.

### Audit loglama
- Moderasyon aksiyonları, rol değişimleri, ban/mute ve bağış seansı durum değişimleri loglanmalı.
- PII loglamaktan kaçının; izlenebilirlik için maskeleme ve request ID kullanın.

### Önerilen testler
- RLS entegrasyon testleri:
  - Üye olmayan kullanıcı özel topluluk içeriğini okuyamaz/yazamaz.
  - Üye başka bir üyenin post/comment’ini moderator değilse değiştiremez.
  - Rol değiştirme endpoint’leri admin olmayanları reddeder.
- API testleri: IDOR ve pagination üzerinden veri sızması denemeleri.
- CI’de dependency ve secret taraması.

### Bu repo için sonraki adımlar
- `benefisocial.sql` şemasını migration’lara taşıyıp her tabloda RLS’i etkinleştirin ve yukarıdaki desenlerle policy yazın.
- `profiles`, `rfh`, `offers`, `projects`, `events`, `comments`, `reports` için otomatik RLS entegrasyon testleri ekleyin.
- Lint/format/test ve secret scanning içeren GitHub Actions yapılandırın; Dependabot’u açın.
- Bağış Seansları için güvenlik uyarıları ve doğrulama yollarını yazılı hale getirmeden yayınlamayın.
