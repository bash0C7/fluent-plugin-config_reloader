require 'spec_helper'

describe do
  let(:driver) {Fluent::Test::OutputTestDriver.new(Fluent::ConfigReloaderOutput, tag).configure(config)}

  describe 'emit' do
    let(:tag) {'test.metrics'}
    let(:record1) {{ 'field1' => 50, 'otherfield' => 99}}
    let(:record2) {{ 'field1' => 150, 'otherfield' => 199}}
    let(:time) {0}

      let(:config) {
        %[
            type config_reloader
            config_file spec/child_test.conf
            reload_file spec/reload.txt
            reload_file_watch_interval 0
        ]
      }


    describe :emit do
      it do
        d = driver
        d.run do
          d.instance.emit(tag, Fluent::OneEventStream.new(time.to_i, {"a"=>1}), Fluent::Test::TestOutputChain.new)
          d.instance.emit(tag, Fluent::OneEventStream.new(time.to_i, {"a"=>2}), Fluent::Test::TestOutputChain.new)
          sleep 1
        end
        d.instance.outputs.each {|o|
          expect([
              [time, {"a"=>1}],
              [time, {"a"=>2}],
            ]).to eq(o.events)
        }
      end
    end
    
    describe :update do
      let(:reload_file) {'spec/reload.txt'}
      after(:each) do
        File.delete(reload_file) if File.exists?(reload_file)
      end
      
      it do
        pending("WIP")
        
        expect_any_instance_of(Fluent::ConfigReloaderOutput).to receive(:update).once

        d = driver
        d.run do
          d.instance.emit(tag, Fluent::OneEventStream.new(time.to_i, {"a"=>1}), Fluent::Test::TestOutputChain.new)
          sleep 1
        end
        open(reload_file, 'w') do |o|
          o.write 'xx'
        end
        sleep 2
        sleep 2
      end
    end
  end
end