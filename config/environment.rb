# Load the Rails application.
require File.expand_path('../application', __FILE__)
require 'casclient'
require 'casclient/frameworks/rails/filter'
require 'casclient/frameworks/rails/cas_proxy_callback_controller'

# Initialize the Rails application.
Cas::Application.initialize!

CASClient::Frameworks::Rails::Filter.configure(
	:cas_base_url 				=> "https://login-test.cc.nd.edu/cas/",
	:proxy_callback_url 			=> "https://localhost:3002/cas_proxy_callback/receive_pgt",
	:extra_attributes_session_key 		=> :cas_extra_attr,
	:enable_single_sign_out 		=> true
)
