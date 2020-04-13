defmodule Seraph.Test.UserToPost.Wrote do
  use Seraph.Schema.Relationship
  import Seraph.Changeset

  relationship "WROTE" do
    start_node Seraph.Test.User
    end_node Seraph.Test.Post

    property :at, :utc_datetime
  end

  def changeset(wrote, params \\ %{}) do
    wrote
    |> cast(params, [:start_node, :end_node, :at])
  end
end

defmodule Seraph.Test.User do
  use Seraph.Schema.Node
  import Seraph.Changeset

  node "User" do
    property :firstName, :string
    property :lastName, :string
    property :viewCount, :integer, default: 1

    outgoing_relationship "WROTE", Seraph.Test.Post, :posts, through: Seraph.Test.UserToPost.Wrote

    outgoing_relationship "READ", Seraph.Test.Post, :read_posts
    outgoing_relationship "FOLLOWS", Seraph.Test.User, :followeds

    incoming_relationship "EDITED_BY", Seraph.Test.Post, :edited_posts
    incoming_relationship "FOLLOWED", Seraph.Test.User, :followers

    @spec changeset(Seraph.Schema.Node.t(), map) :: Seraph.Changeset.t()
    def changeset(user, params \\ %{}) do
      user
      |> cast(params, [:firstName, :lastName, :viewCount, :additionalLabels])

      # |> cast_relationship("WROTE", params[:new_post])
      # |> cast_relationship(Seraph.Test.UserToPost.Wrote, params[:new_post], params[:rel_data])
      # |> put_related_nodes(:wrote, [])
    end

    def update_viewcount_changeset(user, params \\ %{}) do
      user
      |> cast(params, [:viewCount])
    end
  end
end

defmodule Seraph.Test.Post do
  use Seraph.Schema.Node
  import Seraph.Changeset

  node "Post" do
    property :title, :string
    property :text, :string
  end

  def changeset(post, params \\ %{}) do
    post
    |> cast(params, [:title, :text])
  end
end
