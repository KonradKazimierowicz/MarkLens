(function () {
  'use strict';

  var bootstrap = window.__MARKLENS_BOOTSTRAP__;
  if (!bootstrap) { throw new Error('MarkLens bootstrap data is missing.'); }

  var state = deepClone(bootstrap.settings);
  var defaults = deepClone(bootstrap.defaultSettings || bootstrap.settings);
  var systemDark = window.matchMedia('(prefers-color-scheme: dark)');
  var saveTimer = null;
  var saveInProgress = false;
  var saveDirty = false;
  var toastTimer = null;
  var currentPresetId = 'default';
  var lastScrollY = window.pageYOffset || 0;

  var elements = {
    content: document.getElementById('content'),
    topbar: document.getElementById('topbar'),
    reveal: document.getElementById('topbarRevealZone'),
    progress: document.getElementById('progressBar'),
    toc: document.getElementById('tocPanel'),
    tocList: document.getElementById('tocList'),
    tocOverlay: document.getElementById('tocOverlay'),
    tocToggle: document.getElementById('tocToggle'),
    settings: document.getElementById('settingsPanel'),
    settingsOverlay: document.getElementById('settingsOverlay'),
    settingsButton: document.getElementById('settingsButton'),
    settingsClose: document.getElementById('settingsClose'),
    settingsBody: document.getElementById('settingsBody'),
    saveStatus: document.getElementById('saveStatus'),
    presetSelect: document.getElementById('presetSelect'),
    deletePreset: document.getElementById('deletePresetButton'),
    logo: document.getElementById('brandLogo'),
    favicon: document.getElementById('favicon'),
    toast: document.getElementById('toast')
  };

  var colorFields = [
    ['background', 'Page background'], ['surface', 'Document surface'], ['surfaceAlt', 'Secondary surface'],
    ['text', 'Body text'], ['muted', 'Muted text'], ['heading', 'Headings'], ['link', 'Links'],
    ['accent', 'Accent'], ['border', 'Borders'], ['codeBackground', 'Code blocks'], ['codeText', 'Code text'],
    ['inlineCodeBackground', 'Inline code'], ['quoteBackground', 'Quotes'], ['tableStripe', 'Table stripes'], ['scrollbar', 'Scrollbar'],
    ['danger', 'Warnings'], ['syntaxComment', 'Syntax: comments'], ['syntaxKeyword', 'Syntax: keywords'], ['syntaxString', 'Syntax: strings'],
    ['syntaxNumber', 'Syntax: numbers'], ['syntaxTitle', 'Syntax: titles'], ['syntaxAttribute', 'Syntax: attributes'], ['syntaxBuiltin', 'Syntax: built-ins']
  ];
  var fontChoices = ['Segoe UI', 'Arial', 'Calibri', 'Georgia', 'Times New Roman', 'Verdana', 'Trebuchet MS', 'Cascadia Mono', 'Consolas'];
  var fontStacks = {
    'Segoe UI': '"Segoe UI", system-ui, sans-serif', Arial: 'Arial, sans-serif', Calibri: 'Calibri, "Segoe UI", sans-serif',
    Georgia: 'Georgia, serif', 'Times New Roman': '"Times New Roman", serif', Verdana: 'Verdana, sans-serif',
    'Trebuchet MS': '"Trebuchet MS", sans-serif', 'Cascadia Mono': '"Cascadia Mono", Consolas, monospace', Consolas: 'Consolas, monospace'
  };
  var cssPalette = {
    background: '--reader-bg', surface: '--reader-surface', surfaceAlt: '--reader-surface-alt', text: '--reader-text',
    muted: '--reader-muted', heading: '--reader-heading', link: '--reader-link', accent: '--reader-accent', border: '--reader-border',
    codeBackground: '--reader-code-bg', codeText: '--reader-code-text', inlineCodeBackground: '--reader-inline-code-bg',
    quoteBackground: '--reader-quote-bg', tableStripe: '--reader-table-stripe', scrollbar: '--reader-scrollbar', danger: '--reader-danger',
    syntaxComment: '--reader-syntax-comment', syntaxKeyword: '--reader-syntax-keyword', syntaxString: '--reader-syntax-string',
    syntaxNumber: '--reader-syntax-number', syntaxTitle: '--reader-syntax-title', syntaxAttribute: '--reader-syntax-attribute', syntaxBuiltin: '--reader-syntax-builtin'
  };

  function deepClone(value) { return JSON.parse(JSON.stringify(value)); }

  function deepMerge(target, patch) {
    Object.keys(patch || {}).forEach(function (key) {
      var value = patch[key];
      if (value && typeof value === 'object' && !Array.isArray(value)) {
        if (!target[key] || typeof target[key] !== 'object' || Array.isArray(target[key])) { target[key] = {}; }
        deepMerge(target[key], value);
      } else {
        target[key] = deepClone(value);
      }
    });
    return target;
  }

  function getPath(object, path) {
    return path.split('.').reduce(function (value, key) { return value == null ? undefined : value[key]; }, object);
  }

  function setPath(object, path, value) {
    var parts = path.split('.');
    var current = object;
    parts.slice(0, -1).forEach(function (part) {
      if (!current[part] || typeof current[part] !== 'object') { current[part] = {}; }
      current = current[part];
    });
    current[parts[parts.length - 1]] = value;
  }

  function api(path, options) {
    options = options || {};
    options.headers = Object.assign({ 'X-MarkLens-Token': bootstrap.csrfToken }, options.headers || {});
    return fetch(path, options).then(function (response) {
      if (!response.ok) {
        return response.text().then(function (message) { throw new Error(message || ('Request failed: ' + response.status)); });
      }
      var type = response.headers.get('content-type') || '';
      return type.indexOf('application/json') >= 0 ? response.json() : response.text();
    });
  }

  function resolveTheme() {
    if (state.theme.mode === 'auto') { return systemDark.matches ? 'dark' : 'light'; }
    return state.theme.mode;
  }

  function applySettings() {
    var root = document.documentElement;
    var mode = resolveTheme();
    var palette = state.theme[mode];
    root.setAttribute('data-theme', mode);
    root.style.colorScheme = mode;
    Object.keys(cssPalette).forEach(function (key) { root.style.setProperty(cssPalette[key], palette[key]); });
    root.style.setProperty('--reader-font-body', fontStacks[state.typography.fontBody] || fontStacks['Segoe UI']);
    root.style.setProperty('--reader-font-heading', fontStacks[state.typography.fontHeading] || fontStacks['Segoe UI']);
    root.style.setProperty('--reader-font-code', fontStacks[state.typography.fontCode] || fontStacks.Consolas);
    root.style.setProperty('--reader-font-size', state.typography.fontSize + 'px');
    root.style.setProperty('--reader-line-height', String(state.typography.lineHeight));
    root.style.setProperty('--reader-heading-scale', String(state.typography.headingScale));
    root.style.setProperty('--reader-max-width', state.layout.maxWidth + 'px');
    root.style.setProperty('--reader-padding', state.layout.contentPadding + 'px');
    root.style.setProperty('--reader-block-spacing', String(state.layout.blockSpacing));
    root.style.setProperty('--reader-radius', state.components.radius + 'px');
    root.style.setProperty('--reader-shadow', { none: 'none', soft: '0 12px 34px color-mix(in srgb, var(--reader-text) 8%, transparent)', medium: '0 18px 48px color-mix(in srgb, var(--reader-text) 16%, transparent)' }[state.components.shadow]);
    root.style.setProperty('--reader-scrollbar-width', { thin: '7px', regular: '10px', wide: '14px' }[state.components.scrollbarWidth]);
    root.setAttribute('data-quote-style', state.components.quoteStyle);
    root.setAttribute('data-table-style', state.components.tableStyle);
    root.setAttribute('data-separator-style', state.components.separatorStyle);

    document.body.classList.toggle('no-header', !state.branding.showHeader);
    document.getElementById('brandTitle').textContent = state.branding.title;
    document.getElementById('brandWorkspace').textContent = state.branding.workspace;
    document.getElementById('footerName').textContent = state.branding.title;
    document.getElementById('documentName').textContent = bootstrap.document.fileName;
    document.getElementById('documentPath').textContent = bootstrap.document.fullPath;
    document.getElementById('documentBlock').hidden = !state.branding.showFileName && !state.branding.showFilePath;
    document.getElementById('documentName').hidden = !state.branding.showFileName;
    document.getElementById('documentPath').hidden = !state.branding.showFilePath;
    document.getElementById('identityDivider').hidden = document.getElementById('documentBlock').hidden;
    document.title = bootstrap.document.fileName + ' · ' + state.branding.title;

    var hasLogo = Boolean(state.branding.logoFile);
    elements.logo.style.display = state.branding.showLogo && hasLogo ? 'block' : 'none';
    if (hasLogo) { elements.logo.src = '/api/logo?v=' + encodeURIComponent(state.branding.logoFile); }
    if (hasLogo && state.branding.useLogoAsFavicon) {
      elements.favicon.type = state.branding.logoFile.indexOf('.png') > 0 ? 'image/png' : 'image/jpeg';
      elements.favicon.href = '/api/logo?v=' + encodeURIComponent(state.branding.logoFile);
    } else {
      elements.favicon.type = 'image/svg+xml';
      elements.favicon.href = "data:image/svg+xml,%3Csvg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 64 64'%3E%3Crect width='64' height='64' rx='14' fill='%23" + palette.accent.substring(1) + "'/%3E%3Cpath d='M15 19h8l9 12 9-12h8v26h-8V31L32 43 23 31v14h-8z' fill='%23" + palette.surface.substring(1) + "'/%3E%3C/svg%3E";
    }

    var tocVisible = state.behavior.showTableOfContents;
    elements.toc.classList.toggle('is-closed', !tocVisible);
    elements.tocToggle.setAttribute('aria-expanded', String(tocVisible));
    populateForm();
  }

  function makeColorControls(mode, targetId) {
    var target = document.getElementById(targetId);
    colorFields.forEach(function (entry) {
      var label = document.createElement('label');
      label.className = 'color-field';
      var input = document.createElement('input');
      input.type = 'color'; input.setAttribute('data-setting', 'theme.' + mode + '.' + entry[0]);
      var text = document.createElement('span'); text.textContent = entry[1];
      label.appendChild(input); label.appendChild(text); target.appendChild(label);
    });
  }

  function initializeForm() {
    makeColorControls('light', 'lightColors');
    makeColorControls('dark', 'darkColors');
    document.querySelectorAll('[data-font-select]').forEach(function (select) {
      fontChoices.forEach(function (font) { var option = document.createElement('option'); option.value = font; option.textContent = font; select.appendChild(option); });
    });
    populatePresets();
  }

  function populateForm() {
    document.querySelectorAll('[data-setting]').forEach(function (input) {
      var value = getPath(state, input.getAttribute('data-setting'));
      if (input.type === 'checkbox') { input.checked = Boolean(value); }
      else { input.value = String(value); }
    });
    document.querySelectorAll('[data-output]').forEach(function (output) {
      var path = output.getAttribute('data-output');
      var value = getPath(state, path);
      output.textContent = value + (path === 'layout.maxWidth' || path === 'layout.contentPadding' || path === 'components.radius' || path === 'typography.fontSize' ? ' px' : '');
    });
    document.getElementById('removeLogoButton').disabled = !state.branding.logoFile;
  }

  function populatePresets(selectedId) {
    var select = elements.presetSelect;
    selectedId = selectedId || currentPresetId;
    select.textContent = '';
    var builtGroup = document.createElement('optgroup'); builtGroup.label = 'Built-in';
    bootstrap.builtInPresets.forEach(function (preset) { var option = document.createElement('option'); option.value = preset.id; option.textContent = preset.name; builtGroup.appendChild(option); });
    select.appendChild(builtGroup);
    if (state.customPresets.length) {
      var customGroup = document.createElement('optgroup'); customGroup.label = 'Custom';
      state.customPresets.forEach(function (preset) { var option = document.createElement('option'); option.value = preset.id; option.textContent = preset.name; customGroup.appendChild(option); });
      select.appendChild(customGroup);
    }
    if (select.querySelector('option[value="' + cssEscape(selectedId) + '"]')) { select.value = selectedId; }
    else { select.value = 'default'; currentPresetId = 'default'; }
    elements.deletePreset.disabled = select.value.indexOf('custom-') !== 0;
  }

  function cssEscape(value) { return String(value).replace(/[^a-zA-Z0-9_-]/g, ''); }

  function queueSave(immediate) {
    saveDirty = true;
    elements.saveStatus.textContent = 'Saving…';
    clearTimeout(saveTimer);
    if (immediate) { pumpSave(); }
    else { saveTimer = setTimeout(pumpSave, 180); }
  }

  function pumpSave() {
    if (saveInProgress || !saveDirty) { return; }
    saveInProgress = true; saveDirty = false;
    var snapshot = deepClone(state);
    api('/api/settings', { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(snapshot) })
      .then(function (validated) {
        if (!saveDirty) { state = validated; applySettings(); populatePresets(currentPresetId); }
        elements.saveStatus.textContent = saveDirty ? 'Saving…' : 'Saved locally';
      })
      .catch(function (error) { elements.saveStatus.textContent = 'Could not save'; showToast(error.message); })
      .then(function () { saveInProgress = false; if (saveDirty) { pumpSave(); } });
  }

  function showToast(message) {
    elements.toast.textContent = message; elements.toast.classList.add('show'); clearTimeout(toastTimer);
    toastTimer = setTimeout(function () { elements.toast.classList.remove('show'); }, 3000);
  }

  function decodeMarkdown() {
    var binary = atob(bootstrap.document.markdownBase64);
    var bytes = new Uint8Array(binary.length);
    for (var index = 0; index < binary.length; index += 1) { bytes[index] = binary.charCodeAt(index); }
    return new TextDecoder('utf-8', { fatal: false }).decode(bytes);
  }

  function safeLink(link) {
    var raw = (link.getAttribute('href') || '').trim();
    if (!raw) { return; }
    if (raw.charAt(0) === '#') { return; }
    try {
      var url = new URL(raw, 'https://marklens.invalid/');
      if (url.protocol === 'http:' || url.protocol === 'https:' || url.protocol === 'mailto:') {
        if (url.hostname === 'marklens.invalid' && url.protocol === 'https:') { throw new Error('Relative file links are disabled'); }
        link.target = '_blank'; link.rel = 'noopener noreferrer'; return;
      }
    } catch (ignore) { /* disabled below */ }
    link.removeAttribute('href'); link.classList.add('unsafe-link'); link.title = 'This local or unsafe link was disabled by MarkLens.';
  }

  function safeImage(image) {
    var raw = (image.getAttribute('src') || '').trim();
    if (/^data:image\/(png|jpeg|gif|webp);base64,[a-z0-9+/=\s]+$/i.test(raw)) { return; }
    if (raw && !/^[a-z][a-z0-9+.-]*:/i.test(raw) && raw.indexOf('//') !== 0) {
      image.src = '/api/document-asset?path=' + encodeURIComponent(raw.replace(/\\/g, '/'));
      image.loading = 'lazy'; image.referrerPolicy = 'no-referrer'; return;
    }
    image.removeAttribute('src'); image.alt = (image.alt || 'Image') + ' (blocked by privacy settings)';
  }

  function renderMarkdown() {
    var markdown = decodeMarkdown();
    if (!markdown.trim()) { var empty = document.createElement('p'); empty.className = 'empty-state'; empty.textContent = 'This document is empty.'; elements.content.replaceChildren(empty); return; }
    try {
      if (!window.marked || !window.DOMPurify) { throw new Error('Renderer libraries are unavailable.'); }
      var rendered = window.marked.parse(markdown, { gfm: true, breaks: false, async: false });
      var clean = window.DOMPurify.sanitize(rendered, {
        USE_PROFILES: { html: true }, SANITIZE_DOM: true, ALLOW_DATA_ATTR: false,
        FORBID_TAGS: ['script', 'style', 'iframe', 'object', 'embed', 'form', 'meta', 'link', 'base', 'audio', 'video', 'source'],
        FORBID_ATTR: ['style', 'srcset', 'formaction', 'poster', 'autofocus']
      });
      elements.content.innerHTML = clean;
      elements.content.querySelectorAll('a').forEach(safeLink);
      elements.content.querySelectorAll('img').forEach(safeImage);
      elements.content.querySelectorAll('input').forEach(function (input) {
        if (input.type !== 'checkbox') { input.remove(); } else { input.disabled = true; }
      });
      elements.content.querySelectorAll('table').forEach(function (table) { var wrapper = document.createElement('div'); wrapper.className = 'table-wrap'; table.parentNode.insertBefore(wrapper, table); wrapper.appendChild(table); });
      if (window.hljs) { elements.content.querySelectorAll('pre code').forEach(function (block) { window.hljs.highlightElement(block); }); }
      buildTableOfContents();
    } catch (error) {
      elements.content.textContent = '';
      var warning = document.createElement('p'); warning.className = 'render-error'; warning.textContent = 'Markdown rendering failed. The source is shown as plain text.';
      var pre = document.createElement('pre'); pre.className = 'raw-fallback'; pre.textContent = markdown;
      elements.content.appendChild(warning); elements.content.appendChild(pre);
    }
  }

  function buildTableOfContents() {
    var headings = Array.prototype.slice.call(elements.content.querySelectorAll('h1, h2, h3, h4'));
    elements.tocList.textContent = '';
    var used = {};
    headings.forEach(function (heading, index) {
      var base = heading.textContent.trim().toLowerCase().replace(/[^\p{L}\p{N}]+/gu, '-').replace(/^-|-$/g, '') || ('section-' + (index + 1));
      var slug = base; var suffix = 2; while (used[slug]) { slug = base + '-' + suffix; suffix += 1; } used[slug] = true; heading.id = slug;
      var link = document.createElement('a'); link.href = '#' + slug; link.textContent = heading.textContent.trim(); link.setAttribute('data-level', heading.tagName.substring(1)); elements.tocList.appendChild(link);
    });
    if (!headings.length) { var note = document.createElement('span'); note.textContent = 'No headings in this document.'; note.style.fontSize = '12px'; note.style.padding = '0 10px'; elements.tocList.appendChild(note); }
    setupScrollSpy(headings);
  }

  function setupScrollSpy(headings) {
    if (!('IntersectionObserver' in window)) { return; }
    var observer = new IntersectionObserver(function (entries) {
      entries.forEach(function (entry) {
        if (entry.isIntersecting) {
          elements.tocList.querySelectorAll('a').forEach(function (link) { link.classList.toggle('active', link.getAttribute('href') === '#' + entry.target.id); });
        }
      });
    }, { rootMargin: '-15% 0px -70% 0px', threshold: 0 });
    headings.forEach(function (heading) { observer.observe(heading); });
  }

  function openSettings() { document.body.classList.add('settings-open'); elements.settings.setAttribute('aria-hidden', 'false'); elements.settingsClose.focus(); }
  function closeSettings() { document.body.classList.remove('settings-open'); elements.settings.setAttribute('aria-hidden', 'true'); elements.settingsButton.focus(); }

  function applyPreset(id) {
    var preset = bootstrap.builtInPresets.concat(state.customPresets).find(function (item) { return item.id === id; });
    if (!preset) { return; }
    var appearance = deepClone(defaults);
    deepMerge(appearance, preset.settings || {});
    state.theme = appearance.theme; state.typography = appearance.typography; state.layout = appearance.layout; state.components = appearance.components;
    currentPresetId = id; elements.deletePreset.disabled = id.indexOf('custom-') !== 0; applySettings(); queueSave(true);
  }

  function bindEvents() {
    elements.settingsButton.addEventListener('click', openSettings); elements.settingsClose.addEventListener('click', closeSettings); elements.settingsOverlay.addEventListener('click', closeSettings);
    document.addEventListener('keydown', function (event) { if (event.key === 'Escape' && document.body.classList.contains('settings-open')) { closeSettings(); } });
    elements.settingsBody.addEventListener('input', function (event) {
      var input = event.target; var path = input.getAttribute('data-setting'); if (!path) { return; }
      var value = input.type === 'checkbox' ? input.checked : (input.hasAttribute('data-number') ? Number(input.value) : input.value);
      setPath(state, path, value); currentPresetId = 'customized'; applySettings(); queueSave(false);
    });
    elements.settingsBody.addEventListener('change', function (event) {
      var input = event.target; var path = input.getAttribute('data-setting'); if (!path) { return; }
      var value = input.type === 'checkbox' ? input.checked : (input.hasAttribute('data-number') ? Number(input.value) : input.value);
      setPath(state, path, value); currentPresetId = 'customized'; applySettings(); queueSave(true);
    });
    elements.presetSelect.addEventListener('change', function () { applyPreset(elements.presetSelect.value); });
    document.getElementById('savePresetButton').addEventListener('click', function () {
      var name = window.prompt('Name this preset:'); if (!name || !name.trim()) { return; }
      var id = 'custom-' + Date.now().toString(36);
      state.customPresets.push({ id: id, name: name.trim().substring(0, 40), settings: { theme: deepClone(state.theme), typography: deepClone(state.typography), layout: deepClone(state.layout), components: deepClone(state.components) } });
      currentPresetId = id; populatePresets(id); queueSave(true); showToast('Custom preset saved.');
    });
    elements.deletePreset.addEventListener('click', function () {
      var id = elements.presetSelect.value; if (id.indexOf('custom-') !== 0) { return; }
      state.customPresets = state.customPresets.filter(function (preset) { return preset.id !== id; }); currentPresetId = 'default'; populatePresets('default'); queueSave(true); showToast('Custom preset deleted.');
    });
    document.getElementById('themeToggle').addEventListener('click', function () { state.theme.mode = resolveTheme() === 'dark' ? 'light' : 'dark'; applySettings(); queueSave(true); });
    document.getElementById('reloadButton').addEventListener('click', function () { window.location.reload(); });
    document.getElementById('copyPathButton').addEventListener('click', function () {
      navigator.clipboard.writeText(bootstrap.document.fullPath).then(function () { showToast('Source path copied.'); }).catch(function () { showToast('Could not copy the source path.'); });
    });
    elements.tocToggle.addEventListener('click', function () {
      if (window.innerWidth <= 1050) { elements.toc.classList.toggle('mobile-open'); elements.tocOverlay.classList.toggle('open'); }
      else { state.behavior.showTableOfContents = !state.behavior.showTableOfContents; applySettings(); queueSave(true); }
    });
    elements.tocOverlay.addEventListener('click', function () { elements.toc.classList.remove('mobile-open'); elements.tocOverlay.classList.remove('open'); });
    elements.tocList.addEventListener('click', function () { elements.toc.classList.remove('mobile-open'); elements.tocOverlay.classList.remove('open'); });
    document.getElementById('resetButton').addEventListener('click', function () {
      if (!window.confirm('Reset all appearance, branding, and custom presets to MarkLens defaults?')) { return; }
      state = deepClone(defaults); currentPresetId = 'default'; applySettings(); populatePresets('default'); queueSave(true); showToast('Default settings restored.');
    });
    document.getElementById('exportButton').addEventListener('click', function () {
      var exported = deepClone(state); exported.exportedBy = 'MarkLens'; exported.exportedAt = new Date().toISOString();
      var blob = new Blob([JSON.stringify(exported, null, 2) + '\n'], { type: 'application/json' }); var url = URL.createObjectURL(blob);
      var link = document.createElement('a'); link.href = url; link.download = 'marklens-settings.json'; document.body.appendChild(link); link.click(); link.remove(); setTimeout(function () { URL.revokeObjectURL(url); }, 0);
    });
    document.getElementById('importButton').addEventListener('click', function () { document.getElementById('importInput').click(); });
    document.getElementById('importInput').addEventListener('change', function (event) {
      var file = event.target.files[0]; event.target.value = ''; if (!file) { return; }
      if (file.size > 256 * 1024) { showToast('Configuration files may not exceed 256 KB.'); return; }
      file.text().then(JSON.parse).then(function (candidate) {
        return api('/api/settings', { method: 'PUT', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify(candidate) });
      }).then(function (validated) { state = validated; currentPresetId = 'customized'; applySettings(); populatePresets(); showToast('Configuration imported.'); })
        .catch(function () { showToast('That file is not a valid MarkLens configuration.'); });
    });
    document.getElementById('logoInput').addEventListener('change', function (event) {
      var file = event.target.files[0]; event.target.value = ''; if (!file) { return; }
      if (['image/png', 'image/jpeg'].indexOf(file.type) < 0 || file.size > bootstrap.limits.logoBytes) { showToast('Choose a PNG or JPEG file no larger than 2 MB.'); return; }
      var reader = new FileReader(); reader.onload = function () {
        api('/api/logo', { method: 'POST', headers: { 'Content-Type': 'application/json' }, body: JSON.stringify({ name: file.name, type: file.type, data: String(reader.result).split(',')[1] }) })
          .then(function (validated) { state = validated; state.branding.showLogo = true; applySettings(); queueSave(true); showToast('Logo updated.'); })
          .catch(function (error) { showToast(error.message); });
      }; reader.readAsDataURL(file);
    });
    document.getElementById('removeLogoButton').addEventListener('click', function () {
      api('/api/logo', { method: 'DELETE' }).then(function (validated) { state = validated; applySettings(); showToast('Logo removed.'); }).catch(function (error) { showToast(error.message); });
    });
    systemDark.addEventListener ? systemDark.addEventListener('change', function () { if (state.theme.mode === 'auto') { applySettings(); } }) : systemDark.addListener(function () { if (state.theme.mode === 'auto') { applySettings(); } });
    window.addEventListener('scroll', function () {
      var top = window.pageYOffset || document.documentElement.scrollTop || 0; var height = document.documentElement.scrollHeight - document.documentElement.clientHeight;
      elements.progress.style.width = (height > 0 ? Math.min(100, Math.max(0, top / height * 100)) : 0) + '%';
      if (state.behavior.autoHideToolbar) { elements.topbar.classList.toggle('is-hidden', top > lastScrollY && top > 90); } else { elements.topbar.classList.remove('is-hidden'); }
      lastScrollY = top;
    }, { passive: true });
    elements.reveal.addEventListener('mouseenter', function () { elements.topbar.classList.remove('is-hidden'); });
    window.addEventListener('pagehide', function () { fetch('/api/shutdown', { method: 'POST', headers: { 'X-MarkLens-Token': bootstrap.csrfToken }, keepalive: true }).catch(function () {}); });
  }

  initializeForm(); applySettings(); renderMarkdown(); bindEvents();
}());
