class SearchWorker
  include Sidekiq::Worker

  def perform(full_name, login)
    if full_name.present? && login.present?
      contribution = Contribution.find_or_initialize_by(login: login, full_name: full_name)

      if contribution.new_record?
        Contribution.fetch_all(login, full_name)
        logger.info "Fetching is finished. #{login} #{full_name}"
      else
        if contribution.recently_searched?
          logger.info "Do nothing because maybe another worker is fetching now. #{login} #{full_name}"
        elsif contribution.recently_fetched?
          logger.info "Do nothing because this contribution is fetched for 5 minutes from now. #{login} #{full_name}"
        else
          # TODO implement update logic
          contribution.touch(:searched_at)
          contribution.touch(:fetched_at)
          logger.info "Updating is finished. #{login} #{full_name}"
        end
      end
    else
      logger.info "Either login or full_name is empty. #{login} #{full_name}"
    end
  end
end