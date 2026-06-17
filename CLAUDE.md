# CLAUDE.md — components-web-app

This is the demo/template application for `@cwa/nuxt`. It runs against the shared Docker API at `https://localhost/_api`.

## Scope

This CLAUDE.md is the primary place to track demo fixes, fixture updates, and template changes needed as a result of module-side decisions. Do not modify application code directly unless explicitly asked.

---

## Nested page templates — `pageDataProperty` pattern (complete, pending module fix)

**Status: Fixtures done. Templates correct. Blocked on a module-side path header bug for the child-page case.**

Templates (`NestedTopicTemplate.vue`, `NestedSubPageTemplate.vue`) use `props.iri` as the `CwaComponentGroup` location. The template page's primary group has a `ComponentPosition` with `pageDataProperty='introContent'` (no direct component). Each `NestedPageData` instance has `introContent` set to its own `HtmlContent` entity. Fixtures reloaded 2026-06-16.

**What works now:**
- `/topic-1` → intro content shows ✓ (path header = `/topic-1`, resolves Topic 1's PageData, reads `introContent`)

**What is broken (module bug):**
- `/topic-1/chapter-one` → parent template's intro slot is empty ✗

Root cause: the module sends `path = <leaf URL>` as a single header applied to ALL requests in the manifest batch. `ComponentPositionNormalizer` uses that path to look up the current PageData via `PageDataProvider::getPageData()` → `route->getPageData()`. For route `/topic-1/chapter-one` the route resolves to a static `Page` (no PageData), so `getPageData()` returns `null` and `introContent` is not substituted.

**Fix needed in the module** — tracked in module CLAUDE.md. The fetcher must send depth-appropriate `path` headers: when fetching a resource that belongs to depth N, use the route path from depth N's manifest group, not the leaf (deepest) path.

---

## Layout component groups: not an IRI-string issue

The API returns `componentGroups` on a `Layout` resource as **embedded JSON-LD objects**, not IRI strings. This was a module-side bug (now fixed in `fetcher.ts`) — no fixture changes needed. Nav links in the layout now render correctly for unauthenticated users.

---

## Migrate fixtures to `CwaFixtureBuilder`

> **Task: Replace `AbstractPageFixture`-based fixtures with the new `CwaFixtureBuilder` fluent API.**

`CwaFixtureBuilder` and `AbstractCwaScaffold` ship in `silverback/api-components-bundle`. They replace the manual persist boilerplate in each fixture class.

### What the builder handles (no longer write this manually)

- Layout entity creation and deduplication by `reference`
- Page entity creation with `isTemplate`, `layout`, `reference`, `uiComponent`, and optional `title`/`metaDescription`
- ComponentGroup creation linked to a Layout or Page, with `allowedComponents` IRI resolution
- ComponentPosition creation for concrete components (`add()`) and `pageDataProperty` slots (`pageDataPosition()`), with auto-incrementing sort values (×10)
- Route creation: explicit path (`route: '/path'`, `routeName: 'name'`) or auto-generated via `RouteGenerator::create()` (slugifies title, prefixes with parent path)
- PageData template linking (`$pageData->page = $templatePage` automatically when `template: 'page-ref'` is passed)
- Nested hierarchy: `->nested(fn)` sets `parentPage`/`parentPageData` on children and ensures parent routes are created before child routes
- Named route registry: `$cwa->getRoute('name')` after `flush()`
- Timestamped fields on all entities
- All `flush()` calls in correct order (entities → groups → routes → positions)

### What the app still creates manually (builder does not handle)

The builder's `add($component)` takes any `AbstractComponent` instance — the app creates that instance before calling `add()`:

```php
$htmlContent = new HtmlContent();
$htmlContent->html = '...';
$htmlContent->setPublishedAt(new \DateTime());
// Then pass to builder:
->group('primary')->add($htmlContent)
```

The builder does NOT know about:
- `HtmlContent`, `Image`, `Collection`, `NavigationLink`, `BlogArticleData` — app-specific entity creation
- `CwaPlaceholderProvider` — placeholder content generation (still call `$this->getCwaPlaceholderProvider()->generate(...)`)
- `publishedAt` on components — set on the entity before passing to `add()`
- `publishedResource` (draft → published link) — set on the entity before passing to `add()`
- `BlogArticleData.htmlContent`, `NestedPageData.introContent` — app-specific property assignments

### How to use `AbstractCwaScaffold`

`AbstractCwaScaffold` implements `FixtureInterface`. The Doctrine Fixtures Bundle picks it up automatically if registered as a service. Its `load()` calls `build()` then `flush()`.

```php
use Silverback\ApiComponentsBundle\Fixture\AbstractCwaScaffold;
use Silverback\ApiComponentsBundle\Fixture\CwaFixtureBuilder;

class AppScaffold extends AbstractCwaScaffold
{
    public function build(CwaFixtureBuilder $cwa): void
    {
        $navGroup = $cwa->layout('main', 'CwaLayoutPrimary')
            ->group('top', allow: [NavigationLink::class]);

        $cwa->page('home', 'PrimaryPageTemplate', layout: 'main', route: '/', routeName: 'home-page',
            configure: function (PageBuilder $page) {
                $page->title('Welcome to CWA')->metaDescription('A demo CWA website');
                $page->group('primary')
                    ->add((new HtmlContent())->setHtml('...')->setPublishedAt(new \DateTime()))
                    ->add(new Image());
            }
        );

        // Nav bar populated after routes exist
        $navGroup->add(
            (new NavigationLink())->setLabel('Home')->setRoute($cwa->getRoute('home-page'))->setPublishedAt(new \DateTime())
        );
    }
}
```

Register in `config/services.yaml` if not using autoconfigure:
```yaml
App\DataFixtures\AppScaffold:
    autoconfigure: true
```

### `CwaFixtureBuilder` API reference

```
CwaFixtureBuilder
  ->withManager(ObjectManager): static
  ->layout(ref: string, uiComponent: string): LayoutBuilder
  ->page(ref, uiComponent, layout, ?route, ?routeName, isTemplate=false, ?Closure $configure): PageBuilder
  ->pageData(AbstractPageData, ?template, ?route, ?routeName, ?Closure $configure): PageDataBuilder
  ->getRoute(routeName): Route                    (only valid after flush())
  ->flush(): void

LayoutBuilder
  ->getLayout(): Layout
  ->group(name, allow: [], ?Closure $configure): GroupBuilder

PageBuilder
  ->title(string): self
  ->metaDescription(string): self
  ->group(name, ?Closure $configure): GroupBuilder
  ->nested(Closure): void                         (Closure receives CwaFixtureBuilder with parent context)
  ->getPage(): Page
  ->getRoute(): ?Route

PageDataBuilder
  ->nested(Closure): void
  ->getPageData(): AbstractPageData
  ->getRoute(): ?Route

GroupBuilder
  ->add(AbstractComponent, ?sort): self           (sort defaults to 10, 20, 30, ... auto-incremented)
  ->pageDataPosition(property: string, ?sort): self
```

**Route generation rules:**

| Situation | Result |
|---|---|
| `route: '/path'` explicit | Creates Route with that path; `routeName:` registers it in `getRoute()` |
| `isTemplate: true`, no explicit `route:` | No Route created |
| No `route:`, not template | `RouteGenerator::create()` called — slugifies title, prefixes with parent path if nested |
| `->pageData(..., template: 'ref')` | `pageData->page` is set to the Page registered under `ref` |
| `->nested(fn)` on PageDataBuilder | Children inside `fn` have `parentPageData` set automatically |
| `->nested(fn)` on PageBuilder | Children inside `fn` have `parentPage` set automatically |

### Migration plan for current fixtures

#### Priority 1 — `HomePageFixture`

Replace with a scaffold that covers the layout, nav bar, and home page. The scaffold can contain all the nav registration (currently split across `AbstractPageFixture::createLayout` → `addNavigationLink`).

Key mapping:
- `createLayout` → `$cwa->layout('main', 'CwaLayoutPrimary')->group('top', allow: [NavigationLink::class])`
- `createPage('home', 'PrimaryPageTemplate', $layout)` → `$cwa->page('home', 'PrimaryPageTemplate', layout: 'main', route: '/', routeName: 'home-page', configure: fn(PageBuilder $p) => $p->title(...)->group('primary')->add(...)->add(...))`
- Nav links: call `$navGroup->add(new NavigationLink(...))` after `flush()` returns — or better, pass a second closure that runs after routes exist (builder guarantees routes exist before positions are created)
- The nav group's `add()` calls happen inside `flush()`'s phase 4. If nav links reference routes by `getRoute('name')`, call them **inside a `->group('top', configure: fn)` closure** — closures are evaluated in phase 4, after all routes from phase 3 are available

Actually: `GroupBuilder` closures passed to `->group('top', configure: fn)` are evaluated eagerly when `group()` is called, NOT in phase 4. Route references must be passed AFTER `flush()`. For nav links, hold the `GroupBuilder` reference and call `add()` after the scaffold's `flush()`:

```php
public function build(CwaFixtureBuilder $cwa): void
{
    $navGroup = $cwa->layout('main', 'CwaLayoutPrimary')->group('top', allow: [NavigationLink::class]);

    $cwa->page('home', 'PrimaryPageTemplate', layout: 'main', route: '/', routeName: 'home-page',
        configure: fn(PageBuilder $p) => $p->title('Welcome to CWA')
    );

    // Must be called by the caller (AppScaffold::build) AFTER $cwa->flush()
    // OR: build a helper that registers nav links after flush.
    // For now: the scaffold's build() returns the $navGroup and nav setup happens post-flush.
}
```

Simpler approach: split into two phases — call `flush()` manually inside `build()` to get routes, then add nav links, then the scaffold's `load()` calls `flush()` again:

```php
public function build(CwaFixtureBuilder $cwa): void
{
    $navGroup = $cwa->layout('main', 'CwaLayoutPrimary')->group('top', allow: [NavigationLink::class]);

    $cwa->page('home', 'PrimaryPageTemplate', layout: 'main', route: '/', routeName: 'home-page',
        configure: fn(PageBuilder $p) => $p->title('Welcome to CWA')
    );
    $cwa->page('blog-list', 'PrimaryPageTemplate', layout: 'main', route: '/blog-articles', routeName: 'blog-page',
        configure: fn(PageBuilder $p) => $p->title('Blog')
    );

    $cwa->flush();  // routes now exist

    $navGroup->add((new NavigationLink())->setLabel('Home')->setRoute($cwa->getRoute('home-page'))->setPublishedAt(new \DateTime()));
    $navGroup->add((new NavigationLink())->setLabel('Blog')->setRoute($cwa->getRoute('blog-page'))->setPublishedAt(new \DateTime()));
    // AbstractCwaScaffold::load() calls flush() again after build() returns — picks up nav positions
}
```

> **Important**: `AbstractCwaScaffold::load()` calls `build()` then `flush()`. If `build()` calls `flush()` internally (to get named routes for nav links), that is safe — `flush()` is idempotent on already-persisted entities and a second `flush()` just picks up any newly added group members.

#### Priority 2 — `BlogCollectionPageFixture`

Merge into the main scaffold's `build()` — one scaffold can own all site pages. The `Collection` component is created manually and passed to `->group('primary')->add($collection)`.

#### Priority 3 — `BlogArticlesFixture`

The blog template page and article instances merge into the main scaffold. `pageDataProperty` positions use `->pageDataPosition('image')` and `->pageDataPosition('htmlContent')`. Article `BlogArticleData` instances use explicit `route:` per item. The `htmlContent` property is set on the `BlogArticleData` before passing to `pageData()`.

#### Priority 4 — `NestedPageDataFixture`

This is the most complex — demonstrates the builder's full nested support. `NestedPageData` instances use `->pageData($topicPd, template: 'topic-template')` then `->nested(fn($child) => $child->page('chapter-1', ...))`. The `introContent` HtmlContent is set on the `NestedPageData` before passing to `pageData()`. RouteGenerator auto-prefixes child paths.

#### What to delete after migration

- `AbstractPageFixture.php` — replaced by `AbstractCwaScaffold` + builder
- All individual `*Fixture.php` files — replaced by a single `AppScaffold` (or a small set of scaffolds if fixtures need Doctrine ordering)
- `config/services.yaml` entries for the old fixtures if any were explicit

#### Doctrine fixture ordering

`AbstractCwaScaffold` does not implement `DependentFixtureInterface`. If a single `AppScaffold` class handles everything, no ordering is needed. If split across multiple scaffold classes, use `DependentFixtureInterface` as before.

`UsersFixture.php` does not use `AbstractPageFixture` and has no dependency on page content — it can stay as-is.
