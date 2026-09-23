<?php

declare(strict_types=1);

namespace App\Entity;

use ApiPlatform\Doctrine\Orm\Filter\FreeTextQueryFilter;
use ApiPlatform\Doctrine\Orm\Filter\OrFilter;
use ApiPlatform\Doctrine\Orm\Filter\PartialSearchFilter;
use ApiPlatform\Doctrine\Orm\Filter\SortFilter;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\QueryParameter;
use Doctrine\ORM\Mapping as ORM;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractPageData;

/**
 * @author Daniel West <daniel@silverback.is>
 */
#[Orm\Entity]
#[ApiResource(
    mercure: true,
    order: [ 'createdAt' => 'DESC' ],
    paginationItemsPerPage: 12,
    parameters: [
        'search' => new QueryParameter(filter: new FreeTextQueryFilter(new OrFilter(new PartialSearchFilter())), properties: ['title']),
        'order[:property]' => new QueryParameter(filter: new SortFilter(), properties: ['title', 'createdAt']),
    ],
)]
class BlogArticleData extends AbstractPageData
{
    #[Orm\ManyToOne(targetEntity: HtmlContent::class)]
    #[Orm\JoinColumn(nullable: true, onDelete: 'SET NULL')]
    public ?HtmlContent $htmlContent = null;

    #[Orm\ManyToOne(targetEntity: Image::class)]
    #[Orm\JoinColumn(nullable: true, onDelete: 'SET NULL')]
    public ?Image $image = null;

    public function getRoutePath () {
        return $this->getRoute()?->getPath();
    }
}
