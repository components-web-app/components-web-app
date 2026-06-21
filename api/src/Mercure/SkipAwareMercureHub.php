<?php

declare(strict_types=1);

namespace App\Mercure;

use Symfony\Component\Mercure\HubInterface;
use Symfony\Component\Mercure\Jwt\TokenFactoryInterface;
use Symfony\Component\Mercure\Jwt\TokenProviderInterface;
use Symfony\Component\Mercure\Update;

final class SkipAwareMercureHub implements HubInterface
{
    public function __construct(private readonly HubInterface $inner) {}

    public function getUrl(): string
    {
        return $this->inner->getUrl();
    }

    public function getPublicUrl(): string
    {
        return $this->inner->getPublicUrl();
    }

    public function getProvider(): TokenProviderInterface
    {
        return $this->inner->getProvider();
    }

    public function getFactory(): ?TokenFactoryInterface
    {
        return $this->inner->getFactory();
    }

    public function publish(Update $update): string
    {
        if (getenv('SKIP_MERCURE_PUBLISH') === 'true') {
            return '';
        }

        return $this->inner->publish($update);
    }
}
