# SoBeneficial 

[English](#english) | [Türkçe](#turkce)

## English

### What is SoBeneficial?
SoBeneficial is a community-first social network designed to be beneficial rather than addictive or toxic. Each community is its own mini social space with optional modules (Q&A, resources, events, mentorship, jobs/collaboration) and a carefully guarded **Donated Sessions** concept where volunteers or professionals can donate time slots safely and ethically. The project keeps a nonprofit/mission-first mindset—growth should not depend on rage or clickbait.

### Why mission-first?
Traditional social networks reward outrage and endless scrolling. SoBeneficial prioritizes:
- Community health over virality
- Privacy-by-default spaces for sensitive groups
- Transparent rules and moderation
- Supportive culture instead of clout chasing

### Key concepts
- **Community-first:** People join a context, not a global feed. Communities can be public, private, or hybrid.
- **Modular spaces:** Communities decide which modules are on (posts, Q&A, resources, events, mentorship, jobs/collab).
- **Donated Sessions:** Time-bounded help sessions with explicit boundaries and disclaimers; never a replacement for professional care.

### Where we are today (audit)
- **Backend:** FastAPI scaffold under `backend/` with health check, profile/auth helpers, and placeholder routes for RFH (requests-for-help), content, QA, projects, events, notifications, and matching. Uses async SQLAlchemy with Supabase Postgres connection handling and `.env.example` for configuration. No migrations or CI yet.
- **Database:** `benefisocial.sql` contains a non-runnable reference schema (tables like profiles, rfh, offers, projects, comments, events, reports). RLS policies are not codified in the repo yet.
- **Frontend:** Flutter shell in `frontend/` with Supabase client configuration in `lib/config.dart`, auth guard (GitHub/Google OAuth via Supabase), and skeleton screens for RFH and profiles. Requires manual URL/key configuration; no build scripts beyond standard Flutter commands.
- **Tooling/CI:** No GitHub Actions or linters are wired at the repo root. Backend and Flutter lint/test configs live in their directories. 
- **Docs & site:** Documentation is being refreshed in this PR. A simple GitHub Pages-friendly pitch site lives in `docs-site/`.

### Tech stack
- **Backend:** Python FastAPI + async SQLAlchemy, ORJSON, Loguru
- **Database:** Supabase Postgres (with RLS to be enforced), Supabase Auth JWKS verification
- **Frontend:** Flutter (Dart) + Supabase client

### Repository structure (high-level)
- `backend/` – FastAPI app (`app/main.py`, routers under `app/api/v1/`), `requirements.txt`, `.env.example`, dev scripts
- `frontend/` – Flutter project with `lib/config.dart`, platform folders, `analysis_options.yaml`
- `benefisocial.sql` – Reference schema (do not execute as-is)
- `docs-site/` – Static bilingual landing page for GitHub Pages (HTML/CSS/JS)
- `LICENSE` – GPL-3.0 license

### Getting started (local development)

#### Backend (FastAPI)
1. Install Python 3.11+ and create a virtual environment:
   ```bash
   cd backend
   python -m venv .venv
   source .venv/bin/activate  # Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```
2. Create your environment file:
   ```bash
   cp .env.example .env
   ```
3. Fill `.env` with your Supabase project values:
   - `DATABASE_URL`: Supabase Postgres URI with `?sslmode=require` (edit to use your credentials; the sample value is a placeholder).
   - `SUPABASE_JWKS_URL`: `https://<project>.supabase.co/auth/v1/.well-known/jwks.json`.
   - `SUPABASE_AUDIENCE`: Usually `authenticated`.
   - `CORS_ORIGINS`: Comma-separated origins (e.g., `http://localhost:3000`).
   - `DEV_ALLOW_UNVERIFIED`: `true` only for local/dev while wiring auth.
4. Run the API:
   ```bash
   ./uvicorn_dev.sh  # or: uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```
5. Open docs at http://127.0.0.1:8000/api/docs.

#### Frontend (Flutter)
1. Install Flutter and enable web support (`flutter config --enable-web`).
2. Configure Supabase and backend endpoints in `frontend/lib/config.dart` (replace the sample URL and anon key with your project’s values; keep service role keys out of the client).
3. Install dependencies and run:
   ```bash
   cd frontend
   flutter pub get
   flutter run -d chrome  # or another device
   ```

#### Supabase setup (example workflow)
1. Create a Supabase project; note the **Project URL**, **anon public key**, and **service role key**.
2. In Database settings, copy the connection string, switch the driver to `postgresql+asyncpg`, and keep `sslmode=require`.
3. Set `SUPABASE_JWKS_URL` using your project URL.
4. Enable RLS on tables you create; start with `profiles`, `rfh`, `offers`, `projects`, `events`, `comments`, `reports`, and any membership table you add. Policies should deny by default and check `auth.uid()` + membership/role.
5. Keep the **service role key** only in backend environments or secret managers—never in the Flutter app or the repo.

### Contributing
We welcome contributors across engineering, design, and community building.
- Open an issue for ideas, bugs, or security concerns.
- Keep PRs small and describe any schema or auth assumptions.
- Good first issues: documentation improvements, RLS policy tests, Flutter UI polish, GitHub Pages content.

### Roadmap & security
- Roadmap: [ROADMAP.md](./ROADMAP.md)
- Security guidance: [SECURITY.md](./SECURITY.md)
- Code of Conduct: [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)

### License
Licensed under [GPL-3.0](./LICENSE). If you need a different license for specific contributions, open an issue so we can discuss alignment with the mission-first goals.

---

## Türkçe

### SoBeneficial nedir?
SoBeneficial (eski adıyla BeneFiSocial), bağımlılık veya toksiklik yerine **gerçek fayda** üretmek için tasarlanmış topluluk-odaklı bir sosyal ağdır. Her topluluk kendi mini sosyal alanına ve açıp kapatabileceği modüllere sahiptir (Soru-Cevap, kaynaklar, etkinlikler, mentorluk, işler/işbirlikleri). **Bağış Seansları** modeliyle gönüllüler veya profesyoneller güvenli ve etik şekilde zaman dilimleri bağışlayabilir.

### Neden misyon-öncelikli?
Klasik sosyal ağlar öfke ve sonsuz kaydırmayı ödüllendiriyor. SoBeneficial ise şunları önceleyerek farklılaşır:
- Viral büyüme yerine topluluk sağlığı
- Hassas gruplar için varsayılan gizlilik
- Şeffaf kurallar ve moderasyon
- Ün peşinde koşmak yerine destekleyici kültür

### Temel kavramlar
- **Topluluk önce gelir:** İnsanlar global bir akışa değil, bağlama katılır. Topluluklar açık, kapalı veya hibrit olabilir.
- **Modüler alanlar:** Topluluk hangi modüllerin açık olacağını seçer (paylaşımlar, Soru-Cevap, kaynaklar, etkinlikler, mentorluk, işler/işbirlikleri).
- **Bağış Seansları:** Sınırları net, uyarıları belirgin zaman dilimleri; profesyonel hizmetin yerine geçmez.

### Güncel durum (denetim)
- **Backend:** `backend/` altında FastAPI iskeleti; sağlık kontrolü ve RFH, içerik, QA, projeler, etkinlikler, bildirimler, eşleştirme için taslak router’lar mevcut. Supabase Postgres’e async bağlantı yapısı ve `.env.example` var; migration/CI yok.
- **Veritabanı:** `benefisocial.sql` çalıştırılabilir değildir; profil, rfh, offers, projects, comments, events, reports gibi tabloları içeren referans şema olarak tutulur. RLS politikaları repoda tanımlı değil.
- **Frontend:** `frontend/` içinde Flutter kabuğu; `lib/config.dart` dosyasında Supabase istemcisi ayarları, Supabase OAuth guard’ı ve RFH/profil ekran taslakları var. URL/anahtarlar manuel doldurulmalı; standart Flutter komutları dışında ek script yok.
- **Araçlar/CI:** Repo kökünde GitHub Actions yok. Backend ve Flutter için format/lint ayarları kendi klasörlerinde.
- **Doküman & site:** Bu PR ile güncellendi. GitHub Pages uyumlu tanıtım sayfası `docs-site/` klasöründe.

### Teknoloji yığını
- **Backend:** Python FastAPI + async SQLAlchemy, ORJSON, Loguru
- **Veritabanı:** Supabase Postgres (RLS zorunlu), Supabase Auth JWKS doğrulaması
- **Frontend:** Flutter (Dart) + Supabase istemcisi

### Depo yapısı (özet)
- `backend/` – FastAPI uygulaması (`app/main.py`, `app/api/v1/` router’lar), `requirements.txt`, `.env.example`, geliştirme scriptleri
- `frontend/` – Flutter projesi, `lib/config.dart`, platform klasörleri, `analysis_options.yaml`
- `benefisocial.sql` – Referans şema (doğrudan çalıştırmayın)
- `docs-site/` – GitHub Pages için statik iki dilli tanıtım sayfası (HTML/CSS/JS)
- `LICENSE` – GPL-3.0 lisansı

### Başlarken (lokal geliştirme)

#### Backend (FastAPI)
1. Python 3.11+ kurun, sanal ortam oluşturun:
   ```bash
   cd backend
   python -m venv .venv
   source .venv/bin/activate  # Windows: .venv\Scripts\activate
   pip install -r requirements.txt
   ```
2. Ortam dosyasını oluşturun:
   ```bash
   cp .env.example .env
   ```
3. `.env` içini Supabase projenizle doldurun:
   - `DATABASE_URL`: Supabase Postgres URI (kimlik bilgilerinizi girin, `sslmode=require` kalsın).
   - `SUPABASE_JWKS_URL`: `https://<proje>.supabase.co/auth/v1/.well-known/jwks.json`.
   - `SUPABASE_AUDIENCE`: Genellikle `authenticated`.
   - `CORS_ORIGINS`: Virgülle ayrılmış origin listesi.
   - `DEV_ALLOW_UNVERIFIED`: Yalnızca lokal/dev için `true` bırakın.
4. API’yi çalıştırın:
   ```bash
   ./uvicorn_dev.sh  # veya: uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
   ```
5. Dokümanlara http://127.0.0.1:8000/api/docs adresinden bakın.

#### Frontend (Flutter)
1. Flutter kurun ve web desteğini açın (`flutter config --enable-web`).
2. `frontend/lib/config.dart` içindeki Supabase ve backend adreslerini kendi değerlerinizle güncelleyin (service role anahtarını **asla** koymayın).
3. Bağımlılıkları kurup çalıştırın:
   ```bash
   cd frontend
   flutter pub get
   flutter run -d chrome
   ```

#### Supabase kurulumu (örnek akış)
1. Supabase projesi açın; **Proje URL’i**, **anon public key** ve **service role key** değerlerini alın.
2. Database bağlantı stringini `postgresql+asyncpg` formatına çevirin ve `sslmode=require` bırakın.
3. `SUPABASE_JWKS_URL` değerini proje URL’inizle ayarlayın.
4. Oluşturduğunuz tablolarda RLS’i açın; `profiles`, `rfh`, `offers`, `projects`, `events`, `comments`, `reports` ve üyelik tablonuzda deny-by-default + `auth.uid()` + üyelik/rol kontrolü yapın.
5. **Service role key** sadece backend/secret manager ortamlarında kalsın; Flutter istemcisine veya repoya koymayın.

### Katkıda bulunma
Mühendislik, tasarım ve topluluk alanlarında katkılar bekliyoruz.
- Fikir, bug veya güvenlik konularını issue açarak paylaşın.
- PR’ları küçük tutun; şema veya yetkilendirme varsayımlarını açıklayın.
- Yeni başlayanlar için: dokümantasyon geliştirme, RLS testleri, Flutter UI iyileştirmeleri, GitHub Pages içeriği.

### Yol haritası ve güvenlik
- Yol haritası: [ROADMAP.md](./ROADMAP.md)
- Güvenlik rehberi: [SECURITY.md](./SECURITY.md)
- Topluluk kuralları: [CODE_OF_CONDUCT.md](./CODE_OF_CONDUCT.md)

### Lisans
[GPL-3.0](./LICENSE) lisansı ile dağıtılır. Misyon-öncelikli hedeflerle çelişmeyen alternatif lisans talepleri için issue açabilirsiniz.

---

**GitHub Pages:** Statik tanıtım sayfası `docs-site/` klasöründedir. GitHub Pages’te kaynak olarak bu klasörü seçebilir veya içeriği `docs/` ya da köke kopyalayabilirsiniz.
