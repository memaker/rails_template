class SearchWorker
  include Sidekiq::Worker

  def perform(full_name, login, start_day, end_day)
    if full_name.present? && login.present?
      contribution = Contribution.find_or_initialize_by(login: login, full_name: full_name)

      if contribution.new_record?
        Contribution.fetch_all(login, full_name, Time.at(start_day).utc, Time.at(end_day).utc)
        logger.info "Fetching is finished. #{login} #{full_name}"
      else
        if contribution.recently_analyzed?
          logger.info "Do nothing because this contribution is analyzed recently. #{login} #{full_name}"
        elsif contribution.recently_fetched?
          logger.info "Do nothing because this contribution is fetched recently. #{login} #{full_name}"
        elsif contribution.recently_searched?
          logger.info "Do nothing because maybe another worker is fetching now. #{login} #{full_name}"
        else
          # TODO implement update logic
          Contribution.fetch_all(login, full_name, Time.at(start_day).utc, Time.at(end_day).utc)
          logger.info "Updating is finished. #{login} #{full_name}"
        end
      end
    else
      logger.info "Do nothing because either login or full_name is empty. #{login} #{full_name}"
    end
  end
end