class AuthController < ApplicationController
  skip_before_filter :auth, :only => :create

  def create
    if ENV['GITHUB_TEAM_ID'].nil? || team_access?
      user = User.where(
        :github_id => auth_hash['uid'],
        :login => auth_hash['info']['nickname']
      ).first_or_create

      user.access_token = auth_hash.credentials['token']
      user.save

      session[:github_user_id] = auth_hash['uid']
      redirect_to session.delete(:return_to)
    else
      render :status => :forbidden, :text => "Forbidden"
    end
  end

  def destroy
    session.clear
    redirect_to (ENV['GITHUB_ENTERPRISE_URL'] || "https://github.com")
  end

  protected

  def github_api_url
    ghe_url = ENV['GITHUB_ENTERPRISE_URL']
    ghe_url ? "#{ghe_url}/api/v3" : "https://api.github.com"
  end

  def auth_hash
    env['omniauth.auth']
  end

  def team_access?
    host   = github_api_url
    path   = "/teams/#{ENV['GITHUB_TEAM_ID']}/members"
    params = "access_token=#{auth_hash.credentials['token']}"
    uri    = URI.parse("#{host}#{path}?#{params}")

    http         = Net::HTTP.new(uri.host, uri.port)
    request      = Net::HTTP::Get.new("#{uri.path}?#{uri.query}")
    http.use_ssl = true

    team_members = JSON.parse(http.request(request).body)

    team_members.any? do |user_hash|
      user_hash['login'] == auth_hash['info']['nickname']
    end
  end
end
