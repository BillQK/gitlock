defmodule GitlockWorkflows.Port do
  @moduledoc """
  A typed input or output slot on a workflow node.

  Ports define the data contract between nodes. An edge can only connect
  an output port to an input port with a compatible data type.

  ## Type hierarchy

      :commits ─────────────────────┐
      :hotspots ──┐                 │
      :couplings ─┤                 │
      :knowledge_silos ─┤           │
      :code_age ─────────┼→ :analysis_result ──→ :any
      :blast_radius ─────┤
      :coupled_hotspots ─┤
      :summary ──────────┘

  Logic and transform nodes use `:analysis_result` or `:any` for maximum flexibility.
  """

  @type data_type ::
          :commits
          | :hotspots
          | :couplings
          | :knowledge_silos
          | :code_age
          | :blast_radius
          | :coupled_hotspots
          | :complexity_trends
          | :summary
          | :analysis_result
          | :boolean
          | :any
          | :text

  @type t :: %__MODULE__{
          id: String.t(),
          name: String.t(),
          data_type: data_type(),
          optional: boolean()
        }

  @enforce_keys [:id, :name, :data_type]
  defstruct [:id, :name, :data_type, optional: false]

  @analysis_subtypes [
    :hotspots,
    :couplings,
    :knowledge_silos,
    :code_age,
    :blast_radius,
    :coupled_hotspots,
    :complexity_trends,
    :summary
  ]

  @doc "Creates a new port with a generated id."
  @spec new(String.t(), data_type(), keyword()) :: t()
  def new(name, data_type, opts \\ []) do
    %__MODULE__{
      id: gen_id(),
      name: name,
      data_type: data_type,
      optional: Keyword.get(opts, :optional, false)
    }
  end

  @doc """
  Checks whether an output port's type is compatible with an input port's type.

  Compatibility rules (in priority order):
  1. Exact match is always compatible
  2. `:any` input accepts everything
  3. Analysis subtypes are compatible with `:analysis_result`
  4. `:analysis_result` output is compatible with `:any`
  """
  @spec compatible?(t(), t()) :: boolean()
  def compatible?(%__MODULE__{data_type: same}, %__MODULE__{data_type: same}), do: true

  # :any accepts everything
  def compatible?(%__MODULE__{}, %__MODULE__{data_type: :any}), do: true

  # Analysis subtypes → :analysis_result
  def compatible?(%__MODULE__{data_type: source_type}, %__MODULE__{data_type: :analysis_result})
      when source_type in @analysis_subtypes,
      do: true

  def compatible?(_, _), do: false

  @doc "Returns the list of analysis subtype atoms."
  @spec analysis_subtypes() :: [data_type()]
  def analysis_subtypes, do: @analysis_subtypes

  defp gen_id, do: :crypto.strong_rand_bytes(8) |> Base.encode16(case: :lower)
end
