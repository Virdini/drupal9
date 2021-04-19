<?php

use Drupal\Core\Cache\Cache;
use Drupal\Core\Cache\CacheableMetadata;
use Drupal\Core\Access\AccessResult;
use Drupal\Core\Session\AccountInterface;
use Drupal\Core\Entity\FieldableEntityInterface;
use Drupal\Core\Language\LanguageInterface;
use Drupal\Core\TypedData\TranslatableInterface;
use Drupal\Core\Entity\EntityInterface;
use Drupal\Core\Template\Attribute;
use Drupal\Core\Form\FormStateInterface;
use Drupal\file\FileInterface;
use Drupal\Core\Entity\ContentEntityInterface;
use Drupal\Core\Url;
use Drupal\Core\Field\BaseFieldDefinition;
use Drupal\Core\Entity\EntityTypeInterface;
use Drupal\Core\Field\FieldDefinitionInterface;
use Drupal\Core\Render\Element\Email;
use Drupal\Core\StringTranslation\TranslatableMarkup;

/**
 * Implements hook_form_FORM_ID_alter() for install_configure_form().
 */
function vbase_form_install_configure_form_alter(&$form) {
  $form['site_information']['site_name']['#default_value'] = 'Virdini Drupal';
  $form['site_information']['site_mail']['#default_value'] = 'dev@virdini.net';
  $form['admin_account']['account']['name']['#default_value'] = 'admin';
  $form['admin_account']['account']['mail']['#default_value'] = 'dev@virdini.net';
  $form['regional_settings']['site_default_country']['#default_value'] = 'UA';
  $form['update_notifications']['enable_update_status_module']['#default_value'] = 0;
  $form['update_notifications']['enable_update_status_emails']['#default_value'] = 0;
}

/**
 * Implements hook_google_tag_snippets_alter().
 */
function vbase_google_tag_snippets_alter(&$snippets) {
  $snippets['noscript'] = str_replace('<noscript', '<noscript class="visually-hidden"', $snippets['noscript']);
}

/**
 * Implements hook_ENTITY_TYPE_create_access().
 */
function vbase_taxonomy_term_create_access(AccountInterface $account, array $context, $entity_bundle) {
  return AccessResult::allowedIfHasPermission($account, 'vbase term all create');
}

/**
 * Implements hook_entity_access().
 */
function vbase_entity_access(EntityInterface $entity, $operation, AccountInterface $account) {
  $access = AccessResult::neutral();
  switch ($operation) {
    case 'view':
      if (in_array($entity->getEntityTypeId(), ['node', 'taxonomy_term'])) {
        $config = \Drupal::config('vbase.settings.cp');
        $bundles = $config->get($entity->getEntityTypeId() == 'node' ? 'node_bundles' : 'taxonomy_vocabularies');
        if (!empty($bundles) && in_array($entity->bundle(), $bundles)) {
          if (!$account->hasPermission('vbase view protected content')) {
            $route_match = \Drupal::routeMatch();
            if (preg_match('/entity\.' . $entity->getEntityTypeId() . '\.canonical$/', $route_match->getRouteName(), $matches)) {
              $route_entity = $route_match->getParameter($entity->getEntityTypeId());
              $access = AccessResult::forbiddenIf($route_entity->id() == $entity->id());
            }
            $access->addCacheContexts(['route']);
          }
          $access->cachePerPermissions();
        }
        $access->addCacheableDependency($config);
      }
      break;

    case 'update':
      if ($entity->getEntityTypeId() == 'user') {
        $access = AccessResult::forbiddenIf($entity->id() == 1 && $account->id() != 1)->cachePerUser();
      }
      break;
  }
  return $access;
}

/**
 * Implements hook_ENTITY_TYPE_presave() for node.
 */
function vbase_node_presave(EntityInterface $entity) {
  if ($entity->get('pubdate')->getString() == 0) {
    $entity->get('pubdate')->setValue([]);
  }
  if ($entity->get('unpubdate')->getString() == 0) {
    $entity->get('unpubdate')->setValue([]);
  }
}

/**
 * Implements hook_ENTITY_TYPE_load() for node.
 */
