use Mix.Config

config :exhmac, :nonce_ttl, 900
config :exhmac, :timestamp_offset, 900

config :logger, :console,
  format: "[$level]$message | $metadata\n",
  metadata: [:pid],
  level: :none
