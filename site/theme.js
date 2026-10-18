(function () {
  'use strict';

  var root = document.documentElement;
  var systemTheme = window.matchMedia('(prefers-color-scheme: dark)');
  var savedTheme;
  try { savedTheme = window.localStorage.getItem('yash-portfolio-theme'); } catch (error) { /* Storage may be disabled. */ }
  var manualPreference = savedTheme === 'light' || savedTheme === 'dark';

  function applyTheme(theme) {
    root.dataset.theme = theme;
    var meta = document.querySelector('meta[name="theme-color"]');
    if (meta) meta.setAttribute('content', theme === 'dark' ? '#101722' : '#f8fafc');
    var button = document.getElementById('theme-toggle');
    if (button) {
      var label = theme === 'dark' ? 'Switch to light theme' : 'Switch to dark theme';
      button.setAttribute('aria-label', label);
      button.setAttribute('title', label);
    }
  }

  applyTheme(manualPreference ? savedTheme : (systemTheme.matches ? 'dark' : 'light'));

  function connectButton() {
    var button = document.getElementById('theme-toggle');
    if (!button) return;
    applyTheme(root.dataset.theme);
    button.hidden = false;
    button.addEventListener('click', function () {
      var nextTheme = root.dataset.theme === 'dark' ? 'light' : 'dark';
      manualPreference = true;
      applyTheme(nextTheme);
      try { window.localStorage.setItem('yash-portfolio-theme', nextTheme); } catch (error) { /* Theme still works for this visit. */ }
    });
  }

  if (document.readyState === 'loading') {
    document.addEventListener('DOMContentLoaded', connectButton, { once: true });
  } else {
    connectButton();
  }
  systemTheme.addEventListener('change', function (event) {
    if (!manualPreference) applyTheme(event.matches ? 'dark' : 'light');
  });
}());
