use Mix.Config

config :logger, :console,
  format: "[$level]$message | $metadata\n",
  metadata: [:pid],
  level: :none
