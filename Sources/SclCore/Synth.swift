// The synth strip above the keyboard and its script. Everything is plain Web Audio (no library): each key press
// starts one sine oscillator per pitch the key carries (data-c, cents above 1/1), behind a gain with a 100 ms
// attack and a 100 ms release, so chords and several fingers play polyphonically.
//   1/1 is the keyboard's C: middle C at octave 0, a major sixth below the A4 reference (440 Hz unless changed in the
//   box next to the octave stepper). Each octave step is a real 2:1 octave, from -4 to +4.
//   Audio is on from the start (the context itself is created shortly after the page has been shown); the browser still keeps the audio context suspended until the first tap or click on the
//   page, so the script resumes it on every gesture. Only the keyboard triggers sound.
import Foundation

func synthHeader(reference: Double, octave: Int) -> String {
    let on = esc(tr("audio.on")), off = esc(tr("audio.off"))
    let down = esc(tr("oct.down")), up = esc(tr("oct.up")), oct = esc(tr("oct")), tuning = esc(tr("tuning"))
    return """
    <div class="phead"><h2>\(esc(tr("onePeriod")))</h2><div class="synth" data-ref="\(refText(reference))" data-oct="\(octave)">\
    <button class="audio" type="button" title="\(off)" aria-label="\(off)" data-t-on="\(off)" data-t-off="\(on)">\
    <svg class="i-off" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9v6h4l5 4V5L8 9H4z" fill="currentColor"/><path d="M17 9l5 6M22 9l-5 6"/></svg>\
    <svg class="i-on" viewBox="0 0 24 24" fill="none" stroke="currentColor" stroke-width="2" stroke-linecap="round" stroke-linejoin="round"><path d="M4 9v6h4l5 4V5L8 9H4z" fill="currentColor"/><path d="M16.5 8.5a5 5 0 0 1 0 7M19 6a8.5 8.5 0 0 1 0 12"/></svg>\
    </button>\
    <button class="odn" type="button" title="\(down)" aria-label="\(down)">&minus;</button>\
    <span class="oval" title="\(oct)" aria-label="\(oct)">\(octave)</span>\
    <button class="oup" type="button" title="\(up)" aria-label="\(up)">+</button>\
    <label class="tune" title="\(tuning)">A4 <input class="ref" type="text" inputmode="decimal" size="6" value="\(refText(reference))" aria-label="\(tuning)"> Hz</label>\
    </div></div>
    """
}

/// 440 -> "440", 432.5 -> "432.5"
private func refText(_ hz: Double) -> String {
    var s = String(format: "%.2f", hz)
    while s.contains(".") && (s.hasSuffix("0") || s.hasSuffix(".")) { s.removeLast() }
    return s
}

