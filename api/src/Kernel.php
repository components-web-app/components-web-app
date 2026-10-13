<?php

namespace App;

use App\DependencyInjection\SkolemIriConverterResetPass;
use Symfony\Bundle\FrameworkBundle\Kernel\MicroKernelTrait;
use Symfony\Component\DependencyInjection\ContainerBuilder;
use Symfony\Component\HttpKernel\Kernel as BaseKernel;

class Kernel extends BaseKernel
{
    use MicroKernelTrait;

    protected function build(ContainerBuilder $container): void
    {
        // Default priority: must run before ResettableServicePass (-32) builds the resetter's list (#161).
        $container->addCompilerPass(new SkolemIriConverterResetPass());
    }
}
