<?php

declare(strict_types=1);

$url = getenv('DATABASE_URL');
if (!$url) {
    echo "DATABASE_URL not set, skipping test DB setup\n";
    exit(0);
}

$parsed = parse_url($url);
if (!$parsed || empty($parsed['host'])) {
    echo "Could not parse DATABASE_URL, skipping test DB setup\n";
    exit(0);
}

$host = $parsed['host'];
$port = $parsed['port'] ?? 5432;
$dbname = ltrim($parsed['path'] ?? 'app', '/');
$user = $parsed['user'] ?? '';
$pass = $parsed['pass'] ?? '';

$dsn = "pgsql:host={$host};port={$port};dbname={$dbname}";

try {
    $pdo = new PDO($dsn, $user, $pass);
    $pdo->exec('CREATE EXTENSION IF NOT EXISTS citext;');
    echo "citext extension ready on {$dbname}\n";
} catch (PDOException $e) {
    echo "Warning: could not create citext extension: " . $e->getMessage() . "\n";
    exit(1);
}
