defmodule BloomList do
  @moduledoc """
  A behaviour for implementing bloomfilter module.

  The `BloomList` behaviour is a implementation of the `GenServer` behaviour which
  will keep the bloomfilter in state of `GenServer`. Support some bloomfilter operations:

    * initialize: initial bloomfilter through call `init_bloom_data` callback
    * add: add `key(s)` to bloomfilter, and call `handle_add_single` or `handle_add_list`
    * delete: only call `handle_delete` callback rather than delete `key` from bloomfilter

  As we know, bloomfilter only can check one key `must not exist`, can't ensure one key must
  exist. So, if return `true` from bloomfilter through `member?` function, the `BloomList`
  can not return `true` directly to caller. Thus, `BloomList` will call `handle_maybe_exist`
  callback function to double check if the key really in bloomlist.

  An example `BloomList` module:

      defmodule BloomList.Test.BlackList do
        @moduledoc false

        use BloomList

        def start_link(_) do
          BloomList.start_link(__MODULE__, nil,
            name: __MODULE__,
            bloom_options: [capacity: 2000, error: 0.7]
          )
        end

        def reinit(data_list \\ []) do
          BloomList.reinit_bloom_data(__MODULE__, data_list)
        end

        def add(key) do
          BloomList.add(__MODULE__, key)
        end

        def add_list(key_list) do
          BloomList.add_list(__MODULE__, key_list)
        end

        def delete(key) do
          BloomList.delete(__MODULE__, key)
        end

        def member?(key) do
          BloomList.member?(__MODULE__, key)
        end

        # callback
        def init_bloom_data(_) do
          data_list = [1, 2, 3, 4, 5]
          {data_list, %{data_list: data_list}}
        end

        # callback
        def handle_reinit_bloom_data([], _) do
          data_list = [2, 3, 4, 5, 6, 7]
          {data_list, %{data_list: data_list}}
        end

        def handle_reinit_bloom_data(data_list, _) do
          {data_list, %{data_list: data_list}}
        end

        # callback
        def handle_maybe_exist(key, %{data_list: data_list}) do
          Enum.member?(data_list, key)
        end

        # callback
        def handle_delete(key, %{data_list: data_list} = state) do
          %{state | data_list: List.delete(data_list, key)}
        end

        # callback
        def handle_add_single(key, %{data_list: data_list} = state) do
          %{state | data_list: [key | data_list]}
        end

        # callback
        def handle_add_list(key_list, %{data_list: data_list} = state) do
          %{state | data_list: key_list ++ data_list}
        end

        # __end_of_module__
      end

  The example above realized a `blacklist` module which follows a common pattern.
  """

  use GenServer

  @doc """
  Called when the bloomlist first started. The params for this callback is passed from
  `start_link/3`.

  Returning `{[any], any}` the first element is a list, which will be put into bloomfilter
  as members to inital bloomfilter. And the second element is the custom state.
  """
  @callback init_bloom_data(any) :: {[any], any}

  @doc """
  Called the the bloomlist want to reinit bloomfilter members. The first param for this
  function is `data_list` which from the second param of `reinit_bloom_data/2`.

      def reinit_bloom_data(bloom_name, data_list) do
        GenServer.call(bloom_name, {:reinit_bloom_data, data_list})
      end

  As the above function, the `data_list` will be passed to `handle_reinit_bloom_data/2`
  callback as first param.

  The second param is the custom state.


  Returning `{[any], any}` is the new bloomfilter data and new custom state.
  """
  @callback handle_reinit_bloom_data([any], any) :: {[any], any}

  @doc """
  Called after get `true` when check one key if member of bloomfilter. The first param is
  the key from `member?/2` and the second one is the custom state.

  Returning the boolean value.
  """
  @callback handle_maybe_exist(any, any) :: boolean()

  @doc """
  Called when add single key to bloomlist. The first param is the new key to add, and the
  second one is custom state.

  Returning the new custom state.
  """
  @callback handle_add_single(any, any) :: any

  @doc """
  Called when add a key list to bloomlist. The first param is the key list to add, and
  second one is the custom state.

  Returning the new custom state.
  """
  @callback handle_add_list([any], any) :: any

  @doc """
  Called when delete one key from bloomlist. `bloomfilter` not supported delete operation
  this callback just only for the bloomlist to update custom state.

  Returning the new custom state.
  """
  @callback handle_delete(any, any) :: any

  defmacro __using__(_) do
    quote location: :keep do
      @behaviour BloomList

      @doc false
      def child_spec(opts) do
        %{
          id: __MODULE__,
          start: {__MODULE__, :start_link, [opts]},
          type: :worker,
          restart: :permanent,
          shutdown: 5000
        }
      end

      @doc false
      def handle_reinit_bloom_data(data_list, state) do
        {data_list, state}
      end

      @doc false
      def handle_maybe_exist(_, _) do
        true
      end

      @doc false
      def handle_add_single(_, state) do
        state
      end

      @doc false
      def handle_add_list(_, state) do
        state
      end

      @doc false
      def handle_delete(_, state) do
        state
      end

      defoverridable handle_maybe_exist: 2,
                     handle_add_single: 2,
                     handle_add_list: 2,
                     handle_delete: 2,
                     handle_reinit_bloom_data: 2,
                     child_spec: 1
    end
  end

  @doc """
  Start a bloomlist process linked to the current process.

  This function is used to start a `BloomList` process in a supervision tree,
  which will execute `GenServer.start_link/3` to start one real `GenServer`
  process.Then the init/1 callback for `GenServer` in this module will be
  executed and will keep one bloomfilter data block in its state.

  When `init/1` callback in this module execute, the `init_bloom_data/1`
  function in callback module will be executed.
  """
  @spec start_link(module, any, Keyword.t()) :: GenServer.on_start()
  def start_link(mod, args, options) do
    name = Keyword.fetch!(options, :name)
    GenServer.start_link(__MODULE__, {mod, options, args}, name: name)
  end

  @doc """
  Reinit bloom data for one bloomlist.
  """
  @spec reinit_bloom_data(atom, [any]) :: :ok
  def reinit_bloom_data(bloom_name, data_list) do
    GenServer.call(bloom_name, {:reinit_bloom_data, data_list})
  end

  @doc """
  Check the key if member bloomlist.
  """
  @spec member?(atom, any) :: boolean()
  def member?(bloom_name, key) do
    bloom_ets_list = :ets.tab2list(generate_ets_table_name(bloom_name))
    mod = Keyword.get(bloom_ets_list, :mod)
    custom_state = Keyword.get(bloom_ets_list, :custom_state)

    Bloomex.member?(Keyword.get(bloom_ets_list, :bloom), key) and
      apply(mod, :handle_maybe_exist, [key, custom_state])
  end

  @doc """
  Check the key if member bloomlist using sync mode, it will execute by
  `GenServer` process serially.
  """
  @spec sync_member?(atom, any) :: boolean()
  def sync_member?(bloom_name, key) do
    GenServer.call(bloom_name, {:member?, key})
  end

  @doc """
  Add one key to bloomlist.
  """
  @spec add(atom, any) :: :ok
  def add(bloom_name, key) do
    GenServer.call(bloom_name, {:add, key})
  end

  @doc """
  Add key list to bloomlist.
  """
  @spec add_list(atom, [any]) :: :ok
  def add_list(bloom_name, key_list) do
    GenServer.call(bloom_name, {:add_list, key_list})
  end

  @doc """
  Delete key from bloomlist.
  """
  @spec delete(atom, any) :: :ok
  def delete(bloom_name, key) do
    GenServer.call(bloom_name, {:delete, key})
  end

  @doc false
  def init({mod, options, args}) do
    bloom_name = Keyword.fetch!(options, :name)
    bloom_options = Keyword.get(options, :bloom_options, [])
    bloom_ets = generate_ets_table_name(bloom_name)
    _ = :ets.new(bloom_ets, [:named_table, :set, :public, {:read_concurrency, true}])
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

  @doc false
  def handle_call(
        {:reinit_bloom_data, data_list},
        _from,
        %{
          bloom_ets: bloom_ets,
          mod: mod,
          bloom_options: bloom_options,
          custom_state: custom_state
        } = state
      ) do
    {data_list, custom_state} = mod.handle_reinit_bloom_data(data_list, custom_state)

    bloom =
      bloom_options
      |> init_empty_bloom()
      |> batch_add_data(data_list)

    :ets.insert(bloom_ets, [{:bloom, bloom}, {:custom_state, custom_state}])
    {:reply, :ok, %{state | bloom: bloom, custom_state: custom_state}}
  end

  @doc false
  def handle_call(
        {:member?, key},
        _from,
        %{bloom: bloom, mod: mod, custom_state: custom_state} = state
      ) do
    res = Bloomex.member?(bloom, key) and apply(mod, :handle_maybe_exist, [key, custom_state])
    {:reply, res, state}
  end

  @doc false
  def handle_call(
        {:delete, key},
        _from,
        %{bloom_ets: bloom_ets, custom_state: custom_state, mod: mod} = state
      ) do
    new_custom_state = mod.handle_delete(key, custom_state)
    :ets.insert(bloom_ets, {:custom_state, new_custom_state})
    {:reply, :ok, %{state | custom_state: new_custom_state}}
  end

  @doc false
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

  @doc false
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

  # __end_of_module__
end
