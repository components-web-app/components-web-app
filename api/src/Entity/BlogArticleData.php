<?php

declare(strict_types=1);

namespace App\Entity;


use ApiPlatform\Core\Annotation\ApiFilter;
use ApiPlatform\Core\Annotation\ApiResource;
use ApiPlatform\Core\Bridge\Doctrine\Orm\Filter\OrderFilter;
use ApiPlatform\Core\Bridge\Doctrine\Orm\Filter\SearchFilter;
use Doctrine\ORM\Mapping as ORM;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractPageData;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * @author Daniel West <daniel@silverback.is>
 * @ORM\Entity()
 * @ApiResource(mercure="true", attributes={"order"={"createdAt": "DESC"}, "pagination_items_per_page"=10})
 * @ApiFilter(SearchFilter::class, properties={"title": "ipartial"})
 * @ApiFilter(OrderFilter::class, properties={"title", "createdAt"})
 */
class BlogArticleData extends AbstractPageData
{
    /**
     * @ORM\ManyToOne(targetEntity=HtmlContent::class)
     * @ORM\JoinColumn(nullable=true)
     */
    public ?HtmlContent $htmlContent = null;
}
