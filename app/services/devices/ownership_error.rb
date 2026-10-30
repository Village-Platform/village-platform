module Devices
  # A request tried to change or detach a device it does not own (mapped to 403 in ErrorHandling).
  class OwnershipError < StandardError; end
end
