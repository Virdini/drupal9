<?php

namespace Drupal\vbase\Form;

use Drupal\Core\Form\FormStateInterface;

/**
 * Configure site meta-tags settings for this site.
 */
class TagsSettings extends ConfigTypedFormBase {

  /**
   * {@inheritdoc}
   */
  protected $configName = 'vbase.settings.tags';

  /**
   * {@inheritdoc}
   */
  public function getFormId() {
    return 'vbase_tags_settings';
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state) {
    $config = $this->config($this->configName);
    $definition = $this->definition($this->configName);

    $form['base'] = [
      '#type' => 'textfield',
      '#title' => $this->t($definition['mapping']['base']['label']),
      '#default_value' => $config->get('base'),
    ];
    foreach ($definition['mapping'] as $key => $info) {
      if ($info['type'] == 'boolean') {
        $form[$key] = [
          '#type' => 'checkbox',
          '#title' => $this->t($info['label']),
          '#default_value' => $config->get($key),
        ];
      }
    }
    return parent::buildForm($form, $form_state);
  }

}
