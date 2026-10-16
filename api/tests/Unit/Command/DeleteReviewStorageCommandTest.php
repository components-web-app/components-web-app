<?php

declare(strict_types=1);

namespace App\Tests\Unit\Command;

use App\Command\DeleteReviewStorageCommand;
use League\Flysystem\Filesystem;
use League\Flysystem\Local\LocalFilesystemAdapter;
use PHPUnit\Framework\Attributes\DataProvider;
use PHPUnit\Framework\TestCase;
use Symfony\Component\Console\Command\Command;
use Symfony\Component\Console\Output\BufferedOutput;

// `delete review` empties a review app's prefix, and nothing else (#166).
class DeleteReviewStorageCommandTest extends TestCase
{
    private string $root;
    private Filesystem $filesystem;

    protected function setUp(): void
    {
        $this->root = sys_get_temp_dir() . '/cwa-review-storage-' . bin2hex(random_bytes(4));
        $this->filesystem = new Filesystem(new LocalFilesystemAdapter($this->root));
        $this->filesystem->write('a.png', 'a');
        $this->filesystem->write('cache/general/a.webp', 'b');
    }

    protected function tearDown(): void
    {
        $this->filesystem->deleteDirectory('');
        @rmdir($this->root);
    }

    public static function refusedPrefixes(): iterable
    {
        yield 'bucket root' => [''];
        yield 'a production prefix' => ['site-a/'];
        yield 'every review app' => ['review/'];
        yield 'a site under a review path' => ['review/my-branch/site-a/'];
    }

    public static function reviewPrefixes(): iterable
    {
        yield 'review app' => ['review/my-branch/'];
        yield 'review app under a project prefix' => ['site-a/review/my-branch/'];
    }

    #[DataProvider('refusedPrefixes')]
    public function test_it_refuses_anything_but_one_review_prefix(string $prefix): void
    {
        $status = (new DeleteReviewStorageCommand($this->filesystem, $prefix))(new BufferedOutput());

        self::assertSame(Command::FAILURE, $status);
        self::assertTrue($this->filesystem->fileExists('a.png'));
    }

    #[DataProvider('reviewPrefixes')]
    public function test_it_deletes_every_file_under_a_review_prefix(string $prefix): void
    {
        $output = new BufferedOutput();
        $status = (new DeleteReviewStorageCommand($this->filesystem, $prefix))($output);

        self::assertSame(Command::SUCCESS, $status);
        self::assertStringContainsString('Deleted 2 file(s)', $output->fetch());
        self::assertFalse($this->filesystem->fileExists('a.png'));
        self::assertFalse($this->filesystem->fileExists('cache/general/a.webp'));
    }
}
