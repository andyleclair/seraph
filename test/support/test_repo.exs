config = [
  uri: "bolt://localhost:7687",
  auth: [username: "neo4j", password: "password"],
  pool_size: 5,
  max_overflow: 1
]

Application.put_env(:seraph, Seraph.TestRepo, config)

defmodule Seraph.TestRepo do
  use Seraph.Repo, otp_app: :seraph
end

Seraph.TestRepo.start_link()
