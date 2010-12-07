require 'test_helper'

if ENV["BENCH"]
  
  require 'bench'
  
  class Performance < ActiveRecord::Base
    serialize_with_options do
      only :name
    end
    
    serialize_with_options(:return_nil_on) do
      only :name
      return_nil_on :name
    end
  end
  
  perf = Performance.create(:name => "Run code run", :seconds => 120)
  
  benchmark 'xml default' do
    perf.to_xml
  end
  
  benchmark 'json default' do
    perf.to_json
  end
  
  benchmark 'xml default return_nil_on' do
    perf.to_xml(:return_nil_on)
  end
  
  benchmark 'json default return_nil_on' do
    perf.to_json(:return_nil_on)
  end
  
  run 5_000
end