<?php

declare(strict_types=1);

namespace App\Tests\Unit\Monolog;

use App\Monolog\ErrorMailHandler;
use Monolog\Formatter\GoogleCloudLoggingFormatter;
use Monolog\Formatter\RedactingFormatter;
use Monolog\Handler\DeduplicationHandler;
use Monolog\Handler\FingersCrossedHandler;
use Monolog\Logger;
use PHPUnit\Framework\TestCase;
use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Mime\Email;
use Symfony\Component\Mime\RawMessage;
use Symfony\Component\Yaml\Yaml;

/**
 * The error mail handler is configured in the production environment alone, so the functional
 * suite, which runs in the test environment, cannot reach it. What the handler
 * does is therefore proved here, against the chain config/packages/prod/monolog.yaml describes rather
 * than against a copy of it: the levels, the buffer, the deduplication window and the formatter are
 * all read out of that file, so relaxing any of them fails here.
 *
 * "One email" is the assertion that matters most: one per request, and one per unique error per
 * window, so a failing site can't flood the inbox or get its mail provider restricted (#162).
 */
class ErrorMailTest extends TestCase
{
    private const RECIPIENT = 'developer@example.com';

    /**
     * @var array<string, array<string, mixed>>
     */
    private array $handlers;

    /**
     * @var array<string, mixed>
     */
    private array $services;

    private string $store;

    protected function setUp(): void
    {
        $config = Yaml::parseFile(dirname(__DIR__, 3).'/config/packages/prod/monolog.yaml');
        $this->handlers = $config['monolog']['handlers'];
        $this->services = $config['services'];
        $this->store = sys_get_temp_dir().'/'.uniqid('error-mail-dedup-', true).'.log';
    }

    protected function tearDown(): void
    {
        if (file_exists($this->store)) {
            unlink($this->store);
        }
    }

    public function testAnUncaughtExceptionSendsOneEmailForTheWholeRequest(): void
    {
        $sent = $this->handleRequest(function (Logger $logger): void {
            $logger->debug('Matched route "_api_/pages/{id}{._format}_patch".', ['request_uri' => 'https://www.example.com/_api/pages/home']);
            $logger->info('User Deprecated: something or other.');
            $logger->critical(
                'Uncaught PHP Exception RuntimeException: "The page lookup blew up" at PageDataProvider.php line 88',
                ['exception' => new \RuntimeException('The page lookup blew up')]
            );
        });

        $this->assertCount(1, $sent);
        $this->assertStringContainsString('RuntimeException', $this->body($sent[0]));
    }

    /**
     * fingers_crossed replays every buffered record, and MailHandler sends one message per batch. Two
     * failures in one request are therefore still one email, not two.
     */
    public function testTwoFailuresInOneRequestAreStillOneEmail(): void
    {
        $sent = $this->handleRequest(function (Logger $logger): void {
            $logger->critical('Uncaught PHP Exception RuntimeException: "first" at Foo.php line 1');
            $logger->critical('Exception thrown when handling an exception (LogicException: second at Bar.php line 2)');
        });

        $this->assertCount(1, $sent);
    }

    public function testTheEmailCarriesNothingTheStderrRedactionStrips(): void
    {
        $sent = $this->handleRequest(function (Logger $logger): void {
            $logger->debug('Matched route "app_password_reset".', [
                'request_uri' => 'https://www.example.com/_api/password/reset/request/someone@example.com?confirmation_token=t0k3nt0k3nt0k3n',
            ]);
            $logger->critical(
                'Uncaught PHP Exception Doctrine\DBAL\Exception: "An exception occurred while executing a query: parameters'
                .' [\\"someone@example.com\\", \\"$2y$13$C4i0S4nN2gZsOHu6oZcdKuhbqwzVn8pTqJkKQ3sVbLqFmEwTpXaBe\\"]" at Statement.php line 12',
                [
                    'plainPassword' => 'correct horse battery staple',
                    'authorization' => 'Bearer eyJhbGciOiJIUzI1NiJ9.eyJzdWIiOiIxMjM0NTY3ODkwIn0.dBjftJeZ4CVPmB92K27uhbUJU1p1r',
                ]
            );
        });

        $this->assertCount(1, $sent);
        $body = $this->body($sent[0]);

        $this->assertStringNotContainsString('someone@example.com', $body);
        $this->assertStringNotContainsString('t0k3nt0k3nt0k3n', $body);
        $this->assertStringNotContainsString('correct horse battery staple', $body);
        $this->assertStringNotContainsString('eyJhbGciOiJIUzI1NiJ9', $body);
        $this->assertStringNotContainsString('$2y$13$C4i0S4nN2gZsOHu6oZcdKuhbqwzVn8pTqJkKQ3sVbLqFmEwTpXaBe', $body);
        // Redaction that took the name or the location of the fault with it would make the alert
        // useless. The class name arrives JSON-escaped, hence the fragment.
        $this->assertStringContainsString('DBAL', $body);
        $this->assertStringContainsString('Statement.php line 12', $body);
    }

    /**
     * The subject is a header, and the parent handler formats it through a LineFormatter rather than
     * the redacting formatter, so it must never carry the record's message.
     */
    public function testTheSubjectCarriesNoPartOfTheRecord(): void
    {
        $sent = $this->handleRequest(static function (Logger $logger): void {
            $logger->critical('Uncaught PHP Exception RuntimeException: "someone@example.com could not be saved" at Foo.php line 1');
        });

        $subject = $sent[0]->getSubject();
        $this->assertSame($this->services['app.monolog.handler.error_mail']['arguments']['$subject'], $subject);
        $this->assertStringNotContainsString('someone@example.com', (string) $subject);
    }

