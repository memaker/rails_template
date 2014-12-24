class GithubUser
  include Mongoid::Document
  include Mongoid::Timestamps

  # field :id, type: Integer    # 1
  field :login, type: String  # octocat
  field :name, type: String   # monalisa octocat
  field :access_token, type: String

  def client
    Octokit::Client.new(access_token: access_token)
  end

  def self.create_from_sawyer(user)
    create(id: user.id, login: user.login, name: user.name)
  end

  def self.create_from_string(user)
    create_from_sawyer(Octokit.user(user))
  end
end
