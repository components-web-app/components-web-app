<?php

namespace App\Entity;

use ApiPlatform\Metadata\ApiResource;
use Doctrine\ORM\Mapping as ORM;
use Silverback\ApiComponentsBundle\Annotation as Silverback;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractComponent;
use Silverback\ApiComponentsBundle\Entity\Utility\PublishableTrait;
use Symfony\Component\Validator\Constraints as Assert;

#[Silverback\Publishable]
#[ApiResource(mercure: true)]
#[Orm\Entity]
class Title extends AbstractComponent
{
    use PublishableTrait;

    #[Assert\NotBlank(groups: ['Title:published'])]
    #[Orm\Column(type: 'text', nullable: true)]
    public ?string $title = null;
}
