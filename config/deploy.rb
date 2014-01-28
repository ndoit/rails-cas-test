set :use_sudo, false
set :APP_NAME, "cas"
set :APP_ROOT, "/home/vagrant/cas"
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

namespace :vagrant do

  desc "copy ssl certs for vagrant"
  task :ssl_certs do
    on roles(:web) do
        execute :sudo, "cp /vagrant/ssl/* #{fetch(:NGINX_HOME)}/ssl"
    end
  end

  task :setup do
    invoke 'vagrant:ssl_certs'
    invoke 'deploy:nginx_conf'
    invoke 'deploy:stop_servers'
    invoke 'deploy:start_servers'
  end

end

namespace :deploy do


   desc "set up nginx conf files"
   task :nginx_conf do
     on roles(:web) do
       puts Dir.pwd
       begin
          execute :sudo, "mv #{fetch(:NGINX_HOME)}/conf/nginx.conf #{fetch(:NGINX_HOME)}/conf/nginx.conf.last" 
       rescue Exception => error
         puts "Could not move existing nginx.conf"
       end
       execute :sudo, "ln -s #{fetch(:APP_ROOT)}/config/nginx.conf #{fetch(:NGINX_HOME)}/conf/nginx.conf"
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

  # not properly implemented yet!
  desc "checks out the app from version control"
  task :deploy do
    invoke 'deploy:stop_servers'
    invoke 'deploy:clean'
    on roles(:web) do
      execute "cp -r /home/vagrant/#{fetch(:APP_NAME)} #{fetch(:APP_ROOT)}"
    end
    invoke 'deploy:nginx_conf'
    invoke 'bundle:install'
    invoke 'deploy:start_servers'
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
