use Mix.Config

config :exhmac, :nonce_ttl_secs, 900
config :exhmac, :timestamp_offset_secs, 900

config :logger, :console,
  format: "[$level]$message | $metadata\n",
  metadata: [:pid],
  level: :none
