<?php

// Behat and behatch/contexts are missing explicit return types required by Symfony 8:
// - Extension::process() must be `: void` (CompilerPassInterface now declares it)
// - EventSubscriberInterface::getSubscribedEvents() now declares `: array`
// This patches all affected vendor files until upstream fixes land in stable releases.

declare(strict_types=1);

$vendorDir = __DIR__ . '/../vendor';

$patches = [
    // process() without ': void' — applies to behat extensions and behatch
    [
        'dirs' => [
            $vendorDir . '/behat/behat/src',
            $vendorDir . '/behatch/contexts/src',
        ],
        'pattern' => '/public function process\(ContainerBuilder \$container\)(?!:)/',
        'replacement' => 'public function process(ContainerBuilder $container): void',
    ],
    // getSubscribedEvents() without ': array' — behatch HttpCallListener
    [
        'dirs' => [
            $vendorDir . '/behatch/contexts/src',
        ],
        'pattern' => '/public static function getSubscribedEvents\(\)(?!:)/',
        'replacement' => 'public static function getSubscribedEvents(): array',
    ],
];

$totalPatched = 0;
foreach ($patches as $patch) {
    foreach ($patch['dirs'] as $dir) {
        if (!is_dir($dir)) {
            continue;
        }
        $iterator = new RecursiveIteratorIterator(new RecursiveDirectoryIterator($dir));
        foreach ($iterator as $file) {
            if ($file->getExtension() !== 'php') {
                continue;
            }
            $content = file_get_contents($file->getPathname());
            $fixed = preg_replace($patch['pattern'], $patch['replacement'], $content);
            if ($fixed !== $content) {
                file_put_contents($file->getPathname(), $fixed);
                echo "Patched: " . $file->getPathname() . "\n";
                $totalPatched++;
            }
        }
    }
}

if ($totalPatched === 0) {
    echo "Behat void patch: nothing to patch (already applied or not installed).\n";
}
