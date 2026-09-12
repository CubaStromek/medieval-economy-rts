/* Display existing frames only. Works from file: without fetch or image processing. */
(function () {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const manifest = window.WALK_MANIFEST;
  const state = { frame: 0, fps: 10, playing: false, ready: false, guides: false, lastTime: null, elapsed: 0 };
  let rafId = 0;
  let cards = [];
  const finite = (n) => typeof n === 'number' && Number.isFinite(n);
  const positive = (n) => finite(n) && n > 0;
  const relativeFile = (file) => typeof file === 'string' && file.length > 0 && !/^(?:[a-z][a-z0-9+.-]*:|\/|\\)/i.test(file);

  function showStatus(text) {
    $('status').textContent = text;
    $('status').hidden = !text;
  }

  if (!manifest || manifest.direction !== 'SE' || !positive(manifest.frameWidth) || !positive(manifest.frameHeight)
      || !positive(manifest.bodyHeight) || manifest.bodyHeight > manifest.frameHeight
      || !Array.isArray(manifest.anchor) || manifest.anchor.length !== 2 || !manifest.anchor.every(finite)
      || !Array.isArray(manifest.frames) || manifest.frames.length !== 8
      || !manifest.frames.every((frame) => frame && relativeFile(frame.file))) {
    showStatus('Chybí úplný popis osmi snímků pro směr SE. Náhled potřebuje vedle sebe manifest.js a složku frames.');
    $('message').textContent = 'Podklady zatím nejsou připravené k přehrání.';
    return;
  }

  const count = manifest.frames.length;
  state.fps = [4, 8, 10].includes(manifest.defaultFps) ? manifest.defaultFps : 10;
  $('fps').value = String(state.fps);
  const label = (i) => typeof manifest.frames[i].label === 'string' && manifest.frames[i].label.trim()
    ? manifest.frames[i].label : 'Fáze ' + (i + 1);

  function placeSprite(stage, sprite, guide, small) {
    const bounds = stage.getBoundingClientRect();
    const scale = small ? 33 / manifest.bodyHeight : Math.max(.01, Math.min(
      (bounds.width - 36) / manifest.frameWidth, (bounds.height - 24) / manifest.frameHeight));
    const width = manifest.frameWidth * scale;
    const height = manifest.frameHeight * scale;
    const left = (bounds.width - width) / 2;
    const top = small ? 72 - manifest.anchor[1] * scale : (bounds.height - height) / 2;
    sprite.style.width = width + 'px';
    sprite.style.height = height + 'px';
    sprite.style.left = left + 'px';
    sprite.style.top = top + 'px';
    guide.style.left = left + manifest.anchor[0] * scale + 'px';
    guide.style.top = top + manifest.anchor[1] * scale + 'px';
    guide.hidden = !state.guides || !state.ready;
  }

  function layout() {
    placeSprite($('large-stage'), $('large-sprite'), $('large-guide'), false);
    placeSprite($('small-stage'), $('small-sprite'), $('small-guide'), true);
  }

  function setFrame(index) {
    state.frame = ((index % count) + count) % count;
    const frame = manifest.frames[state.frame];
    $('large-sprite').src = frame.file;
    $('small-sprite').src = frame.file;
    $('phase-label').textContent = label(state.frame);
    $('phase-detail').textContent = 'Snímek ' + (state.frame + 1) + ' / ' + count + ' · jihovýchod ↘';
    $('counter').textContent = (state.frame + 1) + ' / ' + count;
    $('frame').value = String(state.frame);
    $('frame').setAttribute('aria-valuetext', 'Snímek ' + (state.frame + 1) + ': ' + label(state.frame));
    cards.forEach((card, i) => card.setAttribute('aria-pressed', String(i === state.frame)));
  }

  function setPlayback(playing) {
    state.playing = playing && state.ready;
    state.lastTime = null;
    state.elapsed = 0;
    $('play').textContent = state.playing ? 'Ⅱ Pozastavit' : '▶ Přehrát';
    $('play').setAttribute('aria-label', state.playing ? 'Pozastavit animaci' : 'Přehrát animaci');
    if (state.playing && !rafId) rafId = requestAnimationFrame(animate);
    if (!state.playing && rafId) { cancelAnimationFrame(rafId); rafId = 0; }
  }

  function animate(now) {
    rafId = 0;
    if (!state.playing) return;
    if (state.lastTime !== null) state.elapsed += Math.min(now - state.lastTime, 250);
    state.lastTime = now;
    const duration = 1000 / state.fps;
    if (state.elapsed >= duration) {
      const steps = Math.floor(state.elapsed / duration);
      state.elapsed -= steps * duration;
      setFrame(state.frame + steps);
    }
    rafId = requestAnimationFrame(animate);
  }

  function step(amount) {
    if (!state.ready) return;
    setPlayback(false);
    setFrame(state.frame + amount);
  }

  const loads = manifest.frames.map((frame, index) => {
    const card = document.createElement('button');
    card.type = 'button'; card.className = 'frame-card'; card.disabled = true;
    card.setAttribute('aria-label', 'Zastavit na snímku ' + (index + 1) + ': ' + label(index));
    card.setAttribute('aria-pressed', String(index === 0));
    const img = document.createElement('img');
    img.alt = ''; img.width = manifest.frameWidth; img.height = manifest.frameHeight;
    const caption = document.createElement('div'); caption.className = 'frame-label';
    const number = document.createElement('b'); number.textContent = String(index + 1).padStart(2, '0');
    const name = document.createElement('span'); name.textContent = label(index);
    caption.append(number, name); card.append(img, caption); $('frames').appendChild(card);
    cards.push(card);
    card.addEventListener('click', () => { setPlayback(false); setFrame(index); });
    return new Promise((resolve) => {
      img.onload = () => {
        const valid = img.naturalWidth === manifest.frameWidth && img.naturalHeight === manifest.frameHeight;
        if (!valid) { card.classList.add('error'); name.textContent = 'Jiné rozměry'; }
        resolve({ valid, index });
      };
      img.onerror = () => { card.classList.add('error'); name.textContent = 'Chybí snímek'; resolve({ valid: false, index }); };
      img.src = frame.file;
    });
  });

  $('play').addEventListener('click', () => setPlayback(!state.playing));
  $('previous').addEventListener('click', () => step(-1));
  $('next').addEventListener('click', () => step(1));
  $('frame').addEventListener('input', () => { setPlayback(false); setFrame(Number($('frame').value)); });
  $('fps').addEventListener('change', () => { state.fps = Number($('fps').value); state.elapsed = 0; state.lastTime = null; });
  $('guides').addEventListener('change', () => { state.guides = $('guides').checked; layout(); });
  document.addEventListener('keydown', (event) => {
    if (!state.ready || event.altKey || event.ctrlKey || event.metaKey || event.shiftKey
        || /^(INPUT|SELECT|TEXTAREA|BUTTON)$/.test(event.target.tagName) || event.target.isContentEditable) return;
    if (event.code === 'Space') { event.preventDefault(); setPlayback(!state.playing); }
    else if (event.code === 'ArrowLeft') { event.preventDefault(); step(-1); }
    else if (event.code === 'ArrowRight') { event.preventDefault(); step(1); }
  });
  document.addEventListener('visibilitychange', () => { state.lastTime = null; state.elapsed = 0; });
  window.addEventListener('resize', layout);
  if (typeof ResizeObserver !== 'undefined') {
    const observer = new ResizeObserver(layout);
    observer.observe($('large-stage')); observer.observe($('small-stage'));
  }
  layout();
  Promise.all(loads).then((results) => {
    const failed = results.filter((result) => !result.valid).map((result) => result.index + 1);
    if (failed.length) {
      showStatus('Snímky ' + failed.join(', ') + ' chybí nebo mají jiné rozměry než popis. Cyklus zatím nelze přehrát.');
      $('message').textContent = 'Pro přehrání je potřeba všech osm snímků.';
      return;
    }
    state.ready = true;
    ['play', 'previous', 'next', 'frame'].forEach((id) => { $(id).disabled = false; });
    cards.forEach((card) => { card.disabled = false; });
    $('message').hidden = true;
    $('large-sprite').hidden = false; $('small-sprite').hidden = false;
    setFrame(0); layout();
    const reducedMotion = typeof window.matchMedia === 'function' && window.matchMedia('(prefers-reduced-motion: reduce)').matches;
    setPlayback(!reducedMotion);
  });
}());
