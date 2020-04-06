defmodule Neo4jex.Test.UserToPost.Wrote do
  use Neo4jex.Schema.Relationship
  import Neo4jex.Changeset

  relationship "WROTE" do
    start_node Neo4jex.Test.User
    end_node Neo4jex.Test.Post

    property :at, :utc_datetime
  end

  def changeset(wrote, params \\ %{}) do
    wrote
    |> cast(params, [:start_node, :end_node, :at])
  end
end

defmodule Neo4jex.Test.User do
  use Neo4jex.Schema.Node
  import Neo4jex.Changeset

  node "User" do
    property :firstName, :string
    property :lastName, :string
    property :viewCount, :integer, default: 1

    outgoing_relationship "WROTE", Neo4jex.Test.Post, :posts,
      through: Neo4jex.Test.UserToPost.Wrote

    outgoing_relationship "READ", Neo4jex.Test.Post, :read_posts
    outgoing_relationship "FOLLOWS", Neo4jex.Test.User, :followeds

    incoming_relationship "EDITED_BY", Neo4jex.Test.Post, :edited_posts
    incoming_relationship "FOLLOWED", Neo4jex.Test.User, :followers

    @spec changeset(Neo4jex.Schema.Node.t(), map) :: Ecto.Changeset.t()
    def changeset(user, params \\ %{}) do
      user
      |> cast(params, [:firstName, :lastName, :viewCount, :additionalLabels])

      # |> cast_relationship("WROTE", params[:new_post])
      # |> cast_relationship(Neo4jex.Test.UserToPost.Wrote, params[:new_post], params[:rel_data])
      # |> put_related_nodes(:wrote, [])
    end

    def update_viewcount_changeset(user, params \\ %{}) do
      user
      |> cast(params, [:viewCount])
    end
  end
end

defmodule Neo4jex.Test.Post do
  use Neo4jex.Schema.Node
  import Neo4jex.Changeset

  node "Post" do
    property :title, :string
    property :text, :string
  end

  def changeset(post, params \\ %{}) do
    post
    |> cast(params, [:title, :text])
  end
end
