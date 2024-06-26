import Ecto.Query
import Ecto.Changeset

alias Algora.{Admin, Accounts, Library, Repo, Storage, Cache, ML, Shows}

IEx.configure(inspect: [charlists: :as_lists])

if Code.ensure_loaded?(ExSync) && function_exported?(ExSync, :register_group_leader, 0) do
  ExSync.register_group_leader()
end
