class OctokitUtil
  def self.client
    @@access_token ||= IO.read(File.join(Rails.root, '.access_token')) rescue ''
    Octokit::Client.new(access_token: @@access_token)
  end
end