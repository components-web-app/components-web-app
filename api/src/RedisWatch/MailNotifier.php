<?php

declare(strict_types=1);

namespace App\RedisWatch;

use Psr\Log\LoggerInterface;
use Silverback\ApiComponentsBundle\Utility\EmailRecipientList;
use Symfony\Component\DependencyInjection\Attribute\Autowire;
use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Mime\Address;
use Symfony\Component\Mime\Email;

/**
 * Emails the site's notification address (MAILER_EMAIL, as the orphan scan does); unset means no email.
 */
final class MailNotifier implements Notifier
{
    public function __construct(
        private readonly MailerInterface $mailer,
        #[Autowire(env: 'string:default::MAILER_EMAIL')]
        private readonly string $recipients,
        #[Autowire(env: 'string:default::WEBSITE_NAME')]
        private readonly string $websiteName,
        private readonly ?LoggerInterface $logger = null,
    ) {
    }

    public function send(string $subject, string $body): string
    {
        $recipients = array_values(array_filter(array_map('trim', EmailRecipientList::split($this->recipients))));
        if ([] === $recipients) {
            return self::NO_RECIPIENTS;
        }

        try {
            $to = array_map(static fn (string $recipient): Address => Address::create($recipient), $recipients);
            $name = trim($this->websiteName);
            $this->mailer->send(
                (new Email())
                    ->from($to[0])
                    ->to(...$to)
                    ->subject(('' !== $name ? $name.': ' : '').$subject)
                    ->text($body),
            );
        } catch (\Throwable $e) {
            $this->logger?->error('The Redis watch email was not sent: '.$e->getMessage(), ['exception' => $e]);

            return self::FAILED;
        }

        return self::SENT;
    }
}