function vbase_node_load($entities) {
  foreach ($entities as $entity) {
    if ($entity->get('pubdate')->getString() == 0) {
      $entity->get('pubdate')->setValue([]);
    }
    if ($entity->get('unpubdate')->getString() == 0) {
      $entity->get('unpubdate')->setValue([]);
    }
  }
}

/**
 * Implements hook_cron().
 */
function vbase_cron() {
  $storage = \Drupal::entityTypeManager()->getStorage('node');
  // Delayed publish
  $query = $storage->getQuery();
  $query->condition('status', 0)
        ->condition('pubdate', 0, '<>')
        ->condition('pubdate', time(), '<');
  foreach ($storage->loadMultiple($query->execute()) as $entity) {
    _vbase_publish_delayed($entity);
    if ($entity->isTranslatable()) {
      foreach ($entity->getTranslationLanguages(FALSE) as $lang) {
        _vbase_publish_delayed($entity->getTranslation($lang->getId()));
      }
    }
  }
  // Delayed unpublish
  $query = $storage->getQuery();
  $query->condition('status', 1)
        ->condition('unpubdate', 0, '<>')
        ->condition('unpubdate', time(), '<');
  foreach ($storage->loadMultiple($query->execute()) as $entity) {
    _vbase_unpublish_delayed($entity);
    if ($entity->isTranslatable()) {
      foreach ($entity->getTranslationLanguages(FALSE) as $lang) {
        _vbase_unpublish_delayed($entity->getTranslation($lang->getId()));
      }
    }
  }
}

function _vbase_publish_delayed(EntityInterface $entity) {
  if (!$entity->isPublished() && $entity->get('pubdate')->getString() != 0 && $entity->get('pubdate')->getString() <= time()) {
    $entity->setPublished(TRUE)->save();
  }
}

function _vbase_unpublish_delayed(EntityInterface $entity) {
  if ($entity->isPublished() && $entity->get('unpubdate')->getString() != 0 && $entity->get('unpubdate')->getString() <= time()) {
    $entity->setPublished(FALSE)->save();
  }
}

/**
 * Implements hook_entity_base_field_info().
 */
function vbase_entity_base_field_info(EntityTypeInterface $entity_type) {
  if ($entity_type->id() == 'node') {
    $fields['pubdate'] = BaseFieldDefinition::create('timestamp')
      ->setLabel(t('Published from'))
      ->setDescription(t('The time that the node must be published.'))
      ->setRevisionable(TRUE)
      ->setTranslatable(TRUE)
      ->setDisplayOptions('form', [
        'type' => 'vbase_datetime_timestamp',
        'weight' => 0,
      ])
      ->setDisplayConfigurable('view', TRUE)
      ->setDisplayConfigurable('form', TRUE);
    $fields['unpubdate'] = BaseFieldDefinition::create('timestamp')
      ->setLabel(t('Unpublished from'))
      ->setDescription(t('The time that the node must be unpublished.'))
      ->setRevisionable(TRUE)
      ->setTranslatable(TRUE)
      ->setDisplayOptions('form', [
        'type' => 'vbase_datetime_timestamp',
        'weight' => 0,
      ])
      ->setDisplayConfigurable('view', TRUE)
      ->setDisplayConfigurable('form', TRUE);
    return $fields;
  }
}

/**
 * Implements hook_entity_field_access().
 */
function vbase_entity_field_access($operation, FieldDefinitionInterface $field_definition, AccountInterface $account) {
  if ($operation == 'edit' && in_array($field_definition->getName(), ['pubdate', 'unpubdate'])
      && $field_definition->getTargetEntityTypeId() == 'node') {
    if ($account->hasPermission('vbase delayed publishing all')
        || $account->hasPermission('vbase delayed publishing '. $field_definition->getTargetEntityTypeId())) {
      return AccessResult::allowed()->cachePerPermissions();
    }
    return AccessResult::forbidden()->cachePerPermissions();
  }
  return AccessResult::neutral();
}

/**
 * Implements hook_form_BASE_FORM_ID_alter() for node_form().
 */
function vbase_form_node_form_alter(&$form) {
  if (isset($form['pubdate'])) {
    $form['pubdate']['#group'] = 'author';
  }
  if (isset($form['unpubdate'])) {
    $form['unpubdate']['#group'] = 'author';
  }
}

