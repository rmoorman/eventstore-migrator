defmodule EventStore.Migrator.StorageCase do
  use ExUnit.CaseTemplate

  alias EventStore.Storage

  setup do
    Application.stop(:eventstore)
    reset_storage()
    Application.ensure_all_started(:eventstore)

    :ok
  end

  defp reset_storage do
    storage_config = Application.get_env(:eventstore, Storage)

    {:ok, conn} = Postgrex.start_link(storage_config)

    Storage.Initializer.reset!(conn)
  end
end
