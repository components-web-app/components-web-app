<?php

use Symfony\Component\DependencyInjection\Loader\Configurator\ContainerConfigurator;

return static function (ContainerConfigurator $configurator) {
    $services = $configurator->services();
    $services
        ->defaults()
        ->autowire()
        ->autoconfigure();

    // No test-only services yet.
};
