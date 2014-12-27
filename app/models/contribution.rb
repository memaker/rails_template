class Contribution
  include Mongoid::Document
  include Mongoid::Timestamps

  field :login, type: String
  field :full_name, type: String

  has_one :github_user
  has_one :repository
  has_many :commits
  has_many :issues

  validates :login, :full_name, presence: true

  index({ login: 1, full_name: 1 }, { unique: true, background: true })

  def fetch_github_user
    if github_user.blank?
      _github_user = GithubUser.find_or_initialize_by(login: login)
      if _github_user.new_record?
        _github_user = GithubUser.create_from_string(login)
      end
      self.github_user = _github_user
    end
  end

  def fetch_repository
    if repository.blank?
      _repository = Repository.find_or_initialize_by(full_name: full_name)
      if _repository.new_record?
        _repository = Repository.create_from_string(full_name)
      end
      self.repository = _repository
    end
  end

  def fetch_commits
    # TODO fetch in parallel
    self.commits =
      client.commits(full_name, author: login).map do |commit|
        if Commit.where(full_name: full_name, sha: commit.sha).exists?
          Commit.find_by(full_name: full_name, sha: commit.sha)
        else
          Commit.create_from_string(full_name, commit.sha)
        end
      end
  end

  def fetch_issues
    self.issues =
      if Issue.where(full_name: full_name, related_to: login).exists?
        Issue.where(full_name: full_name, related_to: login)
      else
        _issues = client.issues(full_name, assignee: login)
        _issues += client.issues(full_name, creator: login)
        _issues.uniq! { |i| i.number }
        _issues.map { |issue| Issue.create_from_sawyer(issue, login) }
      end
  end

  def additions_sum
    commits.inject(0){|sum, commit| sum + commit.stats[:additions] }
  end

  def deletions_sum
    commits.inject(0){|sum, commit| sum + commit.stats[:deletions] }
  end

  private

  def client
    OctokitUtil.client
  end
end
