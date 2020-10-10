<?php

namespace Drupal\vbase\Form;

use Drupal\Core\Form\FormStateInterface;

/**
 * Provides a 'UserManagement'
 */
class UserManagement extends ConfigTypedFormBase {

  /**
   * {@inheritdoc}
   */
  protected $configName = 'vbase.settings.users';

  /**
   * {@inheritdoc}
   */
  public function getFormId() {
    return 'vbase_user_management';
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state) {
    $config = $this->config($this->configName);
    $definition = $this->definition($this->configName);

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
