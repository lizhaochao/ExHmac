use Mix.Config

config :logger, :console,
  format: "$time [$level]$message | $metadata\n",
  metadata: [:pid],
  level: :debug

# the 2 following configs should set 2 places.
config :exhmac, :precision, :millisecond
config :exhmac, :nonce_freezing_secs, 60
# normal
config :exhmac, :gc_interval_milli, 20_000
config :exhmac, :gc_warn_count, 10
config :exhmac, :disable_noncer, false
config :exhmac, :log, false
