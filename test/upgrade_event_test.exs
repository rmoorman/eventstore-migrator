defmodule EventStore.Migrator.UpgradeEventTest do
  use EventStore.Migrator.StorageCase

  alias EventStore.Migrator.EventFactory

  defmodule OriginalEvent, do: defstruct [uuid: nil]
  defmodule UpgradedEvent, do: defstruct [uuid: nil, additional: nil]
  defmodule AnotherEvent, do: defstruct [uuid: nil]

  describe "upgrade an event" do
    setup [:append_events, :migrate]

    test "should upgrade only matching events" do
      {:ok, events} = EventStore.Migrator.Reader.read_migrated_events()

      assert length(events) == 3
      assert pluck(events, :event_id) == [1, 2, 3]
      assert pluck(events, :stream_version) == [1, 2, 3]
      assert pluck(events, :event_type) == [
        "#{__MODULE__}.AnotherEvent",
        "#{__MODULE__}.UpgradedEvent",
        "#{__MODULE__}.AnotherEvent"
      ]
      assert Enum.at(events, 1).data == String.trim("""
{\"uuid\":2,\"additional\":\"upgraded\"}
""")
    end

    test "should copy stream", context do
      {:ok, stream_id, stream_version} = EventStore.Migrator.Reader.stream_info(context[:stream_uuid])

      assert stream_id == 1
      assert stream_version == 3
    end
  end

  defp migrate(context) do
    EventStore.Migrator.migrate(fn stream ->
      Stream.map(
        stream,
        fn (event) ->
          case event.data do
            %OriginalEvent{uuid: uuid} ->
              %EventStore.RecordedEvent{event |
                event_type: "#{__MODULE__}.UpgradedEvent",
                data: %UpgradedEvent{uuid: uuid, additional: "upgraded"},
              }
            _ -> event
          end
        end
      )
    end)

    context
  end

  defp append_events(_context) do
    stream_uuid = UUID.uuid4()

    events = EventFactory.to_event_data([
      %AnotherEvent{uuid: 1},
      %OriginalEvent{uuid: 2},
      %AnotherEvent{uuid: 3}
    ])

    EventStore.append_to_stream(stream_uuid, 0, events)

    [stream_uuid: stream_uuid]
  end

  def pluck(enumerable, field) do
    Enum.map(enumerable, &Map.get(&1, field))
  end
end
