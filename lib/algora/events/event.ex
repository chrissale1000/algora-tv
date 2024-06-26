defmodule Algora.Events.Event do
  use Ecto.Schema
  import Ecto.Changeset

  schema "events" do
    field :actor_id, :string
    field :user_id, :integer
    field :video_id, :integer
    field :channel_id, :integer
    field :show_id, :integer
    field :user_handle, :string, virtual: true
    field :user_display_name, :string, virtual: true
    field :user_email, :string, virtual: true
    field :user_avatar_url, :string, virtual: true
    field :user_github_handle, :string, virtual: true
    field :user_meta, :string, virtual: true
    field :first_video_id, :integer, virtual: true
    field :first_video_title, :string, virtual: true
    field :name, Ecto.Enum, values: [:subscribed, :unsubscribed, :watched, :rsvpd, :unrsvpd]

    timestamps()
  end

  def changeset(event, attrs) do
    event
    |> cast(attrs, [:actor_id, :user_id, :video_id, :channel_id, :name])
    |> validate_required([:actor_id, :name])
  end
end
