<?php

declare(strict_types=1);

namespace App\Http;

use Symfony\Component\HttpFoundation\Request;

/**
 * The visitor's IP address, for per-visitor limits such as a form's rate limit (#225).
 *
 * Behind Cloudflare, getClientIp() is a Cloudflare edge address shared by many visitors. Caddy resolves the visitor as
 * its rate limit does (CF-Connecting-IP only from Cloudflare's ranges, CLOUDFLARE_IP_RANGES and CADDY_TRUSTED_PROXIES
 * included) and passes it as the CWA_VISITOR_IP server variable, which no request header can set. Without it (console
 * commands, functional tests) this is getClientIp().
 */
final class VisitorIp
{
    public function of(Request $request): ?string
    {
        // Behind an unknown public proxy Caddy's value is "<proxy address> <X-Forwarded-For>": the proxy's address counts.
        $resolved = strtok((string) $request->server->get('CWA_VISITOR_IP', ''), ' ');
        if (false !== $resolved && false !== filter_var($resolved, \FILTER_VALIDATE_IP)) {
            return $resolved;
        }

        return $request->getClientIp();
    }
}