/**
 * Implements hook_form_BASE_FORM_ID_alter() for the taxonomy_term_form().
 */
function vbase_form_taxonomy_term_form_alter(&$form, FormStateInterface &$form_state) {
  if (!isset($form['advanced'])) {
    $form['advanced'] = [
      '#type' => 'vertical_tabs',
      '#weight' => 99,
    ];
  }
  if (isset($form['relations']['#type']) && $form['relations']['#type'] == 'details') {
   $form['relations']['#group'] = 'advanced';
  }
}

/**
 * Implements hook_mail_alter().
 */
function vbase_mail_alter(&$message) {
  if (isset($message['params']['vbase_attachments'])
      && is_array($message['params']['vbase_attachments'])) {
    $uid = 'vbase-' . md5(uniqid(time(), TRUE));
    $lines = '';
    $lines .= "--$uid\r\n";
    $lines .= 'Content-Type: '. $message['headers']['Content-Type'] ."\r\n\r\n";
    $lines .= wordwrap(implode("\r\n\r\n", $message['body'])) . "\r\n";
    foreach ($message['params']['vbase_attachments'] as $attachment) {
      if ($attachment['content']) {
        $lines .= "\r\n--$uid\r\n";
        $lines .= 'Content-Type: '. $attachment['mime'] .'; name="'. $attachment['name'] ."\"\r\n";
        $lines .= 'Content-Disposition: attachment; filename="'. $attachment['name'] ."\"\r\n";
        $lines .= 'Content-Transfer-Encoding: base64'."\r\n\r\n";
        $lines .= chunk_split(base64_encode($attachment['content']));
      }
    }
    $lines .= "--$uid--";
    $message['body'] = [$lines];
    $message['headers']['Content-Type'] = 'multipart/mixed; boundary="'. $uid .'"';
  }
}

/**
 * Implements hook_form_alter().
 */
function vbase_form_alter(&$form, FormStateInterface $form_state, $form_id) {
  switch ($form_id) {
    case 'user_pass_reset':
      $form['actions']['submit']['#button_type'] = 'primary';
      if (isset($form['message']['#markup']) && $form['message']['#markup'] instanceof TranslatableMarkup) {
        $arguments = $form['message']['#markup']->getArguments();
        if (isset($arguments['%user_name']) && ($user = user_load_by_name($arguments['%user_name']))) {
          $arguments['%user_name'] = $user->getDisplayName();
          $form['message']['#markup'] = t($form['message']['#markup']->getUntranslatedString(), $arguments);
        }
      }
      break;

    case 'user_pass':
      $form['#submit'][] = 'vbase_user_forms_redirect';
      $form['actions']['submit']['#button_type'] = 'primary';
      $config = \Drupal::config('vbase.settings.users');
      vbase_add_cacheable_dependency($form, $config);
      if ($config->get('login_by_email')) {
        $form['name']['#title'] = t('Email address');
      }
      break;

    case 'user_login_form':
      $form['actions']['submit']['#button_type'] = 'primary';
      $config = \Drupal::config('vbase.settings.users');
      vbase_add_cacheable_dependency($form, $config);
      if ($config->get('login_by_email')) {
        $form['name']['#title'] = t('Email address');
        $form['name']['#type'] = 'email';
        $form['name']['#maxlength'] = Email::EMAIL_MAX_LENGTH;
        $form['name']['#element_validate'][] = 'vbase_user_login_by_email';
        $form['name']['#description'] = t('Enter your email address.');
        $form['pass']['#description'] = t('Enter the password that accompanies your email address.');
      }
      break;

    case 'user_register_form':
      if (!isset($form['administer_users']['#value']) || !$form['administer_users']['#value']) {
        $form['#submit'][] = 'vbase_user_forms_redirect';
        if (isset($form['actions']['submit']['#submit'])) {
          $form['actions']['submit']['#submit'][] = 'vbase_user_forms_redirect';
        }
      }
      $config = \Drupal::config('vbase.settings.users');
      vbase_add_cacheable_dependency($form, $config);
      if ($config->get('register_by_email')) {
        $form['account']['name']['#type'] = 'value';
        $form['account']['name']['#value'] = \Drupal::service('vbase.generator')->userName('vbase_');
      }
      break;
  }
}

