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
      insist { subject.get("hello") } == "world"
      insist { subject.get("list" ).to_a } == [1,2,3] # to_a for JRuby + JrJacksom which creates Java ArrayList
      insist { subject.get("hash") } == { "k" => "v" }
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
      insist { subject.get("data")["hello"] } == "world"
      insist { subject.get("data")["list" ].to_a } == [1,2,3] # to_a for JRuby + JrJacksom which creates Java ArrayList
      insist { subject.get("data")["hash"] } == { "k" => "v" }
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
      insist { subject.get("tags") }.include?("_jsonparsefailure")
      insist { subject.get("tags") }.include?("_custom_failure_tag")
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
      insist { subject.get("@timestamp") }.is_a?(LogStash::Timestamp)
      insist { LogStash::Json.dump(subject.get("@timestamp")) } == "\"2013-10-19T00:14:32.996Z\""
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
      insist { subject.get("example") }.is_a?(Hash)
      insist { subject.get("example")["hello"] } == "world"
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
      insist { subject.get("data")[0]["k"] } == "v"
      insist { subject.get("data")[1]["l"].to_a } == [1,2,3] # to_a for JRuby + JrJacksom which creates Java ArrayList
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
        expect(event.get('tags')).to be_a(Array)
      end

      it "add a json parser failure tag" do
        expect(event.get('tags')).to include("_jsonparsefailure")
      end

      context "there are two different errors added" do

        let(:event)  { LogStash::Event.new("message" => message, "tags" => ["_anotherkinfoffailure"] ) }

        it "pile the different error messages" do
          expect(event.get('tags')).to include("_jsonparsefailure")
        end

        it "keep the former error messages on the list" do
          expect(event.get('tags')).to include("_anotherkinfoffailure")
        end
      end
    end

    context "the JSON is an ArrayList" do
      let(:message) { "[1, 2, 3]" }

      it "adds the failure tag" do
        expect(event.get('tags')).to include("_jsonparsefailure")
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
        expect(event.get("tags")).to include(LogStash::Event::TIMESTAMP_FAILURE_TAG)
        expect(event.get(LogStash::Event::TIMESTAMP_FAILURE_FIELD)).to eq("foobar")
      end
    end
  end

  describe "parse mixture of json an non-json content (skip_on_invalid_json)" do
    subject(:filter) {  LogStash::Filters::Json.new(config)  }

    let(:config) { {"source" => "message", "remove_field" => ["message"], "skip_on_invalid_json" => skip_on_invalid_json} }
    let(:event) { LogStash::Event.new("message" => message) }

    before(:each) do
      allow(filter.logger).to receive(:warn)
      filter.register
      filter.filter(event)
    end

    let(:message) { "this is not a json message" }

    context "with `skip_on_invalid_json` set to false" do
      let(:skip_on_invalid_json) { false }

      it "sends a warning to the logger" do
        expect(filter.logger).to have_received(:warn).with("Error parsing json", anything())
      end

      it "keeps the source field" do
        expect(event.get("message")).to eq message
      end

      it "adds a parse-error tag" do
        expect(event.get("tags")).to eq ["_jsonparsefailure"]
      end
    end

    context "with `skip_on_invalid_json` set to true" do
      let(:skip_on_invalid_json) { true }

      it "sends no warning" do
        expect(filter.logger).to_not have_received(:warn)
      end

      it "keeps the source field" do
        expect(event.get("message")).to eq message
      end

      it "does not add a parse-error tag" do
        expect(event.get("tags")).to be_nil
      end
    end
  end
end
