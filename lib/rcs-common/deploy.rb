module RCS
  class Deploy
    attr_reader :me, :target

    def initialize(params)
      @target = Target.new(params)
      @me = Me.new
    end

    class Me
      attr_reader :path

      def initialize
        @path ||= File.expand_path(Dir.pwd)

        raise "Missing rakefile" unless File.exists?("#{@path}/Rakefile")
        raise "Not in a git repo" unless Dir.exists?("#{@path}/.git")
      end

      def run(cmd, opts = {})
        puts "executing: #{cmd}"
        opts[:trap] ? `#{cmd}` : Kernel.system(cmd)
      end

      def pending_changes?
        run("cd \"#{path}\" && git status", trap: true) !~ /nothing to commit, working directory clean/
      end

      def ask(question, yes_no: true, choices: %w[y n])
        print("#{question} (#{choices.join(', ')}): ")

        begin
          answer = STDIN.readline.strip.downcase
          yes_no ? (answer == 'y' or answer == 'yes') : answer
        rescue Interrupt
          puts "\nBye"
          exit
        end
      end
    end

    class Target
      attr_reader :user, :address

      def initialize(params)
        @user = params[:user]
        @address = params[:address]
      end

      def add_slash(path)
        path.end_with?('/') ? "#{path}" : "#{path}/"
      end

      def transfer(src, remote_folder, opts = {})
        dst = add_slash(remote_folder)

        run_without_ssh("rsync -tcv #{src} #{user}@#{address}:\"#{dst}\"", opts)
      end

      def mirror!(local_folder, remote_folder, opts = {})
        src = add_slash(local_folder)
        dst = add_slash(remote_folder)

        run_without_ssh("rsync --delete -vazc \"#{src}\" #{user}@#{address}:\"#{dst}\"", opts)
      end

      def mirror(local_folder, remote_folder, opts = {})
        opts[:trap] = true
        result = mirror!(local_folder, remote_folder, opts)
        changes = result.split("\n")[1..-3].reject { |x| x.empty? }
        changed = changes.size > 0 && changes != ["./"]

        if opts[:changes]
          changed ? result : nil
        else
          changed
        end
      end

      def restart_service(name)
        run_with_ssh("net stop \"#{name}\"; net start \"#{name}\"")
      end

      def run_with_ssh(command, opts = {})
        run_without_ssh("ssh #{user}@#{address} \""+ command.gsub('"', '\"') +"\"", opts)
      end

      alias :run :run_with_ssh

      def run_without_ssh(cmd, opts = {})
        puts "executing: #{cmd}"
        opts[:trap] ? `#{cmd}` : Kernel.system(cmd)
      end
    end
  end
end
