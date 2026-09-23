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
    #[Assert\File(maxSize: '20M')]
    // Building the thumbnail with GD takes about 11.7 MB per megapixel, so 40 MP needs
    // about 470 MB, inside PHP's 512M memory_limit (10-app.ini). A bigger photo would
    // fail with a 500, so reject it here with a clear message instead. SVG is exempt:
    // it has no pixel dimensions to detect, and Assert\Image would reject it outright.
    #[Assert\When(
        expression: 'value !== null && value.getMimeType() !== "image/svg+xml"',
        constraints: [
            new Assert\Image(
                maxPixels: 40_000_000,
                maxPixelsMessage: 'This image is too large ({{ pixels }} pixels). Please resize it to at most {{ max_pixels }} pixels (about 7700 x 5200) and upload it again.',
            ),
        ],
    )]
    public ?File $file = null;
}
