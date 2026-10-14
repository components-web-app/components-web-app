<?php

declare(strict_types=1);

namespace App\Monolog;

use Monolog\Formatter\FormatterInterface;
use Monolog\Handler\SymfonyMailerHandler;
use Monolog\Level;
use Symfony\Component\Mailer\MailerInterface;
use Symfony\Component\Mime\Email;

/**
 * Mails one message per batch of log records handed to it, to a recipient that may be unset.
 *
 * monolog-bundle's own symfony_mailer handler builds the Email from a service definition while the
 * container boots, so an unset recipient there fails the cache warm rather than being a quiet no-op.
 * Here an unset recipient or sender means no error mail, and a transport that cannot deliver is
 * swallowed: this is an alert, and the stderr log the cluster ships is the reliable record (#162).
 */
final class ErrorMailHandler extends SymfonyMailerHandler
{
    public function __construct(
        MailerInterface $mailer,
        private readonly string $toEmailAddress,
        private readonly string $fromEmailAddress,
        // Free of Monolog's placeholders on purpose: the parent formats the subject through a
        // LineFormatter of its own, not the redacting formatter, so a %message% here would put an
        // unredacted message in a mail header.
        string $subject,
        FormatterInterface $formatter,
        int|string|Level $level = Level::Critical,
    ) {
        parent::__construct(
            $mailer,
            static fn (): Email => (new Email())
                ->from($fromEmailAddress)
                ->to($toEmailAddress)
                ->subject($subject),
            $level,
        );

        $this->setFormatter($formatter);
    }

    protected function send(string $content, array $records): void
    {
        if ('' === trim($this->toEmailAddress) || '' === trim($this->fromEmailAddress)) {
            return;
        }

        try {
            parent::send($content, $records);
        } catch (\Throwable) {
            // An alert that cannot be delivered must not become the incident, and logging the failure
            // here is what the excluded mailer channel exists to prevent.
        }
    }
}
