# Sourced by docker-entrypoint.sh. Single-server production (compose.prod.yaml, #207): compose can't escape or anchor,
# so the host settings are built here from SITE_HOST and SITE_ALIASES, as k8s.sh's apply_site_defaults builds them.
# A non-empty TRUSTED_HOSTS, CORS_ALLOW_ORIGIN or MERCURE_CORS_ORIGIN wins. Kubernetes sets all three, so it's a no-op there.
cwa_site_host_defaults() {
	[ -n "${SITE_HOST:-}" ] || return 0
	_cwa_alt=""
	_cwa_origins=""
	# SITE_ALIASES is space-separated (Caddy refuses "a,b" in SERVER_NAME); commas are tolerated here.
	for _cwa_host in $(printf '%s %s' "$SITE_HOST" "${SITE_ALIASES:-}" | tr ',' ' '); do
		case "$_cwa_host" in
			*[!A-Za-z0-9.-]*|.*|*.)
				echo "SITE_HOST and SITE_ALIASES must be host names without a scheme or port, not '$_cwa_host'." >&2
				return 1
				;;
		esac
		_cwa_alt="${_cwa_alt:+$_cwa_alt|}$(printf '%s' "$_cwa_host" | sed 's/[.]/\\./g')"
		_cwa_origins="${_cwa_origins:+$_cwa_origins }https://$_cwa_host"
	done
	[ -n "${TRUSTED_HOSTS:-}" ] || TRUSTED_HOSTS="^(?:$_cwa_alt|localhost)\$"
	[ -n "${CORS_ALLOW_ORIGIN:-}" ] || CORS_ALLOW_ORIGIN="^https://(?:$_cwa_alt)\$"
	[ -n "${MERCURE_CORS_ORIGIN:-}" ] || MERCURE_CORS_ORIGIN="$_cwa_origins"
	export TRUSTED_HOSTS CORS_ALLOW_ORIGIN MERCURE_CORS_ORIGIN
	unset _cwa_alt _cwa_origins _cwa_host
}
