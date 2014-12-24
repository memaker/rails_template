class GithubRepository
  include Mongoid::Document
  include Mongoid::Timestamps

  field :id, type: Integer       # 1296269
  field :name, type: String      # Hello-World
  field :full_name, type: String # octocat/Hello-World
end
