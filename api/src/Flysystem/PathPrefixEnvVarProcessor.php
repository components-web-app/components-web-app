<?php

declare(strict_types=1);

namespace App\Flysystem;

use Symfony\Component\DependencyInjection\EnvVarProcessorInterface;
use Symfony\Component\DependencyInjection\Exception\RuntimeException;

// %env(storage_prefix:GCLOUD_PATH_PREFIX)%: '' or a path with no leading slash and one trailing slash (#166).
final class PathPrefixEnvVarProcessor implements EnvVarProcessorInterface
{
    public function getEnv(string $prefix, string $name, \Closure $getEnv): string
    {
        return self::normalise((string) $getEnv($name));
    }

    public static function normalise(string $value): string
    {
        $segments = array_values(array_filter(explode('/', trim($value)), static fn (string $s) => '' !== $s));
        foreach ($segments as $segment) {
            if ('.' === $segment || '..' === $segment) {
                throw new RuntimeException(sprintf('A storage path prefix cannot contain "%s": "%s".', $segment, $value));
            }
        }

        return [] === $segments ? '' : implode('/', $segments) . '/';
    }

    public static function getProvidedTypes(): array
    {
        return ['storage_prefix' => 'string'];
    }
}
