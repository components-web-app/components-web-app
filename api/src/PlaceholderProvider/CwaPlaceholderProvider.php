<?php

namespace App\PlaceholderProvider;

class CwaPlaceholderProvider
{
    public const FORMAT_HTML = 'html';
    public const FORMAT_PLAINTEXT = 'plaintext';

    public const LENGTH_SHORT = 'short';
    public const LENGTH_MEDIUM = 'medium';
    public const LENGTH_LONG = 'long';

    protected array $options = [
        'paragraphs' => 3,
        'paragraphLength' => 'medium',
        'includeHeadings' => false,
        'includeLists' => false,
        'includeQuotes' => false,
        'includeCode' => false,
        'includeLinks' => false,
        'format' => self::FORMAT_HTML,
    ];

    protected array $paragraphTemplates = [
        "Our Custom Web Application (CWA) empowers businesses to take control of their online presence with scalable, intuitive tools.",
        "Built with flexibility in mind, the CWA supports dynamic modules tailored to the unique workflows of growing companies.",
        "From rapid deployment to ongoing iteration, our system enables teams to manage content, customer interactions, and analytics — all from one place.",
        "Security, performance, and usability drive the foundation of the platform, ensuring peace of mind for clients and their users.",
        "The admin interface is designed to be user-friendly and accessible, so teams can get started with minimal training.",
        "We integrate seamlessly with third-party services, making it easy to connect your CRM, email platform, and more.",
        "With customizable UI components and branding options, your CWA truly reflects your company’s identity.",
        "Performance optimization is built-in, including server-side rendering and responsive design out of the box.",
    ];

    protected array $headings = [
        "Why Choose Our CWA?",
        "Key Benefits",
        "How It Works",
        "Tailored for Growth",
        "Modular Architecture",
        "Effortless Content Management",
    ];

    protected array $listItems = [
        "Drag-and-drop page builder",
        "Role-based access control",
        "SEO-friendly routing",
        "Real-time notifications",
        "Analytics dashboard",
        "API-first design",
        "Live preview mode",
        "Multilingual support",
        "Component library with dark mode",
        "Automated deployment pipeline",
    ];

    protected array $codeSnippets = [
        "fetch('/api/v1/content', { method: 'GET' })",
        "<component is=\"UserCard\" :user=\"user\" />",
        "const user = await auth.login(email, password);",
        "cwa.renderComponent('Dashboard', userContext);",
    ];

    protected array $quotes = [
        "We switched to the CWA and reduced deployment time by 40%.",
        "The flexibility of the system let us scale without rewriting our stack.",
        "Our marketing team actually enjoys using the CMS now.",
        "Clients have praised the speed and responsiveness of the new site.",
        "We feel supported — not just technically, but strategically too.",
    ];

    protected array $links = [
        'here is a link' => 'https://cwa.rocks',
        'welcome to the link world' => 'https://cwa.rocks',
        'link me up Scotty' => 'https://cwa.rocks',
        'linky mc link face' => 'https://cwa.rocks'
    ];

    public function __construct(array $options = [])
    {
        $this->setOptions($options);
    }

    public function setOptions(array $options): void
    {
        $this->options = array_merge($this->options, $options);
    }

    private function insertNewOutput(array $output, int $maxInserts, callable $callback): array {
        if ($maxInserts < 1) {
            return $output;
        }
        $toInsert = rand(1, $maxInserts);
        for ($i = 0; $i < $toInsert; $i++) {
            $index = count($output) > 0 ? rand(0, count($output) - 1) : 0;
            array_splice($output, $index, 0, $callback());
        }
        return $output;
    }

    public function generate(array $options = []): string
    {
        $options = array_merge($this->options, $options);

        $output = [];

        $totalParagraphs = $options['paragraphs'];
        for ($i = 0; $i < $totalParagraphs; $i++) {
            $output[] = $this->renderParagraph();
        }

        if ($options['includeHeadings']) {
            array_splice($output, 0, 0, $this->renderHeading());
            $output = $this->insertNewOutput($output, $totalParagraphs - 1, [$this, 'renderHeading']);
        }

        $insertables = [
            'includeLists' => 'renderList',
            'includeQuotes' => 'renderQuote',
            'includeCode' => 'renderCode',
        ];

        foreach ($insertables as $flag => $method) {
            if ($options[$flag]) {
                $output = $this->insertNewOutput($output, $totalParagraphs, [$this, $method]);
            }
        }

        return implode("\n\n", $output);
    }

    protected function renderHeading(): string
    {
        $heading = $this->randomElement($this->headings);
        return $this->format("<h2>{$heading}</h2>", $heading);
    }

    protected function renderParagraph(): string
    {
        $sentences = $this->randomSelection($this->paragraphTemplates, $this->getParagraphSentenceCount());
        $text = implode(' ', $sentences);

        if ($this->options['includeLinks']) {
            $text = $this->insertLinks($text);
        }

        return $this->format("<p>{$text}</p>", $text);
    }

    protected function getParagraphSentenceCount(): int
    {
        return match ($this->options['paragraphLength']) {
            self::LENGTH_SHORT => rand(1, 2),
            self::LENGTH_LONG => rand(5, 7),
            default => rand(3, 4), // 'medium' or fallback
        };
    }

    protected function insertLinks(string $text): string
    {
        $phrases = array_keys($this->links);
        shuffle($phrases);
        $numLinks = rand(1, min(2, count($phrases)));

        for ($i = 0; $i < $numLinks; $i++) {
            $phrase = $phrases[$i];
            $url = $this->links[$phrase];

            if (stripos($text, $phrase) !== false) {
                if ($this->options['format'] === self::FORMAT_HTML) {
                    $replacement = "<a href=\"{$url}\">{$phrase}</a>";
                } else {
                    $replacement = "{$phrase} ({$url})";
                }
                $text = preg_replace("/\b" . preg_quote($phrase, '/') . "\b/i", $replacement, $text, 1);
            }
        }

        return $text;
    }

    protected function renderList(): string
    {
        $items = $this->randomSelection($this->listItems, rand(3, 6));
        $tags = ['ul', 'ol'];
        $tag = $tags[array_rand($tags)];
        $html = "<{$tag}>\n";
        foreach ($items as $item) {
            $html .= "<li>{$item}</li>\n";
        }
        $html .= "</{$tag}>";

        $plain = '- ' . implode("\n- ", $items);
        return $this->format($html, $plain);
    }

    protected function renderQuote(): string
    {
        $quote = $this->randomElement($this->quotes);
        return $this->format("<blockquote>{$quote}</blockquote>", "\"{$quote}\"");
    }

    protected function renderCode(): string
    {
        $code = $this->randomElement($this->codeSnippets);
        return $this->format("<pre><code>{$code}</code></pre>", $code);
    }

    protected function format(string $html, string $plain): string
    {
        return $this->options['format'] === 'plaintext' ? $plain : $html;
    }

    protected function randomElement(array $array): string
    {
        return $array[array_rand($array)];
    }

    protected function randomSelection(array $array, int $count): array
    {
        shuffle($array);
        return array_slice($array, 0, $count);
    }
}
