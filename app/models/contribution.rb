class Contribution
  include Mongoid::Document
  include Mongoid::Timestamps

  field :login, type: String
  field :full_name, type: String
  field :searched_at, type: Time # touch when search is started
  field :fetched_at, type: Time  # touch when fetch is finished
  field :fetch_status, type: String

  has_one :github_user
  has_one :repository
  has_many :commits
  has_many :issues

  attr_accessor :rivals

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
    # DEBUG CODE
    sha = full_name.include?('rails_template') ? 'contributor' : 'master'

    sawyer_commits = client.commits(full_name, author: login, sha: sha, per_page: 100)
    saved_commits = Commit.where(full_name: full_name, sha: sawyer_commits.map{|c| c.sha }).to_a
    processed_commits = []

    Parallel.each_with_index(sawyer_commits, in_threads: 5) do |commit, i|
      result =
        if saved_commits.any?{|c| c.sha == commit.sha }
          saved_commits.detect{|c| c.sha == commit.sha }
        else
          Commit.create_from_string(full_name, commit.sha)
        end

      processed_commits << {i: i, result: result}
    end

    self.commits =
      processed_commits.sort_by{|p| p[:i] }.map{|p| p[:result] }.flatten
  end

  def fetch_issues
    self.issues =
      if Issue.where(full_name: full_name, related_to: login).exists?
        Issue.where(full_name: full_name, related_to: login)
      else
        _issues = client.issues(full_name, assignee: login, per_page: 100)
        _issues += client.issues(full_name, creator: login, per_page: 100)
        _issues.uniq! { |i| i.number }
        _issues.map { |issue| Issue.create_from_sawyer(issue, login) }
      end
  end

  # @return [Hash]
  #   {
  #     'login1' => {login: 'login1', commits: [...]},
  #     'login2' => {login: 'login2', commits: [...]},
  #     ...
  #   }
  def fetch_rivals
    # DEBUG CODE
    sha = full_name.include?('rails_template') ? 'contributor' : 'master'

    # TODO fetch in parallel
    rival_commits =
      client.commits(full_name, sha: sha, per_page: 100).map do |commit|
        next if commit.author.login == login

        if Commit.where(full_name: full_name, sha: commit.sha).exists?
          Commit.find_by(full_name: full_name, sha: commit.sha)
        else
          Commit.create_from_string(full_name, commit.sha)
        end
      end.compact

    self.rivals =
      rival_commits.inject({}) do |memo, commit|
        login = commit.author_login
        if memo[login].nil?
          memo[login] = {login: login, commits: []}
        end
        memo[login][:commits] << commit

        memo
      end

    puts 'a'
  end

  def self.fetch_all(login, full_name)
    contribution = Contribution.find_or_initialize_by(login: login, full_name: full_name)
    contribution.touch(:searched_at)
    contribution.update(fetch_status: "Let's go.")
    logger.info "Let's go. #{login} #{full_name}"
    contribution.save

    contribution.update(fetch_status: 'Fetching github user.')
    logger.info "Fetching github user. #{login} #{full_name}"
    contribution.fetch_github_user
    contribution.update(fetch_status: 'Fetching repository meta data.')
    logger.info "Fetching repository meta data. #{login} #{full_name}"
    contribution.fetch_repository
    contribution.update(fetch_status: 'Fetching commits meta data. This is quite time-consuming.')
    logger.info "Fetching commits meta data. This is quite time-consuming. #{login} #{full_name}"
    contribution.fetch_commits
    contribution.update(fetch_status: 'Fetching issues.')
    logger.info "Fetching issues. #{login} #{full_name}"
    contribution.fetch_issues
    contribution.update(fetch_status: 'Fetching rivals. This is quite time-consuming.')
    logger.info "Fetching rivals. This is quite time-consuming. #{login} #{full_name}"
    contribution.fetch_rivals
    contribution.touch(:fetched_at)
    contribution.update(fetch_status: 'Completed.')
    logger.info "Completed. #{login} #{full_name}"
    contribution.save

    contribution
  end

  def recently_fetched?
    fetched_at && fetched_at > Time.now - 5.minutes
  end

  def recently_searched?
    searched_at && searched_at > Time.now - 5.minutes
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
