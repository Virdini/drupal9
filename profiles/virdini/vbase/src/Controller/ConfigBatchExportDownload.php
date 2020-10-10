<?php

namespace Drupal\vbase\Controller;

use Drupal\system\FileDownloadController;
use Symfony\Component\HttpFoundation\Request;

/**
 * Provides a 'ConfigBatchExportDownload'
 */
class ConfigBatchExportDownload extends FileDownloadController {

  public function download(Request $request, $scheme = 'private') {
    return parent::download(new Request(['file' => 'config.tar.gz']), 'temporary');
  }

}
