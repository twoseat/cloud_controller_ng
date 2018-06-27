module CloudController
  class UrlSecretObfuscator
    def self.obfuscate(url)
      return nil if url.nil?

      begin
        parsed_url = URI.parse(url)
      rescue URI::InvalidURIError
        return url
      end

      if parsed_url.user
        parsed_url.user = CloudController::Presenters::Censorship::REDACTED_CREDENTIAL
        parsed_url.password = CloudController::Presenters::Censorship::REDACTED_CREDENTIAL
      end

      parsed_url.to_s
    end
  end
end
