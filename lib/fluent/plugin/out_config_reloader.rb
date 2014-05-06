module Fluent
  class Fluent::ConfigReloaderOutput < Fluent::MultiOutput
    Fluent::Plugin.register_output('config_reloader', self)

    config_param :config_file, :string
    config_param :reload_file, :string
    config_param :reload_file_watch_interval, :integer, :default => 1

    class ReloadFileWatcher
      require 'observer'
      include ::Observable
      
      attr_reader :thread
      
      def self.create(observer, watch_file, interval)
        obj = self.new
        obj.add_observer(observer)
        obj.watch watch_file, interval
        
        obj
      end
      
      def watch watch_file, interval
        mtime = Time.now

        @thread = Thread.new do
          loop do
            if File.exists?(watch_file) && File.mtime(watch_file) > mtime
              mtime = File.mtime(watch_file)
            
              changed
              notify_observers
            end
            sleep interval
          end
        end
      end
    end
 
    def initialize
      super

      @q = Queue.new
    end
 
    def outputs
      [@output]
    end
 
    def configure(conf)
      super
 
      load_config_file
    end
 
    def start
      output_start
      @thread = Thread.new(&method(:run))
      
      @watcher = ReloadFileWatcher.create(self, @reload_file, @reload_file_watch_interval)
      
    rescue
      $log.warn "raises exception: #{$!.class}, '#{$!.message}"
    end
 
    def shutdown
      @watcher.delete_observers
      Thread.kill(@thread) 
      output_shutdown
    rescue
      $log.warn "raises exception: #{$!.class}, '#{$!.message}"
    end
 
    def emit(tag, es, chain)
      param = OpenStruct.new
      param.tag = tag
      param.es = es
      param.chain = chain
 
      @q.push param
    end
 
    def update
      $log.warn 'config_reloader: reload config file start'
      output_shutdown
      load_config_file
      output_start
      $log.warn 'config_reloader: reload config file end'
    end
    
    private
 
    def output_start
      @output.start      
    end
    
    def output_shutdown
      @output.shutdown
    end
    
    def load_config_file
      path = File.expand_path(@config_file)

      store_elements = File.open(path) do |io|
        if File.extname(path) == '.rb'
          require 'fluent/config/dsl'
          Config::DSL::Parser.parse(io, path)
        else
          Config.parse(io, File.basename(path), File.dirname(path), false)
        end
      end.elements.select {|e| e.name == 'store'}

      raise ConfigError, "Multiple <store> directives are not available" unless store_elements.size == 1
      
      store_element = store_elements.first
      
      type = store_element['type']
      unless type
        raise ConfigError, "Missing 'type' parameter on <store> directive"
      end
      log.debug "adding store type=#{type.dump}"
 
      @output = Plugin.new_output(type)
      @output.configure(store_element)
    end
 
    def run
      loop do
        param = @q.pop

        tag = param.tag
        es = param.es
        chain = param.chain
 
        begin
          unless es.repeatable?
            m = MultiEventStream.new
            es.each {|time,record|
              m.add(time, record)
            }
            es = m
          end
          chain = OutputChain.new([@output], tag, es, chain)
          chain.next
        rescue
          $log.warn "raises exception: #{$!.class}, '#{$!.message}, #{param}'"
        end
      end
    end
  end
end