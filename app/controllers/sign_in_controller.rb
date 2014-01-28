class SignInController < ApplicationController
#  before_filter RubyCas::Filter
  before_filter CASClient::Frameworks::Rails::Filter, :except => [:start]

  def start
  end
  
  def index
	self.allow_forgery_protection = false
	service_uri = "https://inside-d.cc.nd.edu"
	@proxy_granting_ticket = session[:cas_pgt]
	@proxy_ticket = CASClient::Frameworks::Rails::Filter.client.proxy_callback_url
  end

  def web_service
    respond_to do |format|
      format.json { render :json => session}
      format.xml  { render :xml => session, :content_type => "application/xml"}
    end
  end

  def logout
	self.allow_forgery_protection = false
	CASClient::Frameworks::Rails::Filter.logout(self)
  end
end