/**
 * Redirect users to user-home.
 */
function vbase_user_forms_redirect(&$form, FormStateInterface $form_state) {
  $form_state->setRedirect('user.page');
}

/**
 * Implements hook_ENTITY_TYPE_presave() for user.
 */
function vbase_user_presave(EntityInterface $entity) {
  $name = $entity->getAccountName();
  if (!$name || strpos($name, 'vbase_') !== 0 || !$entity->isNew()
      || !\Drupal::config('vbase.settings.users')->get('register_by_email')) {
    return;
  }
  $entity->setUsername(\Drupal::service('vbase.generator')->userNameFromMail($entity->getEmail()));
}

/**
 * Set username by mail.
 */
function vbase_user_login_by_email(&$element, FormStateInterface $form_state, &$form) {
  $mail = trim($form_state->getValue('name'));
  if (!empty($mail)) {
    if ($user_by_mail = user_load_by_mail($mail)) {
      $user_by_name = user_load_by_name($mail);
      if (!$user_by_name || $user_by_mail->id() == $user_by_name->id()) {
        $form_state->setValue('name', $user_by_mail->getAccountName());
      }
      else {
        $form_state->setError($element, t('Email validation conflict, please notify administrator.'));
      }
    }
    else {
      $user_input = $form_state->getUserInput();
      $query = isset($user_input['name']) ? ['name' => $user_input['name']] : [];
      $form_state->setError($element, t('Unrecognized email address or password. <a href=":password">Forgot your password?</a>', [':password' => Url::fromRoute('user.pass', [], ['query' => $query])->toString()]));
    }
  }
}

/**
 * Implements hook_file_validate().
 *
 * Temporary fix for file name transliteration.
 *
 * @todo Remove after fix.
 *
 * @see https://www.drupal.org/node/2492171
 */
function vbase_file_validate(FileInterface $file) {
  $errors = [];
  $filename = $file->getFilename();
  // Transliterate and sanitize the destination filename.
  $filename_fixed = \Drupal::transliteration()->transliterate($filename, 'en', '');
  // Replace whitespace.
  $filename_fixed = str_replace(' ', '_', $filename_fixed);
  // Remove remaining unsafe characters.
  $filename_fixed = preg_replace('/[^0-9A-Za-z_.-]/', '', $filename_fixed);
  // Remove multiple consecutive non-alphabetical characters.
  $filename_fixed = preg_replace('/(_)_+|(\.)\.+|(-)-+/', '\\1\\2\\3', $filename_fixed);
  // Force lowercase to prevent issues on case-insensitive file systems.
  $filename_fixed = mb_strtolower($filename_fixed);
  if ($filename != $filename_fixed) {
    $directory = \Drupal::service('file_system')->dirname($file->destination);
    $file->destination = \Drupal::service('file_system')->createFilename($filename_fixed, $directory);
  }
  return $errors;
}

/**
 * Implements hook_theme().
 */
function vbase_theme() {
  return [
    'vbase_adjustment_text' => [
      'render element' => '',
    ],
    'vbase_youtube' => [
      'variables' => [
        'attributes' => [],
        'id' => NULL,
        'width' => NULL,
        'height' => NULL,
        'responsive' => NULL,
      ],
      'file' => 'vbase.theme.inc',
    ],
  ];
}

/**
 * Implements hook_page_attachments().
 */
