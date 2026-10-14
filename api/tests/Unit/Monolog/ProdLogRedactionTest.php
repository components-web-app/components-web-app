<?php

declare(strict_types=1);

namespace App\Tests\Unit\Monolog;

use Monolog\Formatter\GoogleCloudLoggingFormatter;
use Monolog\Formatter\RedactingFormatter;
use Monolog\Level;
use Monolog\LogRecord;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use Symfony\Component\Yaml\Yaml;

/**
 * Production errors leave the container for Cloud Logging, where they are durable and searchable, so
 * what the formatter lets through is a disclosure decision. The formatter is built from the very keys
 * and patterns config/packages/prod/monolog.yaml configures, rather than from a copy of them, so
 * loosening the configuration fails here.
 */
class ProdLogRedactionTest extends TestCase
{
    private RedactingFormatter $formatter;

    protected function setUp(): void
    {
        $config = Yaml::parseFile(dirname(__DIR__, 3).'/config/packages/prod/monolog.yaml');
        $arguments = $config['services']['app.monolog.formatter.redacting']['arguments'];

        $this->formatter = new RedactingFormatter(
            new GoogleCloudLoggingFormatter(),
            $arguments['$sensitiveKeys'],
            $arguments['$patterns']
        );
    }

    public function testMasksTheCredentialFieldsOfTheRegistrationAndPasswordForms(): void
    {
        $line = $this->format('Submission rejected', [
            'username' => 'someone@example.com',
            'plainPassword' => 'correct horse battery staple',
            'oldPassword' => 'previous-secret-value',
            'passwordConfirmationToken' => 'a1b2c3d4e5f6',
        ]);

        $this->assertStringNotContainsString('correct horse battery staple', $line);
        $this->assertStringNotContainsString('previous-secret-value', $line);
        $this->assertStringNotContainsString('a1b2c3d4e5f6', $line);
        $this->assertStringNotContainsString('someone@example.com', $line);
    }

    public function testMasksTheAccountEmailAddressWhereverItAppears(): void
    {
        // The password reset and username change routes carry the address in the path, and the
        // request listener logs the whole URI on every matched route.
        $line = $this->format('Matched route "app_password_reset_request".', [
            'request_uri' => 'https://www.example.com/_api/password/reset/request/someone@example.com?returnTo=/account',
        ]);

        $this->assertStringNotContainsString('someone@example.com', $line);
        $this->assertStringContainsString('app_password_reset_request', $line);
    }

    public function testMasksTokensHandedOverInAQueryString(): void
    {
        $line = $this->format('Matched route "app_password_reset".', [
            'request_uri' => 'https://www.example.com/_api/password/reset?confirmation_token=t0k3nt0k3nt0k3n&api_key=k3yk3yk3y',
        ]);

        $this->assertStringNotContainsString('t0k3nt0k3nt0k3n', $line);
        $this->assertStringNotContainsString('k3yk3yk3y', $line);
    }

    /**
     * The bundle's email links carry the username and a confirmation token as path segments, on the
     * API routes and on the front-end pages the emails link to, so no query-string name gives them away.
     */
    #[DataProvider('emailLinkUris')]
    public function testMasksUsernamesAndTokensInEmailLinkPaths(string $uri): void
    {
        $line = $this->format('Matched route "api_components_verify_email".', ['request_uri' => $uri]);

        $this->assertStringNotContainsString('editor-one', $line);
        $this->assertStringNotContainsString('Zq8vN3kP1tR7', $line);
        $this->assertStringContainsString('api_components_verify_email', $line);
    }

    /**
     * @return iterable<string, array{string}>
     */
    public static function emailLinkUris(): iterable
    {
        yield 'api verify email' => ['https://www.example.com/_api/verify-email/editor-one/Zq8vN3kP1tR7'];
        yield 'api confirm new email' => ['https://www.example.com/_api/confirm-email/editor-one/new%40example.org/Zq8vN3kP1tR7'];
        yield 'api password reset request' => ['https://www.example.com/_api/password/reset/request/editor-one'];
        yield 'page reset password' => ['https://www.example.com/reset-password/editor-one/Zq8vN3kP1tR7'];
        yield 'page confirm new email' => ['https://www.example.com/confirm-new-email/editor-one/new%40example.org/Zq8vN3kP1tR7'];
    }

    public function testMasksJwtsAndAuthorizationHeaderValues(): void
    {
        $line = $this->format(
            'Authorization: Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dBjftJeZ4CVPmB92K27uhbUJU1p1r_wW1gFWFOEjXk'
        );

        $this->assertStringNotContainsString('eyJhbGciOiJIUzI1NiJ9', $line);
        $this->assertStringNotContainsString('dBjftJeZ4CVPmB92K27uhbUJU1p1r_wW1gFWFOEjXk', $line);
    }

    public function testMasksCredentialsCarriedInADsn(): void
    {
        // A mailer or database connection failure puts the DSN it dialled into the exception message.
        $line = $this->format('Connection could not be established with host "ses+smtp://AKIAEXAMPLE:wJalrXUtnFEMI@default"');

        $this->assertStringNotContainsString('wJalrXUtnFEMI', $line);
        $this->assertStringNotContainsString('AKIAEXAMPLE', $line);
    }

    public function testMasksAPasswordHashEchoedBackByTheDatabaseDriver(): void
    {
        $line = $this->format(
            'An exception occurred while executing a query: duplicate key value violates unique constraint,'
            .' parameters ["someone@example.com", "$2y$13$C4i0S4nN2gZsOHu6oZcdKuhbqwzVn8pTqJkKQ3sVbLqFmEwTpXaBe"]'
        );

        $this->assertStringNotContainsString('$2y$13$C4i0S4nN2gZsOHu6oZcdKuhbqwzVn8pTqJkKQ3sVbLqFmEwTpXaBe', $line);
    }

    public function testLeavesTheExceptionClassNameReadable(): void
    {
        // A 415 storm broke every create in another project after its API Platform upgrade. An
        // over-broad pattern that masked long words would have taken the one word naming the fault.
        $line = $this->format(
            'Uncaught PHP Exception Symfony\Component\HttpKernel\Exception\UnsupportedMediaTypeHttpException:'
            .' "The content-type "text/plain" is not supported."'
        );

        $this->assertStringContainsString('UnsupportedMediaTypeHttpException', $line);
        $this->assertStringContainsString('text/plain', $line);
    }

    public function testKeepsTheSeverityAndTimestampCloudLoggingReads(): void
    {
        $decoded = json_decode($this->format('Something failed'), true, 512, \JSON_THROW_ON_ERROR);

        $this->assertSame('ERROR', $decoded['severity']);
        $this->assertArrayHasKey('time', $decoded);
        $this->assertSame('request', $decoded['channel']);
    }

    /**
     * @param array<string, mixed> $context
     */
    private function format(string $message, array $context = []): string
    {
        return $this->formatter->format(new LogRecord(
            new \DateTimeImmutable(),
            'request',
            Level::Error,
            $message,
            $context
        ));
    }
}
