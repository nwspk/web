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
