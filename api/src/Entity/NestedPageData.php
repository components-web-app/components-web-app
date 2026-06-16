<?php

declare(strict_types=1);

namespace App\Entity;

use ApiPlatform\Doctrine\Orm\Filter\SearchFilter;
use ApiPlatform\Metadata\ApiFilter;
use ApiPlatform\Metadata\ApiResource;
use Doctrine\ORM\Mapping as ORM;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractPageData;

#[ORM\Entity]
#[ApiResource(mercure: true)]
#[ApiFilter(SearchFilter::class, properties: ['title' => 'ipartial'])]
class NestedPageData extends AbstractPageData
{
    #[ORM\ManyToOne(targetEntity: HtmlContent::class)]
    #[ORM\JoinColumn(nullable: true, onDelete: 'SET NULL')]
    public ?HtmlContent $introContent = null;
}
