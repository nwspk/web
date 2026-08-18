//= require jquery
//= require jquery_ujs

//= require active_admin

// $(document).ready(function() {
//   $(".best_in_place").best_in_place();
// });

// Close the mobile nav drawer when a link inside it is tapped
// (matters for same-page anchors like /#events, where no page load happens)
document.addEventListener('click', function (e) {
  if (e.target.closest('aside nav a')) {
    var toggle = document.getElementById('nav-toggle');
    if (toggle) toggle.checked = false;
  }
});

// On the homepage the masthead plaque carries the identity, so the sidebar
// starts invisible and fades in scroll-linked: opacity tracks the plaque
// roundel's exit — the fade begins as the roundel starts to slide under the
// viewport top and completes the moment it clears, so the sidebar has fully
// taken over the identity before the roundel is gone.
document.addEventListener('DOMContentLoaded', function () {
  if (!document.body.classList.contains('home')) return;
  var roundel = document.querySelector('.plaque-roundel');
  var nav = document.querySelector('aside nav');
  if (!roundel || !nav) return;
  var mobile = window.matchMedia('(max-width: 940px)');
  var update = function () {
    if (mobile.matches) {
      nav.style.opacity = '';
      nav.style.visibility = '';
      return;
    }
    var rect = roundel.getBoundingClientRect();
    var progress = Math.min(Math.max(-rect.top / rect.height, 0), 1);
    nav.style.opacity = progress;
    nav.style.visibility = progress > 0 ? 'visible' : 'hidden';
  };
  window.addEventListener('scroll', function () { requestAnimationFrame(update); }, { passive: true });
  window.addEventListener('resize', function () { requestAnimationFrame(update); }, { passive: true });
  update();
});

// Homepage TOC links carry the shareable event URL (/events?id=N#event-N) so
// copying them yields a link with social-preview tags — but a normal click
// should still just scroll down the homepage, where the same event rows live.
// Intercept the click, scroll in place, and put the shareable URL in the
// address bar so copy-after-click shares correctly too.
document.addEventListener('click', function (e) {
  var link = e.target.closest('a[data-event-anchor]');
  if (!link) return;
  var target = document.getElementById(link.getAttribute('data-event-anchor'));
  if (!target) return;
  e.preventDefault();
  history.pushState(null, '', link.getAttribute('href'));
  target.scrollIntoView();
});

// Live text filter for the events page. All ~1,700 events are already in the
// DOM (kept lightweight by content-visibility in the CSS), so filtering is a
// substring match over a one-time index — no server round-trips.
document.addEventListener('DOMContentLoaded', function () {
  var input = document.getElementById('event-search-input');
  if (!input) return;
  var countEl = document.getElementById('event-search-count');
  var rows = null;

  function buildIndex() {
    rows = Array.prototype.map.call(document.querySelectorAll('.event[id^="event-"]'), function (el) {
      return { el: el, text: el.textContent.toLowerCase() };
    });
  }

  var timer = null;
  input.addEventListener('input', function () {
    clearTimeout(timer);
    timer = setTimeout(function () {
      if (!rows) buildIndex();
      var q = input.value.trim().toLowerCase();
      var shown = 0;
      rows.forEach(function (r) {
        var match = q === '' || r.text.indexOf(q) !== -1;
        r.el.style.display = match ? '' : 'none';
        if (match) shown++;
      });
      countEl.textContent = q === '' ? '' : shown + ' matching event' + (shown === 1 ? '' : 's');
    }, 120);
  });
});

// Decode Cloudflare-style obfuscated emails client-side, so the address is never
// in the served HTML (bots see "[email protected]") but humans get a real link.
// Mirrors Cloudflare's own email-decode: first hex byte is an XOR key.
(function () {
  function cfDecode(hex) {
    var key = parseInt(hex.substr(0, 2), 16), s = '';
    for (var i = 2; i < hex.length; i += 2) {
      s += String.fromCharCode(parseInt(hex.substr(i, 2), 16) ^ key);
    }
    try { return decodeURIComponent(escape(s)); } catch (e) { return s; }
  }
  document.addEventListener('DOMContentLoaded', function () {
    document.querySelectorAll('.__cf_email__').forEach(function (el) {
      var hex = el.getAttribute('data-cfemail');
      if (!hex) return;
      var email = cfDecode(hex);
      el.textContent = email;
      el.removeAttribute('data-cfemail');
      var a = el.closest('a');
      if (a) a.setAttribute('href', 'mailto:' + email);
    });
  });
})();
