vcl 4.0;

import std;

backend default {
  .host = "${UPSTREAM}";
  .port = "${UPSTREAM_PORT}";
  .max_connections        = 300;
  .first_byte_timeout     = 300s;   # How long to wait before we receive a first byte from our backend?
  .connect_timeout        = 5s;     # How long to wait for a backend connection?
  .between_bytes_timeout  = 2s;     # How long to wait between bytes received from our backend?

  # Health check
  .probe = {
    .request =
      "HEAD /health-check HTTP/1.1"
      "Host: caddy-probe.local"
      "Connection: close"
      "User-Agent: Varnish Health Probe";
    .timeout = 5s;
    .interval = 5s;
    .window = 4;
    .threshold = 2;
  }
}

acl profile {
   # Authorized IPs, add your own IPs from which you want to profile.
   # "x.y.z.w";

   # Add the Blackfire.io IPs when using builds:
   # Ref https://blackfire.io/docs/reference-guide/faq#how-should-i-configure-my-firewall-to-let-blackfire-access-my-apps
   "46.51.168.2";
   "54.75.240.245";
}

# Hosts allowed to send BAN requests
acl invalidators {
  "localhost";
  "${PHP_SERVICE}";
  # local Kubernetes network
  "10.0.0.0"/8;
  "172.16.0.0"/12;
  "192.168.0.0"/16;
}

sub vcl_recv {
  # For health checks
  if (req.method == "GET" && req.url == "/healthz") {
    return (synth(200, "OK"));
  }

  if (req.esi_level > 0) {
    # ESI request should not be included in the profile.
    # Instead you should profile them separately, each one
    # in their dedicated profile.
    # Removing the Blackfire header avoids to trigger the profiling.
    # Not returning let it go trough your usual workflow as a regular
    # ESI request without distinction.
    unset req.http.X-Blackfire-Query;
  }

  unset req.http.x-cache;
  set req.http.grace = "none";
  set req.http.Surrogate-Capability = "abc=ESI/1.0";

  if (req.restarts > 0) {
    set req.hash_always_miss = true;
  }

  # Remove the "Forwarded" HTTP header if exists (security)
  # Removing this causes issues for development on same domain
  # Logins fail, OPTIONS requests fails and more... need to find out why...
  unset req.http.forwarded;

  # Remove fields and preload headers used for vulcain
  # https://github.com/dunglas/vulcain/blob/master/docs/cache.md
  unset req.http.fields;
  unset req.http.preload;

  # If it's a Blackfire query and the client is authorized,
  # just pass directly to the application.
  if (req.http.X-Blackfire-Query && client.ip ~ profile) {
    return (pass);
  }

  # To allow API Platform to ban by cache tags
  if (req.method == "BAN") {
    if (client.ip !~ invalidators) {
      return (synth(405, "Not allowed"));
    }

    if (req.http.ApiPlatform-Ban-Regex) {
      ban("obj.http.Cache-Tags ~ " + req.http.ApiPlatform-Ban-Regex);

      return (synth(200, "Ban added"));
    }

    return (synth(400, "ApiPlatform-Ban-Regex HTTP header must be set."));
  }

  if (req.http.Cookie) {
      set req.http.Cookie = ";" + req.http.Cookie;
      set req.http.Cookie = regsuball(req.http.Cookie, "; +", ";");
      set req.http.Cookie = regsuball(req.http.Cookie, ";(api_component)=", "; \1=");
      set req.http.Cookie = regsuball(req.http.Cookie, ";[^ ][^;]*", "");
      set req.http.Cookie = regsuball(req.http.Cookie, "^[; ]+|[; ]+$", "");

      if (req.http.Cookie == "") {
          // If there are no more cookies, remove the header to get page cached.
          unset req.http.Cookie;
      }
  }
}

sub vcl_hit {
  set req.http.x-cache = "hit";

  if (obj.ttl >= 0s) {
    # A pure unadulterated hit, deliver it
    return (deliver);
  }

  # https://info.varnish-software.com/blog/grace-varnish-4-stale-while-revalidate-semantics-varnish
  if (std.healthy(req.backend_hint)) {
    # Backend is healthy. Limit age to 10s.
    if (obj.ttl + 10s > 0s) {
        set req.http.grace = "normal(limited)";
        return (deliver);
    } else {
        # Fetch the object from the backend
        return (restart);
    }
  }

  # No fresh object and the backend is not healthy
  if (obj.ttl + obj.grace > 0s) {
    # Deliver graced object
    # Automatically triggers a background fetch
    set req.http.grace = "full";
    return (deliver);
  }

  # No valid object to deliver
  # No healthy backend to handle request
  # Return error
  return (synth(503, "API is down"));
}

sub vcl_miss {
	set req.http.x-cache = "miss";
}

sub vcl_pass {
	set req.http.x-cache = "pass";
}

sub vcl_pipe {
	set req.http.x-cache = "pipe uncacheable";
}

sub vcl_synth {
	set resp.http.x-cache = "synth synth";
	call cors;
}

sub vcl_deliver {
  if (obj.uncacheable) {
		set req.http.x-cache = req.http.x-cache + " uncacheable" ;
	} else {
		set req.http.x-cache = req.http.x-cache + " cached" ;
	}
	set resp.http.x-cache = req.http.x-cache;
  set resp.http.grace = req.http.grace;
  # Don't send cache tags related headers to the client
  unset resp.http.url;
  # Comment the following line to send the "Cache-Tags" header to the client (e.g. to use CloudFlare cache tags)
  unset resp.http.Cache-Tags;

  call cors;
}

sub vcl_backend_response {
  # https://info.varnish-software.com/blog/grace-varnish-4-stale-while-revalidate-semantics-varnish
  set beresp.ttl = 10s;
  # Ban lurker friendly header
  set beresp.http.url = bereq.url;
  # Add a grace in case the backend is down
  set beresp.grace = 1h;
}

sub cors {
  if (req.http.Origin ~ "${CORS_ALLOW_ORIGIN}") {
      set resp.http.Access-Control-Allow-Origin = req.http.Origin;
      set resp.http.Access-Control-Allow-Credentials = true;
  }
}
