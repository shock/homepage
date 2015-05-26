if __FILE__ == $0
  puts "Run with: watchr #{__FILE__}. \n\nRequired gems: watchr rev"
  exit 1
end

require 'systemu'
require 'fileutils'

$run_success = 0
$root_dir = File.dirname(__FILE__)

# --------------------------------------------------
# Convenience Methods
# --------------------------------------------------

def simple_growl(message, title = "Watcher")
  puts message
  message = message.gsub(/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]/, "")
  image = $run_success ? "~/.watchr/images/success.jpg" : "~/.watchr/images/failure.gif"
  growlnotify = `which growlnotify`.chomp
  priority = $run_success ? -2 : 2
  sticky_option = ""
  options = "-w -n Watchr --image '#{File.expand_path(image)}' -m '#{message}' '#{title}' -p #{priority} #{sticky_option}"
  system %(#{growlnotify} #{options} &)
end

def growl(title = "Watchr Test Results")
  image = $run_success ? "~/.watchr/images/success.jpg" : "~/.watchr/images/failure.gif"
  message = $run_success ? "SUCCESS! " * 21 : "FAILED! " * 16
  message = message.gsub(/\x1B\[([0-9]{1,2}(;[0-9]{1,2})?)?[m|K]/, "")
  priority = $run_success ? -2 : 2
  sticky_option = !$run_success || title =~ /WHOLE SUITE RESULTS/ ? "-s" : ""
  growlnotify = `which growlnotify`.chomp
  options = "-w -n Watchr --image '#{File.expand_path(image)}' -m '#{message}' '#{title}' -p #{priority} #{sticky_option}"
  system %(#{growlnotify} #{options} &)
end

def run(cmd)
  puts(cmd)
  status, stdout, stderr = systemu cmd
  puts stdout
  puts stderr
  $run_success = stdout.grep(/0 failures/).any? ? true : false
end

def run_all_specs
  cmd = "spec `find spec -name '*_spec.rb' | grep -v integration`"
  puts cmd
  system(cmd)
  $run_success = $?.success?
  growl("WHOLE SUITE RESULTS")
end

def spec(specs)
  files = specs.split(' ')
  specs = []
  files.each do |file|
    if File.exists?(file)
      specs << file
    else
      puts("Spec: #{file} does not exist.")
    end
  end
  run("spec -X #{specs.join(" ")}") if specs.any?
  growl
end

def run_specs *spec
  specs = spec.join(' ')
  spec(specs)
end

def run_suite
  system "clear"
  puts " --- Running all tests ---\n\n"
  run_all_specs
end

def coffee_script(matches)
  # puts matches.inspect
  in_file = matches[0]
  output_dir = "#{$root_dir}/public/assets"
  cmd = "coffee -c -o #{output_dir} #{in_file}"
  # puts cmd
  status, stdout, stderr = systemu cmd
  $run_success = status == 0
  if $run_success
    out_file = nil
    Dir.glob("#{output_dir}/#{matches[2]}*") do |file|
      out_file = file
      if matches2 = file.match(/(.*\.js)\.js/)
        out_file = matches2[1]
        FileUtils.mv(file, out_file)
      end
    end
    simple_growl("#{in_file} compiled to #{out_file.gsub("#{$root_dir}/", '')}")

  else
    simple_growl(stderr)
    systemu 'say "coffee script error"'
  end
end

def compile_scss(matches)
  # puts matches.inspect
  in_file = matches[0]

  output_dir = "#{$root_dir}/public/assets"
  sass_dir = "#{$root_dir}/app/assets/stylesheets"
  cmd = "bundle exec compass compile #{in_file} -I #{sass_dir} --sass-dir #{sass_dir} --css-dir #{output_dir} --output-style expanded"
  puts cmd
  # puts cmd
  status, stdout, stderr = systemu cmd
  $run_success = status == 0
  if $run_success
    out_file = nil
    Dir.glob("#{output_dir}/#{matches[2]}*") do |file|
      out_file = file
      if matches2 = file.match(/(.*\.js)\.js/)
        out_file = matches2[1]
        FileUtils.mv(file, out_file)
      end
    end
    simple_growl("#{in_file} compiled to #{out_file.gsub("#{$root_dir}/", '')}")

  else
    simple_growl(stdout)
    simple_growl(stderr)
    systemu 'say "SCSS compile error"'
  end
end

# # Ctrl-\
# Signal.trap 'QUIT' do
#   # run_suite
# end

# # Ctrl-C
# Signal.trap 'INT' do
#   if @interrupted then
#     abort("\n")
#   else
#     puts "Interrupt a second time to quit"
#     @interrupted = true
#     Kernel.sleep 1.5
#     # raise Interrupt, nil # let the run loop catch it
#     run_suite
#     @interrupted = false
#   end
# end

# --------------------------------------------------
# Watchr Rules
# --------------------------------------------------
watch( '^spec/spec_helper\.rb'                    ) {     run_all_specs }
# watch( '^spec/.*_spec\.rb'                        ) { |m| run_specs(m[0]) }
watch( '^app/(.*)\.rb'                            ) { |m| run_specs("spec/%s_spec.rb" % m[1]) }
watch( '^app/views/(.*)\.erb'                    ) { |m| run_specs("spec/views/%s.erb_spec.rb" % m[1]) }
watch( '^spec/factory/(.*)\.rb'                    ) { |m| run_specs("spec/models/%s_spec.rb" % m[1]) }
watch( '^app/assets/(.*?)/([^/]+)\.coffee'                        ) { |m| coffee_script(m) }
watch( '^app/assets/(.*?)/([^/]+)\.scss'                        ) { |m| compile_scss(m) }


puts "Watching..."
growl("Watcher Running")
