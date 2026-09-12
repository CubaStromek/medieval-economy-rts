/* Local, read-only animation review. No fetch, storage, game state or network. */
(function () {
  'use strict';
  const $ = (id) => document.getElementById(id);
  const names = {
    N: ['Sever', '↑'], NE: ['Severovýchod', '↗'], E: ['Východ', '→'], SE: ['Jihovýchod', '↘'],
    S: ['Jih', '↓'], SW: ['Jihozápad', '↙'], W: ['Západ', '←'], NW: ['Severozápad', '↖']
  };
  const order = Object.keys(names);
  const manifest = window.WALK_MANIFEST;
  const state = { frame: 0, selected: 'SE', playing: false, fps: 10, zoom: 1, guides: false, lastTime: null, elapsed: 0 };
  let entries = [];
  let frameCount = 8;
  let maxExtent = { left: 1, right: 1, up: 1, down: 1 };
  let rafId = 0;

  function status(message) {
    $('status').textContent = message;
    $('status').hidden = !message;
  }
  function problem(message) {
    status(message);
    $('stage-message').textContent = 'Náhled zatím nemá všechny potřebné podklady.';
    $('stage-message').hidden = false;
  }
  function finiteNumber(value) { return typeof value === 'number' && Number.isFinite(value); }
  function validFrame(frame) {
    return frame && Array.isArray(frame.rect) && frame.rect.length === 4 && frame.rect.every(finiteNumber)
      && frame.rect[0] >= 0 && frame.rect[1] >= 0 && frame.rect[2] > 0 && frame.rect[3] > 0
      && Array.isArray(frame.anchor) && frame.anchor.length === 2 && frame.anchor.every(finiteNumber);
  }
  function setPlayback(playing) {
    state.playing = playing;
    state.lastTime = null;
    state.elapsed = 0;
    $('play').textContent = playing ? 'Ⅱ Pozastavit' : '▶ Přehrát';
    $('play').setAttribute('aria-label', playing ? 'Pozastavit animaci' : 'Přehrát animaci');
    if (playing && !rafId) rafId = requestAnimationFrame(animate);
    if (!playing && rafId) { cancelAnimationFrame(rafId); rafId = 0; }
  }
  function setFrame(frame) {
    state.frame = ((frame % frameCount) + frameCount) % frameCount;
    $('frame').value = String(state.frame);
    $('frame').setAttribute('aria-valuetext', 'Snímek ' + (state.frame + 1) + ' z ' + frameCount);
    $('frame-counter').textContent = 'Snímek ' + (state.frame + 1) + ' z ' + frameCount;
    $('focus-frame').textContent = 'Snímek ' + (state.frame + 1) + ' / ' + frameCount;
    render();
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
  function contextFor(canvas) {
    const bounds = canvas.getBoundingClientRect();
    const width = Math.max(1, bounds.width), height = Math.max(1, bounds.height);
    const dpr = Math.min(window.devicePixelRatio || 1, 3);
    const pixelWidth = Math.round(width * dpr), pixelHeight = Math.round(height * dpr);
    if (canvas.width !== pixelWidth || canvas.height !== pixelHeight) { canvas.width = pixelWidth; canvas.height = pixelHeight; }
    const ctx = canvas.getContext('2d');
    ctx.setTransform(dpr, 0, 0, dpr, 0, 0);
    ctx.clearRect(0, 0, width, height);
    ctx.fillStyle = '#fff';
    ctx.fillRect(0, 0, width, height);
    ctx.imageSmoothingEnabled = true;
    ctx.imageSmoothingQuality = 'high';
    return { ctx, width, height };
  }
  function draw(entry, canvas, focused) {
    const { ctx, width, height } = contextFor(canvas);
    if (!entry || entry.loading || entry.error) {
      if (!focused) {
        ctx.fillStyle = entry && entry.error ? '#9d4d2b' : '#839080';
        ctx.font = '12px system-ui, sans-serif'; ctx.textAlign = 'center';
        ctx.fillText(entry && entry.error ? 'Chybí podklad' : 'Načítání…', width / 2, height / 2);
      }
      return;
    }
    const frame = entry.frames[state.frame % entry.frames.length];
    const [sx, sy, sw, sh] = frame.rect;
    const [ax, ay] = frame.anchor;
    const base = Math.min((width - (focused ? 48 : 14)) / (maxExtent.left + maxExtent.right),
      (height - (focused ? 65 : 22)) / (maxExtent.up + maxExtent.down));
    const preferred = finiteNumber(manifest.previewScale) && manifest.previewScale > 0
      ? manifest.previewScale : 300 / (maxExtent.up + maxExtent.down);
    const commonScale = focused ? Math.min(base, preferred * state.zoom) : base;
    const scale = commonScale * entry.displayScale;
    const anchorX = width / 2 + (maxExtent.left - maxExtent.right) * commonScale / 2;
    const anchorY = height / 2 + (maxExtent.up - maxExtent.down) * commonScale / 2;
    ctx.drawImage(entry.image, sx, sy, sw, sh, anchorX - ax * scale, anchorY - ay * scale, sw * scale, sh * scale);
    if (state.guides) {
      ctx.save(); ctx.lineWidth = 1; ctx.strokeStyle = '#9b633e99'; ctx.setLineDash([4, 4]);
      ctx.beginPath(); ctx.moveTo(8, anchorY); ctx.lineTo(width - 8, anchorY); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(anchorX, 8); ctx.lineTo(anchorX, height - 8); ctx.stroke();
      ctx.setLineDash([]); ctx.strokeStyle = '#a8572c'; ctx.lineWidth = 1.5;
      ctx.beginPath(); ctx.arc(anchorX, anchorY, 4, 0, Math.PI * 2); ctx.stroke();
      ctx.beginPath(); ctx.moveTo(anchorX - 8, anchorY); ctx.lineTo(anchorX + 8, anchorY);
      ctx.moveTo(anchorX, anchorY - 8); ctx.lineTo(anchorX, anchorY + 8); ctx.stroke(); ctx.restore();
    }
  }
  function render() {
    entries.forEach((entry) => draw(entry, entry.canvas, false));
    const focused = entries.find((entry) => entry.id === state.selected);
    draw(focused, $('focus-canvas'), true);
    if (focused) {
      $('stage-message').hidden = !focused.loading && !focused.error;
      $('stage-message').textContent = focused.error ? 'Podklad pro tento směr se nepodařilo načíst.' : 'Načítám snímky…';
    }
  }
  function select(id) {
    state.selected = id;
    const title = $('focus-title');
    title.replaceChildren(document.createTextNode(names[id][0] + ' '));
    const small = document.createElement('span'); small.className = 'small'; small.textContent = id + ' ' + names[id][1]; title.appendChild(small);
    $('stage-caption').textContent = names[id][0] + ' · ' + frameCount + ' snímků v cyklu';
    entries.forEach((entry) => entry.button.setAttribute('aria-pressed', String(entry.id === id)));
    render();
  }
  function makeCard(entry) {
    const button = document.createElement('button'); button.type = 'button'; button.className = 'direction';
    button.setAttribute('aria-label', 'Zobrazit detail: ' + names[entry.id][0]); button.setAttribute('aria-pressed', String(entry.id === state.selected));
    const canvas = document.createElement('canvas'); canvas.setAttribute('aria-hidden', 'true'); button.appendChild(canvas);
    const label = document.createElement('div'); label.className = 'direction-label';
    const title = document.createElement('strong'); title.textContent = entry.id + ' ' + names[entry.id][1];
    const detail = document.createElement('span'); detail.textContent = names[entry.id][0];
    label.append(title, detail); button.appendChild(label); $('directions').appendChild(button);
    button.addEventListener('click', () => select(entry.id));
    entry.button = button; entry.canvas = canvas; entry.detail = detail;
  }
  function refreshStatus() {
    const missing = entries.filter((entry) => entry.error).map((entry) => entry.id);
    const pending = entries.filter((entry) => entry.loading).length;
    status(missing.length ? 'Nepodařilo se načíst směry ' + missing.join(', ') + '. Ostatní dostupné směry lze prohlédnout.' :
      pending ? 'Načítám podklady pro ' + pending + ' směrů…' : '');
    const ready = entries.some((entry) => !entry.loading && !entry.error);
    ['play', 'previous', 'next', 'frame'].forEach((id) => { $(id).disabled = !ready; });
    if (!ready) setPlayback(false);
  }
  function loadEntry(entry) {
    entry.image = new Image();
    entry.image.onload = function () {
      const width = entry.image.naturalWidth, height = entry.image.naturalHeight;
      entry.error = entry.frames.some((frame) => frame.rect[0] + frame.rect[2] > width || frame.rect[1] + frame.rect[3] > height);
      entry.loading = false;
      if (entry.error) { entry.button.classList.add('error'); entry.detail.textContent = 'Mimo obraz'; }
      refreshStatus(); render();
    };
    entry.image.onerror = function () {
      entry.loading = false; entry.error = true; entry.button.classList.add('error'); entry.detail.textContent = 'Nenačteno';
      refreshStatus(); render();
    };
    entry.image.src = entry.sheet;
  }

  if (!manifest || !Array.isArray(manifest.directions) || !manifest.directions.length) {
    problem('Chybí manifest.js s popisem snímků. Otevřete náhled ve složce obsahující také manifest.js a složku sheets.'); return;
  }
  frameCount = Number.isInteger(manifest.frameCount) && manifest.frameCount > 0 ? manifest.frameCount : 8;
  const valid = manifest.directions.every((entry) => entry && names[entry.id] && typeof entry.sheet === 'string'
    && entry.sheet.length > 0 && !/^(?:[a-z][a-z0-9+.-]*:|\/|\\)/i.test(entry.sheet)
    && Array.isArray(entry.frames) && entry.frames.length === frameCount && entry.frames.every(validFrame)
    && (entry.displayScale === undefined || finiteNumber(entry.displayScale) && entry.displayScale > 0));
  if (!valid || new Set(manifest.directions.map((entry) => entry.id)).size !== manifest.directions.length) {
    problem('Popis snímků není úplný nebo má neplatné rozměry. Každý směr musí mít stejný počet snímků a vlastní kotvy.'); return;
  }
  entries = manifest.directions.map((entry) => Object.assign({}, entry, { displayScale: entry.displayScale || 1, loading: true, error: false }))
    .sort((a, b) => order.indexOf(a.id) - order.indexOf(b.id));
  entries.forEach((entry) => entry.frames.forEach((frame) => {
    const [ax, ay] = frame.anchor, [, , w, h] = frame.rect, s = entry.displayScale;
    maxExtent.left = Math.max(maxExtent.left, ax * s); maxExtent.right = Math.max(maxExtent.right, (w - ax) * s);
    maxExtent.up = Math.max(maxExtent.up, ay * s); maxExtent.down = Math.max(maxExtent.down, (h - ay) * s);
  }));
  if (!entries.some((entry) => entry.id === state.selected)) state.selected = entries[0].id;
  entries.forEach(makeCard);
  $('frame').max = String(frameCount - 1);
  state.fps = finiteNumber(manifest.fps) ? Math.max(6, Math.min(16, manifest.fps)) : 10;
  if (!Array.from($('fps').options).some((option) => Number(option.value) === state.fps)) {
    const option = document.createElement('option'); option.value = String(state.fps); option.textContent = state.fps + ' sn./s'; $('fps').appendChild(option);
  }
  $('fps').value = String(state.fps);
  (Array.isArray(manifest.notes) ? manifest.notes : []).forEach((note) => {
    if (typeof note !== 'string' || !note.trim()) return;
    const item = document.createElement('li'); item.textContent = note; $('notes').appendChild(item);
  });
  $('technical-note').textContent = entries.length + ' směrů × ' + frameCount + ' snímků · místní náhled';
  $('play').addEventListener('click', () => setPlayback(!state.playing));
  $('previous').addEventListener('click', () => { setPlayback(false); setFrame(state.frame - 1); });
  $('next').addEventListener('click', () => { setPlayback(false); setFrame(state.frame + 1); });
  $('frame').addEventListener('input', () => { setPlayback(false); setFrame(Number($('frame').value)); });
  $('fps').addEventListener('change', () => { state.fps = Number($('fps').value); state.elapsed = 0; });
  $('zoom').addEventListener('change', () => { state.zoom = Number($('zoom').value); render(); });
  $('guides').addEventListener('change', () => { state.guides = $('guides').checked; render(); });
  document.addEventListener('visibilitychange', () => { state.lastTime = null; state.elapsed = 0; });
  window.addEventListener('resize', render);
  if (typeof ResizeObserver !== 'undefined') {
    const observer = new ResizeObserver(render); observer.observe($('focus-canvas').parentElement); observer.observe($('directions'));
  }
  select(state.selected); setFrame(0); refreshStatus(); entries.forEach(loadEntry);
}());