function vbase_page_attachments(array &$attachments) {
  $config = \Drupal::config('vbase.settings.manifest');
  vbase_add_cacheable_dependency($attachments, $config);
  if (($short = $config->get('short_name')) || $config->get('name')) {
    $attachments['#attached']['html_head_link'][] = [[
      'rel' => 'manifest',
      'href' => Url::fromRoute('vbase.manifest')->setAbsolute()->toString(),
    ]];
    if ($short) {
      $attachments['#attached']['html_head'][] = [[
        '#type' => 'html_tag',
        '#tag' => 'meta',
        '#attributes' => [
          'name' => 'apple-mobile-web-app-title',
          'content' => $short,
        ],
      ], 'apple-mobile-web-app-title'];
      $attachments['#attached']['html_head'][] = [[
        '#type' => 'html_tag',
        '#tag' => 'meta',
        '#attributes' => [
          'name' => 'application-name',
          'content' => $short,
        ],
      ], 'application-name'];
    }
    \Drupal::service('vbase.manifest')->setIconLinks($attachments);
  }
  if ($config->get('theme_color')) {
    $attachments['#attached']['html_head'][] = [[
      '#type' => 'html_tag',
      '#tag' => 'meta',
      '#attributes' => [
        'name' => 'theme-color',
        'content' => $config->get('theme_color'),
      ],
    ], 'theme-color'];
  }

  $config = \Drupal::config('vbase.settings.browsers');
  vbase_add_cacheable_dependency($attachments, $config);
  if ($config->get('ie')) {
    $attachments['#attached']['library'][] = 'vbase/ie.'. $config->get('ie');
  }

  $config = \Drupal::config('vbase.settings.tags');
  vbase_add_cacheable_dependency($attachments, $config);
  if ($config->get('telephone')) {
    $attachments['#attached']['html_head'][] = [[
      '#type' => 'html_tag',
      '#tag' => 'meta',
      '#attributes' => [
        'name' => 'SKYPE_TOOLBAR',
        'content' => 'SKYPE_TOOLBAR_PARSER_COMPATIBLE',
      ],
    ], 'SKYPE_TOOLBAR'];
    $attachments['#attached']['html_head'][] = [[
      '#type' => 'html_tag',
      '#tag' => 'meta',
      '#attributes' => [
        'name' => 'format-detection',
        'content' => 'telephone=no',
      ],
    ], 'format-detection'];
  }
  if ($config->get('ie_chrome')) {
    $attachments['#attached']['html_head'][] = [[
      '#type' => 'html_tag',
      '#tag' => 'meta',
      '#browsers' => ['!IE' => FALSE],
      '#weight' => -1000,
      '#attributes' => [
        'http-equiv' => 'X-UA-Compatible',
        'content' => 'IE=edge, chrome=1',
      ],
    ], 'ie-chrome'];
  }
}

/**
 * Implements hook_page_attachments_alter().
 */
function vbase_page_attachments_alter(array &$attachments) {
  // Hide metatags
  $config = \Drupal::config('vbase.settings.tags');
  vbase_add_cacheable_dependency($attachments, $config);
  $keys = [];
  if (!$config->get('generator')) {
    $keys[] = 'system_meta_generator';
  }
  if (!$config->get('mobile')) {
    $keys[] = 'MobileOptimized';
    $keys[] = 'HandheldFriendly';
  }
  if (!$config->get('viewport')) {
    $keys[] = 'viewport';
  }
  if (!empty($keys) && !empty($attachments['#attached']['html_head'])) {
    foreach ($attachments['#attached']['html_head'] as $key => $value) {
      if (in_array($value[1], $keys)) {
        unset($attachments['#attached']['html_head'][$key]);
      }
    }
  }
  // Hide links
  $keys = [
    'delete-form',
    'edit-form',
    'version-history',
    'revision',
    'drupal:content-translation-overview',
    'drupal:content-translation-add',
    'drupal:content-translation-edit',
    'drupal:content-translation-delete',
  ];
  if (!$config->get('shortlink')) {
    $keys[] = 'shortlink';
  }
  $base = FALSE;
  $route_match = \Drupal::routeMatch();
  $route = \Drupal::routeMatch()->getRouteObject();
  if (!$route->hasOption('_vamp') && !in_array($route_match->getRouteName(), ['comment.reply'])) {
    if ($base = $config->get('base')) {
      $keys[] = 'canonical';
    }
  }
  if (!empty($keys) && isset($attachments['#attached']['html_head_link'])) {
    foreach ($attachments['#attached']['html_head_link'] as $key => $value) {
      if (isset($value[0]['rel']) && in_array($value[0]['rel'], $keys)) {
        unset($attachments['#attached']['html_head_link'][$key]);
      }
    }
  }
  if ($base) {
    $url = \Drupal::service('path.matcher')->isFrontPage() ? Url::fromRoute('<front>') : Url::fromRouteMatch($route_match);
    $canonical = $base . $url->toString();
    global $pager_page_array;
    if (is_array($pager_page_array) && !empty($pager_page_array) && ($pager_page_array[0] != 0 || count($pager_page_array) > 1)) {
      $canonical .= '?page='. implode(',', $pager_page_array);
    }
    $attachments['#attached']['html_head_link'][] = [
      ['rel' => 'canonical', 'href' => $canonical],
      TRUE,
    ];
  }
}

