raise "Missing deploy user" unless ENV['DEPLOY_USER']
raise "Missing deploy address" unless ENV['DEPLOY_ADDRESS']

deploy = RCS::Deploy.new(user: ENV['DEPLOY_USER'], address: ENV['DEPLOY_ADDRESS'])

$target, $me = deploy.target, deploy.me

$project = if File.exists?("#{$me.path}/lib/rcs-db")
  :db
elsif File.exists?("#{$me.path}/lib/rcs-collector")
  :collector
elsif File.exists?("#{$me.path}/lib/rcs-common")
  :common
end

raise "Unknown project. Cannot load deploy task" unless $project


desc "Deploy this project to #{$target.address}"
task :deploy do
  if $me.pending_changes?
    exit unless $me.ask('You have pending changes, continue?')
  end

  if $project == :common
    $me.run('rake build')
    $target.mirror("pkg", "./rcs-common")
    $target.run("cd ./rcs-common; \"C:/RCS/Ruby/bin/gem\" install rcs*.gem; \"C:/RCS/Ruby/bin/gem\" clean rcs-common")
    exit
  end

  deploy_rcs_common = $me.ask('Deploy also the rcs-common gem?')

  Rake::Task['deploy:backup'].invoke

  if deploy_rcs_common
    $me.run('cd ../rcs-common; rake build')
    $target.mirror("#{$me.path}/../rcs-common/pkg", "./rcs-common")
    $target.run("cd ./rcs-common; \"C:/RCS/Ruby/bin/gem\" install rcs*.gem; \"C:/RCS/Ruby/bin/gem\" clean rcs-common")
  end

  components, root_dir = nil

  if $project == :db
    components = %w[Aggregator Intelligence OCR Translate Worker Connector DB]
    root_dir = "DB"
  elsif $project == :collector
    components = %w[Collector Carrier Controller]
    root_dir = "Collector"
  else
    exit
  end

  services_to_restart = []

  components.each do |service|
    name = service.downcase
    changes = $target.mirror("#{$me.path}/lib/rcs-#{name}/", "rcs/#{root_dir}/lib/rcs-#{name}-release/", changes: true)

    if changes
      services_to_restart << "RCS#{service}"
      puts "#{name} is changed. RCS#{service} service will be restarted soon."
      # puts changes
    else
      puts "#{name} is up to date, nothing was changed."
    end
  end

  services_to_restart.each { |name| $target.restart_service(name) }
end


if [:db, :collector].include?($project)
  namespace :deploy do

    desc "Tail a log file (default to rcs-db)"
    task :log, [:service_name] do |task, args|
      name = args.service_name.to_s.downcase.strip
      name = 'db' if name.empty?
      filename = "rcs-#{name}_#{Time.now.strftime('%Y-%m-%d')}.log"
      $target.run("tail -F \"C:\\RCS\\DB\\log\\#{filename}\"")
    end

    namespace :sc do

      desc "Show the status of all the rcs-related services"
      task :status do |args|
        result = $target.run('sc query type= service state= all', trap: true)
        result.split("SERVICE_NAME:")[1..-1].each do |text|
          name = text.lines.first.strip
          next if name !~ /RCS/i and name !~ /mongo/i
          next if name =~ /RCSDB\-/
          state = text.lines.find{ |l| l =~ /STATE/ }.split(':').last.gsub(/\d/, '').strip
          state.downcase! if state == 'RUNNING'
          puts "#{name.ljust(20)} #{state}"
        end
      end

      desc "Restart a Windows service (default to RCS DB)"
      task :restart, [:service_name] do |task, args|
        $target.restart_service(args.service_name || 'db')
      end
    end

    desc 'Rollback the last deploy (if any)'
    task :rollback do
      result = $target.run("ls deploy_backups/", trap: true)
      folder = result.split(" ").sort.last

      if folder
        cmds = [
          "cp -r deploy_backups/#{folder}/DB/lib/* rcs/DB/lib",
          "cp -r deploy_backups/#{folder}/Collector/lib/* rcs/Collector/lib"
        ]

        $target.run(cmds.join('; '))
      else
        puts "No backups found :("
      end
    end

    task :backup do
      folder = "#{Time.now.to_i}"

      cmds = [
        "mkdir deploy_backups",
        "mkdir deploy_backups/#{folder}",
        "mkdir deploy_backups/#{folder}/DB",
        "mkdir deploy_backups/#{folder}/Collector",
        "cp -r rcs/DB/lib deploy_backups/#{folder}/DB",
        "cp -r rcs/Collector/lib deploy_backups/#{folder}/Collector"
      ]

      $target.run(cmds.join('; '))
    end
  end
end
