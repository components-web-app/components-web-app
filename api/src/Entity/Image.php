<?php

declare(strict_types=1);

namespace App\Entity;

use ApiPlatform\Core\Annotation\ApiResource;
use Doctrine\ORM\Mapping as ORM;
use Silverback\ApiComponentsBundle\Annotation as Silverback;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractComponent;
use Silverback\ApiComponentsBundle\Entity\Utility\PublishableTrait;
use Silverback\ApiComponentsBundle\Entity\Utility\UploadableTrait;
use Symfony\Component\HttpFoundation\File\File;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * @author Daniel West <daniel@silverback.is>
 * @Silverback\Publishable()
 * @Silverback\Uploadable()
 * @ApiResource(mercure="true")
 * @ORM\Entity
 */
class Image extends AbstractComponent
{
    use PublishableTrait;
    use UploadableTrait;

    /**
     * @Silverback\UploadableField(adapter="local", imagineFilters={})
     * @Assert\File(maxSize="5M")
     * @Assert\Image(
     *     maxWidth = 2000,
     *     maxHeight = 2000
     * )
     */
    public ?File $file = null;
}
