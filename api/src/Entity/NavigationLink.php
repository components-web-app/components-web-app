<?php

declare(strict_types=1);

namespace App\Entity;

use ApiPlatform\Core\Annotation\ApiResource;
use Doctrine\ORM\Mapping as ORM;
use Silverback\ApiComponentsBundle\Annotation as Silverback;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractComponent;
use Silverback\ApiComponentsBundle\Entity\Core\Route;
use Silverback\ApiComponentsBundle\Entity\Utility\PublishableTrait;
use Symfony\Component\Serializer\Annotation\Groups;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * @author Daniel West <daniel@silverback.is>
 * @Silverback\Publishable()
 * @ApiResource(mercure="true")
 * @ORM\Entity
 */
class NavigationLink extends AbstractComponent
{
    use PublishableTrait;

    /**
     * @Assert\NotBlank(groups={"NavigationLink:published"})
     * @ORM\Column(type="text", nullable=true)
     */
    public ?string $label = null;

    /**
     * @Assert\NotBlank(groups={"NavigationLink:published"})
     * @ORM\ManyToOne(targetEntity=Route::class)
     * @ORM\JoinColumn(nullable=true)
     */
    public ?Route $route = null;

    /**
     * @Groups({"NavigationLink:cwa_resource:read"})
     */
    public function getUrl(): ?string
    {
        return $this->route?->getPath();
    }
}
