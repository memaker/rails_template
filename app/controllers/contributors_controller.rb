class ContributorsController < ApplicationController
  before_action :set_contributor, only: [:show, :edit, :update, :destroy]

  respond_to :html

  def index
    @contributors = Contributor.all
    respond_with(@contributors)
  end

  def show
    respond_with(@contributor)
  end

  def new
    @contributor = Contributor.new
    respond_with(@contributor)
  end

  def edit
  end

  def create
    @contributor = Contributor.new(contributor_params)
    @contributor.save
    respond_with(@contributor)
  end

  def update
    @contributor.update(contributor_params)
    respond_with(@contributor)
  end

  def destroy
    @contributor.destroy
    respond_with(@contributor)
  end

  private
    def set_contributor
      @contributor = Contributor.find(params[:id])
    end

    def contributor_params
      params[:contributor]
    end
end
