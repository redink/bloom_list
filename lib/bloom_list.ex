defmodule BloomList do
  @moduledoc """
  Documentation for BloomList.
  """

  use GenServer

  @callback handle_maybe_exist(any, any) :: boolean()

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour BloomList
    end
  end

  def start_link(mod, data_list, options) do
    name = Keyword.fetch!(options, :name)
    GenServer.start_link(__MODULE__, {mod, data_list, options}, name: name)
  end

  def if_member(bloom_name, key, other) do
    case Bloomex.member?(lookup_bloom_ets(bloom_name, :bloom), key) do
      false -> false
      true -> apply(lookup_bloom_ets(bloom_name, :mod), :handle_maybe_exist, [key, other])
    end
  end

  def sync_if_member(bloom_name, key, other) do
    GenServer.call(bloom_name, {:if_member, key, other})
  end

  def add(bloom_name, key) do
    GenServer.call(bloom_name, {:add, key})
  end

  def init({mod, data_list, options}) do
    bloom_name = Keyword.fetch!(options, :name)
    bloom_ets = generate_ets_table_name(bloom_name)
    :ets.new(bloom_ets, [:named_table, :set, :public, {:read_concurrency, true}])

    bloom =
      options
      |> Keyword.get(:bloom_options, [])
      |> init_empty_bloom()
      |> batch_add_data(data_list)

    :ets.insert(bloom_ets, [{:bloom, bloom}, {:mod, mod}])
    {:ok, %{bloom: bloom, mod: mod, bloom_ets: bloom_ets}}
  end

  def handle_call({:if_member, key, other}, %{bloom: bloom, mod: mod} = state) do
    res =
      case Bloomex.member?(bloom, key) do
        false -> false
        true -> apply(mod, :handle_maybe_exist, [key, other])
      end

    {:reply, res, state}
  end

  def handle_call({:add, key}, %{bloom: bloom, bloom_ets: bloom_ets} = state) do
    new_bloom = Bloomex.add(bloom, key)
    :ets.insert(bloom_ets, {:bloom, new_bloom})
    {:reply, :ok, %{state | bloom: new_bloom}}
  end

  @doc false
  defp generate_ets_table_name(bloom_name) do
    String.to_atom("BloomList.#{bloom_name}")
  end

  @doc false
  defp init_empty_bloom(bloom_options) do
    capacity = Keyword.get(bloom_options, :capacity, 1000)
    error = Keyword.get(bloom_options, :error, 0.7)
    Bloomex.plain(capacity, error)
  end

  @doc false
  defp batch_add_data(bloom, data_list) do
    Enum.reduce(data_list, bloom, fn data, bloom -> Bloomex.add(bloom, data) end)
  end

  defp lookup_bloom_ets(bloom_name, ets_key) when ets_key in [:bloom, :mod] do
    [{_, value}] = :ets.lookup(generate_ets_table_name(bloom_name), ets_key)
    value
  end

  # __end_of_module__
end
