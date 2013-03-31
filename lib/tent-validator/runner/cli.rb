require 'awesome_print'
module TentValidator
  module Runner

    class CLI
      def self.run(options = {})
        instance = self.new(options)
        instance.run
      end

      def initialize(options = {})
      end

      def run
        @valid = true
        @valid_count = 0
        @invalid_count = 0

        puts "Running Protocol Validations..."
        results = Runner.run do |results|
          print_results(results.as_json)
        end
        print "\n"
        validator_complete(results.as_json)

        print "\n"
        if @valid
          puts green("#{@valid_count} expectations valid\t0 failed")
        else
          puts green("#{@valid_count} expectations valid\t") + red("#{@invalid_count} failed")
        end
        print "\n"

        exit(1) unless @valid
      end

      def print_results(results, parent_names = [])
        results.each_pair do |name, children|
          next if name == :results
          child_results = children[:results]
          child_results.each do |r|
            valid = result_valid?(r)
            if valid
              @valid_count += 1
              print green(".")
            else
              @valid = false
              @invalid_count += 1
              print red("F")
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
          child_results.each do |r|
            next if result_valid?(r)

            print "\n"
            puts red((parent_names + [name]).join(" "))
            print "\n"

            actual = r.as_json[:actual]
            puts "REQUEST:"
            puts "#{actual[:request_method]} #{actual[:request_url]}"
            puts actual[:request_headers].inject([]) { |m, (k,v)| m << "#{k}: #{v}"; m }.join("\n")
            print "\n"
            puts actual[:request_body]
            print "\n"

            puts "RESPONSE:"
            puts actual[:response_status]
            puts actual[:response_headers].inject([]) { |m, (k,v)| m << "#{k}: #{v}"; m }.join("\n")
            print "\n"
            puts actual[:response_body]
            print "\n"

            puts "FAILED:"
            r.as_json[:expected].each_pair do |key, val|
              next if val[:valid]

              puts key
              ap val[:failed_assertions]
            end

            puts "DIFF:"
            r.as_json[:expected].each_pair do |key, val|
              next if val[:valid]

              puts key
              ap val[:diff]
            end
          end
          validator_complete(children, parent_names + [name])
        end
      end

      def result_valid?(result)
        valid = result.as_json.inject(true) { |memo, (k,v)|
          memo = false unless v[:valid]
          memo
        }
      end

      def green(text); color(text, "\e[32m"); end
      def red(text); color(text, "\e[31m"); end
      def yellow(text); color(text, "\e[33m"); end
      def blue(text); color(text, "\e[34m"); end

      def color(text, color_code)
        "#{color_code}#{text}\e[0m"
      end
    end

  end
end
