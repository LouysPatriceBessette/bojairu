// Static helper for the /contact/invite landing page.
//
// Served by the relay reverse-proxy on the same host as the relay
// (e.g. https://sync.example.tld/contact/invite?v=1&c=...). Invitation
// payload lives only in the query string and is never sent to the server:
// this script reads `window.location.search` on the client only.
(function () {
  'use strict';

  var search = window.location.search || '';
  var params = new URLSearchParams(search);
  var version = params.get('v');
  var payload = params.get('c');
  var shortCodeParam = params.get('s');
  var hasInvite = !!(version && payload);

  var deepSearch = hasInvite
    ? '?v=' + encodeURIComponent(version) +
      '&c=' + encodeURIComponent(payload)
    : '';

  var deepLink = hasInvite
    ? 'bojairu://contact/invite' + deepSearch
    : '';

  function setDeepLinkTargets() {
    var openButtons = document.querySelectorAll('[data-open-app]');
    for (var i = 0; i < openButtons.length; i++) {
      if (hasInvite) {
        openButtons[i].setAttribute('href', deepLink);
      } else {
        openButtons[i].setAttribute('href', 'bojairu://contact/invite');
      }
    }
    var linkBoxes = document.querySelectorAll('[data-invite-link-box]');
    for (var j = 0; j < linkBoxes.length; j++) {
      linkBoxes[j].textContent = hasInvite
        ? deepLink
        : 'bojairu://contact/invite';
    }
  }

  function wireShortCodeRow() {
    var row = document.getElementById('short-code-row');
    var wrap = document.getElementById('short-code-copy-wrap');
    var show = !!(hasInvite && shortCodeParam);
    if (row) row.hidden = !show;
    if (wrap) wrap.hidden = !show;
    if (show) {
      var el = document.getElementById('short-code-value');
      if (el) el.textContent = shortCodeParam;
    }
  }

  function announce(msg) {
    var live = document.getElementById('copy-live');
    if (!live) return;
    live.textContent = '';
    void live.offsetHeight;
    live.textContent = msg;
  }

  function copyToClipboard(text, onDone) {
    if (navigator.clipboard && navigator.clipboard.writeText) {
      navigator.clipboard.writeText(text).then(onDone).catch(function () {
        legacyCopy(text, onDone);
      });
      return;
    }
    legacyCopy(text, onDone);
  }

  function legacyCopy(text, onDone) {
    var ta = document.createElement('textarea');
    ta.value = text;
    ta.setAttribute('readonly', '');
    ta.style.position = 'fixed';
    ta.style.left = '-9999px';
    document.body.appendChild(ta);
    ta.select();
    try {
      document.execCommand('copy');
      onDone();
    } catch (e) {
      announce('Could not copy — select the link and copy manually.');
    }
    document.body.removeChild(ta);
  }

  function setCopiedState(button, copied) {
    if (!button) return;
    if (copied) {
      button.setAttribute('data-copied', 'true');
      window.setTimeout(function () {
        button.removeAttribute('data-copied');
      }, 2200);
    } else {
      button.removeAttribute('data-copied');
    }
  }

  function wireCopyButtons() {
    document.addEventListener('click', function (ev) {
      var t = ev.target;
      if (!t || !t.closest) return;
      var btn = t.closest('[data-copy-kind]');
      if (!btn) return;
      var kind = btn.getAttribute('data-copy-kind');
      if (!kind) return;

      if (btn.hasAttribute('data-requires-invite') && !hasInvite) {
        announce('This page has no invitation to copy.');
        return;
      }

      var text = '';
      if (kind === 'deep') {
        if (!hasInvite) {
          announce('This page has no invitation to copy.');
          return;
        }
        text = deepLink;
      } else if (kind === 'https') {
        text = window.location.href;
      } else if (kind === 'short') {
        if (!hasInvite || !shortCodeParam) {
          announce('No short code on this link.');
          return;
        }
        text = shortCodeParam;
      }

      if (!text) return;

      copyToClipboard(text, function () {
        setCopiedState(btn, true);
        announce('Copied to clipboard.');
      });
    });
  }

  var LANG_KEY = 'bojairu-invite-lang';

  function detectBrowserLang() {
    var candidates = [];
    try {
      if (navigator.languages && navigator.languages.length) {
        for (var i = 0; i < navigator.languages.length; i++) {
          candidates.push(navigator.languages[i]);
        }
      }
    } catch (e) { /* ignore */ }
    if (navigator.language) {
      candidates.push(navigator.language);
    }
    for (var j = 0; j < candidates.length; j++) {
      var raw = String(candidates[j] || '').trim().toLowerCase();
      if (!raw) continue;
      var primary = raw.split('-')[0];
      if (primary === 'en' || primary === 'fr' || primary === 'es') {
        return primary;
      }
    }
    return 'en';
  }

  function persistLang(lang) {
    try {
      window.localStorage.setItem(LANG_KEY, lang);
    } catch (e) { /* ignore */ }
  }

  function applyLang(lang) {
    var allowed = { en: true, fr: true, es: true };
    if (!allowed[lang]) lang = 'en';

    document.documentElement.lang = lang;

    var nodes = document.querySelectorAll('[data-i18n]');
    for (var i = 0; i < nodes.length; i++) {
      var node = nodes[i];
      var loc = node.getAttribute('data-i18n');
      var match = loc === lang;
      node.hidden = !match;
    }

    var switches = document.querySelectorAll('[data-lang-switch]');
    for (var j = 0; j < switches.length; j++) {
      var sw = switches[j];
      var target = sw.getAttribute('data-lang-switch');
      sw.setAttribute('aria-pressed', target === lang ? 'true' : 'false');
    }
  }

  function wireLangSwitch() {
    document.addEventListener('click', function (ev) {
      var t = ev.target;
      if (!t || !t.closest) return;
      var btn = t.closest('[data-lang-switch]');
      if (!btn) return;
      var lang = btn.getAttribute('data-lang-switch');
      if (lang) {
        persistLang(lang);
        applyLang(lang);
      }
    });

    var initial = detectBrowserLang();
    try {
      var stored = window.localStorage.getItem(LANG_KEY);
      if (stored === 'en' || stored === 'fr' || stored === 'es') {
        initial = stored;
      }
    } catch (e) { /* ignore */ }
    applyLang(initial);
  }

  setDeepLinkTargets();
  wireShortCodeRow();
  wireCopyButtons();
  wireLangSwitch();
})();
