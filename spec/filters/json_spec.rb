# encoding: utf-8

require "logstash/devutils/rspec/spec_helper"
require "logstash/filters/json"
require "logstash/timestamp"

describe LogStash::Filters::Json do

  describe "parse message into the event" do
    config <<-CONFIG
      filter {
        json {
          # Parse message as JSON
          source => "message"
        }
      }
    CONFIG

    sample '{ "hello": "world", "list": [ 1, 2, 3 ], "hash": { "k": "v" } }' do
      insist { subject["hello"] } == "world"
      insist { subject["list" ].to_a } == [1,2,3] # to_a for JRuby + JrJacksom which creates Java ArrayList
      insist { subject["hash"] } == { "k" => "v" }
    end
  end

  describe "parse message into a target field" do
    config <<-CONFIG
      filter {
        json {
          # Parse message as JSON, store the results in the 'data' field'
          source => "message"
          target => "data"
        }
      }
    CONFIG

    sample '{ "hello": "world", "list": [ 1, 2, 3 ], "hash": { "k": "v" } }' do
      insist { subject["data"]["hello"] } == "world"
      insist { subject["data"]["list" ].to_a } == [1,2,3] # to_a for JRuby + JrJacksom which creates Java ArrayList
      insist { subject["data"]["hash"] } == { "k" => "v" }
    end
  end

  describe "tag invalid json" do
    config <<-CONFIG
      filter {
        json {
          # Parse message as JSON, store the results in the 'data' field'
          source => "message"
          target => "data"
          tag_on_failure => ["_jsonparsefailure","_custom_failure_tag"]
        }
      }
    CONFIG

    sample "invalid json" do
      insist { subject["tags"] }.include?("_jsonparsefailure")
      insist { subject["tags"] }.include?("_custom_failure_tag")
    end
  end

  describe "fixing @timestamp (#pull 733)" do
    config <<-CONFIG
      filter {
        json {
          source => "message"
        }
      }
    CONFIG

    sample "{ \"@timestamp\": \"2013-10-19T00:14:32.996Z\" }" do
      insist { subject["@timestamp"] }.is_a?(LogStash::Timestamp)
      insist { LogStash::Json.dump(subject["@timestamp"]) } == "\"2013-10-19T00:14:32.996Z\""
    end
  end

  describe "source == target" do
    config <<-CONFIG
      filter {
        json {
          source => "example"
          target => "example"
        }
      }
    CONFIG

    sample({ "example" => "{ \"hello\": \"world\" }" }) do
      insist { subject["example"] }.is_a?(Hash)
      insist { subject["example"]["hello"] } == "world"
    end
  end

  describe "parse JSON array into target field" do
    config <<-CONFIG
      filter {
        json {
          # Parse message as JSON, store the results in the 'data' field'
          source => "message"
          target => "data"
        }
      }
    CONFIG

    sample '[ { "k": "v" }, { "l": [1, 2, 3] } ]' do
      insist { subject["data"][0]["k"] } == "v"
      insist { subject["data"][1]["l"].to_a } == [1,2,3] # to_a for JRuby + JrJacksom which creates Java ArrayList
    end
  end

  context "using message field source" do

    subject(:filter) {  LogStash::Filters::Json.new(config)  }

    let(:config) { {"source" => "message"} }
    let(:event) { LogStash::Event.new("message" => message) }

    before(:each) do
      filter.register
      filter.filter(event)
    end

    context "when json could not be parsed" do
      let(:message) { "random_message" }

      it "add the failure tag" do
        expect(event).to include("tags")
      end

      it "uses an array to store the tags" do
        expect(event['tags']).to be_a(Array)
      end

      it "add a json parser failure tag" do
        expect(event['tags']).to include("_jsonparsefailure")
      end

      context "there are two different errors added" do

        let(:event)  { LogStash::Event.new("message" => message, "tags" => ["_anotherkinfoffailure"] ) }

        it "pile the different error messages" do
          expect(event['tags']).to include("_jsonparsefailure")
        end

        it "keep the former error messages on the list" do
          expect(event['tags']).to include("_anotherkinfoffailure")
        end
      end
    end

    context "the JSON is an ArrayList" do
      let(:message) { "[1, 2, 3]" }

      it "adds the failure tag" do
        expect(event['tags']).to include("_jsonparsefailure")
      end
    end

    context "json contains valid timestamp" do
      let(:message) { "{\"foo\":\"bar\", \"@timestamp\":\"2015-12-02T17:40:00.666Z\"}" }

      it "should set json timestamp" do
        expect(event.timestamp).to be_a(LogStash::Timestamp)
        expect(event.timestamp.to_s).to eq("2015-12-02T17:40:00.666Z")
      end
    end

    context "json contains invalid timestamp" do
      let(:message) { "{\"foo\":\"bar\", \"@timestamp\":\"foobar\"}" }

      it "should set timestamp to current time" do
        expect(event.timestamp).to be_a(LogStash::Timestamp)
        expect(event["tags"]).to include(LogStash::Event::TIMESTAMP_FAILURE_TAG)
        expect(event[LogStash::Event::TIMESTAMP_FAILURE_FIELD]).to eq("foobar")
      end
    end
  end

  describe "parse mixture of json an non-json content (fallback mode)" do
    subject(:filter) {  LogStash::Filters::Json.new(config)  }

    let(:config) { {"source" => "message", "remove_field" => ["message"], "fallback_mode" => fallback_mode} }
    let(:event) { LogStash::Event.new("message" => message) }

    before(:each) do
      allow(filter.logger).to receive(:warn)
      filter.register
      filter.filter(event)
    end

    let(:message) { "this is not a json message" }

    context "with fallback_mode off" do
      let(:fallback_mode) { false }

      it "sends a warning to the logger" do
        expect(filter.logger).to have_received(:warn).with("Error parsing json", anything())
      end

      it "keeps the source field" do
        expect(event["message"]).to eq message
      end

      it "adds a parse-error tag" do
        expect(event["tags"]).to eq ["_jsonparsefailure"]
      end
    end

    context "with fallback_mode on" do
      let(:fallback_mode) { true }

      it "sends no warning" do
        expect(filter.logger).to_not have_received(:warn)
      end

      it "keeps the source field" do
        expect(event["message"]).to eq message
      end

      it "does not add a parse-error tag" do
        expect(event["tags"]).to be_nil
      end
    end
  end
end
