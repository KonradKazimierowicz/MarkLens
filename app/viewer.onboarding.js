(function () {
  'use strict';

  function deepClone(value) { return JSON.parse(JSON.stringify(value)); }

  function deepMerge(target, patch) {
    Object.keys(patch || {}).forEach(function (key) {
      var value = patch[key];
      if (value && typeof value === 'object' && !Array.isArray(value)) {
        if (!target[key] || typeof target[key] !== 'object' || Array.isArray(target[key])) { target[key] = {}; }
        deepMerge(target[key], value);
      } else { target[key] = deepClone(value); }
    });
    return target;
  }

  function focusable(container) {
    return Array.prototype.slice.call(container.querySelectorAll('button:not([disabled]), [href], input:not([disabled]), select:not([disabled]), [tabindex]:not([tabindex="-1"])'))
      .filter(function (element) { return element.offsetParent !== null; });
  }

  function trapFocus(container, event) {
    if (event.key !== 'Tab') { return; }
    var items = focusable(container);
    if (!items.length) { event.preventDefault(); return; }
    var first = items[0]; var last = items[items.length - 1];
    if (event.shiftKey && document.activeElement === first) { event.preventDefault(); last.focus(); }
    else if (!event.shiftKey && document.activeElement === last) { event.preventDefault(); first.focus(); }
  }

  window.MarkLensOnboarding = {
    create: function (options) {
      var welcomeLayer = document.getElementById('onboardingLayer');
      var welcomeDialog = document.getElementById('onboardingDialog');
      var presetContainer = document.getElementById('onboardingPresets');
      var continueButton = document.getElementById('continueOnboardingButton');
      var skipButton = document.getElementById('skipOnboardingButton');
      var tourLayer = document.getElementById('tourLayer');
      var tourCard = document.getElementById('tourCard');
      var tourTitle = document.getElementById('tourTitle');
      var tourDescription = document.getElementById('tourDescription');
      var tourStepLabel = document.getElementById('tourStepLabel');
      var tourDots = document.getElementById('tourDots');
      var tourBack = document.getElementById('tourBackButton');
      var tourNext = document.getElementById('tourNextButton');
      var tourSkip = document.getElementById('tourSkipButton');
      var selectedPreset = null;
      var currentStep = -1;
      var activeTarget = null;
      var presets = options.presets.slice(0, 5);
      var steps = [
        { selector: '#tocToggle', title: 'Table of contents', description: 'Open the document outline and jump straight to any heading. On smaller screens it opens as a scrollable drawer.' },
        { selector: '#themeToggle', title: 'Light and dark mode', description: 'Switch the current document between light and dark reading without opening Appearance.' },
        { selector: '#copyMarkdownButton', title: 'Copy Markdown', description: 'Copy the complete raw Markdown source to the clipboard, including formatting and fenced code.' },
        { selector: '#printButton', title: 'Print or save as PDF', description: 'Open the native print preview. MarkLens prepares a clean document without reader controls or local paths.' },
        { selector: '#settingsButton', title: 'Appearance and behavior', description: 'Fine-tune colors, typography, width, branding, presets, and reader behavior. You can replay this guide there at any time.' }
      ];

      function setBackgroundInert(value) {
        ['topbar', 'readerLayout', 'floatingSettingsButton', 'floatingPrintButton'].forEach(function (id) {
          var element = document.getElementById(id); if (element) { element.inert = value; }
        });
      }

      function presetAppearance(preset) {
        var appearance = deepClone(options.defaults);
        deepMerge(appearance, preset.settings || {});
        return appearance;
      }

      function selectPreset(id) {
        selectedPreset = id;
        presetContainer.querySelectorAll('.preset-card').forEach(function (card) {
          card.setAttribute('aria-checked', String(card.getAttribute('data-preset-id') === id));
        });
        var preset = presets.find(function (item) { return item.id === id; });
        continueButton.disabled = !preset;
        continueButton.textContent = preset ? 'Use ' + preset.name : 'Choose a style';
        if (preset) { options.applyPreset(id); }
      }

      function makePresetCards() {
        presets.forEach(function (preset, index) {
          var appearance = presetAppearance(preset); var palette = appearance.theme.mode === 'dark' ? appearance.theme.dark : appearance.theme.light;
          var card = document.createElement('button');
          card.type = 'button'; card.className = 'preset-card'; card.setAttribute('role', 'radio'); card.setAttribute('aria-checked', 'false'); card.setAttribute('data-preset-id', preset.id);
          card.style.setProperty('--preset-bg', palette.background); card.style.setProperty('--preset-surface', palette.surface); card.style.setProperty('--preset-text', palette.text); card.style.setProperty('--preset-accent', palette.accent);
          var preview = document.createElement('span'); preview.className = 'preset-card__preview'; preview.setAttribute('aria-hidden', 'true');
          var paper = document.createElement('span'); paper.className = 'preset-card__paper';
          ['preset-card__heading', 'preset-card__line', 'preset-card__line', 'preset-card__line'].forEach(function (className) { var line = document.createElement('span'); line.className = className; paper.appendChild(line); });
          preview.appendChild(paper);
          var name = document.createElement('strong'); name.textContent = preset.name;
          var description = document.createElement('small'); description.textContent = preset.description;
          card.appendChild(preview); card.appendChild(name); card.appendChild(description);
          card.addEventListener('click', function () { selectPreset(preset.id); });
          card.addEventListener('keydown', function (event) {
            if (['ArrowRight', 'ArrowDown', 'ArrowLeft', 'ArrowUp'].indexOf(event.key) < 0) { return; }
            event.preventDefault(); var direction = event.key === 'ArrowRight' || event.key === 'ArrowDown' ? 1 : -1;
            var next = presetContainer.querySelectorAll('.preset-card')[(index + direction + presets.length) % presets.length]; next.focus(); next.click();
          });
          presetContainer.appendChild(card);
        });
      }

      function openWelcome() {
        setBackgroundInert(true); document.body.classList.add('onboarding-open'); welcomeLayer.setAttribute('aria-hidden', 'false');
        var first = presetContainer.querySelector('.preset-card'); if (first) { first.focus(); }
      }

      function closeWelcome() {
        document.body.classList.remove('onboarding-open'); welcomeLayer.setAttribute('aria-hidden', 'true'); setBackgroundInert(false);
      }

      function completeWelcome(startGuide) {
        options.complete(); closeWelcome();
        if (startGuide) { startTour(); } else { options.returnFocus(); }
      }

      function clearTarget() {
        if (activeTarget) { activeTarget.classList.remove('tour-target'); activeTarget = null; }
      }

      function positionTour() {
        if (!activeTarget || window.innerWidth <= 700) { return; }
        var target = activeTarget.getBoundingClientRect(); var card = tourCard.getBoundingClientRect(); var gap = 14;
        var left = Math.max(12, Math.min(window.innerWidth - card.width - 12, target.left + target.width / 2 - card.width / 2));
        var top = target.bottom + gap;
        if (top + card.height > window.innerHeight - 12) { top = Math.max(12, target.top - card.height - gap); }
        tourCard.style.left = left + 'px'; tourCard.style.top = top + 'px'; tourCard.style.right = 'auto'; tourCard.style.bottom = 'auto';
      }

      function showStep(index) {
        clearTarget(); currentStep = Math.max(0, Math.min(steps.length - 1, index));
        var step = steps[currentStep]; activeTarget = document.querySelector(step.selector);
        if (activeTarget) { activeTarget.classList.add('tour-target'); }
        tourStepLabel.textContent = 'Step ' + (currentStep + 1) + ' of ' + steps.length;
        tourTitle.textContent = step.title; tourDescription.textContent = step.description;
        tourBack.disabled = currentStep === 0; tourNext.textContent = currentStep === steps.length - 1 ? 'Finish' : 'Next';
        tourDots.querySelectorAll('span').forEach(function (dot, dotIndex) { dot.classList.toggle('active', dotIndex === currentStep); });
        requestAnimationFrame(function () { positionTour(); tourNext.focus(); });
      }

      function startTour() {
        options.beforeTour(); document.body.classList.add('tour-open'); tourLayer.setAttribute('aria-hidden', 'false'); showStep(0);
      }

      function finishTour() {
        clearTarget(); currentStep = -1; document.body.classList.remove('tour-open'); tourLayer.setAttribute('aria-hidden', 'true'); options.returnFocus();
      }

      makePresetCards();
      steps.forEach(function () { var dot = document.createElement('span'); tourDots.appendChild(dot); });
      skipButton.addEventListener('click', function () { completeWelcome(false); });
      continueButton.addEventListener('click', function () { if (selectedPreset) { completeWelcome(true); } });
      document.getElementById('showGuideButton').addEventListener('click', startTour);
      tourSkip.addEventListener('click', finishTour);
      tourBack.addEventListener('click', function () { showStep(currentStep - 1); });
      tourNext.addEventListener('click', function () { if (currentStep === steps.length - 1) { finishTour(); } else { showStep(currentStep + 1); } });
      welcomeDialog.addEventListener('keydown', function (event) { trapFocus(welcomeDialog, event); });
      tourCard.addEventListener('keydown', function (event) { trapFocus(tourCard, event); });
      document.addEventListener('keydown', function (event) {
        if (event.key !== 'Escape') { return; }
        if (document.body.classList.contains('onboarding-open')) { completeWelcome(false); }
        else if (document.body.classList.contains('tour-open')) { finishTour(); }
      });
      window.addEventListener('resize', positionTour);

      if (!options.completeInitially) { openWelcome(); }
      return { startTour: startTour };
    }
  };
}());
