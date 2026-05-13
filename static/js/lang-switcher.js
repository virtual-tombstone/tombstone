(function () {
    const DEFAULT_LANG = 'en';
    const RTL_LANGS = ['ar', 'he', 'fa'];

    function getSelectedLanguage() {
        // 1. Check URL hash fragment first (#ar, #en)
        const hash = window.location.hash.replace('#', '');
        if (hash) return hash;

        // 2. Fall back to previously stored user preference
        const stored = localStorage.getItem('tombstone_lang');
        if (stored) return stored;

        // 3. Fall back to system browser language settings
        const browserLang = navigator.language || navigator.userLanguage;
        if (browserLang) {
            const shortLang = browserLang.split('-')[0];
            return shortLang;
        }

        return DEFAULT_LANG;
    }

    function applyLanguage() {
        const targetLang = getSelectedLanguage();
        
        // Persist selection for their next page visit
        localStorage.setItem('tombstone_lang', targetLang);

        // Find all elements marked for dynamic text replacement
        document.querySelectorAll('[data-translations]').forEach(el => {
            try {
                const translations = JSON.parse(el.getAttribute('data-translations'));
                
                // Lookup target language, fall back to English, then fall back to an empty string
                const localizedText = translations[targetLang] || translations[DEFAULT_LANG] || '';
                
                if (localizedText) {
                    el.innerText = localizedText;
                }

                // Dynamic direction adjustment for translation containers (e.g. Arabic subtitles)
                if (el.hasAttribute('data-auto-dir')) {
                    const isRtl = RTL_LANGS.includes(targetLang);
                    el.setAttribute('dir', isRtl ? 'rtl' : 'ltr');
                }
            } catch (e) {
                console.error('Localization parsing error:', e);
            }
        });

        // Keep UI interactive controls synced up (such as select elements)
        const selectors = document.querySelectorAll('.lang-select');
        selectors.forEach(select => { select.value = targetLang; });
    }

    // Bind core window lifecycles
    window.addEventListener('hashchange', applyLanguage);
    window.addEventListener('DOMContentLoaded', applyLanguage);
})();

