<?php

declare(strict_types=1);

namespace App\Entity;

use ApiPlatform\Metadata\ApiResource;
use Doctrine\ORM\Mapping as ORM;
use Silverback\ApiComponentsBundle\Annotation as Silverback;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractComponent;
use Silverback\ApiComponentsBundle\Entity\Utility\PublishableTrait;
use Silverback\ApiComponentsBundle\Entity\Utility\UploadableTrait;
use Symfony\Component\HttpFoundation\File\File;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * @author Daniel West <daniel@silverback.is>
 */
#[Silverback\Publishable]
#[Silverback\Uploadable]
#[ApiResource(mercure: true)]
#[Orm\Entity]
class Image extends AbstractComponent
{
    use PublishableTrait;
    use UploadableTrait;

    #[Silverback\UploadableField(adapter: 'gcloud', urlGenerator: 'public', imagineFilters: ['thumbnail'])]
    #[Assert\File(maxSize: '5M')]
    public ?File $file = null;
}
