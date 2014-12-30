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
    @date_range = set_date_range

    SearchWorker.perform_async(
      full_name,
      login,
      @date_range[:start_day].to_i,
      @date_range[:end_day].to_i
    )
    @contribution = Contribution.find_or_initialize_by(login: login, full_name: full_name)

    respond_with(@contribution)
  end

  def search_result
    full_name = params[:full_name] # octocat/Hello-World
    login = params[:login]         # octocat

    unless Contribution.where(login: login, full_name: full_name).exists?
      return render json: {message: 'Creating.'}
    end

    contribution = Contribution.find_by(login: login, full_name: full_name)
    unless contribution.recently_analyzed?
      return render json: {message: contribution.fetch_status || 'Processing.'}
    end

    unless result = RedisUtil.get("#{login}:#{full_name}")
      return render json: {message: contribution.fetch_status || 'Analyzing.'}
    end

    contributors = result[:contributors]
    commits_stats = result[:commits_stats]

    render json: {html: render_to_string(
             partial: 'search_result',
             locals: {contribution: contribution, commits_stats: commits_stats, contributors: contributors}
           )}
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

  def set_date_range
    now_utc = DateTime.now.utc
    {
      start_day: now_utc - 6.days,
      end_day: now_utc
    }
  end

  def set_contribution
  end

  def contribution_params
    params[:contribution]
  end
end
