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
    // 30 MP is what the imagine budget (320M) can thumbnail with vips (#136, #141); bigger gets a 422, not a skipped filter.
    // SVG is exempt: it has no pixel dimensions, and Assert\Image would reject it outright.
    #[Assert\When(
        expression: 'value !== null && value.getMimeType() !== "image/svg+xml"',
        constraints: [
            new Assert\Image(
                maxPixels: 30_000_000,
                maxPixelsMessage: 'This image is too large ({{ pixels }} pixels). Please resize it to at most {{ max_pixels }} pixels (about 6700 x 4470) and upload it again.',
            ),
        ],
    )]
    public ?File $file = null;
}
