class GithubUser
  include Mongoid::Document
  include Mongoid::Timestamps

  field :id, type: Integer    # 1
  field :login, type: String  # octocat
  field :name, type: String   # monalisa octocat
  field :access_token, type: String

  def client
    Octokit::Client.new(access_token: access_token)
  end
end
