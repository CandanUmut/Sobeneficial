# SECURITY.md

# Security Policy — SoBeneficial

SoBeneficial; FastAPI (Python) backend, Supabase (Postgres) veritabanı ve Flutter (Dart) istemci ile geliştirilir.
Bu projede güvenlik, özellikle **RLS (Row Level Security)** ve erişim kontrolü açısından kritik önceliktir.

---

## 1) Supported Versions
Proje aktif geliştirme aşamasında olduğu için “latest main” hedeflenir.
Üretim ortamı oluştuğunda sürümleme ve destek politikası netleştirilecektir.

---

## 2) Reporting a Vulnerability (Güvenlik Açığı Bildirimi)

Lütfen güvenlik açıklarını **public issue** olarak paylaşmayın.

Tercih edilen yöntemler:
1. **GitHub Security Advisories** (repo → Security → Advisories → New draft)
2. Eğer advisory kullanamıyorsanız: repo sahiplerinin README’de belirttiği güvenlik iletişim kanalına yazın.

Bildirimde şu bilgileri paylaşmak çok yardımcı olur:
- Açığın kısa özeti ve etkisi (impact)
- Tekrarlanabilir adımlar (PoC mümkünse)
- Etkilenen endpoint / tablo / policy
- Önerilen fix fikri (varsa)

> Not: Bu proje “community safety” odaklı olduğu için, özellikle yetkisiz veri erişimi (RLS bypass), private community leak, auth/role escalation gibi açıklar yüksek önceliklidir.

---

## 3) Threat Model (Kısa)
Öncelikli tehditler:
- Private community içerik sızıntısı
- Yetkisiz okuma/yazma (RLS eksik/yanlış)
- Role escalation (member → moderator/admin)
- Spam/abuse (rate limit eksikliği)
- Secret leak (Supabase service role key vb.)
- Insecure direct object reference (IDOR)

---

## 4) Supabase / Postgres RLS: Minimum Güvenlik Standardı (MVP için bile şart)

### 4.1 RLS temel kuralları
- Tüm “user data” içeren tablolarda: **ALTER TABLE ... ENABLE ROW LEVEL SECURITY**
- Default: **deny-by-default** (policy yoksa erişim yok)
- Policy’lerde:
  - `auth.uid()` ile kullanıcı kimliği doğrula
  - Community membership kontrolü yap
  - Role check (admin/moderator) için membership tablosunu referans al
- `anon` erişimi minimumda olmalı (public content bile kontrollü)

### 4.2 Kritik tablolar için beklenen policy yaklaşımı
Aşağıdaki tablolar *örnek* kapsamdır:
- `profiles`
- `communities`
- `community_members`
- `posts`
- `comments`
- `reactions`
- `reports`
- `moderation_actions`
- `donated_sessions` (ileride)
- `session_requests` (ileride)

**Örnek kurallar:**
- Private community posts:
  - SELECT: sadece topluluk üyesi
  - INSERT: sadece topluluk üyesi
  - UPDATE/DELETE: yazar veya moderator/admin
- community_members:
  - SELECT: sadece topluluk üyesi (veya topluluk public ise sınırlı alan)
  - UPDATE role: sadece owner/admin
- reports:
  - INSERT: üyeler report açabilsin
  - SELECT: sadece moderator/admin (raporlayan kişi kendi raporunu görebilir opsiyon)

### 4.3 Service role key
- Supabase **service role key** sadece backend’de (FastAPI) tutulmalı.
- Flutter uygulamasına **asla** konmamalı.
- Repo’ya **asla** commit edilmemeli.

---

## 5) Backend (FastAPI) Security Baseline

### 5.1 Auth / Authorization
- JWT doğrulama zorunlu
- Endpoint bazlı role-check:
  - “member-only”, “moderator-only”, “admin-only” guard’ları
- “Object-level authorization”:
  - sadece `community_id` göndermek yetmez; kullanıcının o community’de yetkisi kontrol edilmeli

### 5.2 Rate limiting & abuse
- MVP bile olsa:
  - login / signup / password reset rate limit
  - post/comment/create rate limit
  - report spam koruması
- IP + user-based limit kombinasyonu önerilir

### 5.3 Input validation
- Pydantic schema strict validation
- File upload varsa: content-type / size limit / virus scan (ileride)
- XSS riskine karşı: frontend render’da güvenli escaping

### 5.4 Logging & Audit
- Role change, ban/mute, delete gibi kritik aksiyonlar audit log’a düşmeli
- PII log’lanmamalı
- Structured logs (request_id, user_id masked)

---

## 6) Frontend (Flutter) Güvenlik Notları
- Client “güvenlik duvarı” değildir:
  - tüm yetki kontrolleri backend + RLS’de olmalı
- Token storage:
  - secure storage kullan
- Deep link / navigation:
  - IDOR’a yol açacak şekilde “id” ile veri çekme yaparken server-side authorization şart

---

## 7) Secrets Management
- `.env` dosyaları gitignore’da olmalı
- CI/CD’de secret’lar güvenli store’da tutulmalı (GitHub Secrets)
- “public key” ile “service role key” ayrımı net olmalı
- Supabase URL + anon key client’ta olabilir; service role olmaz

---

## 8) Security Checklist (Hızlı Kontrol)
- [ ] RLS tüm tablolar için enabled
- [ ] Policy’ler deny-by-default
- [ ] Private community isolation test edildi
- [ ] Role escalation test edildi
- [ ] Service role key sadece backend
- [ ] Rate limiting aktif
- [ ] Audit log var
- [ ] Dependency scanning açık
- [ ] GitHub secret scanning açık

---

## 9) Güvenlik Testleri (Öneri)
- Integration test: RLS policy testleri (en kritik)
  - Üye olmayan kullanıcı private community post görebiliyor mu? (görememeli)
  - Member başka member’ın private data’sına erişebiliyor mu? (kuralına göre)
  - Member moderator endpoint’ine erişebiliyor mu? (hayır)
- Basit “attack suite”:
  - IDOR denemeleri
  - role change denemeleri
  - pagination üzerinden veri sızdırma denemeleri

---

## 10) Public Communication
Güvenlik açıkları doğrulanmadan kamuya duyurulmaz.
Fix çıktıktan sonra gerekiyorsa kontrollü bir advisory yayınlanır.

---

Bu dosya yaşayan bir belgedir. Güvenlik iyileştirmeleri PR ile eklenebilir.
