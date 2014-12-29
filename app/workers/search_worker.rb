class SearchWorker
  include Sidekiq::Worker

  def perform(login, full_name)
    if full_name.present? && login.present?
      contribution = Contribution.find_or_initialize_by(login: login, full_name: full_name)
      if contribution.new_record?
        Contribution.fetch_all(login, full_name)
      else
        if contribution.updated_at > Time.now.utc - 5.minute
          # Do nothing because this contribution is searched for 5 minutes from now
        else
          # TODO update
          contribution.touch
        end
      end
    end
  end
end