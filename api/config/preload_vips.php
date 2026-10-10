<?php

// vips_init isn't thread-safe: run it once here, before FrankenPHP starts its threads, or the first concurrent images segfault (#141).
if (\extension_loaded('ffi')) {
    try {
        \FFI::cdef('int vips_init(const char *argv0);', 'libvips.so.42')->vips_init('');
    } catch (\FFI\Exception) {
    }
}
