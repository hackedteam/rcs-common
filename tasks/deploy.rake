raise "Missing deploy user" unless ENV['DEPLOY_USER']
raise "Missing deploy address" unless ENV['DEPLOY_ADDRESS']

deploy = RCS::Deploy.new(user: ENV['DEPLOY_USER'], address: ENV['DEPLOY_ADDRESS'])

$target, $me = deploy.target, deploy.me

desc 'Deploy all the code in the lib folder'
task :deploy do
  if $me.pending_changes?
    print 'You have pending changes, continue (y/n)? '
    exit if STDIN.getc != 'y'
  end

  Rake::Task['deploy:backup'].invoke

  services_to_restart = []
  %w[Aggregator Intelligence OCR Translate Worker DB].each do |service|
    name = service.downcase
    result = $target.mirror("#{$me.path}/lib/rcs-#{name}/", "rcs/DB/lib/rcs-#{name}-release/", trap: true)
    something_changed = result.split("\n")[1..-3].reject { |x| x.empty? }.any?

    if something_changed
      services_to_restart << "RCS#{service}"
      puts result
    else
      puts 'nothing changed'
    end
  end

  services_to_restart.each do |service|
    $target.restart_service(service)
  end
end

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
      $target.run("cp -r deploy_backups/#{folder}/lib/* rcs/DB/lib")
    else
      puts "No backups found :("
    end
  end

  task :backup do
    folder = "#{Time.now.to_i}"
    $target.run("mkdir deploy_backups/#{folder}; cp -r rcs/DB/lib deploy_backups/#{folder}")
  end
end
