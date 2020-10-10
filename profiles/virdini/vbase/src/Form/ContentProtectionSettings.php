<?php

namespace Drupal\vbase\Form;

use Drupal\Core\Config\ConfigFactoryInterface;
use Drupal\Core\Config\TypedConfigManagerInterface;
use Drupal\Core\Entity\EntityTypeManagerInterface;
use Drupal\Core\Form\FormStateInterface;
use Symfony\Component\DependencyInjection\ContainerInterface;

/**
 * Configure site content protection settings for this site.
 */
class ContentProtectionSettings extends ConfigTypedFormBase {

  /**
   * {@inheritdoc}
   */
  protected $configName = 'vbase.settings.cp';

  /**
   * The entity type manager.
   *
   * @var \Drupal\Core\Entity\EntityTypeManagerInterface
   */
  protected $entityTypeManager;

  /**
   * Constructs a \Drupal\vbase\Form\ContentProtectionSettings object.
   *
   * @param \Drupal\Core\Config\ConfigFactoryInterface $config_factory
   *   The factory for configuration objects.
   * @param \Drupal\Core\Config\TypedConfigManagerInterface $config_typed
   *   The typed config manager.
   * @param \Drupal\Core\Entity\EntityTypeManagerInterface $entity_type_manager
   *   The entity type manager.
   */
  public function __construct(ConfigFactoryInterface $config_factory, TypedConfigManagerInterface $config_typed, EntityTypeManagerInterface $entity_type_manager) {
    parent::__construct($config_factory, $config_typed);
    $this->entityTypeManager = $entity_type_manager;
  }

  /**
   * {@inheritdoc}
   */
  public static function create(ContainerInterface $container) {
    return new static(
      $container->get('config.factory'),
      $container->get('config.typed'),
      $container->get('entity_type.manager')
    );
  }

  /**
   * {@inheritdoc}
   */
  public function getFormId() {
    return 'vbase_content_protection_settings';
  }

  /**
   * {@inheritdoc}
   */
  public function buildForm(array $form, FormStateInterface $form_state) {
    $config = $this->config($this->configName);
    $definition = $this->definition($this->configName);

    $form['node_bundles'] = [
      '#type' => 'select',
      '#multiple' => TRUE,
      '#title' => $this->t($definition['mapping']['node_bundles']['label']),
      '#options' => [],
      '#default_value' => $config->get('node_bundles'),
    ];
    $form['taxonomy_vocabularies'] = [
      '#type' => 'select',
      '#multiple' => TRUE,
      '#title' => $this->t($definition['mapping']['taxonomy_vocabularies']['label']),
      '#options' => [],
      '#default_value' => $config->get('taxonomy_vocabularies'),
    ];

    $node_type_storage = $this->entityTypeManager->getStorage('node_type');
    $vocabulary_storage = $this->entityTypeManager->getStorage('taxonomy_vocabulary');
    foreach ($node_type_storage->loadMultiple() as $entity) {
      $form['node_bundles']['#options'][$entity->id()] = $entity->label();
    }
    foreach ($vocabulary_storage->loadMultiple() as $entity) {
      $form['taxonomy_vocabularies']['#options'][$entity->id()] = $entity->label();
    }

    return parent::buildForm($form, $form_state);
  }

}
