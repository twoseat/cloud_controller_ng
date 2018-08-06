module VCAP::CloudController
  class DBConnectionOptions
    attr_reader :sql_mode, :max_connections, :pool_timeout, :read_timeout,
      :log_level, :log_db_queries, :after_connect, :sslrootcert, :sslmode, :database_parts

    def initialize(opts = {})
      @sql_mode = [:strict_trans_tables, :strict_all_tables, :no_zero_in_date]
      @max_connections = opts[:max_connections]
      @pool_timeout = opts[:pool_timeout]
      @read_timeout = opts[:read_timeout]
      @log_level = opts[:log_level]
      @log_db_queries = opts[:log_db_queries]
      @after_connect = after_connect
      @sslrootcert = opts[:ca_cert_path]
      @database_parts = opts[:database_parts]
    end

    def self.database_parts_from_connection(connection_string)
      uri = URI.parse(connection_string)
      {
        adapter: uri.scheme,
        host: uri.host,
        port: uri.port,
        user: uri.user,
        password: uri.password && CGI.unescape(uri.password),
        database: uri.path.sub(%r{^/}, ''),
      }
    end

    def self.connection_from_database_parts(config)
      parts = [config[:adapter], '://']
      if config[:user]
        parts << config[:user]
        if config[:password]
          parts << ':'
          parts << CGI.escape(config[:password])
        end
        parts << '@'
      end
      parts << config[:host]
      if config[:port]
        parts << ':'
        parts << config[:port]
      end
      parts << '/'
      parts << config[:database]
      parts.join('')
    end
  end

  class PostgresDBConnectionOptions < DBConnectionOptions
    def initialize(opts = {})
      @after_connect = proc do |connection|
        connection.exec("SET time zone 'UTC'")
      end
      @sslmode = opts[:ssl_verify_hostname] ? 'verify-full' : 'verify-ca'

      super
    end
  end

  class MySQLDBConnectionOptions < DBConnectionOptions
    attr_reader :charset, :sslca, :sslverify, :sslmode

    def initialize(opts = {})
      @sslca = opts[:ca_cert_path] if opts[:ca_cert_path]
      @charset = 'utf8'

      @after_connect = proc do |connection|
        connection.query("SET time_zone = '+0:00'")
      end

      if opts[:ssl_verify_hostname]
        @sslmode = :verify_identity
        # Unclear why this second line is necessary:
        # https://github.com/brianmario/mysql2/issues/879
        @sslverify = true
      else
        @sslmode = :verify_ca
      end

      super
    end
  end

  class DBConnectionOptionsFactory
    class UnknownSchemeError < StandardError;
    end

    def self.build(opts = {})
      potential_scheme = opts.dig(:database_parts, :adapter)

      if potential_scheme.start_with?('mysql')
        return MySQLDBConnectionOptions.new(opts)
      elsif potential_scheme.start_with?('postgres')
        return PostgresDBConnectionOptions.new(opts)
      else
        raise UnknownSchemeError
      end
    end
  end
end