let synthScript = #"""
(function () {
  var AC = window.AudioContext || window.webkitAudioContext;
  var bar = document.querySelector('.synth'), piano = document.querySelector('.piano');
  if (!bar || !piano) return;
  if (!AC) { bar.style.display = 'none'; return; }
  var audio = bar.querySelector('.audio'), odn = bar.querySelector('.odn'), oup = bar.querySelector('.oup');
  var oval = bar.querySelector('.oval'), refBox = bar.querySelector('.ref');
  var ctx = null, master = null, enabled = false, held = {};
  var oct = parseInt(bar.getAttribute('data-oct'), 10) || 0;     // -4 ... 4
  var hz = parseFloat(bar.getAttribute('data-ref')) || 440;      // frequency of A4
  var FADE = 0.1, PEAK = 0.16;

  function ensure() {
    try {
      if (!ctx) {
        var t0 = performance.now();
        ctx = new AC();
        master = ctx.createGain(); master.gain.value = 0.8;
        var comp = ctx.createDynamicsCompressor();
        master.connect(comp); comp.connect(ctx.destination);
        try { window.webkit.messageHandlers.synth.postMessage({ audioMs: Math.round(performance.now() - t0) }); } catch (e) {}
      }
      if (ctx.state !== 'running' && ctx.resume) ctx.resume();
    } catch (e) {}
    return !!ctx;
  }
  function report() {            // the app remembers octave and reference across scales
    try { window.webkit.messageHandlers.synth.postMessage({ ref: hz, oct: oct }); } catch (e) {}
  }
  // 1/1 is the keyboard's C: nine semitones below A4 at octave 0.
  function freq(cents) { return hz * Math.pow(2, -9 / 12 + oct + cents / 1200); }

  function press(id, key) {
    if (!ensure()) return;
    var t = ctx.currentTime, voices = [];
    key.getAttribute('data-c').split(',').forEach(function (c) {
      var o = ctx.createOscillator(), g = ctx.createGain();
      o.type = 'sine';
      o.frequency.value = freq(parseFloat(c));
      g.gain.setValueAtTime(0, t);
      g.gain.linearRampToValueAtTime(PEAK, t + FADE);
      o.connect(g); g.connect(master); o.start(t);
      voices.push([o, g]);
    });
    key.classList.add('down');
    held[id] = { key: key, voices: voices };
  }
  function release(id) {
    var h = held[id]; if (!h) return;
    delete held[id];
    h.key.classList.remove('down');
    var t = ctx.currentTime;
    h.voices.forEach(function (v) {
      var g = v[1].gain;
      g.cancelScheduledValues(t);
      g.setValueAtTime(g.value, t);
      g.linearRampToValueAtTime(0, t + FADE);
      v[0].stop(t + FADE + 0.02);
    });
  }
  function releaseAll() { Object.keys(held).forEach(release); }
  function keyAt(x, y) { var el = document.elementFromPoint(x, y); return el && el.closest ? el.closest('[data-c]') : null; }

  function setEnabled(v) {
    enabled = v;
    if (!v) releaseAll();
    audio.classList.toggle('ac', v);
    audio.classList.toggle('is-on', v);
    var label = audio.getAttribute(v ? 'data-t-on' : 'data-t-off');
    audio.title = label; audio.setAttribute('aria-label', label);
  }
  audio.addEventListener('click', function () { setEnabled(!enabled); if (enabled) ensure(); });

  function setOct(n) {
    oct = Math.max(-4, Math.min(4, n));
    oval.textContent = String(oct);
    odn.disabled = oct <= -4; oup.disabled = oct >= 4;
  }
  odn.addEventListener('click', function () { setOct(oct - 1); report(); });
  oup.addEventListener('click', function () { setOct(oct + 1); report(); });
  refBox.addEventListener('change', function () {
    var v = parseFloat(refBox.value.replace(',', '.'));
    if (isFinite(v) && v >= 100 && v <= 2000) hz = v;
    refBox.value = String(hz);
    report();
  });

  piano.addEventListener('pointerdown', function (e) {
    if (!enabled) return;
    var key = e.target.closest ? e.target.closest('[data-c]') : null;
    if (!key) return;
    e.preventDefault();
    // preventDefault also stops the focus change, so a value still being typed in the tuning box would not be
    // committed before the note is computed: take focus away ourselves.
    if (document.activeElement && document.activeElement.blur) document.activeElement.blur();
    try { piano.setPointerCapture(e.pointerId); } catch (x) {}
    press(e.pointerId, key);
  });
  piano.addEventListener('pointermove', function (e) {     // sliding a finger or the mouse over keys plays them in turn
    var h = held[e.pointerId]; if (!h) return;
    var key = keyAt(e.clientX, e.clientY);
    if (key && key !== h.key) { release(e.pointerId); press(e.pointerId, key); }
  });
  ['pointerup', 'pointercancel', 'lostpointercapture'].forEach(function (n) {
    piano.addEventListener(n, function (e) { release(e.pointerId); });
  });
  // Keep the keyboard free of everything the web view does with touches and clicks on its own: scrolling and
  // rubber-banding, long-press menus, text selection, double-tap and pinch zoom, and synthesized mouse events.
  ['touchstart', 'touchmove'].forEach(function (n) {
    piano.addEventListener(n, function (e) { e.preventDefault(); }, { passive: false });
  });
  ['contextmenu', 'selectstart', 'dblclick', 'dragstart'].forEach(function (n) {
    piano.addEventListener(n, function (e) { e.preventDefault(); });
  });
  document.addEventListener('gesturestart', function (e) { e.preventDefault(); });
  window.addEventListener('blur', releaseAll);
  // Audio starts suspended until the page gets a user gesture; resume it on any of them.
  ['pointerdown', 'touchend', 'click', 'keydown'].forEach(function (n) {
    document.addEventListener(n, function () { if (ctx && ctx.state !== 'running' && ctx.resume) ctx.resume(); }, true);
  });

  setOct(oct);
  refBox.value = String(hz);
  setEnabled(true);
  // Creating the audio context can take a while (it opens the audio device), so the page is shown first and the
  // context is made afterwards; a key press before that creates it on the spot.
  window.addEventListener('load', function () { setTimeout(ensure, 500); });
})();
"""#
