defmodule BloomList do
  @moduledoc """
  Documentation for BloomList.
  """

  use GenServer

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour BloomList

      def handle_maybe_exist(_, _) do
        true
      end

      def handle_add_single(_, state) do
        state
      end

      def handle_add_list(_, state) do
        state
      end

      def handle_delete(_, state) do
        state
      end

      defoverridable handle_maybe_exist: 2,
                     handle_add_single: 2,
                     handle_add_list: 2,
                     handle_delete: 2
    end
  end

  def start_link(mod, args, options) do
    name = Keyword.fetch!(options, :name)
    GenServer.start_link(__MODULE__, {mod, options, args}, name: name)
  end

  def reinit_bloom_data(bloom_name, data_list) do
    GenServer.call(bloom_name, {:reinit_bloom_data, data_list})
  end

  def member?(bloom_name, key) do
    bloom_ets_list = :ets.tab2list(generate_ets_table_name(bloom_name))
    mod = Keyword.get(bloom_ets_list, :mod)
    custom_state = Keyword.get(bloom_ets_list, :custom_state)

    Bloomex.member?(Keyword.get(bloom_ets_list, :bloom), key) and
      apply(mod, :handle_maybe_exist, [key, custom_state])
  end

  def sync_member?(bloom_name, key) do
    GenServer.call(bloom_name, {:member?, key})
  end

  def add(bloom_name, key) do
    GenServer.call(bloom_name, {:add, key})
  end

  def add_list(bloom_name, key_list) do
    GenServer.call(bloom_name, {:add_list, key_list})
  end

  def delete(bloom_name, key) do
    GenServer.call(bloom_name, {:delete, key})
  end

  def init({mod, options, args}) do
    bloom_name = Keyword.fetch!(options, :name)
    bloom_options = Keyword.get(options, :bloom_options, [])
    bloom_ets = generate_ets_table_name(bloom_name)
    :ets.new(bloom_ets, [:named_table, :set, :public, {:read_concurrency, true}])
    {data_list, custom_state} = mod.init_bloom_data(args)

    bloom =
      bloom_options
      |> init_empty_bloom()
      |> batch_add_data(data_list)

    :ets.insert(bloom_ets, [{:bloom, bloom}, {:mod, mod}, {:custom_state, custom_state}])

    {:ok,
     %{
       bloom: bloom,
       mod: mod,
       bloom_ets: bloom_ets,
       custom_state: custom_state,
       bloom_options: bloom_options
     }}
  end

  def handle_call(
        {:reinit_bloom_data, data_list},
        _from,
        %{bloom_ets: bloom_ets, mod: mod, bloom_options: bloom_options} = state
      ) do
    {data_list, custom_state} = mod.handle_reinit_bloom_data(data_list)

    bloom =
      bloom_options
      |> init_empty_bloom()
      |> batch_add_data(data_list)

    :ets.insert(bloom_ets, [{:bloom, bloom}, {:custom_state, custom_state}])
    {:reply, :ok, %{state | bloom: bloom, custom_state: custom_state}}
  end

  def handle_call(
        {:member?, key},
        _from,
        %{bloom: bloom, mod: mod, custom_state: custom_state} = state
      ) do
    res = Bloomex.member?(bloom, key) and apply(mod, :handle_maybe_exist, [key, custom_state])
    {:reply, res, state}
  end

  def handle_call(
        {:delete, key},
        _from,
        %{bloom_ets: bloom_ets, custom_state: custom_state, mod: mod} = state
      ) do
    new_custom_state = mod.handle_delete(key, custom_state)
    :ets.insert(bloom_ets, {:custom_state, new_custom_state})
    {:reply, :ok, %{state | custom_state: new_custom_state}}
  end

  def handle_call(
        {:add, key},
        _from,
        %{bloom: bloom, bloom_ets: bloom_ets, custom_state: custom_state, mod: mod} = state
      ) do
    new_bloom = Bloomex.add(bloom, key)
    new_custom_state = mod.handle_add_single(key, custom_state)
    :ets.insert(bloom_ets, [{:bloom, new_bloom}, {:custom_state, new_custom_state}])
    {:reply, :ok, %{state | bloom: new_bloom, custom_state: new_custom_state}}
  end

  def handle_call(
        {:add_list, key_list},
        _from,
        %{bloom: bloom, bloom_ets: bloom_ets, custom_state: custom_state, mod: mod} = state
      ) do
    new_bloom = batch_add_data(bloom, key_list)
    new_custom_state = mod.handle_add_list(key_list, custom_state)
    :ets.insert(bloom_ets, [{:bloom, new_bloom}, {:custom_state, new_custom_state}])
    {:reply, :ok, %{state | bloom: new_bloom, custom_state: new_custom_state}}
  end

  @doc false
  defp generate_ets_table_name(bloom_name) do
    String.to_atom("BloomList.#{bloom_name}")
  end

  @doc false
  defp init_empty_bloom(bloom_options) do
    capacity = Keyword.get(bloom_options, :capacity, 1000)
    error = Keyword.get(bloom_options, :error, 0.3)
    Bloomex.plain(capacity, error)
  end

  @doc false
  defp batch_add_data(bloom, data_list) do
    Enum.reduce(data_list, bloom, fn data, bloom -> Bloomex.add(bloom, data) end)
  end

  @callback handle_maybe_exist(any, any) :: boolean()

  @callback init_bloom_data([any]) :: {[any], any}

  @callback handle_reinit_bloom_data([any]) :: {[any], any}

  @callback handle_add_single(any, any) :: any

  @callback handle_add_list([any], any) :: any

  @callback handle_delete(any, any) :: any

  # __end_of_module__
end
