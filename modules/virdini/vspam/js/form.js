(function ($) {
  'use strict';

  var forms = $('form.vspam-protect'), form,
      buttons = forms.find('input[type=submit]:not(:disabled)'),
      input = 'input[name="vspam_token"]';

  buttons.prop('disabled', true);
  forms.find(input).val('');

  window.vspamOnload = function() {
    buttons.prop('disabled', false);
  };

  forms.submit(function(e) {
    if ($(this).find(input).val() != '') {
      return true;
    }
    e.preventDefault();
    buttons.prop('disabled', true);
    form = $(this);
    grecaptcha.execute($(this).data('vspam-key'), {action: $(this).data('vspam-action')}).then(function(token) {
      form.find(input).val(token);
      form.submit();
    });
    return false;
  });

})(jQuery);