    public function testTheSameErrorAgainInsideTheWindowSendsNoSecondEmail(): void
    {
        $error = static function (Logger $logger): void {
            $logger->critical('Uncaught PHP Exception RuntimeException: "the same failure" at Foo.php line 1');
        };

        $first = $this->handleRequest($error);
        $second = $this->handleRequest($error);

        $this->assertCount(1, $first);
        $this->assertCount(0, $second);
    }

    public function testADifferentErrorInsideTheWindowStillSendsItsOwnEmail(): void
    {
        $this->handleRequest(static function (Logger $logger): void {
            $logger->critical('Uncaught PHP Exception RuntimeException: "one failure" at Foo.php line 1');
        });

        $sent = $this->handleRequest(static function (Logger $logger): void {
            $logger->critical('Uncaught PHP Exception LogicException: "a different failure" at Bar.php line 2');
        });

        $this->assertCount(1, $sent);
    }

    /**
     * Symfony's ErrorListener logs a 4xx at error and only a 5xx at critical. Mailing at error would
     * mean an email for every 404 and every rejected form.
     */
    public function testAFourHundredSendsNothing(): void
    {
        $sent = $this->handleRequest(static function (Logger $logger): void {
            $logger->error(
                'Uncaught PHP Exception Symfony\Component\HttpKernel\Exception\NotFoundHttpException: "No route found" at ErrorListener.php line 1'
            );
        });

        $this->assertCount(0, $sent);
    }

    public function testAnUnsetRecipientSendsNothingAndRaisesNothing(): void
    {
        $sent = $this->handleRequest(static function (Logger $logger): void {
            $logger->critical('Uncaught PHP Exception RuntimeException: "nobody is listening" at Foo.php line 1');
        }, '');

        $this->assertCount(0, $sent);
    }

    public function testAnUnsetSenderSendsNothingAndRaisesNothing(): void
    {
        $sent = $this->handleRequest(static function (Logger $logger): void {
            $logger->critical('Uncaught PHP Exception RuntimeException: "no sender configured" at Foo.php line 1');
        }, self::RECIPIENT, '');

        $this->assertCount(0, $sent);
    }

    public function testAFailingTransportRaisesNothing(): void
    {
        $mailer = $this->createStub(MailerInterface::class);
        $mailer->method('send')->willThrowException(new \RuntimeException('the transport said no'));

        $handler = new ErrorMailHandler($mailer, self::RECIPIENT, 'noreply@example.com', 'subject', new GoogleCloudLoggingFormatter());
        $handler->handleBatch([new \Monolog\LogRecord(new \DateTimeImmutable(), 'request', \Monolog\Level::Critical, 'boom')]);

        $this->addToAssertionCount(1);
    }

    /**
     * A failing send is logged at error level on the mailer channel, and monolog-bundle attaches a
     * handler to the loggers its channels list allows, so the exclusion is the configuration rather
     * than anything the handler can do.
     */
    public function testTheMailerChannelIsExcluded(): void
    {
        $this->assertContains('!mailer', $this->handlers['error_mail']['channels']);
    }

    /**
     * The one formatter, not a second one configured alongside it: a copy would drift from what the
     * stderr handler redacts.
     */
    public function testTheStderrFormatterIsTheOneReused(): void
    {
        $this->assertSame(
            '@'.$this->handlers['nested']['formatter'],
            $this->services['app.monolog.handler.error_mail']['arguments']['$formatter']
        );
    }

    /**
     * Runs one request's worth of logging through the handler chain the production configuration
     * describes and returns the messages it sent. Every call shares the deduplication store, which is
     * what makes two calls two requests of the same pod.
     *
     * @param callable(Logger): void $request
     *
     * @return list<Email>
     */
    private function handleRequest(callable $request, string $recipient = self::RECIPIENT, string $sender = 'noreply@example.com'): array
    {
        $sent = [];
        $mailer = $this->createStub(MailerInterface::class);
        $mailer->method('send')->willReturnCallback(static function (RawMessage $message) use (&$sent): void {
            $sent[] = $message;
        });

        $arguments = $this->services['app.monolog.formatter.redacting']['arguments'];
        $mail = new ErrorMailHandler(
            $mailer,
            $recipient,
            $sender,
            $this->services['app.monolog.handler.error_mail']['arguments']['$subject'],
            new RedactingFormatter(
                new GoogleCloudLoggingFormatter(),
                $arguments['$sensitiveKeys'],
                $arguments['$patterns']
            ),
            $this->services['app.monolog.handler.error_mail']['arguments']['$level']
        );

        $deduplication = $this->handlers['error_mail_deduplicated'];
        $handler = new FingersCrossedHandler(
            new DeduplicationHandler($mail, $this->store, $deduplication['deduplication_level'], $deduplication['time']),
            $this->handlers['error_mail']['action_level'],
            $this->handlers['error_mail']['buffer_size']
        );

        $request(new Logger('request', [$handler]));
        // The buffers flush when the request ends, which is what closing the chain stands in for.
        $handler->close();

        return $sent;
    }

    private function body(Email $email): string
    {
        return (string) $email->getTextBody();
    }
}
