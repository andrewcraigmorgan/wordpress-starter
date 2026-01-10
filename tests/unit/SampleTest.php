<?php
/**
 * Sample Unit Test
 *
 * This is an example test file. Replace with your actual tests.
 */

use PHPUnit\Framework\TestCase;

class SampleTest extends TestCase
{
    /**
     * Test that basic PHP operations work
     */
    public function testBasicAssertion(): void
    {
        $this->assertTrue(true);
        $this->assertEquals(2, 1 + 1);
    }

    /**
     * Test string operations
     */
    public function testStringOperations(): void
    {
        $string = 'WordPress';
        $this->assertIsString($string);
        $this->assertEquals('WordPress', $string);
        $this->assertStringContainsString('Word', $string);
    }

    /**
     * Test array operations
     */
    public function testArrayOperations(): void
    {
        $array = ['post', 'page', 'attachment'];
        $this->assertIsArray($array);
        $this->assertCount(3, $array);
        $this->assertContains('post', $array);
    }

    /**
     * Example test for a custom function
     * Replace this with actual tests for your custom code
     */
    public function testCustomFunction(): void
    {
        // Example: test a custom sanitization function
        $input = '<script>alert("xss")</script>Hello';
        $expected = 'Hello';

        // This is just a placeholder - replace with your actual function
        $result = strip_tags($input);

        $this->assertEquals($expected, $result);
        $this->assertStringNotContainsString('<script>', $result);
    }

    /**
     * Test that constants are defined correctly
     */
    public function testConstants(): void
    {
        $this->assertTrue(defined('ABSPATH'));
    }
}
