defmodule GitlockPhx.Repo do
  use Ecto.Repo,
    otp_app: :gitlock_phx,
    adapter: Ecto.Adapters.Postgres
end
