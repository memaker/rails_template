class ContributionsController < ApplicationController
  before_action :set_contribution, only: [:edit, :update, :destroy]

  respond_to :html

  def index
    @contributions = Contribution.all
    respond_with(@contributions)
  end

  def show
    full_name = params[:full_name] # octocat/Hello-World
    login = params[:login]         # octocat
    SearchWorker.perform_async(full_name, login)
    @contribution = Contribution.find_or_initialize_by(login: login, full_name: full_name)

    respond_with(@contribution)
  end

  def search_result
    full_name = params[:full_name] # octocat/Hello-World
    login = params[:login]         # octocat

    if Contribution.where(login: login, full_name: full_name).exists?
      contribution = Contribution.find_by(login: login, full_name: full_name)

      if contribution.recently_fetched?
        now_utc = DateTime.now.utc
        contribution.fetch_rivals
        commits_stats = calc_commits_stats(contribution.commits, now_utc - 6.days, now_utc)
        render json: {html: render_to_string(partial: 'search_result', locals: {contribution: contribution, commits_stats: commits_stats})}
      else
        render json: {message: contribution.fetch_status || 'Processing.'}
      end
    else
      render json: {message: 'Creating.'}
    end
  end

  def new
    @contribution = Contribution.new
    respond_with(@contribution)
  end

  def edit
  end

  def create
    @contribution = Contribution.new(contribution_params)
    @contribution.save
    respond_with(@contribution)
  end

  def update
    @contribution.update(contribution_params)
    respond_with(@contribution)
  end

  def destroy
    @contribution.destroy
    respond_with(@contribution)
  end

  private

  def calc_commits_stats(commits, start_time, end_time)
    start_day = start_time.to_date
    end_day = end_time.to_date

    commits_num = (start_day..end_day).map do |date|
      commits.select{|c| c.author_date.to_date == date }.size
    end

    additions_num = (start_day..end_day).map do |date|
      commits.select{|c| c.author_date.to_date == date }.sum{|c| c.stats[:additions] }
    end

    deletions_num = (start_day..end_day).map do |date|
      commits.select{|c| c.author_date.to_date == date }.sum{|c| c.stats[:deletions] }
    end

    point_start_seconds = start_time.beginning_of_day.to_i
    _base_data = {
      type: 'column',
      name: nil,
      pointInterval: 24 * 3_600 * 1_000,
      pointStart: point_start_seconds * 1_000,
      data: nil
    }

    commits_data = _base_data.deep_dup.merge(data: commits_num, name: 'commits')
    additions_data = _base_data.deep_dup.merge(data: additions_num, name: 'additions')
    deletions_data = _base_data.deep_dup.merge(data: deletions_num, name: 'deletions')

    {
      start_day: start_day,
      end_day: end_day,
      all: [commits_data, additions_data, deletions_data],
      commits: [commits_data],
      additions: [additions_data],
      deletions: [deletions_data],
    }
  end

  def set_contribution
  end

  def contribution_params
    params[:contribution]
  end
end
