module VCAP::CloudController
  class DBConnectionOptionsFactory
    class UnknownSchemeError < StandardError
    end
    class << self

      def build(opts)
        potential_scheme = opts.dig(:database_parts, :adapter)

        if potential_scheme.start_with?('mysql')
          adapter_options = mysql_options(opts)
        elsif potential_scheme.start_with?('postgres')
          adapter_options = postgres_options(opts)
        else
          raise UnknownSchemeError
        end

        adapter_options.merge!(opts[:database_parts])
        adapter_options.merge!(
          connection_validation_timeout: opts[:connection_validation_timeout],
          log_db_queries: opts[:log_db_queries],
          log_level: opts[:log_level],
          max_connections: opts[:max_connections],
          pool_timeout: opts[:pool_timeout],
          read_timeout: opts[:read_timeout],
          sql_mode: [:strict_trans_tables, :strict_all_tables, :no_zero_in_date],
        ).compact
      end

      private

      def mysql_options(opts)
        options = {
          charset: 'utf8'
        }
        options[:sslca] = opts[:ca_cert_path] if opts[:ca_cert_path]

        options[:after_connect] = proc do |connection|
          connection.query("SET time_zone = '+0:00'")
        end

        if opts[:ssl_verify_hostname]
          # Unclear why this second line is necessary:
          # https://github.com/brianmario/mysql2/issues/879
          options[:sslmode] = :verify_identity
          options[:sslverify] = true
        else
          options[:sslmode] = :verify_ca
        end

        options
      end

      def postgres_options(opts)
        options = {}

        if opts[:ca_cert_path]
          options[:sslrootcert] = opts[:ca_cert_path]
          options[:sslmode] =  opts[:ssl_verify_hostname] ? 'verify-full' : 'verify-ca'
        end

        options[:after_connect] = proc do |connection|
          connection.exec("SET time zone 'UTC'")
        end

        options
      end
    end
  end
end
