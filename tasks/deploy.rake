require 'rcs-common/deploy'

desc "Deploy this project"
task :deploy do
  user    = ENV['DEPLOY_USER'] || 'Administrator'
  address = ENV['DEPLOY_ADDRESS'] || '192.168.100.100'
  deploy  = RCS::Deploy.new(user: user, address: address)
  $target = deploy.target
  $me     = deploy.me

  if ENV['SKIP_CONFIRM'] != 'yes' and $me.pending_changes?
    exit unless $me.ask('You have pending changes, continue?')
  end

  $me.run('rm -f pkg/*.gem')
  $me.run('rake build')
  $target.run("cd ./rcs-common && del *.gem")
  $target.mirror!("pkg", "./rcs-common")
  $target.run("cd ./rcs-common; \"C:/RCS/Ruby/bin/gem\" install --conservative rcs*.gem; \"C:/RCS/Ruby/bin/gem\" clean rcs-common")
  $target.restart_service('RCSWorker')
end
