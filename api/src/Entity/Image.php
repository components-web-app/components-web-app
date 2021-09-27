<?php

declare(strict_types=1);

namespace App\Entity;

use ApiPlatform\Core\Annotation\ApiResource;
use Doctrine\Common\Collections\ArrayCollection;
use Doctrine\ORM\Mapping as ORM;
use Silverback\ApiComponentsBundle\Annotation as Silverback;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractComponent;
use Silverback\ApiComponentsBundle\Entity\Utility\ImagineFiltersInterface;
use Silverback\ApiComponentsBundle\Entity\Utility\PublishableTrait;
use Silverback\ApiComponentsBundle\Entity\Utility\UploadableTrait;
use Symfony\Component\HttpFoundation\File\File;
use Symfony\Component\HttpFoundation\Request;

/**
 * @author Daniel West <daniel@silverback.is>
 * @Silverback\Publishable()
 * @Silverback\Uploadable()
 * @ApiResource(mercure="true")
 * @ORM\Entity
 */
class Image extends AbstractComponent implements ImagineFiltersInterface
{
    use PublishableTrait;
    use UploadableTrait;

    /**
     * @Silverback\UploadableField(adapter="local")
     */
    public ?File $file = null;

    public function getImagineFilters(string $property, ?Request $request): array
    {
        return ['thumbnail', 'square_thumbnail'];
    }
}
