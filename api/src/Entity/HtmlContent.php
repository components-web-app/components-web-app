<?php

declare(strict_types=1);

namespace App\Entity;

use ApiPlatform\Metadata\ApiResource;
use Doctrine\ORM\Mapping as ORM;
use Silverback\ApiComponentsBundle\Annotation as Silverback;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractComponent;
use Silverback\ApiComponentsBundle\Entity\Utility\PublishableTrait;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * @author Daniel West <daniel@silverback.is>
 */
#[Silverback\Publishable]
#[ApiResource(mercure: true)]
#[Orm\Entity]
class HtmlContent extends AbstractComponent
{
    use PublishableTrait;

    #[Assert\NotBlank(groups: ['HtmlContent:published'])]
    #[Orm\Column(type: 'text', nullable: true)]
    public ?string $html = null;
}
