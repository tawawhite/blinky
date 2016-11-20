#!/usr/bin/ruby
require 'blinky'

conffile = File.join(File.dirname(__FILE__), '..', 'blinky-conf.yml')
if File.exists? conffile
  Blinky.read_config_file conffile
end

storage = Blinky::Storage.new
renderer = Blinky::Renderer.new
logger = Blinky::Utils.new_logger progname: 'ShotWorker'
config = Blinky.config

count = 0
reqlimit = config.shot_max_request.to_i != 0 ? config.shot_max_request.to_i : nil
storage.dequeue do |req|
  count += 1
  logger.info "Starting process request ##{count}#{reqlimit ? "/#{reqlimit}" : ""}"
  begin
    Timeout::timeout((config.webkit_load_timeout * (config.webkit_load_retry + 1) + config.page_complete_timeout) + 10) {
      storage.push_result req, renderer.render(req)
    }
  rescue => e
    logger.error "Screenshot failed. [#{e.class.to_s}] #{e.message};\n#{e.backtrace.pretty_inspect}"
    storage.push_result req, e.message, true
  end
  if reqlimit && count >= reqlimit
    logger.warn "Shot max request has been exceeded (#{Blinky.config.shot_max_request}), exit process!"
    exit
  end
end
