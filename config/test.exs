use Mix.Config

config :logger, :console,
  format: "$time [$level]$message | $metadata\n",
  metadata: [:pid],
  level: :none
