<?php

namespace Drupal\vbase\Form;

use Drupal\Core\Form\FormStateInterface;

/**
 * Configure site browsers support settings for this site.
 */
class BrowsersSupportSettings extends ConfigTypedFormBase {

  /**
   * {@inheritdoc}
   */
  protected $configName = 'vbase.settings.browsers';

  /**
   * {@inheritdoc}
   */
  public function getFormId() {
    return 'vbase_browsers_support_settings';
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state) {
    $config = $this->config($this->configName);
    $definition = $this->definition($this->configName);

    $form['ie'] = [
      '#type' => 'select',
      '#title' => $this->t($definition['mapping']['ie']['label']),
      '#default_value' => $config->get('ie'),
      '#options' => [
        'unsupported' => $this->t('(Unsupported)'),
        '11' => '11',
        '10' => '10+',
        '9' => '9+',
        '8' => '8+',
        '7' => '7+',
      ],
    ];

    return parent::buildForm($form, $form_state);
  }

}
