// Package queryallowlist is a Caddy HTTP handler that drops every query
// parameter not on a list, before the cache and the upstream see the request.
//
// Caddy can delete named parameters (`uri query -name`) but can't keep only a
// list of them, and a cache keyed on the query is missed by any parameter
// nobody reads: `/?x=1`, `/?x=2`, ... each render the page again (#106).
//
// Caddyfile:
//
//	query_allowlist [<matcher>] <name...>
//
// A name keeps the parameter of that name and its bracketed forms, so `order`
// keeps `order`, `order[title]` and `order[]` (also when the brackets are
// percent-encoded). `*` keeps everything, which turns the handler off.
//
// Kept parameters are passed on byte for byte, in their original order: the
// query is only rewritten when something is dropped, and then only by removing
// whole `&`-separated pairs. Caddy's own `uri query` re-encodes the whole query
// whenever it runs, which is what broke Vite's `?vue&type=style...` URLs.
package queryallowlist

import (
	"net/http"
	"net/url"
	"strings"

	"github.com/caddyserver/caddy/v2"
	"github.com/caddyserver/caddy/v2/caddyconfig/caddyfile"
	"github.com/caddyserver/caddy/v2/caddyconfig/httpcaddyfile"
	"github.com/caddyserver/caddy/v2/modules/caddyhttp"
)

func init() {
	caddy.RegisterModule(QueryAllowlist{})
	httpcaddyfile.RegisterHandlerDirective("query_allowlist", parseCaddyfile)
	// Straight after `uri`, so it runs before `cache` (and so before the cache
	// key is built) wherever the cache is ordered after `uri`.
	httpcaddyfile.RegisterDirectiveOrder("query_allowlist", httpcaddyfile.After, "uri")
}

// QueryAllowlist drops every query parameter whose name isn't in Keep.
type QueryAllowlist struct {
	// Parameter names to keep. `name` also keeps `name[...]`. `*` keeps all.
	Keep []string `json:"keep,omitempty"`
}

// CaddyModule returns the Caddy module information.
func (QueryAllowlist) CaddyModule() caddy.ModuleInfo {
	return caddy.ModuleInfo{
		ID:  "http.handlers.query_allowlist",
		New: func() caddy.Module { return new(QueryAllowlist) },
	}
}

// ServeHTTP removes the parameters that aren't allowed, then calls next.
func (q QueryAllowlist) ServeHTTP(w http.ResponseWriter, r *http.Request, next caddyhttp.Handler) error {
	if r.URL.RawQuery != "" {
		if filtered, changed := Filter(r.URL.RawQuery, q.Keep); changed {
			r.URL.RawQuery = filtered
			r.URL.ForceQuery = false
			r.RequestURI = r.URL.RequestURI()
		}
	}
	return next.ServeHTTP(w, r)
}

// Filter returns rawQuery without the pairs whose name isn't allowed by keep,
// and whether anything was removed. Empty pairs (`a&&b`) are removed too.
func Filter(rawQuery string, keep []string) (string, bool) {
	for _, name := range keep {
		if name == "*" {
			return rawQuery, false
		}
	}

	pairs := strings.Split(rawQuery, "&")
	kept := pairs[:0:0]
	for _, pair := range pairs {
		if pair != "" && allowed(pairName(pair), keep) {
			kept = append(kept, pair)
		}
	}
	if len(kept) == len(pairs) {
		return rawQuery, false
	}
	return strings.Join(kept, "&"), true
}

// pairName is the decoded name of a `name=value` pair. An undecodable name
// returns "", which no allowlist entry matches.
func pairName(pair string) string {
	name, _, _ := strings.Cut(pair, "=")
	decoded, err := url.QueryUnescape(name)
	if err != nil {
		return ""
	}
	return decoded
}

func allowed(name string, keep []string) bool {
	if name == "" {
		return false
	}
	for _, k := range keep {
		if name == k || strings.HasPrefix(name, k+"[") {
			return true
		}
	}
	return false
}

// UnmarshalCaddyfile sets up the handler from Caddyfile tokens:
//
//	query_allowlist [<matcher>] <name...>
func (q *QueryAllowlist) UnmarshalCaddyfile(d *caddyfile.Dispenser) error {
	d.Next() // directive name
	q.Keep = append(q.Keep, d.RemainingArgs()...)
	if len(q.Keep) == 0 {
		return d.Err("query_allowlist needs at least one parameter name, or * to keep every parameter")
	}
	if d.NextBlock(0) {
		return d.Err("query_allowlist takes no block")
	}
	return nil
}

func parseCaddyfile(h httpcaddyfile.Helper) (caddyhttp.MiddlewareHandler, error) {
	q := new(QueryAllowlist)
	err := q.UnmarshalCaddyfile(h.Dispenser)
	return q, err
}

// Interface guards
var (
	_ caddyhttp.MiddlewareHandler = (*QueryAllowlist)(nil)
	_ caddyfile.Unmarshaler       = (*QueryAllowlist)(nil)
)
