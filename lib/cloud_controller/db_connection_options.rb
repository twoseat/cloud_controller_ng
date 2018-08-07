module VCAP::CloudController
  class DBConnectionOptionsFactory
    class UnknownSchemeError < StandardError
    end
    class << self

      def build(opts)
        potential_scheme = opts.dig(:database_parts, :adapter)

        if potential_scheme.start_with?('mysql')
          adapter = 'mysql'
          adapter_options = mysql_options(opts)
        elsif potential_scheme.start_with?('postgres')
          adapter = 'postgres'
          adapter_options = mysql_options(opts)
        else
          raise UnknownSchemeError
        end

        {
          sql_mode: [:strict_trans_tables, :strict_all_tables, :no_zero_in_date],
          max_connections: opts[:max_connections],
        }.merge(adapter_options).compact

      end

      private

      def mysql_options(opts)
        {}
      end

      def postgres_options(opts)
        {}
      end
    end
  end
end

# class DBConnectionOptions
#   attr_reader :sql_mode, :max_connections, :pool_timeout, :read_timeout, :connection_validation_timeout,
#               :log_level, :log_db_queries, :after_connect, :sslrootcert, :sslmode, :database_parts
#
#   def initialize(opts={})
#     @sql_mode = [:strict_trans_tables, :strict_all_tables, :no_zero_in_date]
#     @max_connections = opts[:max_connections]
#     @pool_timeout = opts[:pool_timeout]
#     @read_timeout = opts[:read_timeout]
#     @connection_validation_timeout = opts[:connection_validation_timeout]
#     @log_level = opts[:log_level]
#     @log_db_queries = opts[:log_db_queries]
#     @after_connect = after_connect
#     @sslrootcert = opts[:ca_cert_path]
#     @database_parts = opts[:database_parts]
#   end
#
#   def to_hash
#     {
#       sql_mode: @sql_mode,
#       max_connections: @max_connections,
#       pool_timeout: @pool_timeout,
#       read_timeout: @read_timeout,
#       connection_validation_timeout: @connection_validation_timeout,
#       log_level: @log_level,
#       log_db_queries: @log_db_queries,
#       after_connect: @after_connect,
#       sslrootcert: @sslrootcert,
#       database_parts: @database_parts
#     }.compact
#   end
# end
#
# class PostgresDBConnectionOptions < DBConnectionOptions
#   def initialize(opts={})
#     @after_connect = proc do |connection|
#       connection.exec("SET time zone 'UTC'")
#     end
#     @sslmode = opts[:ssl_verify_hostname] ? 'verify-full' : 'verify-ca'
#
#     super
#   end
#
#   def to_hash
#     super.to_hash.merge(
#       {
#         sslmode: @sslmode,
#         after_connect: @after_connect,
#       }
#     ).compact
#   end
# end
#
# class MySQLDBConnectionOptions < DBConnectionOptions
#   attr_reader :charset, :sslca, :sslverify, :sslmode
#
#   def initialize(opts={})
#     @sslca = opts[:ca_cert_path] if opts[:ca_cert_path]
#     @charset = 'utf8'
#
#     @after_connect = proc do |connection|
#       connection.query("SET time_zone = '+0:00'")
#     end
#
#     if opts[:ssl_verify_hostname]
#       @sslmode = :verify_identity
#       # Unclear why this second line is necessary:
#       # https://github.com/brianmario/mysql2/issues/879
#       @sslverify = true
#     else
#       @sslmode = :verify_ca
#     end
#
#     super
#   end
#
#   def to_hash
#     super.to_hash.merge(
#       {
#         sslca: @sslca,
#         charset: @charset,
#         after_connect: @after_connect,
#         sslmode: @sslmode,
#         sslverify: @sslverify,
#       }
#     ).compact
#   end
# end
