use Mix.Config

config :exhmac, :nonce_ttl_secs, 60
config :exhmac, :timestamp_offset_secs, 60
config :exhmac, :collect_interval_milli, 20_000
config :exhmac, :gc_should_warn_count, 10
config :exhmac, :disable_noncer, true

config :logger, :console,
  format: "$time [$level]$message | $metadata\n",
  metadata: [:pid],
  level: :debug
