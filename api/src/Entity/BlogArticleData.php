<?php

declare(strict_types=1);

namespace App\Entity;


use ApiPlatform\Doctrine\Orm\Filter\OrderFilter;
use ApiPlatform\Doctrine\Orm\Filter\SearchFilter;
use ApiPlatform\Metadata\ApiFilter;
use ApiPlatform\Metadata\ApiResource;
use Doctrine\ORM\Mapping as ORM;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractPageData;

/**
 * @author Daniel West <daniel@silverback.is>
 */
#[Orm\Entity]
#[ApiResource(
    mercure: true,
    order: [ 'createdAt' => 'DESC' ],
    paginationItemsPerPage: 10
)]
#[ApiFilter(SearchFilter::class, properties: [ 'title' => 'ipartial' ])]
#[ApiFilter(OrderFilter::class, properties: [ 'title', 'createdAt' ])]
class BlogArticleData extends AbstractPageData
{
    #[Orm\ManyToOne(targetEntity: HtmlContent::class)]
    #[Orm\JoinColumn(nullable: true, onDelete: 'SET NULL')]
    public ?HtmlContent $htmlContent = null;
}
