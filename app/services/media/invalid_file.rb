module Media
  # Raised when an upload does not meet its MediaProfile. `code` is an errors.api.* key.
  class InvalidFile < StandardError
    attr_reader :code, :details

    def initialize(code, details = {})
      @code = code
      @details = details
      super(code)
    end
  end
end
