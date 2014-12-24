class Contributor
  include Mongoid::Document
  include Mongoid::Timestamps

  field :github_user_id, type: Integer
  field :repository_id, type: Integer

  attr_accessor :github_user, :repository

  index({ github_user_id: 1 }, { unique: true, background: true })
  index({ repository_id: 1 }, { unique: true, background: true })
  index({ github_user_id: 1, repository_id: 1 }, { unique: true, background: true })

  def fetch_commits
    self.github_user = fetch_user
    self.repository = fetch_repository

    commits = Octokit.commits(repository.full_name, author: github_user.login)
  end

  def fetch_additions_sum
    commits = fetch_commits.map{|c| Octokit.commit(repository.full_name, c.sha) }
    commits.inject(0){|sum, commit| sum + commit.stats.additions }
  end

  def fetch_deletions_sum
    commits = fetch_commits.map{|c| Octokit.commit(repository.full_name, c.sha) }
    commits.inject(0){|sum, commit| sum + commit.stats.deletions }
  end

  def self.create_from_user_and_repository(user, repo)
    create(github_user_id: user.id, repository_id: repo.id)
  end

  private

  def fetch_user
    raise 'you need set github_user_id' if github_user_id.blank?

    user = GithubUser.find_by(id: github_user_id)
    if user.blank?
      user = GithubUser.create!(Octokit.user(github_user_id).to_hash)
      github_user_id = user.id
    end

    raise "user is blank. #{github_user_id} is correct id?" if user.blank?

    user
  end

  def fetch_repository
    raise 'you need set repository_id' if repository_id.blank?

    repository = Repository.find_by(id: repository_id)
    if repository.blank?
      repository = Repository.create!(Octokit.repository(repository_id).to_hash)
      repository_id = repository.id
    end

    raise "repository is blank. #{repository_id} is correct id?" if repository.blank?

    repository
  end
end
