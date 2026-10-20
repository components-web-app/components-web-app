<?php

declare(strict_types=1);

namespace App\RedisWatch;

/**
 * A minimal Redis client (RESP2 over a socket) for the Redis watch job (#85): the php image has no redis extension,
 * and the job needs only AUTH, INFO and FLUSHDB.
 */
final class RespConnection
{
    /**
     * @param resource $stream
     */
    public function __construct(private $stream)
    {
    }

    /**
     * Connects to host:port and authenticates when a password is given.
     *
     * @throws RedisUnavailable
     */
    public static function open(string $address, string $password, float $timeout): self
    {
        $errno = 0;
        $errstr = '';
        $stream = @stream_socket_client('tcp://'.$address, $errno, $errstr, $timeout);
        if (false === $stream) {
            throw new RedisUnavailable(\sprintf('could not connect to %s: %s', $address, '' !== $errstr ? $errstr : 'error '.$errno));
        }
        $seconds = (int) $timeout;
        stream_set_timeout($stream, $seconds, (int) (($timeout - $seconds) * 1_000_000));

        $connection = new self($stream);
        if ('' !== $password) {
            $connection->command('AUTH', $password);
        }

        return $connection;
    }

    /**
     * @return string|int|list<mixed>|null
     *
     * @throws RedisUnavailable on a connection failure or an error reply
     */
    public function command(string ...$args): string|int|array|null
    {
        $request = '*'.\count($args)."\r\n";
        foreach ($args as $arg) {
            $request .= '$'.\strlen($arg)."\r\n".$arg."\r\n";
        }
        $written = @fwrite($this->stream, $request);
        if (false === $written || $written < \strlen($request)) {
            throw new RedisUnavailable('could not send to Redis');
        }

        return $this->reply();
    }

    public function close(): void
    {
        if (\is_resource($this->stream)) {
            fclose($this->stream);
        }
    }

    /**
     * @return string|int|list<mixed>|null
     */
    private function reply(): string|int|array|null
    {
        $line = $this->line();
        $payload = substr($line, 1);

        switch ($line[0]) {
            case '+':
                return $payload;
            case '-':
                // The reply's first word only: an AUTH error must never echo anything secret into a log or an email.
                throw new RedisUnavailable('Redis answered '.strtok($payload, ' '));
            case ':':
                return (int) $payload;
            case '$':
                $length = (int) $payload;
                if ($length < 0) {
                    return null;
                }

                return substr($this->read($length + 2), 0, $length);
            case '*':
                $count = (int) $payload;
                if ($count < 0) {
                    return null;
                }
                $items = [];
                for ($i = 0; $i < $count; ++$i) {
                    $items[] = $this->reply();
                }

                return $items;
        }

        throw new RedisUnavailable('Redis sent an unexpected reply');
    }

    private function line(): string
    {
        $line = fgets($this->stream);
        if (false === $line || '' === $line) {
            throw new RedisUnavailable($this->timedOut() ? 'Redis did not answer in time' : 'Redis closed the connection');
        }

        return rtrim($line, "\r\n");
    }

    private function read(int $length): string
    {
        $data = '';
        while (\strlen($data) < $length) {
            $chunk = fread($this->stream, $length - \strlen($data));
            if (false === $chunk || '' === $chunk) {
                throw new RedisUnavailable($this->timedOut() ? 'Redis did not answer in time' : 'Redis closed the connection');
            }
            $data .= $chunk;
        }

        return $data;
    }

    private function timedOut(): bool
    {
        return (bool) (stream_get_meta_data($this->stream)['timed_out'] ?? false);
    }
}
