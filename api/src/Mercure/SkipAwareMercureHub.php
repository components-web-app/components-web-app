<?php

declare(strict_types=1);

namespace App\Mercure;

use Symfony\Component\Mercure\HubInterface;
use Symfony\Component\Mercure\Jwt\TokenFactoryInterface;
use Symfony\Component\Mercure\Jwt\TokenProviderInterface;
use Symfony\Component\Mercure\ProtocolVersion;
use Symfony\Component\Mercure\RemoteHubInterface;
use Symfony\Component\Mercure\Update;

/**
 * Decorates the default hub so `SKIP_MERCURE_PUBLISH=true` (set by `load_fixtures`
 * in bin/devops/k8s.sh) skips publishing.
 *
 * Since symfony/mercure 0.8, getUrl() lives on RemoteHubInterface and getProvider()
 * is no longer on any interface. Implementing RemoteHubInterface keeps this decorator
 * a remote hub whenever the inner one is (it is, a `Hub`), and both methods are
 * forwarded only if the inner hub has them, as the bundle's PublishableAwareHub does.
 */
final class SkipAwareMercureHub implements RemoteHubInterface
{
    public function __construct(private readonly HubInterface $inner) {}

    public function getUrl(): string
    {
        if (!$this->inner instanceof RemoteHubInterface) {
            throw new \LogicException(\sprintf('The decorated hub "%s" has no internal URL.', $this->inner::class));
        }

        return $this->inner->getUrl();
    }

    public function getPublicUrl(): string
    {
        return $this->inner->getPublicUrl();
    }

    public function getProvider(): TokenProviderInterface
    {
        if (!method_exists($this->inner, 'getProvider')) {
            throw new \LogicException(\sprintf('The decorated hub "%s" has no token provider.', $this->inner::class));
        }

        return $this->inner->getProvider();
    }

    public function getFactory(): ?TokenFactoryInterface
    {
        return $this->inner->getFactory();
    }

    public function getProtocolVersion(): ProtocolVersion
    {
        return $this->inner->getProtocolVersion();
    }

    public function getCookieName(): string
    {
        return $this->inner->getCookieName();
    }

    public function publish(Update $update): string
    {
        if (getenv('SKIP_MERCURE_PUBLISH') === 'true') {
            return '';
        }

        return $this->inner->publish($update);
    }
}
