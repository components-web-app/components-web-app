<?php

declare(strict_types=1);

namespace App\Entity;


use ApiPlatform\Core\Annotation\ApiResource;
use Doctrine\ORM\Mapping as ORM;
use Silverback\ApiComponentsBundle\Entity\Core\AbstractPageData;
use Symfony\Component\Validator\Constraints as Assert;

/**
 * @author Daniel West <daniel@silverback.is>
 * @ORM\Entity()
 * @ApiResource(mercure="true", attributes={"order"={"createdAt": "DESC"}, "pagination_items_per_page"=10})
 */
class BlogArticleData extends AbstractPageData
{
    /**
     * @Assert\NotBlank()
     * @ORM\ManyToOne(targetEntity=HtmlContent::class)
     */
    public ?HtmlContent $htmlContent = null;
}
