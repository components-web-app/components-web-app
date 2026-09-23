<?php

declare(strict_types=1);

namespace App\Entity;

use ApiPlatform\Doctrine\Orm\Filter\FreeTextQueryFilter;
use ApiPlatform\Doctrine\Orm\Filter\OrFilter;
use ApiPlatform\Doctrine\Orm\Filter\PartialSearchFilter;
use ApiPlatform\Doctrine\Orm\Filter\SortFilter;
use ApiPlatform\Metadata\ApiResource;
use ApiPlatform\Metadata\Delete;
use ApiPlatform\Metadata\Get;
use ApiPlatform\Metadata\GetCollection;
use ApiPlatform\Metadata\Patch;
use ApiPlatform\Metadata\Post;
use ApiPlatform\Metadata\Put;
use ApiPlatform\Metadata\QueryParameter;
use Doctrine\ORM\Mapping as ORM;
use Silverback\ApiComponentsBundle\Entity\User\AbstractUser;

/**
 * @author Daniel West <daniel@silverback.is>
 */
#[ApiResource(
    operations: [
        new GetCollection( order: ['createdAt' => 'DESC'], security: "is_granted('ROLE_SUPER_ADMIN')"),
        new Post( security: "is_granted('ROLE_SUPER_ADMIN')" ),
        new Get( security: "is_granted('ROLE_SUPER_ADMIN') or object.getId() == user.getId()" ),
        new Put( security: "is_granted('ROLE_SUPER_ADMIN') or object.getId() == user.getId()" ),
        new Patch( security: "is_granted('ROLE_SUPER_ADMIN') or object.getId() == user.getId()" ),
        new Delete( security: "is_granted('ROLE_SUPER_ADMIN')" )
    ],
    parameters: [
        'search' => new QueryParameter(filter: new FreeTextQueryFilter(new OrFilter(new PartialSearchFilter())), properties: ['username', 'emailAddress']),
        'order[:property]' => new QueryParameter(filter: new SortFilter(), properties: ['createdAt', 'username']),
    ],
)]
#[ORM\Entity]
#[ORM\Table(name: "`user`")]
class User extends AbstractUser
{
//    public static function loadValidatorMetadata(ClassMetadata $metadata): void
//    {
//        $metadata->addPropertyConstraint('username', new Assert\Email([
//            'message' => 'Please enter a valid email address.',
//        ]));
//    }

//    public function __construct(
//        string $username = '',
//        string $emailAddress = '',
//        bool $emailAddressVerified = false,
//        array $roles = ['ROLE_USER'],
//        string $password = '',
//        bool $enabled = true
//    ) {
//        parent::__construct($username, $emailAddress, $emailAddressVerified, $roles, $password, $enabled);
//        $this->emailAddress = $this->username;
//    }

//    public function setUsername(?string $username): User
//    {
//        parent::setUsername($username);
//        $this->setEmailAddress($username);
//        return $this;
//    }
}
