(function (d) {

  'use strict';

  var select = d.getElementById('edit-logo'),
      img = d.getElementById('developers-settings-logo'),
      url = img.src.substring(0, img.src.lastIndexOf('/') + 1);

  show_logo(select);

  select.addEventListener('change', function() {
    show_logo(this);
  });

  function show_logo(el) {
    img.src = url + el.value;
  }

})(document);
