defmodule SymphonyElixir.Issue do
  @moduledoc """
  Normalized issue representation used by the orchestrator.

  Tracker adapters should return this shape, or a compatible struct/map with the
  same fields. `SymphonyElixir.Linear.Issue` remains supported for backwards
  compatibility with the original Linear implementation.
  """

  defstruct [
    :id,
    :identifier,
    :title,
    :description,
    :priority,
    :state,
    :branch_name,
    :url,
    :assignee_id,
    blocked_by: [],
    labels: [],
    assigned_to_worker: true,
    created_at: nil,
    updated_at: nil
  ]

  @type t :: %__MODULE__{
          id: String.t() | nil,
          identifier: String.t() | nil,
          title: String.t() | nil,
          description: String.t() | nil,
          priority: integer() | nil,
          state: String.t() | nil,
          branch_name: String.t() | nil,
          url: String.t() | nil,
          assignee_id: String.t() | nil,
          labels: [String.t()],
          assigned_to_worker: boolean(),
          created_at: DateTime.t() | nil,
          updated_at: DateTime.t() | nil
        }

  @spec label_names(t() | map()) :: [String.t()]
  def label_names(%{labels: labels}) when is_list(labels), do: labels
  def label_names(_issue), do: []
end
