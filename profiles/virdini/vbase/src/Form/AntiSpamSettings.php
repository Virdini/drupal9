<?php

namespace Drupal\vbase\Form;

use Drupal\Core\Form\FormStateInterface;

/**
 * Configure site anti-spam settings for this site.
 */
class AntiSpamSettings extends ConfigTypedFormBase {

  /**
   * {@inheritdoc}
   */
  protected $configName = 'vbase.settings.antispam';

  /**
   * {@inheritdoc}
   */
  public function getFormId() {
    return 'vbase_antispam_settings';
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state) {
    $config = $this->config($this->configName);
    $definition = $this->definition($this->configName);

    $form['google'] = [
      '#type' => 'fieldset',
      '#title' => $this->t('Google Invisible reCAPTCHA'),
    ];
    foreach (['site_key' => 'google', 'secret_key' => 'google'] as $key => $group) {
      $form[$group][$key] = [
        '#title' => $this->t($definition['mapping'][$key]['label']),
        '#type' => 'textfield',
        '#default_value' => $config->get($key),
      ];
    }
    $form['forms'] = [
      '#type' => 'textarea',
      '#title' => $this->t($definition['mapping']['forms']['label']),
      '#default_value' => $config->get('forms') ? implode("\n", $config->get('forms')) : '',
      '#description' => $this->t('Enter form id one path per line.'),
      '#rows' => 10,
    ];

    return parent::buildForm($form, $form_state);
  }

  /**
   * {@inheritdoc}
   */
  public function submitForm(array &$form, FormStateInterface $form_state) {
    $config = $this->config($this->configName);
    $definition = $this->definition($this->configName);
    foreach ($form_state->getValues() as $key => $value) {
      if (isset($definition['mapping'][$key])) {
        if ($key == 'forms') {
          $value = preg_split('/(\r\n?|\n)/', $value);
        }
        $config->set($key, $value);
      }
    }
    $config->save();
    parent::submitForm($form, $form_state);
  }

}
