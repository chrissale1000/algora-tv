defmodule Algora.Repo.Migrations.CreateShows do
  use Ecto.Migration

  def change do
    create table(:shows) do
      add :title, :string, null: false
      add :description, :string
      add :slug, :citext, null: false
      add :scheduled_for, :naive_datetime
      add :image_url, :string
      add :og_image_url, :string
      add :url, :string
      add :user_id, references(:users, on_delete: :nothing)

      timestamps()
    end

    alter table(:events) do
      add :show_id, references(:shows)
    end

    alter table(:videos) do
      add :show_id, references(:shows)
    end

    alter table(:users) do
      add :twitter_url, :string
    end

    create unique_index(:shows, [:slug])
    create index(:shows, [:user_id])
    create index(:events, [:show_id])
    create index(:videos, [:show_id])
  end
end
