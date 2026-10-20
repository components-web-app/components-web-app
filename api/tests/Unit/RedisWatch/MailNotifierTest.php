<?php

declare(strict_types=1);

namespace App\Tests\Unit\RedisWatch;

use App\RedisWatch\MailNotifier;
use App\RedisWatch\Notifier;
use PHPUnit\Framework\TestCase;
use Symfony\Component\Mailer\Envelope;
use Symfony\Component\Mailer\Exception\TransportException;
use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Mime\Email;
use Symfony\Component\Mime\RawMessage;

/**
 * The watch job emails MAILER_EMAIL, as the orphan scan does (#85); empty means no email.
 */
final class MailNotifierTest extends TestCase
{
    public function testEmailsTheSiteAddress(): void
    {
        $mailer = new RecordingMailer();
        $result = new MailNotifier($mailer, 'Site Team <team@example.com>', 'Example Site')->send('Redis restarted', 'Body');

        self::assertSame(Notifier::SENT, $result);
        $email = $mailer->messages[0];
        self::assertInstanceOf(Email::class, $email);
        self::assertSame('Example Site: Redis restarted', $email->getSubject());
        self::assertSame('team@example.com', $email->getTo()[0]->getAddress());
        self::assertSame('team@example.com', $email->getFrom()[0]->getAddress());
        self::assertSame('Body', $email->getTextBody());
    }

    public function testNoAddressMeansNoEmail(): void
    {
        $mailer = new RecordingMailer();
        self::assertSame(Notifier::NO_RECIPIENTS, new MailNotifier($mailer, '  ', 'Example Site')->send('s', 'b'));
        self::assertSame([], $mailer->messages);
    }

    public function testATransportFailureIsReportedNotThrown(): void
    {
        $mailer = new RecordingMailer(fail: true);
        self::assertSame(Notifier::FAILED, new MailNotifier($mailer, 'team@example.com', '')->send('s', 'b'));
    }
}

final class RecordingMailer implements MailerInterface
{
    /** @var list<RawMessage> */
    public array $messages = [];

    public function __construct(private readonly bool $fail = false)
    {
    }

    public function send(RawMessage $message, ?Envelope $envelope = null): void
    {
        if ($this->fail) {
            throw new TransportException('Connection refused');
        }
        $this->messages[] = $message;
    }
}
