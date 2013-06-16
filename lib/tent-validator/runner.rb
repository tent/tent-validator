require 'api-validator'
require 'awesome_print'
require 'benchmark'

module TentValidator
  module Runner

    ValidatorPlaceholder = Struct.new(:name)

    class Results
      include ApiValidator::Mixins::DeepMerge

      attr_reader :results, :num_skipped
      def initialize
        @results = {}
        @num_skipped = 0
      end

      def merge!(validator_results)
        deep_merge!(results, validator_results.results)
      end

      def skipped(validator)
        if validator.respond_to?(:expectations)
          @num_skipped += validator.expectations.size
        end
        validator.validations.each { |v| skipped(v) }
      end

      def as_json(options = {})
        results
      end
    end

    require 'tent-validator/runner/cli'

    def self.merge_setup_failure(e, results, validator)
      if e.results
        _setup_failure_results = ApiValidator::ResponseExpectation::Results.new(e.response, [e.results])
        results.merge!(ApiValidator::Spec::Results.new(validator, [_setup_failure_results]))
        results.skipped(validator)
      else
        puts %(<#{validator.name} SetupFailure "#{e.message}">:)

        if e.response
          print "\tRESPONSE:\n\t"
          print "status: #{e.response.status}\n\t"
          begin
            if String === e.response.body
              print e.response.body
            else
              print Yajl::Encoder.encode(e.response.body)
            end
          rescue
            print e.response.body
          end
          print "\n\n"
        end

        puts "\t" + e.backtrace.join("\n\t")
      end
    end

    def self.run(&block)
      TentValidator.run_local_server!

      results = Results.new

      begin
        TentValidator.remote_registration

        print "Loading validations..."
        load_time = Benchmark.realtime do
          paths = Dir[File.expand_path(File.join(File.dirname(__FILE__), 'validators', '**', '*_validator.rb'))]
          paths.each { |path| require path }
        end
        print " #{load_time}s\n"

        TentValidator.validators.each do |validator|
          begin
            results.merge!(validator.run)
            block.call(results) if block
          rescue SetupFailure => e
            merge_setup_failure(e, results, validator)
          end
        end
      rescue SetupFailure => e
        merge_setup_failure(e, results, ValidatorPlaceholder.new("Validator Setup"))
      end

      TentValidator.mutex.synchronize do
        if TentValidator.async_local_request_expectations.any?
          timeout = Time.now.to_i + 10
          expectations = []
          ticks = 0
          until TentValidator.async_local_request_expectations.empty?
            TentValidator.async_local_request_expectations.reject! do |expectation|
              _request = TentValidator.local_requests.select { |req|
                _env, _res = req
                _req_path, _req_method, _req_url = _env['PATH_INFO'], _env['REQUEST_METHOD'], parse_url(_env)
                expectation.url_expectations.any? { |e| e.send(:failed_assertions, _req_url).empty? } &&
                expectation.path_expectations.any? { |e| e.send(:failed_assertions, _req_path).empty? } &&
                expectation.method_expectations.any? { |e| e.send(:failed_assertions, _req_method).empty? }
              }.sort_by { |req|
                _env, _res = req
                expectation_results = expectation.validate(expectation.build_request(_env))
                expectation_results += expectation.validate_response(_env, expectation.build_response(_res))
                expectation_results.inject(0) { |m, r|
                  m += 1 if r[:valid]
                  m
                }
              }.last

              if _request
                TentValidator.local_requests.delete(_request)
                expectations << [_request, expectation]

                true # expectation paired to request
              else
                false
              end
            end

            break if Time.now.to_i >= timeout
            if TentValidator.async_local_request_expectations.any?
              if ticks == 0
                print "\n"
                print "Wating for incoming requests... "
              end
              print "#{timeout - Time.now.to_i}."
              ticks += 1
              sleep(1)
            end
          end
          print "\t"

          # Requests found for these expectations
          expectations_results = []
          expectations.each do |i|
            _req, expectation = i
            _env, _res = _req

            expectation_results = expectation.run(_env, _res)
            expectations_results += expectation_results.results

            results.merge!(ApiValidator::Spec::Results.new(expectation.validator, [expectation_results]))
          end

          # No requests found for these expectations
          TentValidator.async_local_request_expectations.each do |expectation|
            results.merge!(ApiValidator::Spec::Results.new(expectation.validator, [expectation.run({}, [])]))
          end

          if TentValidator.async_local_request_expectations.any? || expectations_results.any? { |r| !r[:valid] }
            # print out all unmatched local requests
            TentValidator.local_requests.each do |req|
              _env, _res = req
              validator = ValidatorPlaceholder.new("Request Not Matched")
              expectation = RequestExpectation.new(validator, {})
              results.merge!(
                ApiValidator::Spec::Results.new(validator,
                  [RequestExpectation::Results.new(
                    expectation.build_request(_env),
                    expectation.build_response(_res),
                    [{ :valid => nil, :diff => [], :failed_assertions => [] }]
                )])
              )
            end
          end

          # Reset
          TentValidator.async_local_request_expectations.delete_if { true }

          block.call(results)
        end
      end

      results
    end

    def self.parse_url(env)
      return unless env
      return unless env['REQUEST_PATH']
      url = "#{env['rack.url_scheme']}://#{env['HTTP_HOST']}#{env['REQUEST_PATH']}"
      url << "?#{env['QUERY_STRING']}" unless env['QUERY_STRING'] == ""
      url
    end

  end
end
