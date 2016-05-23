require 'spec_helper'

describe LogstashAuditor do
  before :all do
    @iut = LogstashAuditor::LogstashAuditor.new
    @invalid_logstash_configuration = { "foo" => "bar"}
    @valid_logstash_configuration = { "host_url" => "http://localhost:8080",
                                      "username" => "auditorusername",
                                      "password" => "auditorpassword",
                                      "timeout"  => 3}
    @logstash_configuration_with_incorrect_port = { "host_url" => "http://localhost:9090",
                                                    "username" => "auditorusername",
                                                    "password" => "auditorpassword",
                                                    "timeout"  => 3}
    @logstash_configuration_with_incorrect_host = { "host_url" => "http://somewhere:8080",
                                                    "username" => "auditorusername",
                                                    "password" => "auditorpassword",
                                                    "timeout"  => 3}
    @logstash_configuration_with_incorrect_user = { "host_url" => "http://localhost:8080",
                                                    "username" => "wrongauditorusername",
                                                    "password" => "auditorpassword",
                                                    "timeout"  => 3}
    @iut.configure(@valid_logstash_configuration)
    @elasticsearch = LogstashAuditor::ElasticSearchTestAPI.new('http://localhost:9200')
  end

  it 'has a version number' do
    expect(LogstashAuditor::VERSION).not_to be nil
  end

  context "when configured by SoarAuditorAPI" do
    it 'should accept a valid configuration' do
      expect(@iut.configuration_is_valid(@valid_logstash_configuration)).to eq(true)
    end

    it 'should reject an invalid configuration' do
      expect(@iut.configuration_is_valid(@invalid_logstash_configuration)).to eq(false)
    end
  end

  context "when asked by SoarAuditorAPI to audit" do
    it "should submit audit to logstash with data received" do
      #Create an unique test identifier that will be used to correlate the submitted test audit
      #with the audit found by elastic search.
      test_identifier = @elasticsearch.create_test_id

      debug_message = "some audit event message"
      @iut.audit("rspec_testing:#{test_identifier}:#{Time.now.utc}:#{debug_message}")

      sleep(4) #Allow the event to be saved in Elastic Search before trying to search for it.

      found_event_message = @elasticsearch.search_for_test_id("rspec_testing:#{test_identifier}")
      expect(found_event_message).to be_truthy #Check if audit test identifier has been found
      expect(found_event_message.include?(debug_message)).to eq(true) #Check if the correct audit message was stored
    end

    it "should raise StandardError if logstash connection fails, given incorrect port" do
      expect {
        @iut.configure(@logstash_configuration_with_incorrect_port)
        @iut.audit("message")
      }.to raise_error(StandardError, 'Failed to create connection')
    end

    it "should raise StandardError if logstash connection fails, given incorrect host" do
      expect {
        @iut.configure(@logstash_configuration_with_incorrect_host)
        @iut.audit("message")
      }.to raise_error(StandardError, 'Failed to create connection')
    end

    it "should raise StandardError if logstash authentication fails" do
      expect {
        @iut.configure(@logstash_configuration_with_incorrect_user)
        @iut.audit("message")
      }.to raise_error(StandardError, "Server rejected post with error code 401")
    end
  end
end
