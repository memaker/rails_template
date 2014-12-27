class GithubUser
  include Mongoid::Document
  include Mongoid::Timestamps

  field :login, type: String  # octocat
  field :name, type: String   # monalisa octocat
  field :access_token, type: String

  belongs_to :contribution

  validates :login, :name, presence: true
  validates :id, presence: true, numericality: {only_integer: true}

  def client
    Octokit::Client.new(access_token: access_token)
  end

  def self.create_from_string(user)
    create_from_sawyer(Octokit.user(user))
  end

  private

  def self.create_from_sawyer(user)
    create(id: user.id, login: user.login, name: user.name)
  end
end
