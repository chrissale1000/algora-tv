defmodule Algora.Storage do
  @behaviour Membrane.HTTPAdaptiveStream.Storage

  require Membrane.Logger
  alias Algora.Library

  @pubsub Algora.PubSub

  @enforce_keys [:video]
  defstruct @enforce_keys ++ [video_header: <<>>]

  @type t :: %__MODULE__{
          video: Library.Video.t(),
          video_header: <<>>
        }

  @impl true
  def init(%__MODULE__{} = config), do: config

  @impl true
  def store(
        parent_id,
        name,
        contents,
        metadata,
        ctx,
        %{video: video} = state
      ) do
    path = "#{video.uuid}/#{name}"

    with {:ok, _} <- upload(contents, path, upload_opts(ctx)),
         {:ok, state} <- process_contents(parent_id, name, contents, metadata, ctx, state) do
      {:ok, state}
    else
      {:error, reason} = err ->
        Membrane.Logger.error("Failed to upload #{path}: #{reason}")
        {err, state}
    end
  end

  defp upload_opts(%{type: :manifest} = _ctx) do
    [{:cache_control, "no-cache, no-store, private"}]
  end

  defp upload_opts(_ctx), do: []

  @impl true
  def remove(_parent_id, _name, _ctx, state) do
    {{:error, :not_implemented}, state}
  end

  defp process_contents(
         :video,
         _name,
         contents,
         _metadata,
         %{type: :header, mode: :binary},
         state
       ) do
    {:ok, %{state | video_header: contents}}
  end

  defp process_contents(
         :video,
         _name,
         contents,
         _metadata,
         %{type: :segment, mode: :binary},
         %{video: %{thumbnail_url: nil} = video, video_header: video_header} = state
       ) do
    case Library.store_thumbnail(video, video_header <> contents) do
      {:ok, video} ->
        broadcast_thumbnails_generated!(video)
        {:ok, %{state | video: video}}

      _ ->
        Membrane.Logger.error("Could not generate thumbnails for video #{video.id}")
        {:ok, state}
    end
  end

  defp process_contents(_parent_id, _name, _contents, _metadata, _ctx, state) do
    {:ok, state}
  end

  def upload_to_bucket(contents, remote_path, bucket, opts \\ []) do
    Algora.config([:buckets, bucket])
    |> ExAws.S3.put_object(remote_path, contents, opts)
    |> ExAws.request([])
  end

  def upload_from_filename_to_bucket(
        local_path,
        remote_path,
        bucket,
        cb \\ fn _ -> nil end,
        opts \\ []
      ) do
    %{size: size} = File.stat!(local_path)

    chunk_size = 5 * 1024 * 1024

    ExAws.S3.Upload.stream_file(local_path, [{:chunk_size, chunk_size}])
    |> Stream.map(fn chunk ->
      cb.(%{stage: :persisting, done: chunk_size, total: size})
      chunk
    end)
    |> ExAws.S3.upload(Algora.config([:buckets, bucket]), remote_path, opts)
    |> ExAws.request([])
  end

  def upload(contents, remote_path, opts \\ []) do
    upload_to_bucket(contents, remote_path, :media, opts)
  end

  def upload_from_filename(local_path, remote_path, cb \\ fn _ -> nil end, opts \\ []) do
    upload_from_filename_to_bucket(
      local_path,
      remote_path,
      :media,
      cb,
      opts
    )
  end

  def update_object!(bucket, object, opts) do
    bucket = Algora.config([:buckets, bucket])

    with {:ok, %{body: body}} <- ExAws.S3.get_object(bucket, object) |> ExAws.request(),
         {:ok, res} <- ExAws.S3.put_object(bucket, object, body, opts) |> ExAws.request() do
      res
    else
      err -> err
    end
  end

  defp broadcast!(topic, msg) do
    Phoenix.PubSub.broadcast!(@pubsub, topic, {__MODULE__, msg})
  end

  defp broadcast_thumbnails_generated!(video) do
    broadcast!(Library.topic_livestreams(), %Library.Events.ThumbnailsGenerated{video: video})
  end
end
