use Mix.Config

config :logger, :console,
  format: "$time [$level]$message | $metadata\n",
  metadata: [:pid],
  level: :debug

config :exhmac, :nonce_ttl_secs, 60
config :exhmac, :timestamp_offset_secs, 60
config :exhmac, :gc_interval_milli, 20_000
config :exhmac, :gc_warn_count, 10
config :exhmac, :disable_noncer, false
config :exhmac, :gc_log_callback, &MyHmac.gc_log/1
