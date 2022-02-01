<?php

namespace Drupal\vtech\Form;

use Drupal\vbase\Form\ConfigTypedFormBase;
use Drupal\Core\Form\FormStateInterface;

/**
 * Configure the display of the developer badge.
 */
class DevelopersSettings extends ConfigTypedFormBase {

  /**
   * {@inheritdoc}
   */
  protected $configName = 'vtech.settings.developers';

  /**
   * {@inheritdoc}
   */
  public function getFormId() {
    return 'vtech_developers_settings';
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state) {
    $form['#attached']['library'][] = 'vtech/developers.settings';

    $config = $this->config($this->configName);
    $definition = $this->definition($this->configName);

    $form['logo'] = [
      '#type' => 'select',
      '#title' => $this->t($definition['mapping']['logo']['label']),
      '#default_value' => $config->get('logo'),
      '#field_suffix' => '<img id="developers-settings-logo" src="https://info.virdini.com/logo/'. $config->get('logo') .'" width="'. $config->get('width') .'">',
      '#options' => [
        'logo.svg' => 'logo.svg',
        'logo.dark.svg' => 'logo.dark.svg',
        'virdini.black.svg' => 'virdini.black.svg',
        'virdini.white.svg' => 'virdini.white.svg',
        'virdini.black.t.svg' => 'virdini.black.t.svg',
        'virdini.white.t.svg' => 'virdini.white.t.svg',
      ],
      '#required' => TRUE,
    ];

    $form['width'] = [
      '#type' => 'number',
      '#title' => $this->t($definition['mapping']['width']['label']),
      '#default_value' => $config->get('width'),
      '#required' => TRUE,
      '#step' => 1,
      '#min' => 70,
    ];

    foreach (['nofollow', 'developed', 'maintained', 'label'] as $key) {
      $form[$key] = [
        '#title' => $this->t($definition['mapping'][$key]['label']),
        '#type' => 'checkbox',
        '#default_value' => $config->get($key),
      ];
    }

    return parent::buildForm($form, $form_state);
  }

}
