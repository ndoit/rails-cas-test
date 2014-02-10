set :use_sudo, false
set :ssh_options, { :forward_agent => true }
set :NGINX_CONF_NAME, "cas_server"
set :GITHUB_SSH, "git@github.com:ndoit/rails-cas-test.git"
set :APPS_HOME, "/apps"
set :APP_ROOT, "#{fetch(:APPS_HOME)}/cas"
set :NGINX_HOME, "/usr/local/openresty/nginx"
set :CONFIG_DIR, Dir.pwd


task :hello do 
  puts "hello world"
  puts "x", Dir.pwd, "x"
  puts Dir.pwd
  on roles(:web) do
      execute "echo 'test1'"
      execute "echo #{fetch(:msg, "N/A")}"
  end
end

task :echo_test do 
  puts "printing a message to /tmp/cap_echo_test.txt"
  on roles(:web) do
      execute "echo 'hi' > /tmp/cap_echo_test.txt"
  end
end

namespace :bundle do

  desc "run bundle install and ensure all gem requirements are met"
  task :install do
    on roles(:web) do
      execute "cd #{fetch(:APP_ROOT)}/ && bundle install"
    end
  end

end

namespace :database do

   task :migrate do
     on roles(:web) do
       execute "cd #{fetch(:APP_ROOT)}/ && rake db:migrate"
     end
   end
end


namespace :deploy do

  desc "fetch app and configure (move ssl certs, link server configs, etc. then stop/start servers"
  task :first_time do
    invoke 'deploy:stop_servers'
    invoke 'deploy:clean'
    invoke 'deploy:fetch_app'
    invoke 'deploy:configure'
  end

  desc "move ssl certs, link server configs, stop/start servers"
  task :configure do
    invoke 'deploy:ssl_certs'
    invoke 'deploy:nginx_conf'
    invoke 'bundle:install'
    invoke 'database:migrate'
    invoke 'deploy:reload'
  end

  desc "does a git pull and restarts servers"
  task :reload do
    invoke 'deploy:pull_app'
    invoke 'deploy:stop_servers'
    invoke 'deploy:start_servers'
  end

  desc "updates the app to latest master"
  task :pull_app do
    on roles(:web) do
        execute "cd #{fetch(:APP_ROOT)} && git pull"
    end
  end

  desc "fetch app from github"
  task :fetch_app do
    on roles(:web) do
     	execute "cd #{fetch(:APPS_HOME)} && git clone #{fetch(:GITHUB_SSH)} #{fetch(:APP_ROOT)}"
    end
  end

  desc "copy ssl certs (the self-signed ones that come with this app) to nginx config"
  task :ssl_certs do
    on roles(:web) do
        execute :sudo, "cp #{fetch(:APP_ROOT)}/config/ssl/* #{fetch(:NGINX_HOME)}/ssl"
    end
  end

   desc "set up nginx conf files"
   task :nginx_conf do
     on roles(:web) do
       puts Dir.pwd
       begin
          execute :sudo, "mv #{fetch(:NGINX_HOME)}/conf/nginx.conf #{fetch(:NGINX_HOME)}/conf/nginx.conf.last" 
          begin
              execute :sudo, "unlink #{fetch(:NGINX_HOME)}/conf/nginx.conf"
          rescue Exception => error
              puts "error unlinking nginx.conf.  it probably didn't exist"
          end
          execute :sudo, "ln -s #{fetch(:APP_ROOT)}/config/nginx.conf #{fetch(:NGINX_HOME)}/conf/nginx.conf"
          execute :sudo, "cp -s #{fetch(:APP_ROOT)}/config/#{fetch(:NGINX_CONF_NAME)} #{fetch(:NGINX_HOME)}/conf/sites-available"
          begin
              execute :sudo, "unlink #{fetch(:NGINX_HOME)}/conf/sites-enabled/#{fetch(:NGINX_CONF_NAME)}"
          rescue Exception => error
              puts "error unlinking app nginx server config.  it probably didn't exist"
          end
          execute :sudo, "ln -s #{fetch(:NGINX_HOME)}/conf/sites-available/#{fetch(:NGINX_CONF_NAME)} #{fetch(:NGINX_HOME)}/conf/sites-enabled"
       rescue Exception => error
         puts "Could not move existing nginx.conf"
       end
     end
   end

   desc "cleans out the deploy directory"
   task :clean do
    on roles(:web) do
      begin
        execute "rm -r #{fetch(:APP_ROOT)}" 
      rescue Exception => error
        puts "could not delete app.  maybe it doesn't exist yet."
      end 
    end
  end

  desc "restarts unicorn and nginx"
  task :restart do
    invoke 'deploy:stop_servers'
    invoke 'deploy:start_servers'
  end
  

  desc "stop unicorn"
  task :stop_unicorn do
    on roles(:web) do
      begin
        puts "stopping unicorn"
        execute "kill -9 $(cat #{fetch(:APP_ROOT)}/tmp/pid/unicorn.pid)"
      rescue Exception => error 
        puts "error stopping unicorn... maybe the servers were not on?"
      end
    end 
  end

  desc "stop nginx"
  task :stop_nginx do
    on roles(:web) do
      begin
        puts "stopping nginx (openresty)"
        execute :sudo, "#{fetch(:NGINX_HOME)}/sbin/nginx -s stop"
      rescue Exception => error 
        puts "error stopping nginx... maybe the servers were not on?"
      end
    end 
  end

  task :stop_servers do 
    invoke 'deploy:stop_unicorn'
    invoke 'deploy:stop_nginx'
  end

  task :start_servers do 
    invoke 'deploy:start_unicorn'
    invoke 'deploy:start_nginx'
  end
  
  task :start_unicorn do
    on roles(:web) do
      puts "starting unicorn"
      execute "cd #{fetch(:APP_ROOT)}/ && bundle exec unicorn -c #{fetch(:APP_ROOT)}/config/unicorn.rb -D"
    end
  end

  task :start_nginx do
    on roles(:web) do
      puts "starting nginx"
      execute :sudo, "#{fetch(:NGINX_HOME)}/sbin/nginx"
    end
  end
end
