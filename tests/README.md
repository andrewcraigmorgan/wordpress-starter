# WordPress Tests

This directory contains automated tests for your WordPress site.

## Test Structure

```
tests/
├── phpunit.xml              # PHPUnit configuration
├── bootstrap.php            # Test bootstrap file
├── unit/                    # Unit tests (isolated, no WordPress dependencies)
│   └── SampleTest.php
└── integration/             # Integration tests (require WordPress)
    └── WordPressIntegrationTest.php
```

## Running Tests

### Local (with Docker)

```bash
# Install PHPUnit
docker-compose exec wordpress composer require --dev phpunit/phpunit

# Run all tests
docker-compose exec wordpress vendor/bin/phpunit --configuration tests/phpunit.xml

# Run only unit tests
docker-compose exec wordpress vendor/bin/phpunit --configuration tests/phpunit.xml --testsuite "WordPress Tests"

# Run only integration tests
docker-compose exec wordpress vendor/bin/phpunit --configuration tests/phpunit.xml --testsuite "Integration Tests"

# Run with coverage
docker-compose exec wordpress vendor/bin/phpunit --configuration tests/phpunit.xml --coverage-html coverage-report
```

### Bitbucket Pipeline

Tests run automatically on:
- Every push to any branch
- Every pull request
- Before deployment to production (main branch)

## Writing Tests

### Unit Tests

Place unit tests in `tests/unit/`. These should test individual functions without requiring WordPress.

Example:
```php
<?php
use PHPUnit\Framework\TestCase;

class MyFunctionTest extends TestCase
{
    public function testMyFunction(): void
    {
        $result = my_custom_function('input');
        $this->assertEquals('expected', $result);
    }
}
```

### Integration Tests

Place integration tests in `tests/integration/`. These can use WordPress functions.

Example:
```php
<?php
use PHPUnit\Framework\TestCase;

class MyPluginTest extends TestCase
{
    public function testPluginFunctionality(): void
    {
        $post_id = wp_insert_post([
            'post_title' => 'Test',
            'post_status' => 'publish'
        ]);

        $this->assertGreaterThan(0, $post_id);

        wp_delete_post($post_id, true);
    }
}
```

## Test Guidelines

1. **Isolation**: Each test should be independent
2. **Cleanup**: Delete any data created during tests
3. **Assertions**: Use specific assertions (assertEquals vs assertTrue)
4. **Naming**: Use descriptive test method names (testUserCanLoginWithValidCredentials)
5. **Documentation**: Add docblocks explaining what each test does

## WordPress Test Suite (Optional)

For advanced WordPress testing, install the WordPress test suite:

```bash
# Clone WordPress test library
git clone https://github.com/WordPress/wordpress-develop.git /tmp/wordpress-develop
cd /tmp/wordpress-develop

# Set up test suite
npm install
npm run build

# Create test database
mysql -u root -p -e "CREATE DATABASE IF NOT EXISTS wordpress_test;"

# Set environment variable
export WP_TESTS_DIR=/tmp/wordpress-develop/tests/phpunit
```

Then your integration tests will have full WordPress functionality available.

## Continuous Integration

The Bitbucket pipeline runs:
1. **Code Quality**: PHP linting
2. **Security Scan**: Checks for vulnerabilities
3. **WordPress Standards**: PHPCS with WordPress rules
4. **PHPUnit Tests**: All unit and integration tests

Tests must pass before code can be deployed to production.
