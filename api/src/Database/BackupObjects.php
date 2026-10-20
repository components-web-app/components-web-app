<?php

declare(strict_types=1);

namespace App\Database;

/**
 * Names and retention for the deploy's database backups (#180): <directory><UTC date>-<time>Z-<label>.dump.
 * Only names in that form are ever deleted, so nothing else in the directory is touched.
 */
final class BackupObjects
{
    private const string PATTERN = '/^\d{8}-\d{6}Z-[a-z0-9-]+\.dump$/';

    public static function directory(string $directory): string
    {
        $directory = trim(preg_replace('#/+#', '/', trim($directory)) ?? '', '/');
        foreach (explode('/', $directory) as $segment) {
            if ('.' === $segment || '..' === $segment) {
                throw new \InvalidArgumentException(\sprintf('A backup directory cannot contain "%s".', $segment));
            }
        }

        return '' === $directory ? '' : $directory . '/';
    }

    public static function name(string $directory, \DateTimeInterface $at, string $label): string
    {
        $label = trim(preg_replace('/[^a-z0-9]+/', '-', strtolower($label)) ?? '', '-');
        $utc = \DateTimeImmutable::createFromInterface($at)->setTimezone(new \DateTimeZone('UTC'));

        return self::directory($directory) . $utc->format('Ymd-His') . 'Z-' . ('' === $label ? 'backup' : $label) . '.dump';
    }

    /**
     * The backups in $directory beyond the newest $keep, oldest last.
     *
     * @param iterable<string> $names object names listed under $directory
     *
     * @return list<string>
     */
    public static function expired(iterable $names, string $directory, int $keep): array
    {
        $directory = self::directory($directory);
        $backups = [];
        foreach ($names as $name) {
            if (str_starts_with($name, $directory) && 1 === preg_match(self::PATTERN, substr($name, \strlen($directory)))) {
                $backups[] = $name;
            }
        }
        rsort($backups, \SORT_STRING);

        return \array_slice($backups, max(1, $keep));
    }
}
