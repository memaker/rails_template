module Contribution::Fetchable
  def self.included(klass)
    klass.extend ClassMethods
  end

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
    branch = full_name.include?('rails_template') ? 'contributor' : 'master'

    sawyer_commits = bm('client.commits'){ client.commits(full_name, sha: branch, per_page: 100) }
    saved_commits = bm('Commit.where'){ Commit.where(full_name: full_name, :sha.in => sawyer_commits.map{|c| c.sha }).to_a }
    processed_commits = []

    Parallel.each_with_index(sawyer_commits, in_threads: 5) do |commit, i|
      result =
        if saved_commits.any?{|c| c.sha == commit.sha }
          saved_commits.detect{|c| c.sha == commit.sha }
        else
          bm('Commit.create_from_string'){ Commit.create_from_string(full_name, commit.sha) }
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

  def bm(name, &block)
    self.class.bm(name, &block)
  end

  private

  def client
    OctokitUtil.client
  end

  module ClassMethods
    # Must run in background
    def fetch_all(login, full_name, start_day, end_day)
      contribution = Contribution.find_or_initialize_by(login: login, full_name: full_name)
      contribution.touch(:searched_at)
      contribution.update(fetch_status: "Let's go.")
      logger.info "Let's go. #{login} #{full_name}"
      contribution.save

      contribution.update(fetch_status: 'Fetching github user.')
      logger.info "Fetching github user. #{login} #{full_name}"
      bm('fetch_github_user'){ contribution.fetch_github_user }

      contribution.update(fetch_status: 'Fetching repository meta data.')
      logger.info "Fetching repository meta data. #{login} #{full_name}"
      bm('fetch_repository'){ contribution.fetch_repository }

      contribution.update(fetch_status: 'Fetching commits meta data. This is quite time-consuming.')
      logger.info "Fetching commits meta data. This is quite time-consuming. #{login} #{full_name}"
      bm('fetch_commits'){ contribution.fetch_commits }

      contribution.update(fetch_status: 'Fetching issues.')
      logger.info "Fetching issues. #{login} #{full_name}"
      bm('fetch_issues'){ contribution.fetch_issues }
      contribution.touch(:fetched_at)

      contribution.update(fetch_status: 'Fetching is completed.')
      logger.info "Fetching is completed. #{login} #{full_name}"

      contribution.update(fetch_status: 'Analyzing commits.')
      logger.info "Analyzing commits. #{login} #{full_name}"
      result = {
        contributors: bm('contributors'){ contribution.contributors },
        commits_stats: bm('commits_stats'){ contribution.commits_stats(start_day, end_day) },
      }
      RedisUtil.set(result_key(login, full_name), result)
      contribution.touch(:analyzed_at)

      contribution.update(fetch_status: nil)
      logger.info "Completed. #{login} #{full_name}"

      contribution.save
      contribution
    end

    def bm(name, &block)
      start = Time.now
      result = yield if block_given?
      logger.info "BENCHMARK: #{name} #{(Time.now - start).round(3)} sec"
      result
    end
  end

  extend ClassMethods
end