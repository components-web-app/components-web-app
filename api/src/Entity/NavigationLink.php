<?php

declare(strict_types=1);

namespace App\Entity;

use ApiPlatform\Metadata\ApiResource;
use Doctrine\ORM\Mapping as ORM;
use Silverback\ApiComponentsBundle\Annotation as Silverback;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractComponent;
use Silverback\ApiComponentsBundle\Entity\Core\Route;
use Silverback\ApiComponentsBundle\Entity\Utility\PublishableTrait;
use Symfony\Component\Serializer\Annotation\Groups;
use Symfony\Component\Validator\Constraints as Assert;
use Symfony\Component\Validator\Context\ExecutionContextInterface;

/**
 * @author Daniel West <daniel@silverback.is>
 */
#[Silverback\Publishable]
#[ApiResource(mercure: true)]
#[Orm\Entity]
class NavigationLink extends AbstractComponent
{
    use PublishableTrait;

    #[Assert\NotBlank(groups: ["NavigationLink:published"])]
    #[ORM\Column(type: 'text', nullable: true)]
    public ?string $label = null;

    #[ORM\ManyToOne(targetEntity: Route::class)]
    #[ORM\JoinColumn(nullable: true)]
    public ?Route $route = null;

    #[ORM\Column(type: 'text', nullable: true)]
    public ?string $rawPath = null;

    #[Assert\Callback(groups: ["NavigationLink:published"])]
    public function validate(ExecutionContextInterface $context, $payload): void
    {
        if (null === $this->route && null === $this->rawPath)
            $context->buildViolation('A route or a path is required to publish a Navigation Link')
                ->atPath('route')
                ->addViolation();
    }

    #[Groups(["NavigationLink:cwa_resource:read"])]
    public function getUrl(): ?string
    {
        return $this->rawPath ?: $this->route?->getPath();
    }
}
