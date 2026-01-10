<?php
/**
 * PHPUnit Bootstrap File
 * Sets up the WordPress testing environment
 */

// Composer autoloader (if available)
if (file_exists(__DIR__ . '/../vendor/autoload.php')) {
    require_once __DIR__ . '/../vendor/autoload.php';
}

// Test configuration
define('ABSPATH', __DIR__ . '/../wordpress/');

// Database configuration from environment or defaults
if (!defined('DB_NAME')) {
    define('DB_NAME', getenv('WP_TESTS_DB_NAME') ?: 'wordpress_test');
}
if (!defined('DB_USER')) {
    define('DB_USER', getenv('WP_TESTS_DB_USER') ?: 'wordpress');
}
if (!defined('DB_PASSWORD')) {
    define('DB_PASSWORD', getenv('WP_TESTS_DB_PASSWORD') ?: 'wordpress');
}
if (!defined('DB_HOST')) {
    define('DB_HOST', getenv('WP_TESTS_DB_HOST') ?: '127.0.0.1');
}

// WordPress test suite location (optional - if using WP test suite)
$_tests_dir = getenv('WP_TESTS_DIR');
if (!$_tests_dir) {
    $_tests_dir = '/tmp/wordpress-tests-lib';
}

// Load WordPress test suite if available
if (file_exists($_tests_dir . '/includes/functions.php')) {
    require_once $_tests_dir . '/includes/functions.php';

    function _manually_load_plugin() {
        // Load your custom theme or plugin here for testing
        // require dirname(__FILE__) . '/../wordpress/wp-content/plugins/your-plugin/your-plugin.php';
    }
    tests_add_filter('muplugins_loaded', '_manually_load_plugin');

    require $_tests_dir . '/includes/bootstrap.php';
} else {
    // Basic test environment without WordPress test suite
    echo "WordPress test suite not found. Running basic tests only.\n";

    // Define basic WordPress constants for standalone tests
    if (!defined('WP_CONTENT_DIR')) {
        define('WP_CONTENT_DIR', ABSPATH . 'wp-content');
    }
}

// Set up error reporting for tests
error_reporting(E_ALL);
ini_set('display_errors', '1');

echo "Test environment initialized\n";
