(function () {
  const langButtons = {
    en: document.getElementById('lang-en'),
    tr: document.getElementById('lang-tr'),
  };
  const themeToggle = document.getElementById('theme-toggle');
  const langSections = document.querySelectorAll('[data-lang]');

  function setLanguage(lang) {
    langSections.forEach((el) => {
      el.classList.toggle('active', el.dataset.lang === lang);
      el.setAttribute('aria-hidden', el.dataset.lang !== lang);
    });
    Object.entries(langButtons).forEach(([key, btn]) => {
      if (!btn) return;
      const isActive = key === lang;
      btn.setAttribute('aria-pressed', String(isActive));
      btn.classList.toggle('active', isActive);
    });
    localStorage.setItem('sobeneficial_lang', lang);
  }

  function toggleTheme() {
    const isDark = document.documentElement.classList.toggle('dark');
    themeToggle.textContent = isDark ? '🌙' : '☀️';
    localStorage.setItem('sobeneficial_theme', isDark ? 'dark' : 'light');
  }

  // initialize
  const savedLang = localStorage.getItem('sobeneficial_lang') || 'en';
  const savedTheme = localStorage.getItem('sobeneficial_theme');
  if (savedTheme === 'dark') {
    document.documentElement.classList.add('dark');
    themeToggle.textContent = '🌙';
  }
  setLanguage(savedLang);

  langButtons.en?.addEventListener('click', () => setLanguage('en'));
  langButtons.tr?.addEventListener('click', () => setLanguage('tr'));
  themeToggle?.addEventListener('click', toggleTheme);
})();
