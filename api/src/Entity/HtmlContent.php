<?php

declare(strict_types=1);


namespace App\Entity;


use ApiPlatform\Core\Annotation\ApiResource;
use Doctrine\ORM\Mapping as ORM;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractComponent;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * @author Daniel West <daniel@silverback.is>
 * @ApiResource(mercure="true")
 * @ORM\Entity
 */
class HtmlContent extends AbstractComponent
{
    /**
     * @Assert\NotBlank()
     * @ORM\Column(nullable=false)
     */
    public ?string $html = null;
}
