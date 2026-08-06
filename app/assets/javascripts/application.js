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
