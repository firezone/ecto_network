defmodule EctoNetwork.INET do
  @moduledoc ~S"""
  Support for using Ecto with `:inet` fields.
  """

  @behaviour Ecto.Type

  def type, do: :inet

  @doc "Handle embedding format for CIDR records."
  def embed_as(_), do: :self

  @doc "Handle equality testing for CIDR records."
  def equal?(left, right), do: left == right

  @doc "Handle casting to Postgrex.INET."
  def cast(%Postgrex.INET{} = address), do: {:ok, address}

  def cast(address) when is_tuple(address),
    do: cast(%Postgrex.INET{address: address, netmask: nil})

  def cast(address) when is_binary(address) do
    {address, netmask} =
      case String.split(address, "/") do
        [address] -> {address, nil}
        [address, netmask] -> {address, netmask}
        [address, netmask | _] -> {address, netmask}
      end

    parsed_address =
      address
      |> String.trim()
      |> String.to_charlist()
      |> :inet.parse_address()

    parsed_netmask = cast_netmask(netmask, parsed_address)

    case [parsed_address, parsed_netmask] do
      [_address_result, :error] ->
        :error

      [{:ok, address}, {netmask, ""}] ->
        {:ok, %Postgrex.INET{address: address, netmask: netmask}}

      _ ->
        :error
    end
  end

  def cast(_), do: :error

  @doc "Load from the native Ecto representation."
  def load(%Postgrex.INET{} = inet) do
    {:ok, inet}
  end

  def load(_), do: :error

  @doc "Convert to the native Ecto representation."
  def dump(%Postgrex.INET{} = inet) do
    {:ok, inet}
  end

  def dump(_), do: :error

  @doc "Convert from native Ecto representation to a binary."
  def decode(%Postgrex.INET{address: address, netmask: netmask}) do
    address
    |> :inet.ntoa()
    |> case do
      {:error, _} ->
        :error

      address ->
        address = List.to_string(address)
        if netmask, do: "#{address}/#{netmask}", else: address
    end
  end

  defp cast_netmask(mask, _address) when is_binary(mask) do
    mask
    |> String.trim()
    |> Integer.parse()
  end

  defp cast_netmask(nil, {:ok, _address}) do
    {nil, ""}
  end

  defp cast_netmask(_mask, _address), do: :error
end

defimpl String.Chars, for: Postgrex.INET do
  def to_string(%Postgrex.INET{} = address), do: EctoNetwork.INET.decode(address)
end

if Code.ensure_loaded?(Phoenix.HTML) do
  defimpl Phoenix.HTML.Safe, for: Postgrex.INET do
    def to_iodata(%Postgrex.INET{} = address), do: EctoNetwork.INET.decode(address)
  end
end
