require 'bson'
require 'logger'
require 'rdf/vocab'
require 'uri'
require_relative '../lib/escape_helpers.rb'
require_relative 'sparql/client.rb'

module SinatraTemplate
  module Utils

    # provide methods also as class methods on the module
    extend self

    def generate_uuid
      BSON::ObjectId.new.to_s
    end

    def graph
      ENV['MU_APPLICATION_GRAPH']
    end

    def log
      if @log.nil?
        log_dir = '/logs'
        Dir.mkdir(log_dir) unless Dir.exist?(log_dir)
        @log = Logger.new("#{log_dir}/application.log")
        @log.level = Kernel.const_get("Logger::#{ENV['LOG_LEVEL'].upcase}")
      end
      @log
    end

    def query(query)
      log.info "Executing query: #{query}"
      sparql_client.query query
    end

    def sparql_client
      options = {}
      if ENV['MU_SPARQL_TIMEOUT']
        options[:read_timeout] = ENV['MU_SPARQL_TIMEOUT'].to_i
      end
      SinatraTemplate::SPARQL::Client.new(ENV['MU_SPARQL_ENDPOINT'], **options)
    end

    def sparql_escape_string(value)
      value ? value.to_s.sparql_escape : value
    end

    def sparql_escape_uri(value)
      value ? URI.parse(value).sparql_escape : value
    end

    def sparql_escape_int(value)
      value ? value.to_i.sparql_escape : value
    end

    def sparql_escape_float(value)
      value ? value.to_f.sparql_escape : value
    end

    def sparql_escape_bool(value)
      value ? true.sparql_escape : false.sparql_escape
    end

    def sparql_escape_date(value)
      value ? Date.parse(value).sparql_escape : value
    end

    def sparql_escape_datetime(value)
      value ? DateTime.parse(value).sparql_escape : value
    end

    def update(query)
      log.info "Executing query: #{query}"
      sparql_client.update query, endpoint: update_endpoint
    end

    def update_endpoint
      # update endpoint is a relative path
      ENV['MU_SPARQL_UPDATE_ENDPOINT'] || RDF::URI.new(ENV['MU_SPARQL_ENDPOINT']).request_uri
    end

    def update_modified(subject, modified = DateTime.now)
      query =  " WITH <#{graph}> "
      query += " DELETE {"
      query += "   <#{subject}> <#{RDF::Vocab::DC.modified}> ?modified ."
      query += " }"
      query += " WHERE {"
      query += "   <#{subject}> <#{RDF::Vocab::DC.modified}> ?modified ."
      query += " }"
      update(query)

      query =  " INSERT DATA {"
      query += "   GRAPH <#{graph}> {"
      query += "     <#{subject}> <#{RDF::Vocab::DC.modified}> #{modified.sparql_escape} ."
      query += "   }"
      query += " }"
      update(query)
    end

    # <b>DEPRECATED:</b> Please use <tt>String.sparql_escape</tt> instead.
    def escape_string_parameter(parameter)
      log.warn "escape_string_parameter is deprecated. Please use String.sparql_escape instead"
      if parameter and parameter.is_a? String
        parameter.gsub(/[\\"']/){|s|'\\'+s}
      end
    end

    def verify_string_parameter(parameter)
      if parameter  and parameter.is_a? String
        raise "unauthorized insert in string parameter" if parameter.downcase.include? "insert"
        raise "unauthorized delete in string parameter" if parameter.downcase.include? "delete"
        raise "unauthorized load in string parameter" if parameter.downcase.include? "load"
        raise "unauthorized clear in string parameter" if parameter.downcase.include? "clear"
        raise "unauthorized create in string parameter" if parameter.downcase.include? "create"
        raise "unauthorized drop in string parameter" if parameter.downcase.include? "drop"
        raise "unauthorized copy in string parameter" if parameter.downcase.include? "copy"
        raise "unauthorized move in string parameter" if parameter.downcase.include? "move"
        raise "unauthorized add in string parameter" if parameter.downcase.include? "add"
      end
    end
  end

end
