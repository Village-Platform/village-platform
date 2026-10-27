module Media
  # The uploader's plan has no free slot left for this kind of media (answered with 403).
  class LimitReached < StandardError; end
end