/**
 * Implements hook_entity_view_alter().
 */
function vbase_entity_view_alter(array &$build) {
  // Cheking view_mode for node.
  if ($build['#view_mode'] === 'full') {
    // Cheking html_head_link on attached tags in head.
    if (!isset($build['#attached']['html_head_link'])) {
      return;
    }
    $config = \Drupal::config('vbase.settings.tags');
    vbase_add_cacheable_dependency($build, $config);
    $keys = ['delete-form', 'edit-form', 'version-history', 'revision'];
    if (!$config->get('shortlink')) {
      $keys[] = 'shortlink';
    }
    $route_match = \Drupal::routeMatch();
    $route = \Drupal::routeMatch()->getRouteObject();
    if (!$route->hasOption('_vamp')) {
      if ($config->get('base')) {
        $keys[] = 'canonical';
      }
    }
    foreach ($build['#attached']['html_head_link'] as $key => $value) {
      if (isset($value[0]['rel']) && in_array($value[0]['rel'], $keys)) {
        unset($build['#attached']['html_head_link'][$key]);
      }
    }

  }
}

/**
 * Implements hook_preprocess_html().
 *
 * @see template_preprocess_html()
 */
function vbase_preprocess_html(array &$variables) {
  if (!isset($variables['head_attributes'])) {
    $variables['head_attributes'] = new Attribute();
  }
}

/**
 * Helper function to add cache dependency to render array.
 */
function vbase_add_cacheable_dependency(array &$build, $object) {
  if (!isset($build['#cache'])) {
    $build['#cache'] = [];
  }
  $meta_a = CacheableMetadata::createFromRenderArray($build);
  $meta_b = CacheableMetadata::createFromObject($object);
  $meta_a->merge($meta_b)->applyTo($build);
}

/**
 * Helper function to get current page title.
 */
function _vbase_get_title() {
  return \Drupal::service('token')->replace('[current-page:title]');
}

/**
 * Implements hook_module_implements_alter().
 */
function vbase_module_implements_alter(&$implementations, $hook) {
  if (in_array($hook, ['entity_view_alter', 'page_attachments_alter'])) {
    $group = $implementations['vbase'];
    unset($implementations['vbase']);
    $implementations['vbase'] = $group;
  }
}

/**
 * Creates a web-accessible relative URL for a stream to an external or local file.
 *
 * @param string $uri
 *   The URI to a file for which we need an external URL, or the path to a
 *   shipped file.
 *
 * @return string
 *   If the file URL indeed pointed to a local file and was indeed absolute,
 *   then the transformed, relative URL to the local file. Otherwise: the
 *   original value of $file_url.
 */
function vbase_file_relative_url($uri) {
  return file_url_transform_relative(file_create_url($uri));
}

/**
 * Alias of Kint::dump().
 *
 * Prints passed argument(s) using Kint debug tool.
 * @see https://github.com/kint-php/kint
 */
function vbase_kint() {
  require_once DRUPAL_ROOT . '/libraries/kint/kint.phar';
  $args = func_get_args();
  \Kint::dump($args);
}

/**
 * Computes the difference of arrays.
 *
 * The main difference from the array_diff() is that this method does not
 * remove duplicates. For example:
 * @code
 *   array_diff([1, 1, 1], [1]); // []
 *   vbase_diff_once([1, 1, 1], [1]); // [1, 1]
 * @endcode
 *
 * Keys are maintained from the $array1.
 *
 * The comparison of items is always performed in the strict (===) mode.
 *
 * @param array $array1
 *   The array to compare from.
 * @param array $array2
 *   The array to compare to.
 *
 * @return array
 */
function vbase_diff_once(array $array1, array $array2) {
  foreach ($array2 as $item) {
    // Always use strict mode because otherwise there could be fatal errors on
    // object conversions.
    $key = array_search($item, $array1, TRUE);
    if ($key !== FALSE) {
      unset($array1[$key]);
    }
  }
  return $array1;
}
