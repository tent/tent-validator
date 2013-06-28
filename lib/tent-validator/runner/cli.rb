require 'awesome_print'
require 'benchmark'
require 'rack/multipart/parser'

module TentValidator
  module Runner

    class CLI

      TRANSLATE_KEYS = {
        :current_value => :actual
      }.freeze

      def self.run(options = {})
        instance = self.new(options)
        instance.run
      end

      def initialize(options = {})
      end

      def run
        @valid = []
        @invalid = []

        puts "Running Protocol Validations..."

        results = nil
        exec_time = Benchmark.realtime do
          results = Runner.run do |results|
            print_results(results.as_json)
          end
        end

        print "\n"
        validator_complete(results.as_json)

        print "\n"
        if @invalid.any?
          print green("#{@valid.uniq.size} validations passed\t") + red("#{@invalid.uniq.size} failed")
        else
          print green("#{@valid.uniq.size} validations passed\t0 failed")
        end
        if results.num_skipped > 0
          print yellow("\t#{results.num_skipped} skipped")
        else
          print green("\t0 skipped")
        end

        print "\t#{exec_time}s"

        print "\n"
        print "\n"

        exit(1) if @invalid.any?
      end

      def print_results(results, parent_names = [])
        results.each_pair do |name, children|
          next if name == :results
          child_results = children[:results]
          child_results.each do |r|
            id = r.object_id.to_s
            valid = result_valid?(r)
            if valid
              next if @valid.index(id)
              @valid << id
              print green(".")
            else
              next if @invalid.index(id)
              if valid == false
                @invalid << id
                print red("F")
              end
            end
          end
          print_results(children, parent_names + [name])
        end
      end

      def validator_complete(results, parent_names = [])
        parent_names.reject! { |n| n == "" }
        results.each_pair do |name, children|
          next if name == :results
          child_results = children[:results]
          all_valid = child_results.inject(true) { |v, r|
            _valid = result_valid?(r)
            v = false if !_valid
            v
          }
          child_results.each do |r|
            valid = result_valid?(r)
            next if valid && ((ENV['PRINT_ERROR_CONTEXT'] != 'true') || all_valid)

            if valid
              print "\n"
              puts green((parent_names + [name]).join(" "))
              print "\n"
            elsif valid.nil?
              print "\n"
              puts yellow((parent_names + [name]).join(" "))
              print "\n"
            else
              print "\n"
              puts red((parent_names + [name]).join(" "))
              print "\n"
            end

            actual = r.as_json[:actual]
            puts "REQUEST:"
            puts "#{actual[:request_method]} #{actual[:request_url]}"
            puts (actual[:request_headers] || {}).inject([]) { |m, (k,v)| m << "#{k}: #{v}"; m }.join("\n")
            print "\n"
            puts actual[:request_body]
            print "\n"

            if ENV['PRINT_CANONICAL_JSON'] == 'true' && actual[:request_body]
              print "\n"
              puts "Canonical JSON:"
              if (actual[:request_headers] || {})['Content-Type'] =~ /multipart/
                _post_json = (parse_multipart_body(actual[:request_body], actual[:request_headers]) || {}).find do |k,v|
                  v[:type] =~ Regexp.new("\\A#{Regexp.escape(TentD::API::POST_CONTENT_TYPE.split(';').first)}\\b")
                end.last[:tempfile]
                puts TentCanonicalJson.encode(Yajl::Parser.parse(_post_json))
              else
                puts TentCanonicalJson.encode(Yajl::Parser.parse(actual[:request_body]) || {})
              end
              print "\n"
            end

            puts "RESPONSE:"
            puts actual[:response_status]
            puts (actual[:response_headers] || {}).inject([]) { |m, (k,v)| m << "#{k}: #{v}"; m }.join("\n")
            print "\n"
            if String === actual[:response_body]
              puts actual[:response_body]
            else
              puts Yajl::Encoder.encode(actual[:response_body])
            end
            print "\n"

            unless valid.nil?
              puts "DIFF:"
              r.as_json[:expected].each_pair do |key, val|
                next if val[:valid] || val[:diff].empty?

                puts key
                ap val[:diff].map { |i| translate_keys(i.dup) }
              end
            end
          end
          validator_complete(children, parent_names + [name])
        end
      end

      def result_valid?(result)
        valid = result.as_json[:expected].inject(true) { |memo, (k,v)|
          memo = false if v.has_key?(:valid) && v[:valid] == false
          memo = nil if v.has_key?(:valid) && v[:valid].nil? && memo == true
          memo
        }
      end

      def translate_keys(hash)
        TRANSLATE_KEYS.each_pair do |from, to|
          next unless hash.has_key?(from)
          hash[to] = hash[from]
          hash.delete(from)
        end
        hash
      end

      def green(text); color(text, "\e[32m"); end
      def red(text); color(text, "\e[31m"); end
      def yellow(text); color(text, "\e[33m"); end
      def blue(text); color(text, "\e[34m"); end

      def color(text, color_code)
        "#{color_code}#{text}\e[0m"
      end

      def parse_multipart_body(body, headers)
        Rack::Multipart::Parser.new(
          'rack.input' => StringIO.new(body),
          'CONTENT_TYPE' => headers['Content-Type'],
          'CONTENT_LENGTH' => headers['Content-Length']
        ).parse
      end
    end

  end
end
