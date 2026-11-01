<?php
// Regression test (#227): a project created without a feature keeps no file that still uses that feature's PHP classes
// or (for image) NuxtImg. A dropped feature also drops the features that require it, as create-cwa does.
// Usage (repository root): php bin/test/manifest-features.php

$manifest = json_decode(file_get_contents('cwa-manifest.json'), true, flags: JSON_THROW_ON_ERROR);
$features = $manifest['features'];
$roots = ['api/src', 'api/tests', 'api/config', 'app/app', 'app/nuxt.config.ts', 'e2e/tests'];

function files(string $root): iterable
{
    if (is_file($root)) {
        yield $root;

        return;
    }
    if (!is_dir($root)) {
        return;
    }
    $it = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($root, FilesystemIterator::SKIP_DOTS));
    foreach ($it as $file) {
        $path = $file->getPathname();
        if (!str_contains($path, '/node_modules/') && preg_match('/\.(php|ya?ml|vue|ts|mjs|js)$/', $path)) {
            yield $path;
        }
    }
}

function excluded(string $path, array $excludes): bool
{
    foreach ($excludes as $e) {
        if ($path === $e || (str_ends_with($e, '/') && str_starts_with($path, $e))) {
            return true;
        }
    }

    return false;
}

// The feature and every feature that (transitively) requires it.
function dropped(string $feature, array $features): array
{
    $out = [$feature];
    do {
        $before = count($out);
        foreach ($features as $id => $f) {
            if (!in_array($id, $out, true) && array_intersect($f['requires'] ?? [], $out)) {
                $out[] = $id;
            }
        }
    } while (count($out) !== $before);

    return $out;
}

$failures = 0;
foreach (array_keys($features) as $feature) {
    $ids = dropped($feature, $features);
    $excludes = array_merge(...array_map(fn ($id) => $features[$id]['exclude'] ?? [], $ids));

    // Excluded PHP under api/src: App\<path> for a file, the App\<dir>\ namespace for a directory.
    $patterns = [];
    foreach ($excludes as $e) {
        if (!str_starts_with($e, 'api/src/')) {
            continue;
        }
        $class = 'App\\'.str_replace('/', '\\', preg_replace('#^api/src/|\.php$#', '', $e));
        $patterns[] = str_ends_with($e, '/') ? '/'.preg_quote($class, '/').'/' : '/'.preg_quote($class, '/').'\b/';
        // Same-namespace use inside api/src/Entity needs no import.
        if (preg_match('#^api/src/Entity/(\w+)\.php$#', $e, $m)) {
            $patterns[] = ['api/src/Entity/', '/\b'.$m[1].'::class\b|\??\b'.$m[1].'\s+\$/'];
        }
    }
    if (in_array('image', $ids, true)) {
        $patterns[] = ['app/', '/<nuxt-img\b|<NuxtImg\b/'];
    }

    foreach ($roots as $root) {
        foreach (files($root) as $path) {
            if (excluded($path, $excludes)) {
                continue;
            }
            $text = file_get_contents($path);
            foreach ($patterns as $p) {
                [$scope, $regex] = is_array($p) ? $p : ['', $p];
                if (str_starts_with($path, $scope) && preg_match($regex, $text)) {
                    echo "FAIL ($feature): $path is kept without it but matches $regex\n";
                    ++$failures;
                }
            }
        }
    }
}

if ($failures > 0) {
    exit(1);
}
echo "All checks passed.\n";
