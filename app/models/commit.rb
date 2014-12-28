class Commit
  include Mongoid::Document
  include Mongoid::Timestamps

  field :full_name, type: String
  field :sha, type: String
  field :stats, type: Hash
  field :date, type: DateTime
  field :message, type: String

  belongs_to :contribution

  validates :full_name, :sha, :stats, :date, :message, presence: true

  index({ full_name: 1, sha: 1 }, { unique: true, background: true })

  def self.create_from_string(full_name, sha)
    create_from_sawyer(OctokitUtil.client.commit(full_name, sha))
  end

  private

  def self.create_from_sawyer(commit)
    commit.url =~ %r{repos/(.+)/commits}
    full_name = $1
    date = commit.commit.author.date
    message = commit.commit.message

    create(
      full_name: full_name,
      sha: commit.sha,
      stats: commit.stats.to_hash,
      date: date,
      message: message
    )
  end
end
