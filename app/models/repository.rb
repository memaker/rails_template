class Repository
  include Mongoid::Document
  include Mongoid::Timestamps

  field :name, type: String      # Hello-World
  field :full_name, type: String # octocat/Hello-World

  belongs_to :contribution

  validates :name, :full_name, presence: true
  validates :id, presence: true, numericality: {only_integer: true}

  def self.create_from_string(repo)
    create_from_sawyer(Octokit.repository(repo))
  end

  private

  def self.create_from_sawyer(repo)
    create(id: repo.id, name: repo.name, full_name: repo.full_name)
  end
end
